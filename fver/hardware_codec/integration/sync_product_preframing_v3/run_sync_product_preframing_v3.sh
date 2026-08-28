#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly ROOT=$(CDPATH= builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && builtin pwd -P)
readonly TEST_DIR="$ROOT/fver/hardware_codec/integration/sync_product_preframing_v3"
readonly CHECKER="$TEST_DIR/check_sync_product_preframing_v3.py"
readonly DERIVER="$TEST_DIR/derive_sync_product_preframing_v3.py"
readonly FIXTURE_BASE="$TEST_DIR/fixture_sources_v3.f"
readonly PRODUCT_BASE="$TEST_DIR/product_sources_v3.f"
readonly V2_RESET_RUNNER="$ROOT/fver/hardware_codec/integration/sync_product_preframing_v2/run_current_product_reset_binding_v2.sh"
readonly CORE_RUNNER="$ROOT/fver/hardware_codec/unit/sync_product_core/run_sync_product_core_xcelium_v3.sh"
readonly PRODUCT_CHECKER="$ROOT/fver/hardware_codec/integration/sync_mode_ownership/check_product_filelists.py"
readonly V2_PRODUCT_SEAL="$ROOT/fver/hardware_codec/integration/sync_product_preframing_v2/current-product-source-v2.sha256"
readonly V3_PRODUCT_SEAL="$TEST_DIR/current-product-source-v3.sha256"

readonly CORE_LEAF="$ROOT/source/design/hardware_codec/sync/enc128_v2_vendored.sv"
readonly CORE_RTL="$ROOT/source/design/hardware_codec/sync/opendvs_sync_product_encoder_core.sv"
readonly CORE_TESTBENCH="$ROOT/fver/hardware_codec/unit/sync_product_core/tb_opendvs_sync_product_encoder_core.sv"

readonly XRUN=/opt/cadence/ius-21.09.006/lnx86/tools.lnx86/inca/bin/64bit/xrun
readonly XRUN_SHA256=c2fd01c847845bd35cd20cce428464934a7c42a65666dfc4929e81607989a8a9
readonly XRUN_VERSION=21.09-s006
readonly TIMEOUT=/usr/bin/timeout
readonly SHA256SUM=/usr/bin/sha256sum
readonly PYTHON=/usr/bin/python3
readonly GIT=/usr/bin/git
readonly BASH=/usr/bin/bash
readonly SCRATCH_PARENT=/tmp/opencode/dvs-encoder
readonly LICENSE_VARIABLE=LM_LICENSE_FILE
readonly LICENSE_VALUE=8152@lic-cadence-e.ethz.ch
readonly ELABORATION_TIMEOUT_SECONDS=240
readonly RUN_TIMEOUT_SECONDS=600
readonly REGRESSION_TIMEOUT_SECONDS=1800
readonly LICENSE_ATTEMPTS=3
readonly LICENSE_RETRY_DELAY_SECONDS=5

readonly PASS_MARKER='@@SYNC_PRODUCT_PREFRAMING_ACCEPTANCE_PASS@@ mapping_tiers=2 independent_pulses=2 prefull_observations=1 legacy_full_suppression=1 reset_release_cycles=2 core_instances=1 enc128_leaves=2 default_off=1 cycle13_consume=1 cycle15_completion=1 abort_completions=0 packet_length_assumptions=0'
readonly FAIL_TOKEN='@@SYNC_PRODUCT_PREFRAMING_FAIL@@'
readonly CORE_PASS_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_PASS@@ mapping_cases=3096 tiers=2 sparse_boundary=15 raw_boundary=16 queue_depth_test=4'
readonly CORE_PLANT_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_PLANT_DETECTED@@'
readonly PREFLIGHT_MARKER='@@SYNC_PRODUCT_PREFRAMING_V3_PREFLIGHT_PASS@@ fixture_elaborated=1 behavior_claim=0 xcelium=21.09-s006 contracts=3 seals=4 rtl_hashes=4 evidence_programs=37'
readonly SELF_TEST_MARKER='@@SYNC_PRODUCT_PREFRAMING_V3_SELF_TEST_PASS@@ semantic_plants=10 strengthened_plants=2 structural_controls=9 adversarial_controls=12'
readonly GREEN_MARKER='@@SYNC_PRODUCT_PREFRAMING_V3_GREEN_PASS@@ manifests=3 core_instances=1 enc128_leaves=2 reset_synchronizers=1 source_tiers=2 completion_ports=1 ownership_shell_instances=1 forbidden_sources=0 semantic_plants=10 core_plants=9 structural_controls=9'
readonly BLOCKED_TOKEN='@@SYNC_PRODUCT_PREFRAMING_V3_XCELIUM_BLOCKED@@'
readonly DERIVED_TESTBENCH_SHA256=d19854f4e38eada4b7edf2ec137f56159ce97610ec05f22ce720a8169e4f633c
readonly CORE_COMPAT_SHA256=eaefb783b2408058c193ef3434a5877487e22600fd4c3e92da38170b79f9e38b

readonly -a PLANTS=(
    early_reset_release
    enable_product_admission
    fragment_ready_high
    sync_visibility_high
    swap_record_halves
    couple_tier_valid
    gate_source_with_full
    completion_at_consume
    suppress_cycle15_completion
    completion_on_abort
)
readonly -a PLANT_CHECKS=(
    synchronized-reset-first-release-edge
    product-admission-disabled
    top-fragment-ready-low
    synchronous-availability-low
    top-record-mapping
    top-pulse-independent-bottom-valid
    full-source-valid-before-suppression
    cycle13-is-consume-only
    cycle15-completion
    abort-has-no-completion
)
readonly -a CORE_PLANTS=(
    half_order_swap
    ascending_sparse_positions
    launch_population_16
    nonzero_delta_time
    raw_byte_reversal
    retained_fragment_overwrite
    duplicate_retirement
    lost_retirement
    overflow_without_sticky_fault
)

SCRATCH=''
DERIVED_TESTBENCH=''
FIXTURE_LIST=''
PRODUCT_LIST=''
CORE_COMPAT=''
CORE_EVIDENCE_DIR=''

fail() {
    printf '@@SYNC_PRODUCT_PREFRAMING_V3_RUNNER_FAIL@@ message=%s\n' "$*" >&2
    exit 2
}

blocked() {
    printf '%s message=%s\n' "$BLOCKED_TOKEN" "$*" >&2
    exit 4
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

record_command() {
    local destination=$1
    shift
    printf '%q ' "$@" >"$destination"
    printf '\n' >>"$destination"
}

reject_environment_injection() {
    local name
    local -a names=(
        BASH_ENV ENV CDPATH
        XRUN_FLAGS VERILOG_SOURCES SYSTEMVERILOG_SOURCES RTL_SOURCES
        GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
        LD_PRELOAD LD_LIBRARY_PATH
    )
    for name in "${names[@]}"; do
        [[ ! -v $name ]] || fail "environment_injection_rejected:$name"
    done
}

prepare_scratch() {
    [[ -d $SCRATCH_PARENT && ! -L $SCRATCH_PARENT && -w $SCRATCH_PARENT ]] ||
        fail "scratch_parent_is_not_a_writable_regular_directory"
    SCRATCH=$(mktemp -d "$SCRATCH_PARENT/sync-product-preframing-v3.XXXXXXXXXX") ||
        fail "could_not_create_scratch"
    case $SCRATCH in
        "$SCRATCH_PARENT"/sync-product-preframing-v3.*) ;;
        *) fail "scratch_path_escaped_fixed_parent" ;;
    esac
    chmod 700 "$SCRATCH"
}

cleanup() {
    local rc=$?
    trap - EXIT HUP INT TERM
    if [[ -n ${SCRATCH:-} && -d ${SCRATCH:-} ]]; then
        if (( rc == 0 )); then
            rm -rf -- "$SCRATCH"
        else
            printf '@@SYNC_PRODUCT_PREFRAMING_V3_SCRATCH_PRESERVED@@ path=%s\n' "$SCRATCH" >&2
        fi
    fi
    exit "$rc"
}

verify_fixed_paths() {
    [[ $TEST_DIR == "$ROOT/fver/hardware_codec/integration/sync_product_preframing_v3" ]] ||
        fail "runner_is_not_at_the_fixed_v3_path"
    local path
    for path in "$CHECKER" "$DERIVER" "$FIXTURE_BASE" "$PRODUCT_BASE" \
                "$V2_RESET_RUNNER" "$CORE_RUNNER" "$PRODUCT_CHECKER" \
                "$V2_PRODUCT_SEAL" "$V3_PRODUCT_SEAL" "$CORE_LEAF" \
                "$CORE_RTL" "$CORE_TESTBENCH"; do
        [[ -f $path && ! -L $path ]] || fail "missing_nonregular_or_symlink:$path"
    done
    [[ -x $TIMEOUT && -x $SHA256SUM && -x $PYTHON && -x $GIT && -x $BASH ]] ||
        fail "required_host_tool_is_absent"
}

run_checker() {
    "$PYTHON" -I "$CHECKER" "$@"
}

xcelium_license_failure() {
    "$PYTHON" -I - "$@" <<'PY'
import pathlib
import re
import sys
pattern = re.compile(
    r"NOLIC|license[^\n]*(?:fail|denied|unavailable|checkout)|"
    r"FlexNet[^\n]*(?:fail|denied)",
    re.IGNORECASE,
)
for name in sys.argv[1:]:
    path = pathlib.Path(name)
    if path.is_file() and pattern.search(path.read_text(errors="replace")):
        raise SystemExit(0)
raise SystemExit(1)
PY
}

select_xcelium() {
    [[ -x $XRUN && ! -L $XRUN ]] || blocked "exact_xrun_executable_absent"
    [[ $(hash_file "$XRUN") == "$XRUN_SHA256" ]] || fail "xrun_executable_hash_mismatch"
    local stdout="$SCRATCH/xrun-version.stdout.log"
    local stderr="$SCRATCH/xrun-version.stderr.log"
    set +e
    env -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$LICENSE_VARIABLE=$LICENSE_VALUE" PYTHONDONTWRITEBYTECODE=1 \
        "$TIMEOUT" --signal=TERM --kill-after=5s 30s \
        "$XRUN" -version >"$stdout" 2>"$stderr"
    local rc=$?
    set -e
    (( rc == 0 )) || blocked "xrun_version_probe_failed_exit_$rc"
    "$PYTHON" -I - "$stdout" "$XRUN_VERSION" <<'PY'
import pathlib
import sys
text = pathlib.Path(sys.argv[1]).read_text(errors="replace")
expected = f"TOOL: xrun(64) {sys.argv[2]}"
if not any(" ".join(line.split()) == expected for line in text.splitlines()):
    raise SystemExit("unexpected Xcelium version output")
PY
    printf '@@SYNC_PRODUCT_PREFRAMING_V3_XCELIUM_IDENTITY@@ version=%s sha256=%s\n' \
        "$XRUN_VERSION" "$XRUN_SHA256"
}

run_xcelium() {
    local stage=$1 expectation=$2 timeout_seconds=$3 workdir=$4
    shift 4
    local stage_dir="$SCRATCH/$stage"
    mkdir -p "$stage_dir"
    local attempt rc
    for ((attempt = 1; attempt <= LICENSE_ATTEMPTS; attempt += 1)); do
        local stdout="$stage_dir/attempt-$attempt.stdout.log"
        local stderr="$stage_dir/attempt-$attempt.stderr.log"
        record_command "$stage_dir/attempt-$attempt.command.txt" "$@"
        set +e
        (
            builtin cd -- "$workdir"
            env -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$stage_dir" \
                "$LICENSE_VARIABLE=$LICENSE_VALUE" PYTHONDONTWRITEBYTECODE=1 \
                "$TIMEOUT" --signal=TERM --kill-after=10s "${timeout_seconds}s" \
                "$@" >"$stdout" 2>"$stderr"
        )
        rc=$?
        set -e
        printf '%d\n' "$rc" >"$stage_dir/attempt-$attempt.exit.txt"
        if (( rc == 0 )); then
            [[ $expectation == zero ]] || fail "${stage}_expected_nonzero_but_passed"
            printf '%d\n' "$attempt" >"$stage_dir/successful-attempt.txt"
            printf '%s\n' "$stage_dir"
            return 0
        fi
        if xcelium_license_failure "$stdout" "$stderr" "$stage_dir/xrun.log"; then
            if (( attempt < LICENSE_ATTEMPTS )); then
                sleep "$LICENSE_RETRY_DELAY_SECONDS"
                continue
            fi
            blocked "${stage}_license_unavailable_after_${LICENSE_ATTEMPTS}_attempts"
        fi
        (( rc != 124 && rc != 137 )) || fail "${stage}_timed_out_exit_$rc"
        if [[ $expectation == nonzero ]]; then
            printf '%d\n' "$attempt" >"$stage_dir/successful-attempt.txt"
            printf '%s\n' "$stage_dir"
            return 0
        fi
        print_file "$stdout" >&2
        print_file "$stderr" >&2
        print_file "$stage_dir/xrun.log" >&2
        fail "${stage}_failed_exit_$rc"
    done
    fail "${stage}_internal_retry_exhaustion"
}

derive_runtime_sources() {
    DERIVED_TESTBENCH="$SCRATCH/tb_sync_product_preframing_v3.sv"
    "$PYTHON" -I "$DERIVER" "$DERIVED_TESTBENCH" >/dev/null
    [[ $(hash_file "$DERIVED_TESTBENCH") == "$DERIVED_TESTBENCH_SHA256" ]] ||
        fail "derived_testbench_hash_mismatch"
    run_checker verify-derived-testbench "$DERIVED_TESTBENCH" >/dev/null
    FIXTURE_LIST="$SCRATCH/fixture_sources_v3.runtime.f"
    PRODUCT_LIST="$SCRATCH/product_sources_v3.runtime.f"
    "$PYTHON" -I - "$FIXTURE_BASE" "$PRODUCT_BASE" "$DERIVED_TESTBENCH" \
        "$FIXTURE_LIST" "$PRODUCT_LIST" <<'PY'
import pathlib
import sys
fixture, product, bench, fixture_out, product_out = map(pathlib.Path, sys.argv[1:])
root = pathlib.Path.cwd()
bench_entry = str(bench)
for source, destination in ((fixture, fixture_out), (product, product_out)):
    lines = [line for line in source.read_text(encoding="utf-8").splitlines() if line.strip()]
    lines.append(bench_entry)
    destination.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
PY
}

elaborate_integration() {
    local name=$1 filelist=$2 snapshot=$3
    local library="$SCRATCH/$name-library"
    local log="$SCRATCH/$name/xrun.log"
    run_xcelium "$name" zero "$ELABORATION_TIMEOUT_SECONDS" "$ROOT" \
        "$XRUN" -64bit -sysv_ext .sv -timescale 1ns/1ps \
        -top tb_sync_product_preframing_v3 -elaborate -snapshot "$snapshot" \
        -xmlibdirname "$library" -l "$log" -f "$filelist" >/dev/null
    printf '%s\t%s\t%s\n' "$snapshot" "$library" "$SCRATCH/$name"
}

validate_green_log() {
    local log=$1
    [[ $(count_exact_line "$log" "$PASS_MARKER") == 1 ]] || {
        print_file "$log" >&2
        fail "unplanted_acceptance_marker_count"
    }
    [[ $(count_token "$log" "$FAIL_TOKEN") == 0 ]] ||
        fail "unplanted_log_contains_failure"
}

validate_plant_log() {
    local log=$1 plant=$2 check_name=$3
    local marker="@@SYNC_PRODUCT_PREFRAMING_FAIL@@ plant=$plant check=$check_name"
    [[ $(count_exact_line "$log" "$marker") == 1 ]] || {
        print_file "$log" >&2
        fail "plant_${plant}_did_not_reach_exact_check_$check_name"
    }
    [[ $(count_token "$log" "$FAIL_TOKEN") == 1 ]] ||
        fail "plant_${plant}_failure_marker_count"
    [[ $(count_token "$log" '@@SYNC_PRODUCT_PREFRAMING_ACCEPTANCE_PASS@@') == 0 ]] ||
        fail "plant_${plant}_reached_acceptance"
    local sensitivity=force_or_observation_mutation
    [[ $plant != early_reset_release ]] || sensitivity=forced_product_core_reset_observation
    [[ $plant != couple_tier_valid ]] || sensitivity=forced_tier_valid_coupling
    printf '@@SYNC_PRODUCT_PREFRAMING_V3_PLANT_DETECTED@@ plant=%s check=%s sensitivity=%s exit=nonzero log_sha256=%s\n' \
        "$plant" "$check_name" "$sensitivity" "$(hash_file "$log")"
}

run_snapshot_suite() {
    local suite=$1 snapshot=$2 library=$3
    local log="$SCRATCH/$suite-unplanted/xrun.log"
    run_xcelium "$suite-unplanted" zero "$RUN_TIMEOUT_SECONDS" "$ROOT" \
        "$XRUN" -64bit -R -snapshot "$snapshot" -xmlibdirname "$library" \
        -l "$log" >/dev/null
    validate_green_log "$log"

    local index plant check_name
    for ((index = 0; index < ${#PLANTS[@]}; index += 1)); do
        plant=${PLANTS[$index]}
        check_name=${PLANT_CHECKS[$index]}
        log="$SCRATCH/$suite-plant-$plant/xrun.log"
        run_xcelium "$suite-plant-$plant" nonzero "$RUN_TIMEOUT_SECONDS" "$ROOT" \
            "$XRUN" -64bit -R -snapshot "$snapshot" -xmlibdirname "$library" \
            -l "$log" "+PLANT=$plant" >/dev/null
        validate_plant_log "$log" "$plant" "$check_name"
    done
}

run_fixture_preflight() {
    local identity snapshot library stage_dir
    identity=$(elaborate_integration fixture-elaboration "$FIXTURE_LIST" sync_pf_v3_fixture)
    IFS=$'\t' read -r snapshot library stage_dir <<<"$identity"
    "$PYTHON" -I - "$stage_dir/xrun.log" <<'PY'
import pathlib
import sys
text = pathlib.Path(sys.argv[1]).read_text(errors="replace")
for module in (
    "tb_sync_product_preframing_v3",
    "final_top3",
    "opendvs_sync_product_encoder_core",
    "enc128",
    "rst_sync",
    "opendvs_sync_mode_ownership_shell",
):
    if f"module worklib.{module}:sv" not in text:
        raise SystemExit(f"fixture elaboration lacks module evidence: {module}")
for marker in (
    "@@SYNC_PRODUCT_PREFRAMING_ACCEPTANCE_PASS@@",
    "@@SYNC_PRODUCT_PREFRAMING_FAIL@@",
):
    if marker in text:
        raise SystemExit("fixture preflight emitted a behavior marker")
PY
    printf '%s\t%s\n' "$snapshot" "$library"
}

run_manifest_elaboration() {
    local name=$1 workdir=$2 filelist=$3 top=$4
    local snapshot_name=${name//-/_}
    local library="$SCRATCH/manifest-$name-library"
    local log="$SCRATCH/manifest-$name/xrun.log"
    run_xcelium "manifest-$name" zero "$ELABORATION_TIMEOUT_SECONDS" "$workdir" \
        "$XRUN" -64bit -sysv_ext .sv -timescale 1ns/1ps \
        -top "$top" -elaborate -snapshot "manifest_$snapshot_name" \
        -xmlibdirname "$library" -l "$log" -f "$filelist" >/dev/null
    printf '@@SYNC_PRODUCT_PREFRAMING_V3_MANIFEST_ELABORATED@@ name=%s top=%s\n' \
        "$name" "$top"
}

run_existing_testbench_xcelium() {
    local name=$1 top=$2 testbench=$3 marker=$4 plusarg=${5:-}
    local snapshot_name=${name//-/_}
    local source_list="$SCRATCH/$name-sources.f"
    "$PYTHON" -I - "$PRODUCT_BASE" "$source_list" "$testbench" <<'PY'
import pathlib
import sys
source, destination, regression_tb = map(pathlib.Path, sys.argv[1:])
lines = [line for line in source.read_text(encoding="utf-8").splitlines() if line.strip()]
lines.append(str(regression_tb.relative_to(pathlib.Path.cwd())))
destination.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
PY
    local library="$SCRATCH/$name-library"
    local elab_log="$SCRATCH/$name-elaboration/xrun.log"
    run_xcelium "$name-elaboration" zero "$ELABORATION_TIMEOUT_SECONDS" "$ROOT" \
        "$XRUN" -64bit -sysv_ext .sv -timescale 1ns/1ps \
        -top "$top" -elaborate -snapshot "$snapshot_name" \
        -xmlibdirname "$library" -l "$elab_log" -f "$source_list" >/dev/null
    local run_log="$SCRATCH/$name-run/xrun.log"
    local -a command=(
        "$XRUN" -64bit -R -snapshot "$snapshot_name" -xmlibdirname "$library" -l "$run_log"
    )
    [[ -z $plusarg ]] || command+=("$plusarg")
    run_xcelium "$name-run" zero "$RUN_TIMEOUT_SECONDS" "$ROOT" \
        "${command[@]}" >/dev/null
    [[ $(count_exact_line "$run_log" "$marker") == 1 ]] || {
        print_file "$run_log" >&2
        fail "${name}_exact_regression_marker_absent"
    }
    printf '@@SYNC_PRODUCT_PREFRAMING_V3_ARCHIVED_TEST_PASS@@ name=%s xcelium=1 complete_source_set=1\n' "$name"
}

run_command_regression() {
    local name=$1 marker=$2
    shift 2
    local log="$SCRATCH/$name-command.log"
    record_command "$SCRATCH/$name-command.txt" "$@"
    set +e
    "$TIMEOUT" --signal=TERM --kill-after=10s "${REGRESSION_TIMEOUT_SECONDS}s" \
        "$@" >"$log" 2>&1
    local rc=$?
    set -e
    (( rc == 0 )) || {
        print_file "$log" >&2
        fail "${name}_command_regression_failed_exit_$rc"
    }
    [[ $(count_exact_line "$log" "$marker") == 1 ]] || {
        print_file "$log" >&2
        fail "${name}_command_regression_marker_absent"
    }
    printf '@@SYNC_PRODUCT_PREFRAMING_V3_COMMAND_PASS@@ name=%s log_sha256=%s\n' \
        "$name" "$(hash_file "$log")"
}

generate_core_compatibility_testbench() {
    CORE_COMPAT="$SCRATCH/tb_opendvs_sync_product_encoder_core.xcelium.sv"
    "$PYTHON" -I - "$CORE_TESTBENCH" "$CORE_COMPAT" <<'PY'
import pathlib
import sys
source, destination = map(pathlib.Path, sys.argv[1:])
lines = source.read_text(encoding="utf-8").splitlines(keepends=True)
changes = {
    153: (
        '                $finish_and_return(10);',
        '                $fatal(1, "target Xcelium compatibility termination");',
    ),
    157: (
        '            $finish_and_return(1);',
        '            $fatal(1, "target Xcelium compatibility termination");',
    ),
    1366: ('            $finish_and_return(0);', '            $finish(0);'),
}
plain = [line.removesuffix("\n") for line in lines]
if len(lines) != 1372 or sum("$finish_and_return" in line for line in plain) != 3:
    raise SystemExit("hash-pinned core testbench transformation precondition differs")
derived = list(lines)
for number, (old, new) in changes.items():
    if plain[number - 1] != old or plain.count(old) != 1:
        raise SystemExit(f"core compatibility anchor differs at line {number}")
    ending = "\n" if lines[number - 1].endswith("\n") else ""
    derived[number - 1] = new + ending
destination.write_text("".join(derived), encoding="utf-8", newline="\n")
PY
    [[ $(hash_file "$CORE_COMPAT") == "$CORE_COMPAT_SHA256" ]] ||
        fail "core_compatibility_testbench_hash_mismatch"
}

record_core_source_hashes() {
    local path=$1
    printf 'leaf\t%s\ncore\t%s\ntestbench\t%s\ncompatibility_testbench\t%s\n' \
        "$(hash_file "$CORE_LEAF")" "$(hash_file "$CORE_RTL")" \
        "$(hash_file "$CORE_TESTBENCH")" "$(hash_file "$CORE_COMPAT")" >"$path"
}

run_core_snapshot() {
    local name=$1 plant=$2 expectation=$3 library=$4
    local log="$CORE_EVIDENCE_DIR/run-$name.log"
    local -a command=(
        "$XRUN" -64bit -R -snapshot sync_pf_v3_core_evidence
        -xmlibdirname "$library" -l "$log"
    )
    [[ $plant == none ]] || command+=("+PLANT=$plant")
    local stage_dir attempt
    stage_dir=$(run_xcelium "core-evidence-run-$name" "$expectation" \
        "$RUN_TIMEOUT_SECONDS" "$CORE_EVIDENCE_DIR" "${command[@]}")
    attempt=$(<"$stage_dir/successful-attempt.txt")
    printf '%s\n' "$(<"$stage_dir/attempt-$attempt.exit.txt")" \
        >"$CORE_EVIDENCE_DIR/run-$name.exit.txt"
}

run_core_actual_evidence() {
    generate_core_compatibility_testbench
    CORE_EVIDENCE_DIR="$SCRATCH/core-actual-evidence"
    mkdir -p "$CORE_EVIDENCE_DIR"
    record_core_source_hashes "$CORE_EVIDENCE_DIR/source-hashes.before.tsv"
    local library="$CORE_EVIDENCE_DIR/xcelium.d"
    local elab_log="$SCRATCH/core-evidence-elaboration/xrun.log"
    run_xcelium core-evidence-elaboration zero "$ELABORATION_TIMEOUT_SECONDS" "$ROOT" \
        "$XRUN" -64bit -sysv_ext .sv -timescale 1ns/1ps \
        -top tb_opendvs_sync_product_encoder_core -elaborate \
        -snapshot sync_pf_v3_core_evidence -xmlibdirname "$library" \
        -l "$elab_log" "$CORE_LEAF" "$CORE_RTL" "$CORE_COMPAT" >/dev/null
    run_core_snapshot unplanted none zero "$library"
    local plant
    for plant in "${CORE_PLANTS[@]}"; do
        run_core_snapshot "plant-$plant" "$plant" nonzero "$library"
    done
    record_core_source_hashes "$CORE_EVIDENCE_DIR/source-hashes.after.tsv"
    run_checker verify-core-evidence "$CORE_EVIDENCE_DIR"
}

run_green_regressions() {
    run_existing_testbench_xcelium ownership-product tb_sync_mode_ownership_product \
        "$ROOT/fver/hardware_codec/integration/sync_mode_ownership/tb_sync_mode_ownership_product.sv" \
        '@@SYNC_MODE_OWNERSHIP_ACCEPTANCE_PASS@@ default_raw=1 pending_raw=1 unavailable_raw=1 illegal_raw=1 word31_storage=1 non_mode_identity=1'
    run_existing_testbench_xcelium ownership-safety tb_sync_mode_ownership_safety \
        "$ROOT/fver/hardware_codec/integration/sync_mode_ownership/tb_sync_mode_ownership_safety.sv" \
        '@@SYNC_MODE_OWNERSHIP_SAFETY_PASS@@ raw_pending=1 sync_commit=1 midburst_holds=4 safe_return=1 inactive_isolation=1 sticky_reset=1 readback_addresses=31 integrated_availability_low=1'
    run_existing_testbench_xcelium patched-abort tb_baseline_serial_abort \
        "$ROOT/fver/hardware_codec/integration/baseline_abort/tb_baseline_serial_abort.sv" \
        '@@BASELINE_SERIAL_ABORT_ACCEPTANCE_PASS@@ boundaries=9 replay_bursts=81 normal_bursts=9 lane_bytes=360 premature_pops=0 global_reset_cases=1' \
        +BASELINE_ABORT_RELEASE_PHASE

    run_command_regression current-product-reset \
        '@@SYNC_PRODUCT_PREFRAMING_V2_RESET_PASS@@ checks=11 reset_equations=4' \
        "$BASH" "$V2_RESET_RUNNER"
    run_command_regression qualified-core-runner "$CORE_PASS_MARKER" \
        "$BASH" "$CORE_RUNNER" --expect-green
    run_core_actual_evidence
    run_command_regression product-list-policy \
        '@@SYNC_MODE_OWNERSHIP_FILELIST_PASS@@ explicit_product_list=1 xrun_lists=2 wrapper_order=1 qdi_sources=0 async_sources=0' \
        "$PYTHON" -I "$PRODUCT_CHECKER"
}

run_structural_controls() {
    local log="$SCRATCH/structural-controls.log"
    run_checker structural-self-test >"$log"
    [[ $(count_exact_line "$log" \
        '@@SYNC_PRODUCT_PREFRAMING_V3_STRUCTURE_SELF_TEST_PASS@@ inherited_controls=5 closure_controls=3 ownership_controls=1 structural_controls=9 ownership_shell_instances=1') == 1 ]] || {
        print_file "$log" >&2
        fail "structural_control_marker_absent"
    }
    print_file "$log"
}

run_mechanical_closure() {
    "$BASH" -n "$TEST_DIR/run_sync_product_preframing_v3.sh"
    "$PYTHON" -I - "$CHECKER" "$DERIVER" <<'PY'
import pathlib
import sys
for name in sys.argv[1:]:
    path = pathlib.Path(name)
    compile(path.read_text(encoding="utf-8"), str(path), "exec")
PY
    run_checker scope-audit
    "$GIT" -C "$ROOT" diff --check
    [[ -z $("$GIT" -C "$ROOT" diff --cached --name-only) ]] ||
        fail "staged_paths_are_not_absent"
    printf '@@SYNC_PRODUCT_PREFRAMING_V3_MECHANICAL_CLOSURE_PASS@@ shell_syntax=1 python_compile=2 package_files=11 cache=0 source_seals=3 scope=1 whitespace=1 staged_paths=0\n'
}

usage() {
    printf 'usage: %s --preflight|--self-test|--expect-green\n' "$0" >&2
    exit 2
}

main() {
    [[ $# -eq 1 ]] || usage
    case $1 in
        --preflight|--self-test|--expect-green) ;;
        *) usage ;;
    esac
    export LC_ALL=C
    export PYTHONDONTWRITEBYTECODE=1
    umask 077
    reject_environment_injection
    verify_fixed_paths
    prepare_scratch
    trap cleanup EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    builtin cd -- "$ROOT"

    # Every mode starts by validating the v3 contract, all existing seals, the
    # four frozen integration RTL identities, and every evidence program pin.
    run_checker preflight
    local product_seal_before
    product_seal_before=$(hash_file "$V2_PRODUCT_SEAL")
    [[ $product_seal_before == $(hash_file "$V3_PRODUCT_SEAL") ]] ||
        fail "v2_v3_product_seal_identity_differs_before_execution"
    derive_runtime_sources

    case $1 in
        --preflight)
            select_xcelium
            run_fixture_preflight >/dev/null
            [[ $(hash_file "$V2_PRODUCT_SEAL") == "$product_seal_before" ]] ||
                fail "product_seal_changed_during_preflight"
            printf '%s\n' "$PREFLIGHT_MARKER"
            ;;
        --self-test)
            run_checker self-test
            run_structural_controls
            select_xcelium
            local fixture_identity fixture_snapshot fixture_library
            fixture_identity=$(run_fixture_preflight)
            IFS=$'\t' read -r fixture_snapshot fixture_library <<<"$fixture_identity"
            run_snapshot_suite fixture "$fixture_snapshot" "$fixture_library"
            [[ $(hash_file "$V2_PRODUCT_SEAL") == "$product_seal_before" ]] ||
                fail "product_seal_changed_during_self_test"
            run_mechanical_closure
            printf '%s\n' "$SELF_TEST_MARKER"
            ;;
        --expect-green)
            run_checker expect-green
            select_xcelium
            local product_identity product_snapshot product_library ignored
            product_identity=$(elaborate_integration product-integration "$PRODUCT_LIST" sync_pf_v3_product)
            IFS=$'\t' read -r product_snapshot product_library ignored <<<"$product_identity"
            run_snapshot_suite product "$product_snapshot" "$product_library"

            run_manifest_elaboration product "$ROOT" \
                "$ROOT/fver/hardware_codec/filelists/sync_mode_ownership_product.f" final_top3
            run_manifest_elaboration final-macros \
                "$ROOT/fver/final_macros/scripts" xrun.f final_top3
            run_manifest_elaboration user-wrapper \
                "$ROOT/fver/user_project_wrapper/scripts" xrun.f user_project_wrapper
            run_green_regressions
            run_structural_controls
            run_mechanical_closure
            [[ $(hash_file "$V2_PRODUCT_SEAL") == "$product_seal_before" ]] ||
                fail "v2_product_seal_changed_during_green"
            [[ $(hash_file "$V3_PRODUCT_SEAL") == "$product_seal_before" ]] ||
                fail "v3_product_seal_changed_during_green"
            run_checker expect-green >/dev/null
            printf '@@SYNC_PRODUCT_PREFRAMING_V3_NO_PRODUCTION_EDIT_PASS@@ before=%s after=%s files=25\n' \
                "$product_seal_before" "$(hash_file "$V2_PRODUCT_SEAL")"
            printf '%s\n' "$GREEN_MARKER"
            ;;
    esac
}

main "$@"
