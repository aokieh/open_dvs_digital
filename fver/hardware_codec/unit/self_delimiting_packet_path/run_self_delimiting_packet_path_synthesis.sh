#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly ROOT=$(CDPATH= builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && builtin pwd -P)
readonly TEST_DIR="$ROOT/fver/hardware_codec/unit/self_delimiting_packet_path"
readonly CHECKER="$TEST_DIR/check_self_delimiting_packet_path.py"
readonly PRODUCT="$ROOT/source/design/hardware_codec/sync/opendvs_self_delimiting_packet_path.sv"
readonly TOP=opendvs_self_delimiting_packet_path
readonly YOSYS=/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/yosys
readonly YOSYS_SHA256=7c3e3396b38c129dd7485be5a0a0f0da8e495a94c8fd486059e3bea043a588d6
readonly SCRATCH_PARENT=/tmp/opencode/dvs-encoder
readonly FAIL_MARKER='@@OPENDVS_SELF_DELIMITING_PACKET_PATH_SYNTHESIS_FAIL@@'
readonly PREFLIGHT_MARKER='@@OPENDVS_SELF_DELIMITING_PACKET_PATH_SYNTHESIS_PREFLIGHT_PASS@@'
readonly PASS_MARKER='@@OPENDVS_SELF_DELIMITING_PACKET_PATH_SYNTHESIS_PASS@@ banks=1 bank_bytes=40 unresolved_cells=0 latches=0'

fail() {
    local check=$1
    shift
    printf '%s check=%s message=%s\n' "$FAIL_MARKER" "$check" "$*" >&2
    exit 1
}

hash_file() {
    local line
    line=$(sha256sum -- "$1") || return 1
    printf '%s\n' "${line%% *}"
}

verify() {
    [[ -f $CHECKER && ! -L $CHECKER ]] || fail checker "checker absent"
    python3 -I "$CHECKER" --preflight >/dev/null || fail checker "contract preflight failed"
    [[ -f $PRODUCT && ! -L $PRODUCT ]] ||
        fail missing_product_module "product module is absent: $PRODUCT"
    [[ -x $YOSYS && ! -L $YOSYS ]] || fail yosys "pinned Yosys absent"
    [[ $(hash_file "$YOSYS") == "$YOSYS_SHA256" ]] || fail yosys "Yosys digest changed"
    [[ -d $SCRATCH_PARENT && ! -L $SCRATCH_PARENT && -w $SCRATCH_PARENT ]] ||
        fail scratch_parent "scratch parent unavailable"
    python3 -I - "$PRODUCT" <<'PY' || exit 1
import pathlib
import re
import sys
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
clean = re.sub(r"/\*.*?\*/|//[^\n]*", " ", text, flags=re.S)
if len(re.findall(r"\bmodule\s+opendvs_self_delimiting_packet_path\b", clean)) != 1:
    raise SystemExit("product top declaration is not unique")
patterns = (
    r"logic\s*\[\s*7\s*:\s*0\s*\]\s+\w*packet\w*bank\w*\s*\[\s*0\s*:\s*39\s*\]",
    r"logic\s*\[\s*319\s*:\s*0\s*\]\s+\w*packet\w*bank\w*",
)
if sum(bool(re.search(pattern, clean, re.I)) for pattern in patterns) != 1:
    raise SystemExit("source does not expose exactly one structural 40-byte packet bank")
PY
}

run_synthesis() {
    local scratch
    scratch=$(mktemp -d "$SCRATCH_PARENT/self-delimiting-packet-synthesis.XXXXXXXXXX")
    trap "rm -rf -- '$scratch'" EXIT HUP INT TERM
    cat >"$scratch/synth.ys" <<YOSYS
read_verilog -sv -noautowire $PRODUCT
hierarchy -check -top $TOP
proc
opt
fsm
opt
memory
opt
check -assert
select -assert-none t:\$dlatch t:\$_DLATCH_*
tee -q -o $scratch/stat.json stat -json $TOP
write_json $scratch/netlist.json
YOSYS
    timeout --signal=TERM --kill-after=10s 600s "$YOSYS" -s "$scratch/synth.ys" \
        >"$scratch/yosys.log" 2>&1 || {
        python3 -I - "$scratch/yosys.log" <<'PY' >&2
import pathlib
import sys
sys.stderr.write(pathlib.Path(sys.argv[1]).read_text(errors="replace"))
PY
        fail synthesis "generic synthesis failed"
    }
    python3 -I - "$scratch/netlist.json" "$TOP" <<'PY' || exit 1
import json
import pathlib
import sys
data = json.loads(pathlib.Path(sys.argv[1]).read_text())
top = data.get("modules", {}).get(sys.argv[2])
if not isinstance(top, dict):
    raise SystemExit("mapped JSON lacks the packet-path top")
cells = top.get("cells", {})
if any(cell.get("type") in {"$dlatch", "$_DLATCH_"} for cell in cells.values()):
    raise SystemExit("latch cell remains")
PY
    printf '%s\n' "$PASS_MARKER"
}

case ${1-} in
    --preflight)
        [[ $# -eq 1 ]] || fail usage "expected one argument"
        verify
        printf '%s top=%s bank_bytes=40\n' "$PREFLIGHT_MARKER" "$TOP"
        ;;
    --run)
        [[ $# -eq 1 ]] || fail usage "expected one argument"
        verify
        run_synthesis
        ;;
    *)
        printf 'usage: %s --preflight|--run\n' "$0" >&2
        exit 2
        ;;
esac
