#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly ROOT=$(CDPATH= builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && builtin pwd -P)
readonly TEST_DIR="$ROOT/fver/hardware_codec/unit/self_delimiting_packet_path"
readonly CHECKER="$TEST_DIR/check_self_delimiting_packet_path.py"
readonly FIXTURE="$TEST_DIR/fixture_opendvs_self_delimiting_packet_path.sv"
readonly TESTBENCH="$TEST_DIR/tb_opendvs_self_delimiting_packet_path.sv"
readonly FILELIST="$ROOT/fver/hardware_codec/filelists/self_delimiting_packet_path_unit.f"
readonly PRODUCT="$ROOT/source/design/hardware_codec/sync/opendvs_self_delimiting_packet_path.sv"

readonly IVERILOG_BIN=/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/iverilog
readonly IVERILOG_SHA256=6d84be4052a92cf7184c7149506f5db6ac251f99e438a96ae3ce33f326e2ff9d
readonly VVP_BIN=/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/vvp
readonly VVP_SHA256=9f6d770762b5e77d81216e5f21a634028a9ee062a724eeb116980bdb6cb110cc
readonly PYTHON=/usr/bin/python3
readonly TIMEOUT=/usr/bin/timeout
readonly SHA256SUM=/usr/bin/sha256sum
readonly SCRATCH_PARENT=/tmp/opencode/dvs-encoder

readonly CONTRACT_MARKER='@@OPENDVS_SELF_DELIMITING_PACKET_PATH_CONTRACT_PREFLIGHT_PASS@@'
readonly FIXTURE_MARKER='@@OPENDVS_SELF_DELIMITING_PACKET_PATH_FIXTURE_PREFLIGHT_PASS@@'
readonly RED_MARKER='@@OPENDVS_SELF_DELIMITING_PACKET_PATH_RED_CONFIRMED@@ missing_module=opendvs_self_delimiting_packet_path'
readonly PASS_MARKER='@@OPENDVS_SELF_DELIMITING_PACKET_PATH_PASS@@ rtl_literals=6 grammar_literals=7 populations=128 padding_residues=4 abort_prefixes=319 banks=1 max_bytes=40 plants=12'
readonly FAIL_MARKER='@@OPENDVS_SELF_DELIMITING_PACKET_PATH_FAIL@@'
readonly PLANT_MARKER='@@OPENDVS_SELF_DELIMITING_PACKET_PATH_PLANT_DETECTED@@'

readonly -a PLANTS=(
    crc_corrupt lane_swap raw_half_swap pair_order_swap early_fragment_ack
    bank_overwrite retire_on_consume abort_drops_packet abort_loses_pending
    sequence_no_wrap malformed_ack drain_early_quiescent
)

SCRATCH=''

fail() {
    local check=$1
    shift
    printf '%s check=%s message=%s\n' "$FAIL_MARKER" "$check" "$*" >&2
    exit 1
}

hash_file() {
    local line
    line=$($SHA256SUM -- "$1") || return 1
    printf '%s\n' "${line%% *}"
}

print_file() {
    "$PYTHON" -I - "$1" <<'PY' >&2
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
if path.is_file():
    sys.stderr.write(path.read_text(encoding="utf-8", errors="replace"))
PY
}

reject_environment_injection() {
    local name
    for name in BASH_ENV ENV CDPATH IVERILOG VVP IVERILOG_FLAGS VVP_FLAGS \
                VERILOG_SOURCES SYSTEMVERILOG_SOURCES RTL_SOURCES \
                EXTRA_SOURCES SOURCE_FILES EXTRA_VERILOG_FILES \
                GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE LD_PRELOAD LD_LIBRARY_PATH; do
        [[ ! -v $name ]] || fail environment_injection "rejected variable=$name"
    done
}

verify_tools_and_paths() {
    [[ $TEST_DIR == "$ROOT/fver/hardware_codec/unit/self_delimiting_packet_path" ]] ||
        fail fixed_path "runner did not resolve to the frozen package path"
    local path
    for path in "$CHECKER" "$FIXTURE" "$TESTBENCH" "$FILELIST"; do
        [[ -f $path && ! -L $path ]] || fail fixed_path "missing or nonregular path=$path"
    done
    [[ -x $IVERILOG_BIN && ! -L $IVERILOG_BIN ]] || fail iverilog "pinned compiler absent"
    [[ -x $VVP_BIN && ! -L $VVP_BIN ]] || fail vvp "pinned runtime absent"
    [[ -x $PYTHON && -x $TIMEOUT && -x $SHA256SUM ]] ||
        fail host_tools "required host utility absent"
    [[ $(hash_file "$IVERILOG_BIN") == "$IVERILOG_SHA256" ]] ||
        fail iverilog "pinned compiler digest changed"
    [[ $(hash_file "$VVP_BIN") == "$VVP_SHA256" ]] ||
        fail vvp "pinned runtime digest changed"
    [[ -d $SCRATCH_PARENT && ! -L $SCRATCH_PARENT && -w $SCRATCH_PARENT ]] ||
        fail scratch_parent "scratch parent is not a writable regular directory"
}

prepare_scratch() {
    SCRATCH=$(mktemp -d "$SCRATCH_PARENT/self-delimiting-packet-path.XXXXXXXXXX") ||
        fail scratch "could not create unique scratch"
    case $SCRATCH in
        "$SCRATCH_PARENT"/self-delimiting-packet-path.*) ;;
        *) fail scratch "scratch path escaped fixed parent" ;;
    esac
    chmod 700 "$SCRATCH"
}

cleanup() {
    local rc=$?
    trap - EXIT HUP INT TERM
    if [[ -n ${SCRATCH:-} && -d ${SCRATCH:-} ]]; then
        rm -rf -- "$SCRATCH"
    fi
    exit "$rc"
}

run_checker() {
    local log="$SCRATCH/checker.log"
    set +e
    env -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C PYTHONDONTWRITEBYTECODE=1 \
        "$PYTHON" -I "$CHECKER" --preflight >"$log" 2>&1
    local rc=$?
    set -e
    (( rc == 0 )) || { print_file "$log"; fail contract_preflight "checker exited $rc"; }
    "$PYTHON" -I - "$log" "$CONTRACT_MARKER" <<'PY' || {
import pathlib
import sys
lines = pathlib.Path(sys.argv[1]).read_text(errors="replace").splitlines()
if sum(line.startswith(sys.argv[2]) for line in lines) != 1:
    raise SystemExit(1)
PY
        print_file "$log"
        fail contract_preflight "pass marker was missing or repeated"
    }
}

compile_fixture() {
    local image="$SCRATCH/fixture.vvp"
    local log="$SCRATCH/fixture-compile.log"
    set +e
    env -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$TIMEOUT" --signal=TERM --kill-after=5s 90s \
        "$IVERILOG_BIN" -g2012 -Wall -Wimplicit -s tb_opendvs_self_delimiting_packet_path \
        -o "$image" "$FIXTURE" "$TESTBENCH" >"$log" 2>&1
    local rc=$?
    set -e
    (( rc == 0 )) || { print_file "$log"; fail fixture_compile "fixture compilation exited $rc"; }
    [[ -s $image ]] || fail fixture_compile "fixture compiler emitted no image"
}

validate_unplanted_log() {
    "$PYTHON" -I - "$1" "$PASS_MARKER" "$FAIL_MARKER" "$PLANT_MARKER" <<'PY'
import pathlib
import sys
text = pathlib.Path(sys.argv[1]).read_text(errors="replace")
lines = text.splitlines()
passed, failed, planted = sys.argv[2:5]
if lines.count(passed) != 1:
    raise SystemExit(f"PASS marker count={lines.count(passed)}")
if failed in text or planted in text:
    raise SystemExit("unplanted log contains failure or plant marker")
PY
}

run_fixture_suite() {
    compile_fixture
    local image="$SCRATCH/fixture.vvp"
    local log="$SCRATCH/fixture-unplanted.log"
    set +e
    env -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$TIMEOUT" --signal=TERM --kill-after=10s 300s \
        "$VVP_BIN" "$image" >"$log" 2>&1
    local rc=$?
    set -e
    (( rc == 0 )) || { print_file "$log"; fail fixture_run "unplanted fixture exited $rc"; }
    validate_unplanted_log "$log" || {
        print_file "$log"
        fail fixture_run "unplanted marker contract failed"
    }

    local plant plant_log expected
    for plant in "${PLANTS[@]}"; do
        plant_log="$SCRATCH/fixture-plant-$plant.log"
        set +e
        env -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
            "$TIMEOUT" --signal=TERM --kill-after=5s 30s \
            "$VVP_BIN" "$image" "+PLANT=$plant" >"$plant_log" 2>&1
        rc=$?
        set -e
        (( rc == 10 )) || {
            print_file "$plant_log"
            fail "plant_$plant" "fixture plant exited $rc instead of 10"
        }
        expected="$PLANT_MARKER plant=$plant check=$plant"
        "$PYTHON" -I - "$plant_log" "$expected" "$PASS_MARKER" "$FAIL_MARKER" "$PLANT_MARKER" <<'PY' || {
import pathlib
import sys
text = pathlib.Path(sys.argv[1]).read_text(errors="replace")
lines = text.splitlines()
expected, passed, failed, plant_marker = sys.argv[2:6]
if lines.count(expected) != 1:
    raise SystemExit("exact plant marker missing or repeated")
if passed in text or failed in text:
    raise SystemExit("plant emitted ordinary pass/fail marker")
if sum(plant_marker in line for line in lines) != 1:
    raise SystemExit("extra plant marker")
PY
            print_file "$plant_log"
            fail "plant_$plant" "plant marker contract failed"
        }
    done
}

validate_exact_red_log() {
    "$PYTHON" -I - "$1" <<'PY'
import pathlib
import re
import sys
module = "opendvs_self_delimiting_packet_path"
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
lower = text.lower()
for forbidden in (
    "syntax error", "malformed", "unable to bind", "no top level modules",
    "not found", "no such file", "sorry:", "assertion failed",
):
    if forbidden in lower:
        raise SystemExit(f"non-module RED diagnostic: {forbidden}")
unknown = re.findall(r"Unknown module type:\s*([A-Za-z_$][A-Za-z0-9_$]*)", text)
if not unknown or set(unknown) != {module}:
    raise SystemExit(f"unexpected unresolved modules: {sorted(set(unknown))}")
if "These modules were missing:" not in text or module not in text:
    raise SystemExit("missing-module summary absent")
PY
}

run_expect_red() {
    compile_fixture
    local image="$SCRATCH/red.vvp"
    local log="$SCRATCH/red-compile.log"
    set +e
    env -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$TIMEOUT" --signal=TERM --kill-after=5s 90s \
        "$IVERILOG_BIN" -g2012 -Wall -Wimplicit -s tb_opendvs_self_delimiting_packet_path \
        -o "$image" "$TESTBENCH" >"$log" 2>&1
    local rc=$?
    set -e
    (( rc != 0 && rc != 124 && rc != 137 )) ||
        fail expect_red "real closure returned non-RED exit=$rc"
    validate_exact_red_log "$log" || {
        print_file "$log"
        fail expect_red "failure was not only the unresolved product module"
    }
    [[ ! -s $image ]] || fail expect_red "failed RED closure left an executable image"
    printf '%s\n' "$RED_MARKER"
}

run_expect_green() {
    if [[ ! -f $PRODUCT || -L $PRODUCT ]]; then
        printf '%s check=missing_product_module\n' "$FAIL_MARKER" >&2
        exit 1
    fi
    local image="$SCRATCH/product.vvp"
    local compile_log="$SCRATCH/green-compile.log"
    local run_log="$SCRATCH/green-unplanted.log"
    set +e
    env -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$TIMEOUT" --signal=TERM --kill-after=5s 90s \
        "$IVERILOG_BIN" -g2012 -Wall -Wimplicit -s tb_opendvs_self_delimiting_packet_path \
        -o "$image" -f "$FILELIST" "$TESTBENCH" >"$compile_log" 2>&1
    local rc=$?
    set -e
    (( rc == 0 )) || { print_file "$compile_log"; fail green_compile "product compilation exited $rc"; }
    set +e
    env -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$TIMEOUT" --signal=TERM --kill-after=10s 300s \
        "$VVP_BIN" "$image" >"$run_log" 2>&1
    rc=$?
    set -e
    (( rc == 0 )) || { print_file "$run_log"; fail green_run "product simulation exited $rc"; }
    validate_unplanted_log "$run_log" || {
        print_file "$run_log"
        fail green_run "product marker contract failed"
    }
    printf '%s\n' "$PASS_MARKER"
}

usage() {
    printf 'usage: %s --fixture-preflight|--expect-red|--expect-green\n' "$0" >&2
    exit 2
}

main() {
    [[ $# -eq 1 ]] || usage
    case $1 in
        --fixture-preflight|--expect-red|--expect-green) ;;
        *) usage ;;
    esac
    export LC_ALL=C
    export PYTHONDONTWRITEBYTECODE=1
    umask 077
    reject_environment_injection
    verify_tools_and_paths
    prepare_scratch
    trap cleanup EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    builtin cd -- "$ROOT"
    run_checker
    case $1 in
        --fixture-preflight)
            run_fixture_suite
            printf '%s plants=12 unplanted=1\n' "$FIXTURE_MARKER"
            ;;
        --expect-red) run_expect_red ;;
        --expect-green) run_expect_green ;;
    esac
}

main "$@"
