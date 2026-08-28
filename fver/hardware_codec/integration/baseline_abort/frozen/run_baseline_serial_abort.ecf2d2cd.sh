#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly EXPECTED_BRANCH='integration/hardware-codec-v1'
readonly BASE_COMMIT='344d46dd62060ced54625c4f8da65c8006757963'
readonly BASE_TREE='30941ff2118e1220bd0bada0fe9385a9b001a5ac'
readonly CORRECTED_FINGERPRINT='439e04291a2d1e17072691d32794e8a3f1b410e4f011cecfd43c08e499a47a65'

readonly IVERILOG_BIN='/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/iverilog'
readonly IVERILOG_SHA256='6d84be4052a92cf7184c7149506f5db6ac251f99e438a96ae3ce33f326e2ff9d'
readonly IVERILOG_VERSION='Icarus Verilog version 14.0 (devel) (s20260301-391-g64f13540a-dirty)'
readonly VVP_BIN='/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/vvp'
readonly VVP_SHA256='9f6d770762b5e77d81216e5f21a634028a9ee062a724eeb116980bdb6cb110cc'
readonly VVP_VERSION='Icarus Verilog runtime version 14.0 (devel) (s20260301-391-g64f13540a-dirty)'
readonly TIMEOUT_BIN='/usr/bin/timeout'
readonly TIMEOUT_SHA256='c7ad4153c8fa4cfe78794062789182e39d48f85cc114ba9dc4fa54296ad2a407'

readonly SHA256_BIN='/usr/bin/sha256sum'
readonly GIT_BIN='/usr/bin/git'
readonly MKTEMP_BIN='/usr/bin/mktemp'
readonly CHMOD_BIN='/usr/bin/chmod'
readonly RM_BIN='/usr/bin/rm'
readonly CMP_BIN='/usr/bin/cmp'
readonly SORT_BIN='/usr/bin/sort'
readonly ENV_BIN='/usr/bin/env'

readonly SCRATCH_PARENT='/tmp/opencode/dvs-encoder'
readonly COMPILE_TIMEOUT_SECONDS='30'
readonly RUN_TIMEOUT_SECONDS='30'
readonly RESET_GATE_TIMEOUT_SECONDS='180'
readonly TOP_MODULE='tb_baseline_serial_abort'

readonly -a SOURCE_RELATIVE=(
    'source/design/common/defines.sv'
    'source/design/regfile/regfile_final.sv'
    'source/design/regfile/spi_peripheral_re.sv'
    'source/design/sync_fifo/sync_fifo.sv'
    'source/design/sync_fifo/fifo_intf3.sv'
    'source/design/sync_fifo/sync_fifo_top3.sv'
    'source/design/roic/roic_sm2.sv'
    'source/design/roic/row_scanner.sv'
    'source/design/final_macros/row_decoder_macro2.sv'
    'source/design/final_macros/col_readout_macro.sv'
    'source/design/final_macros/fifo_rows_cols_macro2.sv'
    'source/design/final_macros/final_top3.sv'
)
readonly -a CORRECTED_SOURCE_SHA256=(
    '484efc729c0c542a729ca2c88ecdff8feb7dea1998370525c1dd7732df895455'
    '6ca84909e4f0c8e250b8485ee309feb4be83963a3d194fac9da7c33dd0dcdf6d'
    '10e2c89b3197738bdeaa56814394efa6b9905da3d599fea21076d16037e7a6a5'
    '5349b38c1213401bd90eaee9d64343f3b2ece095b1703873e537db25e3c94a50'
    '29cf88000132c5a84020e422fe89df59beb2c7ba301b51ef406334929597c948'
    '18c1d6c5f2c529d5914aadf80b88ffde990623b0c26e438287976a665dde3a01'
    'e2c022f1bd52ea384b0f904649c5bba96d37ad62997194c7dcdf1bb23430c186'
    '14afb8da008cfeccee6b3f79b696f01cdc1c7c181e47a522bc15dd4fca9a6990'
    '9c30365041cb6f283f3dc881c96f02e6f725fb68993ef30bd36c9a595085e04e'
    '38e170f60cd6bb882c5a50475eb1b68a04c33f187a9cfac25f22cf3d06b642c5'
    '23c1153bf79be77f8f8d403fdfbca17148e4858b04d88eeea66d56a8c9bac551'
    'a26b0a8bfd758b738cf60a2073c5284b467d5eb626bcbefbae8f7cff689977b4'
)

readonly TESTBENCH_RELATIVE='fver/hardware_codec/integration/baseline_abort/tb_baseline_serial_abort.sv'
readonly RUNNER_RELATIVE='fver/hardware_codec/integration/baseline_abort/run_baseline_serial_abort.sh'
readonly README_RELATIVE='fver/hardware_codec/integration/baseline_abort/README.md'
readonly RESET_RUNNER_RELATIVE='fver/hardware_codec/integration/baseline_reset/run_baseline_reset_binding.sh'
readonly TESTBENCH_SHA256='a70ae3fc11c7375dcae50be984e85bdb3bb760be497146b58420e80f6f680dec'
readonly README_SHA256='e23dbaa62de482d58a7adad1951746bd78028bff1ee6f2b3ba2c837374bba685'

readonly RED_MARKER='@@BASELINE_SERIAL_ABORT_RED@@ failing_boundaries=1,2,3,4,5,6,7,8 reason=serializer_progress_survives_chip_select_release'
readonly RED_TOKEN='@@BASELINE_SERIAL_ABORT_RED@@'
readonly BOUNDARY_RED_TOKEN='@@BASELINE_SERIAL_ABORT_BOUNDARY_RED@@'
readonly ACCEPTANCE_MARKER='@@BASELINE_SERIAL_ABORT_ACCEPTANCE_PASS@@ boundaries=9 replay_bursts=81 normal_bursts=9 lane_bytes=360 premature_pops=0 global_reset_cases=1'
readonly ACCEPTANCE_TOKEN='@@BASELINE_SERIAL_ABORT_ACCEPTANCE_PASS@@'
readonly BOUNDARY_PASS_TOKEN='@@BASELINE_SERIAL_ABORT_BOUNDARY_PASS@@'
readonly NORMAL_MARKER='@@BASELINE_SERIAL_ABORT_NORMAL_PASS@@ bursts=9 lane_bytes=36 top_pops=1 bottom_pops=1'
readonly GLOBAL_RESET_MARKER='@@BASELINE_SERIAL_ABORT_GLOBAL_RESET_PASS@@ partial_bursts=4 count=0 read_pointer=0 serializer_chunk=0'
readonly RELEASE_PHASE_MARKER='@@BASELINE_SERIAL_ABORT_RELEASE_PHASE_PASS@@ cases=3 near_edge_ps=2 full_clock_abort_samples=3 asynchronous_resets=0'
readonly APPARATUS_TOKEN='@@BASELINE_SERIAL_ABORT_APPARATUS_FAIL@@'
readonly RAW_ASYNC_CONTROL_FAILURE='@@BASELINE_SERIAL_ABORT_APPARATUS_FAIL@@ check=release-phase-no-asynchronous-reset boundary=0 expected=00000514 actual=00001000'
readonly RAW_ASYNC_CONTROL_REJECTED='@@BASELINE_SERIAL_ABORT_CONTROL_REJECTED@@ control=raw-CS_N-direct-asynchronous-reset check=release-phase-no-asynchronous-reset'
readonly RESET_MARKER='@@NO_ENCODER_BASELINE_RESET_GATE_PASS@@ strict_parse=1 structure=1 behavior=1 controls=4 repository_unchanged=1'
readonly GREEN_GATE_MARKER='@@BASELINE_SERIAL_ABORT_GATE_PASS@@ simulator=iverilog boundaries=9 normal_identity=1 global_reset=1 software_reset=1 repository_unchanged=1'
readonly RED_CONFIRMATION='@@BASELINE_SERIAL_ABORT_RED_CONFIRMED@@ simulator=iverilog failing_boundaries=1,2,3,4,5,6,7,8 repository_unchanged=1'

MODE=''
SCRIPT_DIR=''
ROOT=''
SCRATCH=''
TESTBENCH=''
RUNNER=''
README_FILE=''
RESET_RUNNER=''
REPOSITORY_PRE_SHA256=''
declare -a EXPLICIT_INPUTS=()

error() {
    printf 'ERROR: The baseline serializer abort gate %s\n' "$*" >&2
}

fail() {
    error "$*"
    exit 2
}

hash_file() {
    local digest_line
    digest_line=$($SHA256_BIN -- "$1") || return 1
    printf '%s\n' "${digest_line%% *}"
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

print_file() {
    local path=$1
    local line
    while IFS= read -r line || [[ -n $line ]]; do
        printf '%s\n' "$line"
    done <"$path"
}

require_regular_file() {
    [[ -f $1 && ! -L $1 ]] || fail "requires a regular, non-symbolic-link file at $1."
}

require_hash() {
    local path=$1
    local expected=$2
    local actual
    require_regular_file "$path"
    actual=$(hash_file "$path") || fail "could not hash $path."
    [[ $actual == "$expected" ]] ||
        fail "found an unexpected content identity at $path (expected $expected, actual $actual)."
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
        fail 'could not resolve the repository root.'
    [[ $SCRIPT_DIR == "$ROOT/fver/hardware_codec/integration/baseline_abort" ]] ||
        fail 'is not running from its exact repository path.'
    TESTBENCH="$ROOT/$TESTBENCH_RELATIVE"
    RUNNER="$ROOT/$RUNNER_RELATIVE"
    README_FILE="$ROOT/$README_RELATIVE"
    RESET_RUNNER="$ROOT/$RESET_RUNNER_RELATIVE"
    local relative
    for relative in "${SOURCE_RELATIVE[@]}"; do
        EXPLICIT_INPUTS+=("$ROOT/$relative")
    done
    EXPLICIT_INPUTS+=("$TESTBENCH")
    builtin cd -- "$ROOT" || fail 'could not enter the repository root.'
}

prepare_scratch() {
    [[ -d $SCRATCH_PARENT && ! -L $SCRATCH_PARENT && -O $SCRATCH_PARENT ]] ||
        fail 'requires its owned, non-symbolic-link scratch parent.'
    SCRATCH=$($MKTEMP_BIN -d "$SCRATCH_PARENT/baseline-serial-abort.XXXXXXXXXX") ||
        fail 'could not create unique disposable scratch.'
    case $SCRATCH in
        "$SCRATCH_PARENT"/baseline-serial-abort.*) ;;
        *) fail 'received a disposable scratch path outside its fixed parent.' ;;
    esac
    $CHMOD_BIN 700 "$SCRATCH" || fail 'could not restrict disposable scratch permissions.'
}

cleanup() {
    local rc=$?
    trap - EXIT HUP INT TERM
    if [[ -n ${SCRATCH:-} && -d ${SCRATCH:-} ]]; then
        case $SCRATCH in
            "$SCRATCH_PARENT"/baseline-serial-abort.*) $RM_BIN -rf -- "$SCRATCH" ;;
            *) error 'refused to remove an invalid scratch path.'; rc=1 ;;
        esac
    fi
    exit "$rc"
}

reject_injection() {
    local name
    local -a names=(
        BASH_ENV ENV CDPATH
        IVERILOG VVP IVL IVL_ROOT IVERILOG_FLAGS VVP_FLAGS
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
    [[ -d $ROOT/.git ]] || fail 'requires repository metadata.'
    branch=$($GIT_BIN -C "$ROOT" branch --show-current) || fail 'could not read the branch.'
    [[ $branch == "$EXPECTED_BRANCH" ]] || fail "found branch $branch instead of $EXPECTED_BRANCH."
    base_tree=$($GIT_BIN -C "$ROOT" rev-parse "$BASE_COMMIT^{tree}") ||
        fail 'could not resolve the baseline tree.'
    [[ $base_tree == "$BASE_TREE" ]] || fail 'found the wrong baseline tree.'
    $GIT_BIN -C "$ROOT" merge-base --is-ancestor "$BASE_COMMIT" HEAD ||
        fail 'requires a HEAD descended from the baseline commit.'
}

verify_contract_files() {
    local index
    require_hash "$TESTBENCH" "$TESTBENCH_SHA256"
    require_regular_file "$RUNNER"
    require_hash "$README_FILE" "$README_SHA256"
    require_regular_file "$RESET_RUNNER"
    for ((index = 0; index < ${#SOURCE_RELATIVE[@]}; index += 1)); do
        require_regular_file "${EXPLICIT_INPUTS[$index]}"
    done
}

verify_corrected_source_identity() {
    local index actual
    local manifest="$SCRATCH/corrected-sources.tsv"
    local sorted_manifest="$SCRATCH/corrected-sources.sorted.tsv"
    : >"$manifest"
    for ((index = 0; index < ${#SOURCE_RELATIVE[@]}; index += 1)); do
        actual=$(hash_file "${EXPLICIT_INPUTS[$index]}") ||
            fail "could not hash ${SOURCE_RELATIVE[$index]}."
        [[ $actual == "${CORRECTED_SOURCE_SHA256[$index]}" ]] ||
            fail "GREEN requires corrected production at ${SOURCE_RELATIVE[$index]}."
        printf '%s\t%s\n' "${SOURCE_RELATIVE[$index]}" "$actual" >>"$manifest"
    done
    $SORT_BIN "$manifest" >"$sorted_manifest" || fail 'could not canonicalize the source manifest.'
    actual=$(hash_file "$sorted_manifest") || fail 'could not hash the source manifest.'
    [[ $actual == "$CORRECTED_FINGERPRINT" ]] || fail 'found the wrong corrected source fingerprint.'
    printf '@@BASELINE_SERIAL_ABORT_SOURCES@@ files=12 fingerprint=%s\n' "$actual"
}

verify_tools() {
    local iverilog_version="$SCRATCH/iverilog.version.txt"
    local vvp_version="$SCRATCH/vvp.version.txt"
    require_hash "$IVERILOG_BIN" "$IVERILOG_SHA256"
    require_hash "$VVP_BIN" "$VVP_SHA256"
    require_hash "$TIMEOUT_BIN" "$TIMEOUT_SHA256"
    [[ -x $IVERILOG_BIN && -x $VVP_BIN && -x $TIMEOUT_BIN ]] ||
        fail 'requires executable pinned Icarus and timeout tools.'
    "$IVERILOG_BIN" -V >"$iverilog_version" 2>&1 || fail 'could not identify Icarus.'
    "$VVP_BIN" -V >"$vvp_version" 2>&1 || fail 'could not identify the Icarus runtime.'
    contains_exact_line "$iverilog_version" "$IVERILOG_VERSION" || fail 'found the wrong Icarus version.'
    contains_exact_line "$vvp_version" "$VVP_VERSION" || fail 'found the wrong Icarus runtime version.'
    printf '@@BASELINE_SERIAL_ABORT_TOOLS@@ iverilog_sha256=%s vvp_sha256=%s timeout_sha256=%s\n' \
        "$IVERILOG_SHA256" "$VVP_SHA256" "$TIMEOUT_SHA256"
}

capture_repository() {
    local phase=$1
    local path digest component_name
    local files_manifest="$SCRATCH/repository-files.$phase.tsv"
    local components_manifest="$SCRATCH/repository-components.$phase.tsv"

    $GIT_BIN -C "$ROOT" branch --show-current >"$SCRATCH/repository-branch.$phase.txt" ||
        fail 'could not snapshot the branch.'
    $GIT_BIN -C "$ROOT" rev-parse HEAD >"$SCRATCH/repository-head.$phase.txt" ||
        fail 'could not snapshot HEAD.'
    $GIT_BIN -C "$ROOT" rev-parse 'HEAD^{tree}' >"$SCRATCH/repository-tree.$phase.txt" ||
        fail 'could not snapshot the tree.'
    $GIT_BIN -C "$ROOT" status --porcelain=v1 -z --untracked-files=all \
        >"$SCRATCH/repository-status.$phase.bin" || fail 'could not snapshot status.'
    $GIT_BIN -C "$ROOT" diff --no-ext-diff --binary >"$SCRATCH/repository-diff.$phase.patch" ||
        fail 'could not snapshot the unstaged diff.'
    $GIT_BIN -C "$ROOT" diff --cached --no-ext-diff --binary \
        >"$SCRATCH/repository-staged.$phase.patch" || fail 'could not snapshot the staged diff.'
    $GIT_BIN -C "$ROOT" ls-files --stage >"$SCRATCH/repository-index.$phase.txt" ||
        fail 'could not snapshot the index.'

    : >"$files_manifest"
    while IFS= read -r -d '' path; do
        require_regular_file "$ROOT/$path"
        digest=$(hash_file "$ROOT/$path") || fail "could not hash repository path $path."
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
        digest=$(hash_file "$path") || fail 'could not hash a repository snapshot component.'
        component_name=${path##*/}
        component_name=${component_name/.$phase./.}
        printf '%s\t%s\n' "$digest" "$component_name" >>"$components_manifest"
    done
    hash_file "$components_manifest"
}

compare_repository_snapshots() {
    local index stem
    local -a stems=(
        repository-branch repository-head repository-tree repository-status
        repository-diff repository-staged repository-index repository-files
    )
    local -a suffixes=(txt txt txt bin patch patch txt tsv)
    for ((index = 0; index < ${#stems[@]}; index += 1)); do
        stem=${stems[$index]}
        $CMP_BIN -s "$SCRATCH/$stem.pre.${suffixes[$index]}" \
                    "$SCRATCH/$stem.post.${suffixes[$index]}" ||
            fail "detected a repository change in $stem."
    done
}

run_logged() {
    local name=$1
    shift
    local log="$SCRATCH/$name.log"
    local exit_file="$SCRATCH/$name.exit.txt"
    local rc
    set +e
    "$@" >"$log" 2>&1
    rc=$?
    set -e
    printf '%d\n' "$rc" >"$exit_file"
    (( rc == 0 )) || {
        print_file "$log" >&2
        if (( rc == 124 || rc == 137 )); then
            fail "$name timed out, which is an apparatus failure."
        fi
        fail "$name failed with exit code $rc, which is an apparatus failure."
    }
    printf '@@BASELINE_SERIAL_ABORT_COMMAND@@ stage=%s exit=%d log_sha256=%s\n' \
        "$name" "$rc" "$(hash_file "$log")"
}

run_logged_expect_failure() {
    local name=$1
    shift
    local log="$SCRATCH/$name.log"
    local exit_file="$SCRATCH/$name.exit.txt"
    local rc
    set +e
    "$@" >"$log" 2>&1
    rc=$?
    set -e
    printf '%d\n' "$rc" >"$exit_file"
    (( rc != 0 )) || fail "$name unexpectedly accepted its planted control."
    if (( rc == 124 || rc == 137 )); then
        print_file "$log" >&2
        fail "$name timed out instead of rejecting its planted control."
    fi
    printf '@@BASELINE_SERIAL_ABORT_COMMAND@@ stage=%s exit=%d log_sha256=%s\n' \
        "$name" "$rc" "$(hash_file "$log")"
}

compile_and_run() {
    local executable="$SCRATCH/baseline-serial-abort.vvp"
    local -a simulation_command=("$VVP_BIN" "$executable")
    run_logged compile \
        "$ENV_BIN" -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$TIMEOUT_BIN" --signal=TERM --kill-after=5s "${COMPILE_TIMEOUT_SECONDS}s" \
        "$IVERILOG_BIN" -g2012 -Wall -s "$TOP_MODULE" -o "$executable" \
        "${EXPLICIT_INPUTS[@]}"
    if [[ $MODE == --expect-green ]]; then
        simulation_command+=('+BASELINE_ABORT_RELEASE_PHASE')
    fi
    run_logged simulation \
        "$ENV_BIN" -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$TIMEOUT_BIN" --signal=TERM --kill-after=5s "${RUN_TIMEOUT_SECONDS}s" \
        "${simulation_command[@]}"
}

make_raw_async_control() {
    local final_output=$1
    local fifo_output=$2
    local line
    local final_replacements=0
    local fifo_declarations=0
    local fifo_sensitivities=0
    local fifo_resets=0

    : >"$final_output"
    while IFS= read -r line || [[ -n $line ]]; do
        if [[ $line == '    assign stream_abort = cs_n_sync_pipe[1] & ~cs_n_sync_d;' ]]; then
            line='    assign stream_abort = CS_N & ~cs_n_sync_d;'
            final_replacements=$((final_replacements + 1))
        fi
        printf '%s\n' "$line" >>"$final_output"
    done <"$ROOT/source/design/final_macros/final_top3.sv"

    : >"$fifo_output"
    while IFS= read -r line || [[ -n $line ]]; do
        if [[ $line == '    logic [3:0] shift_ctr;' ]]; then
            printf '%s\n' "$line" >>"$fifo_output"
            printf '%s\n' '    logic serializer_rst_n;' >>"$fifo_output"
            printf '%s\n' '    assign serializer_rst_n = rst_n & ~stream_abort;' >>"$fifo_output"
            fifo_declarations=$((fifo_declarations + 1))
            continue
        fi
        if [[ $line == '    always_ff @(posedge clk or negedge rst_n) begin' ]]; then
            line='    always_ff @(posedge clk or negedge serializer_rst_n) begin'
            fifo_sensitivities=$((fifo_sensitivities + 1))
        elif [[ $line == '        if (!rst_n) begin' ]]; then
            line='        if (!serializer_rst_n) begin'
            fifo_resets=$((fifo_resets + 1))
        fi
        printf '%s\n' "$line" >>"$fifo_output"
    done <"$ROOT/source/design/sync_fifo/fifo_intf3.sv"

    (( final_replacements == 1 )) ||
        fail "made $final_replacements raw-CS_N replacements instead of one."
    (( fifo_declarations == 1 && fifo_sensitivities == 2 && fifo_resets == 2 )) ||
        fail "made the wrong direct-asynchronous-reset control structure."
    [[ $(hash_file "$final_output") != "${CORRECTED_SOURCE_SHA256[11]}" ]] ||
        fail 'did not change final_top3 for the raw-CS_N control.'
    [[ $(hash_file "$fifo_output") != "${CORRECTED_SOURCE_SHA256[4]}" ]] ||
        fail 'did not change fifo_intf3 for the direct-asynchronous-reset control.'
}

compile_and_reject_raw_async_control() {
    local final_control="$SCRATCH/final_top3.raw-cs-n-control.sv"
    local fifo_control="$SCRATCH/fifo_intf3.direct-async-control.sv"
    local executable="$SCRATCH/baseline-serial-abort.raw-async-control.vvp"
    local relative
    local index
    local source_path
    local -a control_inputs=()

    make_raw_async_control "$final_control" "$fifo_control"
    for ((index = 0; index < ${#SOURCE_RELATIVE[@]}; index += 1)); do
        relative=${SOURCE_RELATIVE[$index]}
        case $relative in
            source/design/final_macros/final_top3.sv) source_path=$final_control ;;
            source/design/sync_fifo/fifo_intf3.sv) source_path=$fifo_control ;;
            *) source_path="$ROOT/$relative" ;;
        esac
        control_inputs+=("$source_path")
    done
    control_inputs+=("$TESTBENCH")

    run_logged raw-async-control-compile \
        "$ENV_BIN" -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$TIMEOUT_BIN" --signal=TERM --kill-after=5s "${COMPILE_TIMEOUT_SECONDS}s" \
        "$IVERILOG_BIN" -g2012 -Wall -s "$TOP_MODULE" -o "$executable" \
        "${control_inputs[@]}"
    run_logged_expect_failure raw-async-control-simulation \
        "$ENV_BIN" -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$TIMEOUT_BIN" --signal=TERM --kill-after=5s "${RUN_TIMEOUT_SECONDS}s" \
        "$VVP_BIN" "$executable" +BASELINE_ABORT_RELEASE_PHASE
    [[ $(count_exact_lines "$SCRATCH/raw-async-control-simulation.log" \
                           "$RAW_ASYNC_CONTROL_FAILURE") == 1 ]] ||
        fail 'the raw-CS_N/direct-asynchronous-reset control did not fail at the exact release-phase check.'
    [[ $(count_token_lines "$SCRATCH/raw-async-control-simulation.log" \
                           "$APPARATUS_TOKEN") == 1 ]] ||
        fail 'the raw-CS_N/direct-asynchronous-reset control produced an ambiguous failure count.'
    [[ $(count_token_lines "$SCRATCH/raw-async-control-simulation.log" \
                           "$ACCEPTANCE_TOKEN") == 0 ]] ||
        fail 'the raw-CS_N/direct-asynchronous-reset control reached acceptance.'
    printf '%s\n' "$RAW_ASYNC_CONTROL_REJECTED"
}

verify_simulation_markers() {
    local log="$SCRATCH/simulation.log"
    [[ $(count_exact_lines "$log" "$NORMAL_MARKER") == 1 ]] ||
        fail 'requires one exact uninterrupted-normal marker.'
    [[ $(count_exact_lines "$log" "$GLOBAL_RESET_MARKER") == 1 ]] ||
        fail 'requires one exact global-reset marker.'
    [[ $(count_token_lines "$log" "$APPARATUS_TOKEN") == 0 ]] ||
        fail 'found a test-apparatus failure marker.'

    if [[ $MODE == --expect-red ]]; then
        [[ $(count_exact_lines "$log" "$RED_MARKER") == 1 ]] ||
            fail 'requires the exact frozen RED summary.'
        [[ $(count_token_lines "$log" "$RED_TOKEN") == 1 ]] ||
            fail 'found an ambiguous RED summary count.'
        [[ $(count_token_lines "$log" "$BOUNDARY_RED_TOKEN") == 8 ]] ||
            fail 'requires exactly eight retained-progress boundary failures.'
        [[ $(count_token_lines "$log" "$BOUNDARY_PASS_TOKEN") == 1 ]] ||
            fail 'requires only boundary zero to pass on current production.'
        [[ $(count_token_lines "$log" "$ACCEPTANCE_TOKEN") == 0 ]] ||
            fail 'current production unexpectedly reached the GREEN marker.'
    else
        [[ $(count_exact_lines "$log" "$RELEASE_PHASE_MARKER") == 1 ]] ||
            fail 'requires one exact release-phase marker.'
        [[ $(count_exact_lines "$log" "$ACCEPTANCE_MARKER") == 1 ]] ||
            fail 'requires the exact frozen GREEN acceptance marker.'
        [[ $(count_token_lines "$log" "$ACCEPTANCE_TOKEN") == 1 ]] ||
            fail 'found an ambiguous GREEN marker count.'
        [[ $(count_token_lines "$log" "$BOUNDARY_PASS_TOKEN") == 9 ]] ||
            fail 'requires all nine abort boundaries to pass.'
        [[ $(count_token_lines "$log" "$RED_TOKEN") == 0 ]] ||
            fail 'found a RED summary during a GREEN run.'
    fi
}

run_reset_gate() {
    run_logged reset-gate \
        "$ENV_BIN" -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C \
        "$TIMEOUT_BIN" --signal=TERM --kill-after=5s "${RESET_GATE_TIMEOUT_SECONDS}s" \
        /usr/bin/bash "$RESET_RUNNER"
    [[ $(count_exact_lines "$SCRATCH/reset-gate.log" "$RESET_MARKER") == 1 ]] ||
        fail 'requires the exact no-encoder baseline reset gate marker.'
}

parse_arguments() {
    (( $# == 3 )) || fail 'usage: run_baseline_serial_abort.sh --expect-red|--expect-green --sim iverilog'
    MODE=$1
    [[ $MODE == --expect-red || $MODE == --expect-green ]] ||
        fail 'requires --expect-red or --expect-green as its first argument.'
    [[ $2 == --sim && $3 == iverilog ]] || fail 'supports only --sim iverilog.'
}

main() {
    parse_arguments "$@"
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
    verify_tools
    if [[ $MODE == --expect-green ]]; then
        verify_corrected_source_identity
    fi

    REPOSITORY_PRE_SHA256=$(capture_repository pre)
    compile_and_run
    verify_simulation_markers
    print_file "$SCRATCH/simulation.log"
    if [[ $MODE == --expect-green ]]; then
        compile_and_reject_raw_async_control
    fi
    run_reset_gate
    print_file "$SCRATCH/reset-gate.log"

    local repository_post_sha256
    repository_post_sha256=$(capture_repository post)
    compare_repository_snapshots
    [[ $repository_post_sha256 == "$REPOSITORY_PRE_SHA256" ]] ||
        fail 'detected a repository content change during verification.'
    printf '@@BASELINE_SERIAL_ABORT_IDENTITIES@@ repository_pre_sha256=%s repository_post_sha256=%s testbench_sha256=%s runner_sha256=%s readme_sha256=%s\n' \
        "$REPOSITORY_PRE_SHA256" "$repository_post_sha256" \
        "$(hash_file "$TESTBENCH")" "$(hash_file "$RUNNER")" "$(hash_file "$README_FILE")"

    if [[ $MODE == --expect-red ]]; then
        printf '%s\n' "$RED_CONFIRMATION"
    else
        printf '%s\n' "$GREEN_GATE_MARKER"
    fi
}

main "$@"
