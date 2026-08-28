#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly ROOT=$(CDPATH= builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && builtin pwd -P)
readonly TEST_DIR="$ROOT/fver/hardware_codec/integration/sync_product_preframing_v2"
readonly CHECKER="$TEST_DIR/check_sync_product_preframing_v2.py"
readonly FIXTURE_LIST="$TEST_DIR/fixture_sources_v2.f"
readonly PRODUCT_LIST="$TEST_DIR/product_sources_v2.f"
readonly TESTBENCH="$TEST_DIR/tb_sync_product_preframing_v2.sv"
readonly RESET_RUNNER="$TEST_DIR/run_current_product_reset_binding_v2.sh"
readonly XRUN=/opt/cadence/ius-21.09.006/lnx86/tools.lnx86/inca/bin/64bit/xrun
readonly XRUN_SHA256=c2fd01c847845bd35cd20cce428464934a7c42a65666dfc4929e81607989a8a9
readonly XRUN_VERSION=21.09-s006
readonly TIMEOUT=/usr/bin/timeout
readonly SHA256SUM=/usr/bin/sha256sum
readonly PYTHON=/usr/bin/python3
readonly GIT=/usr/bin/git
readonly SCRATCH_PARENT=/tmp/opencode/dvs-encoder
readonly LICENSE_VARIABLE=LM_LICENSE_FILE
readonly LICENSE_VALUE=8152@lic-cadence-e.ethz.ch
readonly ELABORATION_TIMEOUT_SECONDS=240
readonly RUN_TIMEOUT_SECONDS=180
readonly REGRESSION_TIMEOUT_SECONDS=900
readonly LICENSE_ATTEMPTS=3
readonly LICENSE_RETRY_DELAY_SECONDS=5

readonly PASS_MARKER='@@SYNC_PRODUCT_PREFRAMING_ACCEPTANCE_PASS@@ mapping_tiers=2 independent_pulses=2 prefull_observations=1 legacy_full_suppression=1 reset_release_cycles=2 core_instances=1 enc128_leaves=2 default_off=1 cycle13_consume=1 cycle15_completion=1 abort_completions=0 packet_length_assumptions=0'
readonly FAIL_TOKEN='@@SYNC_PRODUCT_PREFRAMING_FAIL@@'
readonly PREFLIGHT_MARKER='@@SYNC_PRODUCT_PREFRAMING_V2_PREFLIGHT_PASS@@ fixture_elaborated=1 behavior_run=0 xcelium=21.09-s006 archive=1 test_seal=1'
readonly SELF_TEST_MARKER='@@SYNC_PRODUCT_PREFRAMING_V2_SELF_TEST_PASS@@ fixture_green=1 semantic_plants=10 inherited_structural_controls=5 closure_controls=3 structural_controls=8'
readonly RED_MARKER='@@SYNC_PRODUCT_PREFRAMING_V2_RED_FROZEN@@ reasons=3 behavior_run=0 semantic_plants=10 structural_controls=8'
readonly GREEN_MARKER='@@SYNC_PRODUCT_PREFRAMING_V2_GREEN_PASS@@ manifests=3 core_instances=1 enc128_leaves=2 reset_synchronizers=1 source_tiers=2 completion_ports=1 forbidden_sources=0'
readonly BLOCKED_TOKEN='@@SYNC_PRODUCT_PREFRAMING_V2_XCELIUM_BLOCKED@@'

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

SCRATCH=''

fail() {
    printf '@@SYNC_PRODUCT_PREFRAMING_V2_RUNNER_FAIL@@ message=%s\n' "$*" >&2
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
    SCRATCH=$(mktemp -d "$SCRATCH_PARENT/sync-product-preframing-v2.XXXXXXXXXX") ||
        fail "could_not_create_scratch"
    case $SCRATCH in
        "$SCRATCH_PARENT"/sync-product-preframing-v2.*) ;;
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
            printf '@@SYNC_PRODUCT_PREFRAMING_V2_SCRATCH_PRESERVED@@ path=%s\n' "$SCRATCH" >&2
        fi
    fi
    exit "$rc"
}

verify_fixed_paths() {
    [[ $TEST_DIR == "$ROOT/fver/hardware_codec/integration/sync_product_preframing_v2" ]] ||
        fail "runner_is_not_at_the_fixed_v2_path"
    local path
    for path in "$CHECKER" "$FIXTURE_LIST" "$PRODUCT_LIST" "$TESTBENCH" \
                "$RESET_RUNNER"; do
        [[ -f $path && ! -L $path ]] || fail "missing_nonregular_or_symlink:$path"
    done
    [[ -x $TIMEOUT && -x $SHA256SUM && -x $PYTHON && -x $GIT ]] ||
        fail "required_host_tool_is_absent"
}

run_checker() {
    "$PYTHON" -I "$CHECKER" "$1"
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
    [[ $(hash_file "$XRUN") == "$XRUN_SHA256" ]] ||
        fail "xrun_executable_hash_mismatch"
    local stdout="$SCRATCH/xrun-version.stdout.log"
    local stderr="$SCRATCH/xrun-version.stderr.log"
    set +e
    env -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$LICENSE_VARIABLE=$LICENSE_VALUE" \
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
    printf '@@SYNC_PRODUCT_PREFRAMING_V2_XCELIUM_IDENTITY@@ version=%s sha256=%s\n' \
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
                "$LICENSE_VARIABLE=$LICENSE_VALUE" \
                "$TIMEOUT" --signal=TERM --kill-after=10s "${timeout_seconds}s" \
                "$@" >"$stdout" 2>"$stderr"
        )
        rc=$?
        set -e
        printf '%d\n' "$rc" >"$stage_dir/attempt-$attempt.exit.txt"
        if (( rc == 0 )); then
            [[ $expectation == zero ]] || fail "${stage}_expected_nonzero_but_passed"
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

elaborate_filelist() {
    local name=$1 filelist=$2 snapshot=$3
    local library="$SCRATCH/$name-library"
    local log="$SCRATCH/$name/xrun.log"
    run_xcelium "$name" zero "$ELABORATION_TIMEOUT_SECONDS" "$ROOT" \
        "$XRUN" -64bit -sysv_ext .sv -timescale 1ns/1ps \
        -top tb_sync_product_preframing_v2 -elaborate -snapshot "$snapshot" \
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
    printf '@@SYNC_PRODUCT_PREFRAMING_V2_PLANT_DETECTED@@ plant=%s check=%s\n' \
        "$plant" "$check_name"
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
    identity=$(elaborate_filelist fixture-elaboration "$FIXTURE_LIST" sync_pf_v2_fixture)
    IFS=$'\t' read -r snapshot library stage_dir <<<"$identity"
    "$PYTHON" -I - "$stage_dir/xrun.log" <<'PY'
import pathlib
import sys
text = pathlib.Path(sys.argv[1]).read_text(errors="replace")
for module in (
    "tb_sync_product_preframing_v2",
    "tb_sync_product_preframing",
    "final_top3",
    "opendvs_sync_product_encoder_core",
    "enc128",
    "rst_sync",
    "opendvs_sync_mode_ownership_shell",
):
    if f"module worklib.{module}:sv" not in text:
        raise SystemExit(f"fixture elaboration lacks module evidence: {module}")
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
    printf '@@SYNC_PRODUCT_PREFRAMING_V2_MANIFEST_ELABORATED@@ name=%s top=%s\n' \
        "$name" "$top"
}

run_existing_testbench_xcelium() {
    local name=$1 top=$2 testbench=$3 marker=$4 plusarg=${5:-}
    local snapshot_name=${name//-/_}
    local source_list="$SCRATCH/$name-sources.f"
    "$PYTHON" -I - "$PRODUCT_LIST" "$source_list" "$TESTBENCH" "$testbench" <<'PY'
import pathlib
import sys
source, destination, integration_tb, regression_tb = map(pathlib.Path, sys.argv[1:])
lines = [line for line in source.read_text(encoding="utf-8").splitlines() if line.strip()]
root = pathlib.Path.cwd()
integration = str(integration_tb.relative_to(root))
if lines.count(integration) != 1:
    raise SystemExit("v2 integration testbench is not unique in product_sources_v2.f")
lines.remove(integration)
lines.append(str(regression_tb.relative_to(root)))
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
    printf '@@SYNC_PRODUCT_PREFRAMING_V2_ARCHIVED_TEST_PASS@@ name=%s xcelium=1 complete_source_set=1\n' "$name"
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
    printf '@@SYNC_PRODUCT_PREFRAMING_V2_COMMAND_PASS@@ name=%s\n' "$name"
}

run_green_regressions() {
    run_command_regression product-core \
        '@@OPENDVS_SYNC_PRODUCT_CORE_PASS@@ mapping_cases=3096 tiers=2 sparse_boundary=15 raw_boundary=16 queue_depth_test=4' \
        /usr/bin/bash "$ROOT/fver/hardware_codec/unit/sync_product_core/run_sync_product_core_xcelium_v3.sh" --expect-green

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
        /usr/bin/bash "$RESET_RUNNER"
    run_command_regression product-list-policy \
        '@@SYNC_MODE_OWNERSHIP_FILELIST_PASS@@ explicit_product_list=1 xrun_lists=2 wrapper_order=1 qdi_sources=0 async_sources=0' \
        "$PYTHON" -I "$ROOT/fver/hardware_codec/integration/sync_mode_ownership/check_product_filelists.py"
}

run_mechanical_closure() {
    run_checker verify-current-product-seal
    run_checker verify-v1-archive
    run_checker verify-test-seal
    run_checker verify-reset-structure
    run_checker scope-audit
    "$GIT" -C "$ROOT" diff --check
    [[ -z $("$GIT" -C "$ROOT" diff --cached --name-only) ]] ||
        fail "staged_paths_are_not_absent"
    printf '@@SYNC_PRODUCT_PREFRAMING_V2_MECHANICAL_CLOSURE_PASS@@ source_seal=1 archive=1 test_seal=1 reset=1 scope=1 whitespace=1 staged_paths=0\n'
}

usage() {
    printf 'usage: %s --preflight|--self-test|--expect-red|--expect-green\n' "$0" >&2
    exit 2
}

main() {
    [[ $# -eq 1 ]] || usage
    case $1 in
        --preflight|--self-test|--expect-red|--expect-green) ;;
        *) usage ;;
    esac
    export LC_ALL=C
    umask 077
    reject_environment_injection
    verify_fixed_paths
    prepare_scratch
    trap cleanup EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    builtin cd -- "$ROOT"
    run_checker verify-v1-archive
    run_checker verify-test-seal

    case $1 in
        --preflight)
            run_checker preflight
            select_xcelium
            run_fixture_preflight >/dev/null
            run_checker verify-v1-archive >/dev/null
            run_checker verify-test-seal >/dev/null
            printf '%s\n' "$PREFLIGHT_MARKER"
            ;;
        --self-test)
            run_checker preflight
            run_checker self-test
            select_xcelium
            local fixture_identity fixture_snapshot fixture_library
            fixture_identity=$(run_fixture_preflight)
            IFS=$'\t' read -r fixture_snapshot fixture_library <<<"$fixture_identity"
            run_snapshot_suite fixture "$fixture_snapshot" "$fixture_library"
            run_checker verify-v1-archive >/dev/null
            run_checker verify-test-seal >/dev/null
            printf '%s\n' "$SELF_TEST_MARKER"
            ;;
        --expect-red)
            run_checker preflight
            select_xcelium
            run_fixture_preflight >/dev/null
            run_checker expect-red
            run_checker scope-audit
            "$GIT" -C "$ROOT" diff --check
            run_checker verify-v1-archive >/dev/null
            run_checker verify-test-seal >/dev/null
            printf '%s\n' "$RED_MARKER"
            ;;
        --expect-green)
            run_checker expect-green
            select_xcelium
            local product_identity product_snapshot product_library ignored
            product_identity=$(elaborate_filelist product-elaboration "$PRODUCT_LIST" sync_pf_v2_product)
            IFS=$'\t' read -r product_snapshot product_library ignored <<<"$product_identity"
            run_snapshot_suite product "$product_snapshot" "$product_library"

            run_manifest_elaboration product "$ROOT" \
                "$ROOT/fver/hardware_codec/filelists/sync_mode_ownership_product.f" final_top3
            run_manifest_elaboration final-macros \
                "$ROOT/fver/final_macros/scripts" xrun.f final_top3
            run_manifest_elaboration user-wrapper \
                "$ROOT/fver/user_project_wrapper/scripts" xrun.f user_project_wrapper
            run_green_regressions
            run_mechanical_closure
            printf '%s\n' "$GREEN_MARKER"
            ;;
    esac
}

main "$@"
