#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly ROOT=$(CDPATH= builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && builtin pwd -P)
readonly TEST_DIR="$ROOT/fver/hardware_codec/integration/sync_product_preframing_v2"
readonly CHECKER="$TEST_DIR/check_sync_product_preframing_v2.py"
readonly PRODUCT_LIST="$TEST_DIR/product_sources_v2.f"
readonly PRODUCT_TESTBENCH="$TEST_DIR/tb_sync_product_preframing_v2.sv"
readonly RESET_TESTBENCH="$TEST_DIR/tb_current_product_reset_binding_v2.sv"
readonly CURRENT_SEAL="$TEST_DIR/current-product-source-v2.sha256"
readonly XRUN=/opt/cadence/ius-21.09.006/lnx86/tools.lnx86/inca/bin/64bit/xrun
readonly XRUN_SHA256=c2fd01c847845bd35cd20cce428464934a7c42a65666dfc4929e81607989a8a9
readonly XRUN_VERSION=21.09-s006
readonly PYTHON=/usr/bin/python3
readonly SHA256SUM=/usr/bin/sha256sum
readonly TIMEOUT=/usr/bin/timeout
readonly SCRATCH_PARENT=/tmp/opencode/dvs-encoder
readonly LICENSE_VARIABLE=LM_LICENSE_FILE
readonly LICENSE_VALUE=8152@lic-cadence-e.ethz.ch
readonly ELABORATION_TIMEOUT_SECONDS=240
readonly RUN_TIMEOUT_SECONDS=180
readonly PASS_MARKER='@@SYNC_PRODUCT_PREFRAMING_V2_RESET_PASS@@ checks=11 reset_equations=4'
readonly FAIL_TOKEN='@@SYNC_PRODUCT_PREFRAMING_V2_RESET_FAIL@@'

SCRATCH=''

fail() {
    printf '@@SYNC_PRODUCT_PREFRAMING_V2_RESET_RUNNER_FAIL@@ message=%s\n' "$*" >&2
    exit 2
}

hash_file() {
    local line
    line=$($SHA256SUM -- "$1") || return 1
    printf '%s\n' "${line%% *}"
}

print_file() {
    [[ -f $1 ]] || return 0
    "$PYTHON" -I - "$1" <<'PY'
import pathlib
import sys
print(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace"), end="")
PY
}

count_exact_line() {
    "$PYTHON" -I - "$1" "$2" <<'PY'
import pathlib
import sys
lines = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace").splitlines()
print(lines.count(sys.argv[2]))
PY
}

count_token() {
    "$PYTHON" -I - "$1" "$2" <<'PY'
import pathlib
import sys
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
print(text.count(sys.argv[2]))
PY
}

cleanup() {
    local rc=$?
    trap - EXIT HUP INT TERM
    if [[ -n ${SCRATCH:-} && -d ${SCRATCH:-} ]]; then
        if (( rc == 0 )); then
            rm -rf -- "$SCRATCH"
        else
            printf '@@SYNC_PRODUCT_PREFRAMING_V2_RESET_SCRATCH_PRESERVED@@ path=%s\n' "$SCRATCH" >&2
        fi
    fi
    exit "$rc"
}

reject_environment_injection() {
    local name
    for name in BASH_ENV ENV CDPATH XRUN_FLAGS VERILOG_SOURCES \
                SYSTEMVERILOG_SOURCES RTL_SOURCES LD_PRELOAD LD_LIBRARY_PATH; do
        [[ ! -v $name ]] || fail "environment_injection_rejected:$name"
    done
}

run_clean() {
    local timeout_seconds=$1 stdout=$2 stderr=$3
    shift 3
    set +e
    env -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$LICENSE_VARIABLE=$LICENSE_VALUE" \
        "$TIMEOUT" --signal=TERM --kill-after=10s "${timeout_seconds}s" \
        "$@" >"$stdout" 2>"$stderr"
    local rc=$?
    set -e
    (( rc == 0 )) || {
        print_file "$stdout" >&2
        print_file "$stderr" >&2
        print_file "$SCRATCH/xrun.log" >&2
        (( rc != 124 && rc != 137 )) || fail "Xcelium_stage_timed_out_exit_$rc"
        fail "Xcelium_stage_failed_exit_$rc"
    }
}

main() {
    [[ $# -eq 0 ]] || fail "usage:$0"
    export LC_ALL=C
    umask 077
    reject_environment_injection
    [[ $TEST_DIR == "$ROOT/fver/hardware_codec/integration/sync_product_preframing_v2" ]] ||
        fail "runner_is_not_at_fixed_v2_path"
    local path
    for path in "$CHECKER" "$PRODUCT_LIST" "$PRODUCT_TESTBENCH" \
                "$RESET_TESTBENCH" "$CURRENT_SEAL"; do
        [[ -f $path && ! -L $path ]] || fail "missing_nonregular_or_symlink:$path"
    done
    [[ -x $XRUN && ! -L $XRUN ]] || fail "exact_xrun_executable_absent"
    [[ $(hash_file "$XRUN") == "$XRUN_SHA256" ]] || fail "xrun_hash_mismatch"
    [[ -d $SCRATCH_PARENT && ! -L $SCRATCH_PARENT && -w $SCRATCH_PARENT ]] ||
        fail "scratch_parent_is_not_writable"
    SCRATCH=$(mktemp -d "$SCRATCH_PARENT/current-product-reset-v2.XXXXXXXXXX") ||
        fail "could_not_create_scratch"
    case $SCRATCH in
        "$SCRATCH_PARENT"/current-product-reset-v2.*) ;;
        *) fail "scratch_path_escaped_fixed_parent" ;;
    esac
    chmod 700 "$SCRATCH"
    trap cleanup EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    builtin cd -- "$ROOT"

    "$PYTHON" -I "$CHECKER" verify-v1-archive
    "$PYTHON" -I "$CHECKER" verify-test-seal
    "$PYTHON" -I "$CHECKER" verify-current-product-seal
    "$PYTHON" -I "$CHECKER" verify-reset-structure
    local seal_before
    seal_before=$(hash_file "$CURRENT_SEAL")

    run_clean 30 "$SCRATCH/version.stdout.log" "$SCRATCH/version.stderr.log" \
        "$XRUN" -version
    "$PYTHON" -I - "$SCRATCH/version.stdout.log" "$XRUN_VERSION" <<'PY'
import pathlib
import sys
expected = f"TOOL: xrun(64) {sys.argv[2]}"
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
if not any(" ".join(line.split()) == expected for line in text.splitlines()):
    raise SystemExit("unexpected Xcelium version")
PY

    local reset_list="$SCRATCH/current-product-reset-sources.f"
    "$PYTHON" -I - "$PRODUCT_LIST" "$reset_list" "$PRODUCT_TESTBENCH" \
        "$RESET_TESTBENCH" <<'PY'
import pathlib
import sys
source, destination, product_tb, reset_tb = map(pathlib.Path, sys.argv[1:])
root = pathlib.Path.cwd()
lines = [line for line in source.read_text(encoding="utf-8").splitlines() if line.strip()]
product = str(product_tb.relative_to(root))
if lines.count(product) != 1:
    raise SystemExit("product testbench is not unique in product_sources_v2.f")
lines.remove(product)
lines.append(str(reset_tb.relative_to(root)))
destination.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
PY

    local library="$SCRATCH/xcelium.d"
    local snapshot=sync_pf_v2_current_reset
    run_clean "$ELABORATION_TIMEOUT_SECONDS" "$SCRATCH/elaborate.stdout.log" \
        "$SCRATCH/elaborate.stderr.log" \
        "$XRUN" -64bit -sysv_ext .sv -timescale 1ns/1ps \
        -top tb_current_product_reset_binding_v2 -elaborate -snapshot "$snapshot" \
        -xmlibdirname "$library" -l "$SCRATCH/xrun.log" -f "$reset_list"
    run_clean "$RUN_TIMEOUT_SECONDS" "$SCRATCH/run.stdout.log" \
        "$SCRATCH/run.stderr.log" \
        "$XRUN" -64bit -R -snapshot "$snapshot" -xmlibdirname "$library" \
        -l "$SCRATCH/reset-run.log"

    [[ $(count_exact_line "$SCRATCH/reset-run.log" "$PASS_MARKER") == 1 ]] || {
        print_file "$SCRATCH/reset-run.log" >&2
        fail "exact_reset_pass_marker_absent"
    }
    [[ $(count_token "$SCRATCH/reset-run.log" "$FAIL_TOKEN") == 0 ]] ||
        fail "reset_run_contains_failure_marker"
    [[ $(hash_file "$CURRENT_SEAL") == "$seal_before" ]] ||
        fail "current_product_source_seal_changed_during_reset_gate"
    "$PYTHON" -I "$CHECKER" verify-current-product-seal >/dev/null
    printf '%s\n' "$PASS_MARKER"
}

main "$@"
