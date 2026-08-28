#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [[ $# -ne 1 || ( $1 != --expect-red && $1 != --expect-green ) ]]; then
    printf 'usage: %s --expect-red|--expect-green\n' "$0" >&2
    exit 2
fi
readonly MODE=$1
readonly ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
readonly IVERILOG=/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/iverilog
readonly VVP=/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/vvp
readonly TESTBENCH="$ROOT/fver/hardware_codec/integration/sync_mode_ownership/tb_sync_mode_ownership_product.sv"
readonly SHELL_SV="$ROOT/source/design/hardware_codec/control/opendvs_sync_mode_ownership_shell.sv"
readonly CHECKER="$ROOT/fver/hardware_codec/integration/sync_mode_ownership/check_product_filelists.py"
readonly PRODUCT_LIST="$ROOT/fver/hardware_codec/filelists/sync_mode_ownership_product.f"
readonly TIMEOUT=/usr/bin/timeout
readonly SCRATCH_PARENT=/tmp/opencode/dvs-encoder
readonly RED_TOKEN=@@SYNC_MODE_OWNERSHIP_RED@@
readonly PASS_TOKEN=@@SYNC_MODE_OWNERSHIP_ACCEPTANCE_PASS@@

scratch=$(mktemp -d "$SCRATCH_PARENT/sync-mode-ownership.XXXXXXXXXX")
cleanup() { rm -rf -- "$scratch"; }
trap cleanup EXIT HUP INT TERM

sources=(
    "$ROOT/source/design/common/defines.sv"
    "$ROOT/source/design/regfile/regfile_final.sv"
    "$ROOT/source/design/regfile/spi_peripheral_re.sv"
    "$ROOT/source/design/sync_fifo/sync_fifo.sv"
    "$ROOT/source/design/sync_fifo/fifo_intf3.sv"
    "$ROOT/source/design/sync_fifo/sync_fifo_top3.sv"
    "$ROOT/source/design/roic/roic_sm2.sv"
    "$ROOT/source/design/roic/row_scanner.sv"
    "$ROOT/source/design/final_macros/row_decoder_macro2.sv"
    "$ROOT/source/design/final_macros/col_readout_macro.sv"
    "$ROOT/source/design/final_macros/fifo_rows_cols_macro2.sv"
)
[[ ! -f $SHELL_SV ]] || sources+=("$SHELL_SV")
sources+=("$ROOT/source/design/final_macros/final_top3.sv" "$TESTBENCH")

if ! "$IVERILOG" -g2012 -Wall -s tb_sync_mode_ownership_product \
    -o "$scratch/test.vvp" "${sources[@]}" >"$scratch/compile.log" 2>&1; then
    python3 -c 'from pathlib import Path; print(Path("'$scratch'/compile.log").read_text(), end="")' >&2
    exit 2
fi
set +e
"$VVP" "$scratch/test.vvp" >"$scratch/run.log" 2>&1
rc=$?
set -e

red_count=$(grep -cF "$RED_TOKEN" "$scratch/run.log" || true)
pass_count=$(grep -cF "$PASS_TOKEN" "$scratch/run.log" || true)
if [[ $MODE == --expect-red ]]; then
    [[ $rc -ne 0 && $red_count -eq 1 && $pass_count -eq 0 ]] || {
        python3 -c 'from pathlib import Path; print(Path("'$scratch'/run.log").read_text())' >&2
        exit 2
    }
    printf '@@SYNC_MODE_OWNERSHIP_RED_CONFIRMED@@ status_readback_absent=1\n'
else
    [[ $rc -eq 0 && $red_count -eq 0 && $pass_count -eq 1 ]] || {
        python3 -c 'from pathlib import Path; print(Path("'$scratch'/run.log").read_text())' >&2
        exit 2
    }
    builtin cd -- "$ROOT"
    if ! "$TIMEOUT" --signal=TERM --kill-after=5s 30s \
        "$IVERILOG" -g2012 -Wall -s final_top3 \
        -o "$scratch/product.vvp" -c "$PRODUCT_LIST" \
        >"$scratch/product-compile.log" 2>&1; then
        python3 -c 'from pathlib import Path; print(Path("'$scratch'/product-compile.log").read_text(), end="")' >&2
        exit 2
    fi
    python3 "$CHECKER"
    python3 -c 'from pathlib import Path; print(Path("'$scratch'/run.log").read_text(), end="")'
    printf '@@SYNC_MODE_OWNERSHIP_GATE_PASS@@ availability_low=1 patched_product=1 product_top_elaborated=1\n'
fi
