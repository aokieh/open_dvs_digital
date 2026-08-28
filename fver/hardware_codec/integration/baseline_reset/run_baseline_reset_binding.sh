#!/usr/bin/env bash
set -euo pipefail

readonly EXPECTED_BRANCH='integration/hardware-codec-v1'
readonly DESTINATION_BASE_COMMIT='344d46dd62060ced54625c4f8da65c8006757963'
readonly DESTINATION_BASE_TREE='30941ff2118e1220bd0bada0fe9385a9b001a5ac'

readonly YOSYS_BIN='/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/yosys'
readonly YOSYS_SHA256='7c3e3396b38c129dd7485be5a0a0f0da8e495a94c8fd486059e3bea043a588d6'
readonly YOSYS_VERSION='Yosys 0.68+120 (git sha1 a34d3baae-dirty, Release, Clang /usr/bin/clang++ 21.1.8)'
readonly IVERILOG_BIN='/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/iverilog'
readonly IVERILOG_SHA256='6d84be4052a92cf7184c7149506f5db6ac251f99e438a96ae3ce33f326e2ff9d'
readonly IVERILOG_VERSION='Icarus Verilog version 14.0 (devel) (s20260301-391-g64f13540a-dirty)'
readonly VVP_BIN='/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/vvp'
readonly VVP_SHA256='9f6d770762b5e77d81216e5f21a634028a9ee062a724eeb116980bdb6cb110cc'
readonly VVP_VERSION='Icarus Verilog runtime version 14.0 (devel) (s20260301-391-g64f13540a-dirty)'
readonly TIMEOUT_BIN='/usr/bin/timeout'
readonly TIMEOUT_SHA256='c7ad4153c8fa4cfe78794062789182e39d48f85cc114ba9dc4fa54296ad2a407'

readonly GIT_BIN='/usr/bin/git'
readonly SHA256_BIN='/usr/bin/sha256sum'
readonly MKTEMP_BIN='/usr/bin/mktemp'
readonly CMP_BIN='/usr/bin/cmp'
readonly RM_BIN='/usr/bin/rm'
readonly CHMOD_BIN='/usr/bin/chmod'
readonly ENV_BIN='/usr/bin/env'

readonly SCRATCH_PARENT='/tmp/opencode/dvs-encoder'
readonly PARSE_TIMEOUT_SECONDS='30'
readonly COMPILE_TIMEOUT_SECONDS='30'
readonly RUN_TIMEOUT_SECONDS='30'

readonly DEFINES_REL='source/design/common/defines.sv'
readonly DUT_REL='source/design/final_macros/fifo_rows_cols_macro2.sv'
readonly TESTBENCH_REL='fver/hardware_codec/integration/baseline_reset/tb_baseline_reset_binding.sv'
readonly RUNNER_REL='fver/hardware_codec/integration/baseline_reset/run_baseline_reset_binding.sh'
readonly README_REL='fver/hardware_codec/integration/baseline_reset/README.md'
readonly DUT_SHA256='23c1153bf79be77f8f8d403fdfbca17148e4858b04d88eeea66d56a8c9bac551'
readonly TESTBENCH_SHA256='82d4cf27c4d718b179712461dc970a56318bfa9ed2e0493b19924daf5252fa61'

readonly TOP_MODULE='tb_baseline_reset_binding'
readonly POSITIVE_MARKER='@@NO_ENCODER_BASELINE_RESET_ACCEPTANCE_PASS@@ checks=11 reset_equations=4'
readonly POSITIVE_TOKEN='@@NO_ENCODER_BASELINE_RESET_ACCEPTANCE_PASS@@'
readonly FAILURE_TOKEN='@@NO_ENCODER_BASELINE_RESET_FAIL@@'
readonly STRUCTURE_MARKER='@@NO_ENCODER_BASELINE_RESET_STRUCTURE_PASS@@ equations=4 fsm_port_references=2 fifo_port_references=2 undeclared_references=0'
readonly GATE_MARKER='@@NO_ENCODER_BASELINE_RESET_GATE_PASS@@ strict_parse=1 structure=1 behavior=1 controls=4 repository_unchanged=1'

SCRIPT_DIR=''
ROOT=''
SCRATCH=''
DEFINES=''
DUT=''
TESTBENCH=''
RUNNER=''
README_FILE=''
SOURCE_SHA256_PRE=''
RUNNER_SHA256_PRE=''
README_SHA256_PRE=''
REPOSITORY_SHA256_PRE=''

baseline_error() {
    printf 'ERROR: The no-encoder baseline reset gate %s\n' "$*" >&2
}

fail() {
    baseline_error "$*"
    exit 2
}

hash_file() {
    local digest_line
    digest_line=$($SHA256_BIN -- "$1") || return 1
    printf '%s\n' "${digest_line%% *}"
}

require_hash() {
    local path=$1
    local expected=$2
    local actual
    [[ -f $path && ! -L $path ]] || fail "requires a regular, non-symbolic-link file at $path."
    actual=$(hash_file "$path") || fail "could not hash $path."
    [[ $actual == "$expected" ]] || fail "found an unexpected content identity at $path."
}

contains_exact_line() {
    local path=$1
    local expected=$2
    local line
    while IFS= read -r line || [[ -n $line ]]; do
        [[ $line == "$expected" ]] && return 0
    done <"$path"
    return 1
}

count_exact_lines() {
    local path=$1
    local expected=$2
    local line
    local count=0
    while IFS= read -r line || [[ -n $line ]]; do
        [[ $line == "$expected" ]] && count=$((count + 1))
    done <"$path"
    printf '%d\n' "$count"
}

count_token_lines() {
    local path=$1
    local token=$2
    local line
    local count=0
    while IFS= read -r line || [[ -n $line ]]; do
        [[ $line == *"$token"* ]] && count=$((count + 1))
    done <"$path"
    printf '%d\n' "$count"
}

record_command() {
    local destination=$1
    shift
    printf '%q ' "$@" >"$destination"
    printf '\n' >>"$destination"
}

run_stage() {
    local stage_name=$1
    local expected_exit=$2
    shift 2
    local command_file="$SCRATCH/$stage_name.command.txt"
    local log_file="$SCRATCH/$stage_name.log"
    local exit_file="$SCRATCH/$stage_name.exit.txt"
    local command_hash log_hash
    local rc

    record_command "$command_file" "$@"
    set +e
    "$@" >"$log_file" 2>&1
    rc=$?
    set -e
    printf '%d\n' "$rc" >"$exit_file"

    if [[ $expected_exit == zero ]]; then
        (( rc == 0 )) || fail "$stage_name failed with exit code $rc."
    elif [[ $expected_exit == nonzero ]]; then
        (( rc != 0 )) || fail "$stage_name unexpectedly passed."
        (( rc != 124 && rc != 137 )) || fail "$stage_name timed out instead of rejecting its planted defect."
    else
        fail "has an internal expected-exit error for $stage_name."
    fi

    command_hash=$(hash_file "$command_file") || fail "could not hash the $stage_name command."
    log_hash=$(hash_file "$log_file") || fail "could not hash the $stage_name log."
    printf '@@NO_ENCODER_BASELINE_RESET_COMMAND@@ stage=%s exit=%d command_sha256=%s log_sha256=%s\n' \
        "$stage_name" "$rc" "$command_hash" "$log_hash"
}

resolve_paths() {
    local script_source=${BASH_SOURCE[0]}
    local script_parent
    case $script_source in
        */*) script_parent=${script_source%/*} ;;
        *) script_parent='.' ;;
    esac
    SCRIPT_DIR=$(CDPATH= builtin cd -- "$script_parent" && builtin pwd -P) ||
        fail 'could not resolve its runner directory.'
    ROOT=$(CDPATH= builtin cd -- "$SCRIPT_DIR/../../../.." && builtin pwd -P) ||
        fail 'could not resolve the destination repository root.'
    [[ $SCRIPT_DIR == "$ROOT/fver/hardware_codec/integration/baseline_reset" ]] ||
        fail 'is not running from its exact destination path.'
    DEFINES="$ROOT/$DEFINES_REL"
    DUT="$ROOT/$DUT_REL"
    TESTBENCH="$ROOT/$TESTBENCH_REL"
    RUNNER="$ROOT/$RUNNER_REL"
    README_FILE="$ROOT/$README_REL"
    builtin cd -- "$ROOT" || fail 'could not enter the destination repository root.'
}

prepare_scratch() {
    [[ -d $SCRATCH_PARENT && ! -L $SCRATCH_PARENT && -O $SCRATCH_PARENT ]] ||
        fail 'requires its owned, non-symbolic-link scratch parent.'
    SCRATCH=$($MKTEMP_BIN -d "$SCRATCH_PARENT/baseline-reset-run.XXXXXXXXXX") ||
        fail 'could not create unique disposable scratch.'
    case $SCRATCH in
        "$SCRATCH_PARENT"/baseline-reset-run.*) ;;
        *) fail 'received a disposable scratch path outside its fixed parent.' ;;
    esac
    $CHMOD_BIN 700 "$SCRATCH" || fail 'could not restrict disposable scratch permissions.'
}

cleanup() {
    local rc=$?
    trap - EXIT HUP INT TERM
    if [[ -n ${SCRATCH:-} && -d ${SCRATCH:-} ]]; then
        case $SCRATCH in
            "$SCRATCH_PARENT"/baseline-reset-run.*) $RM_BIN -rf -- "$SCRATCH" ;;
            *) baseline_error 'refused to remove an invalid scratch path.'; rc=1 ;;
        esac
    fi
    exit "$rc"
}

reject_injection() {
    local name
    local -a names=(
        BASH_ENV ENV CDPATH
        YOSYS YOSYS_FLAGS IVERILOG VVP IVL IVL_ROOT IVERILOG_FLAGS VVP_FLAGS
        VERILOG_SOURCES SYSTEMVERILOG_SOURCES RTL_SOURCES SOURCES SOURCE_FILES
        GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
        GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CEILING_DIRECTORIES
        LD_PRELOAD LD_LIBRARY_PATH
    )
    for name in "${names[@]}"; do
        [[ ! -v $name ]] || fail "rejects environment injection through $name."
    done
}

verify_repository_identity() {
    local branch base_tree
    [[ -d $ROOT/.git ]] || fail 'requires destination repository metadata.'
    branch=$($GIT_BIN -C "$ROOT" branch --show-current) || fail 'could not read the destination branch.'
    [[ $branch == "$EXPECTED_BRANCH" ]] || fail 'found the wrong destination branch.'
    base_tree=$($GIT_BIN -C "$ROOT" rev-parse "$DESTINATION_BASE_COMMIT^{tree}") ||
        fail 'could not resolve the destination base tree.'
    [[ $base_tree == "$DESTINATION_BASE_TREE" ]] || fail 'found the wrong destination base tree.'
    $GIT_BIN -C "$ROOT" merge-base --is-ancestor "$DESTINATION_BASE_COMMIT" HEAD ||
        fail 'requires a destination HEAD descended from the fixed base commit.'
}

verify_tool_identities() {
    local iverilog_output="$SCRATCH/iverilog.version.txt"
    local vvp_output="$SCRATCH/vvp.version.txt"
    local yosys_output="$SCRATCH/yosys.version.txt"

    require_hash "$YOSYS_BIN" "$YOSYS_SHA256"
    require_hash "$IVERILOG_BIN" "$IVERILOG_SHA256"
    require_hash "$VVP_BIN" "$VVP_SHA256"
    require_hash "$TIMEOUT_BIN" "$TIMEOUT_SHA256"
    [[ -x $YOSYS_BIN && -x $IVERILOG_BIN && -x $VVP_BIN && -x $TIMEOUT_BIN ]] ||
        fail 'requires executable pinned design tools.'

    "$YOSYS_BIN" -V >"$yosys_output" 2>&1 || fail 'could not identify the pinned Yosys parser.'
    "$IVERILOG_BIN" -V >"$iverilog_output" 2>&1 || fail 'could not identify the pinned Icarus compiler.'
    "$VVP_BIN" -V >"$vvp_output" 2>&1 || fail 'could not identify the pinned Icarus runtime.'
    contains_exact_line "$yosys_output" "$YOSYS_VERSION" || fail 'found the wrong pinned Yosys version.'
    contains_exact_line "$iverilog_output" "$IVERILOG_VERSION" || fail 'found the wrong pinned Icarus compiler version.'
    contains_exact_line "$vvp_output" "$VVP_VERSION" || fail 'found the wrong pinned Icarus runtime version.'

    printf '@@NO_ENCODER_BASELINE_RESET_TOOLS@@ yosys_sha256=%s iverilog_sha256=%s vvp_sha256=%s timeout_sha256=%s\n' \
        "$YOSYS_SHA256" "$IVERILOG_SHA256" "$VVP_SHA256" "$TIMEOUT_SHA256"
}

capture_repository() {
    local phase=$1
    local path digest component_name
    local files_manifest="$SCRATCH/repository-files.$phase.tsv"
    local components_manifest="$SCRATCH/repository-components.$phase.tsv"

    $GIT_BIN -C "$ROOT" branch --show-current >"$SCRATCH/repository-branch.$phase.txt" ||
        fail 'could not snapshot the destination branch.'
    $GIT_BIN -C "$ROOT" rev-parse HEAD >"$SCRATCH/repository-head.$phase.txt" ||
        fail 'could not snapshot the destination HEAD.'
    $GIT_BIN -C "$ROOT" rev-parse 'HEAD^{tree}' >"$SCRATCH/repository-tree.$phase.txt" ||
        fail 'could not snapshot the destination tree.'
    $GIT_BIN -C "$ROOT" status --porcelain=v1 -z --untracked-files=all \
        >"$SCRATCH/repository-status.$phase.bin" || fail 'could not snapshot destination status.'
    $GIT_BIN -C "$ROOT" diff --no-ext-diff --binary >"$SCRATCH/repository-diff.$phase.patch" ||
        fail 'could not snapshot destination changes.'
    $GIT_BIN -C "$ROOT" diff --cached --no-ext-diff --binary \
        >"$SCRATCH/repository-staged.$phase.patch" || fail 'could not snapshot staged changes.'
    $GIT_BIN -C "$ROOT" ls-files --stage >"$SCRATCH/repository-index.$phase.txt" ||
        fail 'could not snapshot the destination index.'

    : >"$files_manifest"
    while IFS= read -r -d '' path; do
        [[ -f $ROOT/$path && ! -L $ROOT/$path ]] ||
            fail "cannot content-hash destination path $path."
        digest=$(hash_file "$ROOT/$path") || fail "could not content-hash destination path $path."
        printf '%s\t%s\n' "$digest" "$path" >>"$files_manifest"
    done < <($GIT_BIN -C "$ROOT" ls-files --cached --others --exclude-standard -z)

    : >"$components_manifest"
    for path in \
        "$SCRATCH/repository-branch.$phase.txt" \
        "$SCRATCH/repository-head.$phase.txt" \
        "$SCRATCH/repository-tree.$phase.txt" \
        "$SCRATCH/repository-status.$phase.bin" \
        "$SCRATCH/repository-diff.$phase.patch" \
        "$SCRATCH/repository-staged.$phase.patch" \
        "$SCRATCH/repository-index.$phase.txt" \
        "$files_manifest"; do
        digest=$(hash_file "$path") || fail "could not hash repository snapshot component $path."
        component_name=${path##*/}
        component_name=${component_name/.$phase./.}
        printf '%s\t%s\n' "$digest" "$component_name" >>"$components_manifest"
    done
    hash_file "$components_manifest"
}

compare_repository_snapshots() {
    local stem
    local -a stems=(
        repository-branch repository-head repository-tree repository-status
        repository-diff repository-staged repository-index repository-files
    )
    local -a suffixes=(txt txt txt bin patch patch txt tsv)
    local index
    for ((index = 0; index < ${#stems[@]}; index += 1)); do
        stem=${stems[$index]}
        $CMP_BIN -s "$SCRATCH/$stem.pre.${suffixes[$index]}" \
                    "$SCRATCH/$stem.post.${suffixes[$index]}" ||
            fail "detected a destination repository change in $stem."
    done
}

verify_contract_files() {
    require_hash "$DUT" "$DUT_SHA256"
    require_hash "$TESTBENCH" "$TESTBENCH_SHA256"
    [[ -f $DEFINES && ! -L $DEFINES ]] || fail 'requires the explicit definitions source.'
    [[ -f $RUNNER && ! -L $RUNNER ]] || fail 'requires the exact runner source.'
    [[ -f $README_FILE && ! -L $README_FILE ]] || fail 'requires the focused test documentation.'
}

verify_structure() {
    local line
    local equation_count=0
    local fsm_count=0
    local fifo_count=0
    local undeclared_count=0

    while IFS= read -r line || [[ -n $line ]]; do
        [[ $line != *fsm_rst_n_reg* ]] || undeclared_count=$((undeclared_count + 1))
        [[ $line != *fifo_rst_n_reg* ]] || undeclared_count=$((undeclared_count + 1))
        case $line in
            '    assign fsm_row_rst_n_top = rst_n & ~fsm_rst_n;'|'    assign fsm_row_rst_n_bot = rst_n & ~fsm_rst_n;')
                equation_count=$((equation_count + 1))
                fsm_count=$((fsm_count + 1))
                ;;
            '    assign col_rst_n_top     = rst_n & ~fifo_rst_n;'|'    assign col_rst_n_bot     = rst_n & ~fifo_rst_n;')
                equation_count=$((equation_count + 1))
                fifo_count=$((fifo_count + 1))
                ;;
            *'assign fsm_row_rst_n_top'*|*'assign fsm_row_rst_n_bot'*|*'assign col_rst_n_top'*|*'assign col_rst_n_bot'*)
                fail 'found an unexpected effective-reset equation.'
                ;;
        esac
    done <"$DUT"

    (( equation_count == 4 && fsm_count == 2 && fifo_count == 2 && undeclared_count == 0 )) ||
        fail "found the wrong effective-reset structure: equations=$equation_count fsm=$fsm_count fifo=$fifo_count undeclared=$undeclared_count."
    printf '%s\n' "$STRUCTURE_MARKER"
}

make_mutant() {
    local control=$1
    local output=$2
    local line
    local replacements=0
    local expected_replacements

    : >"$output"
    while IFS= read -r line || [[ -n $line ]]; do
        case "$control:$line" in
            'swapped-port:    assign fsm_row_rst_n_top = rst_n & ~fsm_rst_n;')
                line='    assign fsm_row_rst_n_top = rst_n & ~fifo_rst_n;'; replacements=$((replacements + 1)) ;;
            'swapped-port:    assign fsm_row_rst_n_bot = rst_n & ~fsm_rst_n;')
                line='    assign fsm_row_rst_n_bot = rst_n & ~fifo_rst_n;'; replacements=$((replacements + 1)) ;;
            'swapped-port:    assign col_rst_n_top     = rst_n & ~fifo_rst_n;')
                line='    assign col_rst_n_top     = rst_n & ~fsm_rst_n;'; replacements=$((replacements + 1)) ;;
            'swapped-port:    assign col_rst_n_bot     = rst_n & ~fifo_rst_n;')
                line='    assign col_rst_n_bot     = rst_n & ~fsm_rst_n;'; replacements=$((replacements + 1)) ;;
            'ignored-pulse:    assign col_rst_n_top     = rst_n & ~fifo_rst_n;')
                line='    assign col_rst_n_top     = rst_n;'; replacements=$((replacements + 1)) ;;
            'ignored-pulse:    assign col_rst_n_bot     = rst_n & ~fifo_rst_n;')
                line='    assign col_rst_n_bot     = rst_n;'; replacements=$((replacements + 1)) ;;
            'inverted-polarity:    assign fsm_row_rst_n_top = rst_n & ~fsm_rst_n;')
                line='    assign fsm_row_rst_n_top = rst_n & fsm_rst_n;'; replacements=$((replacements + 1)) ;;
            'inverted-polarity:    assign fsm_row_rst_n_bot = rst_n & ~fsm_rst_n;')
                line='    assign fsm_row_rst_n_bot = rst_n & fsm_rst_n;'; replacements=$((replacements + 1)) ;;
            'inverted-polarity:    assign col_rst_n_top     = rst_n & ~fifo_rst_n;')
                line='    assign col_rst_n_top     = rst_n & fifo_rst_n;'; replacements=$((replacements + 1)) ;;
            'inverted-polarity:    assign col_rst_n_bot     = rst_n & ~fifo_rst_n;')
                line='    assign col_rst_n_bot     = rst_n & fifo_rst_n;'; replacements=$((replacements + 1)) ;;
            'one-tier-only:    assign fsm_row_rst_n_bot = rst_n & ~fsm_rst_n;')
                line='    assign fsm_row_rst_n_bot = rst_n;'; replacements=$((replacements + 1)) ;;
        esac
        printf '%s\n' "$line" >>"$output"
    done <"$DUT"

    case $control in
        swapped-port) expected_replacements=4 ;;
        ignored-pulse) expected_replacements=2 ;;
        inverted-polarity) expected_replacements=4 ;;
        one-tier-only) expected_replacements=1 ;;
        *) fail "does not recognize planted control $control." ;;
    esac
    (( replacements == expected_replacements )) ||
        fail "made $replacements replacements instead of $expected_replacements for $control."
    [[ $(hash_file "$output") != "$DUT_SHA256" ]] || fail "did not change the source for $control."
}

compile_source() {
    local stage=$1
    local source_path=$2
    local output_path=$3
    run_stage "$stage" zero \
        "$ENV_BIN" -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$TIMEOUT_BIN" --signal=TERM --kill-after=5s "${COMPILE_TIMEOUT_SECONDS}s" \
        "$IVERILOG_BIN" -g2012 -Wall -i -s "$TOP_MODULE" -o "$output_path" \
        "$DEFINES" "$source_path" "$TESTBENCH"
}

verify_real_behavior() {
    local executable="$SCRATCH/baseline-reset-real.vvp"
    local log="$SCRATCH/real-behavior.log"
    compile_source real-compile "$DUT" "$executable"
    run_stage real-behavior zero \
        "$ENV_BIN" -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$TIMEOUT_BIN" --signal=TERM --kill-after=5s "${RUN_TIMEOUT_SECONDS}s" \
        "$VVP_BIN" "$executable"
    [[ $(count_exact_lines "$log" "$POSITIVE_MARKER") == 1 ]] ||
        fail 'requires one exact positive behavior marker.'
    [[ $(count_token_lines "$log" "$POSITIVE_TOKEN") == 1 ]] ||
        fail 'found an ambiguous positive behavior marker count.'
    [[ $(count_token_lines "$log" "$FAILURE_TOKEN") == 0 ]] ||
        fail 'found a failure marker in the real focused behavior run.'
}

verify_control() {
    local control=$1
    local expected_marker=$2
    local mutant="$SCRATCH/fifo_rows_cols_macro2.$control.sv"
    local executable="$SCRATCH/baseline-reset-$control.vvp"
    local log="$SCRATCH/control-$control.log"

    make_mutant "$control" "$mutant"
    compile_source "control-$control-compile" "$mutant" "$executable"
    run_stage "control-$control" nonzero \
        "$ENV_BIN" -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$TIMEOUT_BIN" --signal=TERM --kill-after=5s "${RUN_TIMEOUT_SECONDS}s" \
        "$VVP_BIN" "$executable"
    [[ $(count_exact_lines "$log" "$expected_marker") == 1 ]] ||
        fail "$control did not fail at its exact named check."
    [[ $(count_token_lines "$log" "$FAILURE_TOKEN") == 1 ]] ||
        fail "$control produced an ambiguous negative marker count."
    [[ $(count_token_lines "$log" "$POSITIVE_TOKEN") == 0 ]] ||
        fail "$control reached the positive acceptance marker."
    printf '@@NO_ENCODER_BASELINE_RESET_CONTROL_REJECTED@@ control=%s named_check_marker_sha256=%s\n' \
        "$control" "$(printf '%s\n' "$expected_marker" | $SHA256_BIN | { read -r value _; printf '%s' "$value"; })"
}

main() {
    (( $# == 0 )) || fail 'accepts no arguments.'
    export LC_ALL=C
    umask 077
    resolve_paths
    prepare_scratch
    trap cleanup EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    reject_injection
    verify_repository_identity
    verify_contract_files
    verify_tool_identities

    SOURCE_SHA256_PRE=$(hash_file "$DUT")
    RUNNER_SHA256_PRE=$(hash_file "$RUNNER")
    README_SHA256_PRE=$(hash_file "$README_FILE")
    REPOSITORY_SHA256_PRE=$(capture_repository pre)

    run_stage strict-no-implicit-net-parse zero \
        "$ENV_BIN" -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$TIMEOUT_BIN" --signal=TERM --kill-after=5s "${PARSE_TIMEOUT_SECONDS}s" \
        "$YOSYS_BIN" -q -p \
        "read_verilog -sv -noautowire $DEFINES $DUT"
    verify_structure
    verify_real_behavior

    verify_control swapped-port \
        '@@NO_ENCODER_BASELINE_RESET_FAIL@@ check=isolated-row-state-machine-pulse expected=0011 actual=1100'
    verify_control ignored-pulse \
        '@@NO_ENCODER_BASELINE_RESET_FAIL@@ check=isolated-first-in-first-out-pulse expected=1100 actual=1111'
    verify_control inverted-polarity \
        '@@NO_ENCODER_BASELINE_RESET_FAIL@@ check=released-software-pulses expected=1111 actual=0000'
    verify_control one-tier-only \
        '@@NO_ENCODER_BASELINE_RESET_FAIL@@ check=isolated-row-state-machine-pulse expected=0011 actual=0111'

    [[ $(hash_file "$DUT") == "$SOURCE_SHA256_PRE" ]] || fail 'detected a source change during the gate.'
    [[ $(hash_file "$RUNNER") == "$RUNNER_SHA256_PRE" ]] || fail 'detected a runner change during the gate.'
    [[ $(hash_file "$README_FILE") == "$README_SHA256_PRE" ]] || fail 'detected a documentation change during the gate.'
    local repository_sha256_post
    repository_sha256_post=$(capture_repository post)
    compare_repository_snapshots
    [[ $repository_sha256_post == "$REPOSITORY_SHA256_PRE" ]] ||
        fail 'detected a repository content-hash change during the gate.'

    printf '@@NO_ENCODER_BASELINE_RESET_IDENTITIES@@ source_pre_sha256=%s source_post_sha256=%s testbench_sha256=%s runner_pre_sha256=%s runner_post_sha256=%s readme_pre_sha256=%s readme_post_sha256=%s repository_pre_sha256=%s repository_post_sha256=%s\n' \
        "$SOURCE_SHA256_PRE" "$(hash_file "$DUT")" "$(hash_file "$TESTBENCH")" \
        "$RUNNER_SHA256_PRE" "$(hash_file "$RUNNER")" \
        "$README_SHA256_PRE" "$(hash_file "$README_FILE")" \
        "$REPOSITORY_SHA256_PRE" "$repository_sha256_post"
    printf '%s\n' "$GATE_MARKER"
}

main "$@"
