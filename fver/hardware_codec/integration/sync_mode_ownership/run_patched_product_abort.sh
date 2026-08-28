#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
readonly IVERILOG=/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/iverilog
readonly VVP=/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/vvp
readonly TIMEOUT=/usr/bin/timeout
readonly SHELL_SV="$ROOT/source/design/hardware_codec/control/opendvs_sync_mode_ownership_shell.sv"
readonly FINAL_TOP="$ROOT/source/design/final_macros/final_top3.sv"
readonly FIFO_INTF="$ROOT/source/design/sync_fifo/fifo_intf3.sv"
readonly TESTBENCH="$ROOT/fver/hardware_codec/integration/baseline_abort/tb_baseline_serial_abort.sv"
readonly RESET_RUNNER="$ROOT/fver/hardware_codec/integration/baseline_reset/run_baseline_reset_binding.sh"
readonly SCRATCH_PARENT=/tmp/opencode/dvs-encoder
readonly COMPILE_TIMEOUT_SECONDS=30
readonly RUN_TIMEOUT_SECONDS=30
readonly RESET_TIMEOUT_SECONDS=180

readonly ACCEPTANCE_MARKER='@@BASELINE_SERIAL_ABORT_ACCEPTANCE_PASS@@ boundaries=9 replay_bursts=81 normal_bursts=9 lane_bytes=360 premature_pops=0 global_reset_cases=1'
readonly RELEASE_MARKER='@@BASELINE_SERIAL_ABORT_RELEASE_PHASE_PASS@@ cases=3 near_edge_ps=2 full_clock_abort_samples=3 asynchronous_resets=0'
readonly GLOBAL_RESET_MARKER='@@BASELINE_SERIAL_ABORT_GLOBAL_RESET_PASS@@ partial_bursts=4 count=0 read_pointer=0 serializer_chunk=0'
readonly APPARATUS_TOKEN='@@BASELINE_SERIAL_ABORT_APPARATUS_FAIL@@'
readonly RAW_ASYNC_CONTROL_FAILURE='@@BASELINE_SERIAL_ABORT_APPARATUS_FAIL@@ check=release-phase-no-asynchronous-reset boundary=0 expected=00000514 actual=00001000'
readonly RAW_ASYNC_CONTROL_REJECTED='@@BASELINE_SERIAL_ABORT_CONTROL_REJECTED@@ control=raw-CS_N-direct-asynchronous-reset check=release-phase-no-asynchronous-reset'
readonly RESET_MARKER='@@NO_ENCODER_BASELINE_RESET_GATE_PASS@@ strict_parse=1 structure=1 behavior=1 controls=4 repository_unchanged=1'

fail() {
    printf 'PATCHED PRODUCT ABORT GATE FAILED: %s\n' "$*" >&2
    exit 2
}

print_file() {
    python3 -c 'from pathlib import Path; print(Path("'$1'").read_text(), end="")'
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

run_success() {
    local name=$1
    local timeout_seconds=$2
    shift 2
    local log="$scratch/$name.log"
    local rc
    set +e
    "$TIMEOUT" --signal=TERM --kill-after=5s "${timeout_seconds}s" "$@" >"$log" 2>&1
    rc=$?
    set -e
    if (( rc != 0 )); then
        print_file "$log" >&2
        (( rc != 124 && rc != 137 )) || fail "$name timed out"
        fail "$name exited with status $rc"
    fi
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
    done <"$FINAL_TOP"

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
    done <"$FIFO_INTF"

    (( final_replacements == 1 )) ||
        fail "made $final_replacements raw-CS_N replacements instead of one"
    (( fifo_declarations == 1 && fifo_sensitivities == 2 && fifo_resets == 2 )) ||
        fail 'made the wrong direct-asynchronous-reset control structure'
}

[[ $# -eq 0 ]] || fail "usage: $0"
[[ -f $SHELL_SV ]] || fail "missing synchronous ownership shell: $SHELL_SV"
scratch=$(mktemp -d "$SCRATCH_PARENT/patched-product-abort.XXXXXXXXXX")
cleanup() { rm -rf -- "$scratch"; }
trap cleanup EXIT HUP INT TERM

sources=(
    "$ROOT/source/design/common/defines.sv"
    "$ROOT/source/design/regfile/regfile_final.sv"
    "$ROOT/source/design/regfile/spi_peripheral_re.sv"
    "$ROOT/source/design/sync_fifo/sync_fifo.sv"
    "$FIFO_INTF"
    "$ROOT/source/design/sync_fifo/sync_fifo_top3.sv"
    "$ROOT/source/design/roic/roic_sm2.sv"
    "$ROOT/source/design/roic/row_scanner.sv"
    "$ROOT/source/design/final_macros/row_decoder_macro2.sv"
    "$ROOT/source/design/final_macros/col_readout_macro.sv"
    "$ROOT/source/design/final_macros/fifo_rows_cols_macro2.sv"
    "$SHELL_SV"
    "$FINAL_TOP"
    "$TESTBENCH"
)

run_success compile "$COMPILE_TIMEOUT_SECONDS" \
    "$IVERILOG" -g2012 -Wall -s tb_baseline_serial_abort \
    -o "$scratch/test.vvp" "${sources[@]}"
run_success simulation "$RUN_TIMEOUT_SECONDS" \
    "$VVP" "$scratch/test.vvp" +BASELINE_ABORT_RELEASE_PHASE

[[ $(count_exact_lines "$scratch/simulation.log" "$ACCEPTANCE_MARKER") == 1 ]] ||
    fail 'requires one exact full acceptance marker'
[[ $(count_exact_lines "$scratch/simulation.log" "$RELEASE_MARKER") == 1 ]] ||
    fail 'requires one exact full release-phase marker'
[[ $(count_exact_lines "$scratch/simulation.log" "$GLOBAL_RESET_MARKER") == 1 ]] ||
    fail 'requires one exact global-reset marker'
[[ $(count_token_lines "$scratch/simulation.log" "$APPARATUS_TOKEN") == 0 ]] ||
    fail 'positive replay emitted an apparatus failure marker'
print_file "$scratch/simulation.log"

final_control="$scratch/final_top3.raw-cs-n-control.sv"
fifo_control="$scratch/fifo_intf3.direct-async-control.sv"
make_raw_async_control "$final_control" "$fifo_control"
control_sources=(
    "$ROOT/source/design/common/defines.sv"
    "$ROOT/source/design/regfile/regfile_final.sv"
    "$ROOT/source/design/regfile/spi_peripheral_re.sv"
    "$ROOT/source/design/sync_fifo/sync_fifo.sv"
    "$fifo_control"
    "$ROOT/source/design/sync_fifo/sync_fifo_top3.sv"
    "$ROOT/source/design/roic/roic_sm2.sv"
    "$ROOT/source/design/roic/row_scanner.sv"
    "$ROOT/source/design/final_macros/row_decoder_macro2.sv"
    "$ROOT/source/design/final_macros/col_readout_macro.sv"
    "$ROOT/source/design/final_macros/fifo_rows_cols_macro2.sv"
    "$SHELL_SV"
    "$final_control"
    "$TESTBENCH"
)
run_success raw-async-control-compile "$COMPILE_TIMEOUT_SECONDS" \
    "$IVERILOG" -g2012 -Wall -s tb_baseline_serial_abort \
    -o "$scratch/control.vvp" "${control_sources[@]}"

set +e
"$TIMEOUT" --signal=TERM --kill-after=5s "${RUN_TIMEOUT_SECONDS}s" \
    "$VVP" "$scratch/control.vvp" +BASELINE_ABORT_RELEASE_PHASE \
    >"$scratch/raw-async-control-simulation.log" 2>&1
control_rc=$?
set -e
(( control_rc != 0 )) || fail 'raw asynchronous control unexpectedly passed'
(( control_rc != 124 && control_rc != 137 )) ||
    fail 'raw asynchronous control timed out instead of reaching the known rejection'
[[ $(count_exact_lines "$scratch/raw-async-control-simulation.log" \
                       "$RAW_ASYNC_CONTROL_FAILURE") == 1 ]] ||
    fail 'raw asynchronous control did not reach the exact known rejection'
[[ $(count_token_lines "$scratch/raw-async-control-simulation.log" \
                       "$APPARATUS_TOKEN") == 1 ]] ||
    fail 'raw asynchronous control produced an ambiguous rejection count'
[[ $(count_token_lines "$scratch/raw-async-control-simulation.log" \
                       '@@BASELINE_SERIAL_ABORT_ACCEPTANCE_PASS@@') == 0 ]] ||
    fail 'raw asynchronous control reached acceptance'
printf '%s\n' "$RAW_ASYNC_CONTROL_REJECTED"

run_success reset-gate "$RESET_TIMEOUT_SECONDS" /usr/bin/bash "$RESET_RUNNER"
[[ $(count_exact_lines "$scratch/reset-gate.log" "$RESET_MARKER") == 1 ]] ||
    fail 'requires the exact existing global/software reset gate marker'
print_file "$scratch/reset-gate.log"

printf '@@PATCHED_PRODUCT_ABORT_GATE_PASS@@ historical_gate_preserved=1 patched_replay=1 exact_markers=1 raw_async_control_rejected=1 reset_gate=1\n'
