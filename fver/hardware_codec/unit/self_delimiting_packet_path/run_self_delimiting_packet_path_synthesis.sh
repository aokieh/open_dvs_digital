#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR=$(CDPATH= builtin cd -- "${BASH_SOURCE[0]%/*}" && builtin pwd -P)
readonly ROOT=$(CDPATH= builtin cd -- "$SCRIPT_DIR/../../../.." && builtin pwd -P)
readonly TEST_DIR="$ROOT/fver/hardware_codec/unit/self_delimiting_packet_path"
readonly CHECKER="$TEST_DIR/check_self_delimiting_packet_path.py"
readonly PRODUCT="$ROOT/source/design/hardware_codec/sync/opendvs_self_delimiting_packet_path.sv"
readonly TOP=opendvs_self_delimiting_packet_path
readonly YOSYS_BIN=/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/yosys
readonly YOSYS_SHA256=7c3e3396b38c129dd7485be5a0a0f0da8e495a94c8fd486059e3bea043a588d6
readonly PYTHON=/usr/bin/python3.14
readonly ENV_BIN=/usr/bin/env
readonly SHA256SUM=/usr/bin/sha256sum
readonly TIMEOUT=/usr/bin/timeout
readonly MKTEMP=/usr/bin/mktemp
readonly CHMOD=/usr/bin/chmod
readonly RM=/usr/bin/rm
readonly SCRATCH_PARENT=/tmp/opencode/dvs-encoder
readonly FAIL_MARKER='@@OPENDVS_SELF_DELIMITING_PACKET_PATH_SYNTHESIS_FAIL@@'
readonly PREFLIGHT_MARKER='@@OPENDVS_SELF_DELIMITING_PACKET_PATH_SYNTHESIS_PREFLIGHT_PASS@@'
readonly PASS_MARKER='@@OPENDVS_SELF_DELIMITING_PACKET_PATH_SYNTHESIS_PASS@@ banks=1 bank_bytes=40 unresolved_cells=0 latches=0'

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
    for name in BASH_ENV ENV CDPATH YOSYS YOSYS_FLAGS YOSYS_DATDIR \
                VERILOG_SOURCES SYSTEMVERILOG_SOURCES RTL_SOURCES \
                EXTRA_SOURCES SOURCE_FILES EXTRA_VERILOG_FILES \
                GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE TMPDIR TEMP TMP \
                PYTHONPATH PYTHONHOME LD_PRELOAD LD_LIBRARY_PATH; do
        [[ ! -v $name ]] || fail environment_injection "rejected variable=$name"
    done
}

verify() {
    [[ $TEST_DIR == "$ROOT/fver/hardware_codec/unit/self_delimiting_packet_path" ]] ||
        fail fixed_path "synthesis runner escaped the frozen package path"
    local path
    for path in "$CHECKER" "$PRODUCT"; do
        [[ -f $path && ! -L $path ]] || fail fixed_path "missing or nonregular path=$path"
    done
    [[ -x $YOSYS_BIN && ! -L $YOSYS_BIN ]] || fail yosys "pinned Yosys absent"
    [[ $(hash_file "$YOSYS_BIN") == "$YOSYS_SHA256" ]] ||
        fail yosys "Yosys digest changed"
    for path in "$PYTHON" "$ENV_BIN" "$SHA256SUM" "$TIMEOUT" "$MKTEMP" \
                "$CHMOD" "$RM"; do
        [[ -x $path && ! -L $path ]] || fail host_tools "unpinned host tool path=$path"
    done
    [[ -d $SCRATCH_PARENT && ! -L $SCRATCH_PARENT && -w $SCRATCH_PARENT ]] ||
        fail scratch_parent "scratch parent unavailable"

    "$ENV_BIN" -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C PYTHONDONTWRITEBYTECODE=1 \
        "$PYTHON" -I "$CHECKER" --preflight >/dev/null ||
        fail checker "contract preflight failed"
    "$PYTHON" -I - "$PRODUCT" <<'PY' || fail source_structure "source structure differs"
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
clean = re.sub(r"/\*.*?\*/|//[^\n]*", " ", text, flags=re.S)
if len(re.findall(r"\bmodule\s+opendvs_self_delimiting_packet_path\b", clean)) != 1:
    raise SystemExit("product top declaration is not unique")
packed_bank = re.findall(
    r"\blogic\s*\[\s*319\s*:\s*0\s*\]\s+([A-Za-z_$][\w$]*)\s*;",
    clean,
)
if packed_bank.count("packet_bank_q") != 1:
    raise SystemExit("source lacks the unique packed 320-bit retained bank")
if re.search(r"\blogic\s*\[\s*7\s*:\s*0\s*\]\s+\w*bank\w*\s*\[", clean, re.I):
    raise SystemExit("source retains a fixture-style byte-array bank")
if "work_body" in clean or re.search(r"\btask\s+automatic\s+(?:append|clear)", clean):
    raise SystemExit("source retains fixture builder structure")
PY
}

prepare_scratch() {
    SCRATCH=$($MKTEMP -d "$SCRATCH_PARENT/self-delimiting-packet-synthesis.XXXXXXXXXX") ||
        fail scratch "could not create unique scratch"
    case $SCRATCH in
        "$SCRATCH_PARENT"/self-delimiting-packet-synthesis.*) ;;
        *) fail scratch "scratch path escaped fixed parent" ;;
    esac
    "$CHMOD" 700 "$SCRATCH"
}

cleanup() {
    local rc=$?
    trap - EXIT HUP INT TERM
    if [[ -n ${SCRATCH:-} && -d ${SCRATCH:-} ]]; then
        "$RM" -rf -- "$SCRATCH"
    fi
    exit "$rc"
}

run_synthesis() {
    prepare_scratch
    trap cleanup EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM

    builtin printf '%s\n' \
        "read_verilog -sv -noautowire $PRODUCT" \
        "hierarchy -check -top $TOP" \
        'proc' \
        'check -assert' \
        "write_json $SCRATCH/retained-bank.json" \
        'opt' \
        'fsm' \
        'opt' \
        'memory' \
        'opt' \
        'check -assert' \
        'select -assert-none t:$dlatch t:$_DLATCH_*' \
        "tee -q -o $SCRATCH/stat.json stat -json $TOP" \
        "write_json $SCRATCH/netlist.json" >"$SCRATCH/synth.ys"

    set +e
    "$ENV_BIN" -i HOME=/tmp PATH=/usr/bin:/bin LC_ALL=C TMPDIR="$SCRATCH" \
        "$TIMEOUT" --signal=TERM --kill-after=10s 600s \
        "$YOSYS_BIN" -s "$SCRATCH/synth.ys" >"$SCRATCH/yosys.log" 2>&1
    local rc=$?
    set -e
    if (( rc != 0 )); then
        print_file "$SCRATCH/yosys.log"
        fail synthesis "generic synthesis exited $rc"
    fi

    "$PYTHON" -I - "$SCRATCH/retained-bank.json" \
        "$SCRATCH/netlist.json" "$TOP" <<'PY' || {
import json
import pathlib
import sys

def load_top(path, top_name):
    data = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    module = data.get("modules", {}).get(top_name)
    if not isinstance(module, dict):
        raise SystemExit(f"mapped JSON lacks the packet-path top: {path}")
    return module


def bank_bits(module, label):
    bank = module.get("netnames", {}).get("packet_bank_q")
    if not isinstance(bank, dict) or len(bank.get("bits", [])) != 320:
        raise SystemExit(f"{label} lacks named 320-bit packet_bank_q")
    return tuple(bank["bits"])


top_name = sys.argv[3]
structural = load_top(sys.argv[1], top_name)
structural_bits = bank_bits(structural, "post-proc structure")
if len(set(structural_bits)) != 320 or not all(
        isinstance(bit, int) for bit in structural_bits
):
    raise SystemExit("post-proc packet bank bits are aliased or constant")

structural_drivers = []
retained_320 = []
for name, cell in structural.get("cells", {}).items():
    cell_type = str(cell.get("type", ""))
    q_bits = tuple(cell.get("connections", {}).get("Q", []))
    if set(q_bits) & set(structural_bits):
        structural_drivers.append((name, cell_type, q_bits))
    if "dff" in cell_type.lower() and len(q_bits) == 320:
        retained_320.append((name, cell_type, q_bits))
if len(structural_drivers) != 1:
    raise SystemExit(
        f"post-proc packet bank sequential driver count={len(structural_drivers)}"
    )
driver_name, driver_type, driver_bits = structural_drivers[0]
if "dff" not in driver_type.lower() or driver_bits != structural_bits:
    raise SystemExit(
        f"post-proc packet bank driver differs: {driver_name}:{driver_type}:"
        f"{len(driver_bits)}"
    )
if retained_320 != [structural_drivers[0]]:
    raise SystemExit(
        f"post-proc retained 320-bit banks differ: "
        f"{[(name, kind) for name, kind, _ in retained_320]}"
    )

final = load_top(sys.argv[2], top_name)
final_bits = bank_bits(final, "optimized structure")
variable_bits = tuple(bit for bit in final_bits if isinstance(bit, int))
if len(set(variable_bits)) != len(variable_bits):
    raise SystemExit("optimized packet bank variable bits are aliased")
if any(bit not in {"0", "1", "x", "z"} for bit in final_bits if not isinstance(bit, int)):
    raise SystemExit("optimized packet bank contains an invalid constant bit")

final_drivers = []
latches = []
unresolved = []
for name, cell in final.get("cells", {}).items():
    cell_type = str(cell.get("type", ""))
    lower_type = cell_type.lower()
    if "latch" in lower_type:
        latches.append((name, cell_type))
    if not cell_type.startswith("$"):
        unresolved.append((name, cell_type))
    q_bits = tuple(cell.get("connections", {}).get("Q", []))
    if set(q_bits) & set(variable_bits):
        final_drivers.append((name, cell_type, q_bits))
if latches:
    raise SystemExit(f"latch cells remain: {latches}")
if unresolved:
    raise SystemExit(f"unresolved cells remain: {unresolved}")
if len(final_drivers) != 1:
    raise SystemExit(f"optimized packet bank driver count={len(final_drivers)}")
final_name, final_type, final_driver_bits = final_drivers[0]
if "dff" not in final_type.lower() or final_driver_bits != variable_bits:
    raise SystemExit(
        f"optimized packet bank driver differs: {final_name}:{final_type}:"
        f"{len(final_driver_bits)} variable={len(variable_bits)}"
    )
PY
        fail generated_structure "generated packet-bank structure differs"
    }
    printf '%s\n' "$PASS_MARKER"
}

main() {
    [[ $# -eq 1 ]] || fail usage "expected one argument"
    case $1 in
        --preflight|--run) ;;
        *) fail usage "expected --preflight or --run" ;;
    esac
    export LC_ALL=C
    export PYTHONDONTWRITEBYTECODE=1
    umask 077
    reject_environment_injection
    verify
    case $1 in
        --preflight)
            printf '%s top=%s bank_bytes=40 generated_bank_gate=enabled\n' \
                "$PREFLIGHT_MARKER" "$TOP"
            ;;
        --run) run_synthesis ;;
    esac
}

main "$@"
