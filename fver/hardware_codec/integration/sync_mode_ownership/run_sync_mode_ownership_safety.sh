#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
readonly IVERILOG=/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/iverilog
readonly VVP=/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/vvp
readonly TIMEOUT=/usr/bin/timeout
readonly PRODUCT_LIST="$ROOT/fver/hardware_codec/filelists/sync_mode_ownership_product.f"
readonly TESTBENCH="$ROOT/fver/hardware_codec/integration/sync_mode_ownership/tb_sync_mode_ownership_safety.sv"
readonly CHECKER="$ROOT/fver/hardware_codec/integration/sync_mode_ownership/check_product_filelists.py"
readonly SCRATCH_PARENT=/tmp/opencode/dvs-encoder
readonly PASS_MARKER='@@SYNC_MODE_OWNERSHIP_SAFETY_PASS@@ raw_pending=1 sync_commit=1 midburst_holds=4 safe_return=1 inactive_isolation=1 sticky_reset=1 readback_addresses=31 integrated_availability_low=1'
readonly FAIL_TOKEN='@@SYNC_MODE_OWNERSHIP_SAFETY_FAIL@@'

[[ $# -eq 0 ]] || { printf 'usage: %s\n' "$0" >&2; exit 2; }
scratch=$(mktemp -d "$SCRATCH_PARENT/sync-mode-ownership-safety.XXXXXXXXXX")
cleanup() { rm -rf -- "$scratch"; }
trap cleanup EXIT HUP INT TERM

builtin cd -- "$ROOT"
if ! "$TIMEOUT" --signal=TERM --kill-after=5s 30s \
    "$IVERILOG" -g2012 -Wall -s tb_sync_mode_ownership_safety \
    -o "$scratch/test.vvp" -c "$PRODUCT_LIST" "$TESTBENCH" \
    >"$scratch/compile.log" 2>&1; then
    python3 -c 'from pathlib import Path; print(Path("'$scratch'/compile.log").read_text(), end="")' >&2
    exit 2
fi
if ! "$TIMEOUT" --signal=TERM --kill-after=5s 30s \
    "$VVP" "$scratch/test.vvp" >"$scratch/run.log" 2>&1; then
    python3 -c 'from pathlib import Path; print(Path("'$scratch'/run.log").read_text(), end="")' >&2
    exit 2
fi

[[ $(grep -cFx "$PASS_MARKER" "$scratch/run.log" || true) -eq 1 ]]
[[ $(grep -cF "$FAIL_TOKEN" "$scratch/run.log" || true) -eq 0 ]]
python3 "$CHECKER"
python3 -c 'from pathlib import Path; print(Path("'$scratch'/run.log").read_text(), end="")'
printf '@@SYNC_MODE_OWNERSHIP_SAFETY_GATE_PASS@@ product_list_elaborated=1 integrated_top=final_top3 direct_shell=1\n'
