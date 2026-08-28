#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../../../.." && pwd -P)
TEST_DIR="$ROOT/fver/hardware_codec/unit/sync_product_core"
LEAF="$ROOT/source/design/hardware_codec/sync/enc128_v2_vendored.sv"
CORE="$ROOT/source/design/hardware_codec/sync/opendvs_sync_product_encoder_core.sv"
RUNNER="$TEST_DIR/run_sync_product_core_synthesis.sh"
README="$TEST_DIR/README.md"
TOP=opendvs_sync_product_encoder_core

CONTROLLER_EXPECTED_HOST=rpgraca-server
REMOTE_HOST=10.10.0.3
REMOTE_EXPECTED_HOST=rpgracaHPelite
REMOTE_ROUTE_VERSION=remote-host-v3
REMOTE_DRIVER_VERSION=product-core-remote-driver-v1
SCRATCH_PARENT=/tmp/opencode/dvs-encoder
REMOTE_SCRATCH_PARENT=/tmp/opencode/dvs-encoder
REMOTE_YOSYS=/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/yosys
REMOTE_PDK=/home/rpgraca/.ciel/ciel/sky130/versions/40cee970d8a9b7eaea35a34fe7d6068f05721f0a/sky130A
REMOTE_LIBERTY="$REMOTE_PDK/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
REMOTE_NO_SYNTH="$REMOTE_PDK/libs.tech/openlane/sky130_fd_sc_hd/no_synth.cells"
REMOTE_DRC_EXCLUDE="$REMOTE_PDK/libs.tech/openlane/sky130_fd_sc_hd/drc_exclude.cells"
REMOTE_SYNTHESIS_LIMIT_SECONDS=1800

EXPECTED_LEAF_SHA=0c77fa83ec15af0c06df96b04dcfc67dd02cad23ffd075cf1f59f879a6cad54d
EXPECTED_YOSYS_SHA=7c3e3396b38c129dd7485be5a0a0f0da8e495a94c8fd486059e3bea043a588d6
EXPECTED_YOSYS_VERSION='Yosys 0.68+120 (git sha1 a34d3baae-dirty, Release, Clang /usr/bin/clang++ 21.1.8)'
EXPECTED_LIBERTY_SHA=8e78e14442062dba34d414fca6490b2f6b96038d4510d1438ca44fee31487135
EXPECTED_NO_SYNTH_SHA=8bd5ee6d949870fd389d177d4b987eeb4d22b55614eea3de8a8f6705fd8982be
EXPECTED_DRC_EXCLUDE_SHA=8785391a0540d4b96b52b242dc57bf337860e607eed09a25664673f710a9afb7

PASS_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_SYNTHESIS_PASS@@'
PREFLIGHT_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_SYNTHESIS_PREFLIGHT_PASS@@'
FAIL_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_SYNTHESIS_FAIL@@'
BLOCKED_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_SYNTHESIS_ENVIRONMENT_BLOCKED@@'

usage() {
    printf 'usage: %s --preflight-remote|--run-remote|--resume-validation REMOTE_SCRATCH\n' "$0" >&2
}

design_fail() {
    local check=$1
    shift
    printf '%s check=%s message=%s\n' "$FAIL_MARKER" "$check" "$*" >&2
    exit 1
}

environment_block() {
    local check=$1
    shift
    printf '%s check=%s message=%s\n' "$BLOCKED_MARKER" "$check" "$*" >&2
    exit 4
}

hash_file() {
    local output
    output=$(sha256sum "$1")
    printf '%s\n' "${output%% *}"
}

guard_hash() {
    local path=$1 expected=$2 label=$3 class=${4:-design}
    if [[ ! -f "$path" || -L "$path" ]]; then
        if [[ "$class" == environment ]]; then
            environment_block "$label" "missing, non-regular, or symbolic-link path: $path"
        fi
        design_fail "$label" "missing, non-regular, or symbolic-link path: $path"
    fi
    local observed
    observed=$(hash_file "$path")
    if [[ "$observed" != "$expected" ]]; then
        if [[ "$class" == environment ]]; then
            environment_block "$label" \
                "SHA-256 mismatch expected=$expected observed=$observed path=$path"
        fi
        design_fail "$label" \
            "SHA-256 mismatch expected=$expected observed=$observed path=$path"
    fi
}

read_readme_hash() {
    local label=$1
    python3 -I - "$README" "$label" <<'PY'
import pathlib
import re
import sys
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
matches = re.findall(
    rf"^- {re.escape(sys.argv[2])}: `([0-9a-f]{{64}})`$", text, re.MULTILINE
)
if len(matches) != 1:
    raise SystemExit(f"README hash label {sys.argv[2]!r} occurs {len(matches)} times")
print(matches[0])
PY
}

verify_controller() {
    local observed
    observed=$(hostname)
    [[ "$observed" == "$CONTROLLER_EXPECTED_HOST" ]] || \
        environment_block controller_host \
            "remote synthesis must start on $CONTROLLER_EXPECTED_HOST, observed=$observed"
    [[ -d "$SCRATCH_PARENT" && ! -L "$SCRATCH_PARENT" && -w "$SCRATCH_PARENT" ]] || \
        environment_block scratch_parent \
            "controller scratch parent is absent, a symlink, or not writable"
    local tool
    for tool in timeout nice ionice ssh scp tar python3 sha256sum; do
        command -v "$tool" >/dev/null || \
            environment_block "controller_tool_$tool" "$tool is unavailable"
    done
}

verify_local_sources() {
    guard_hash "$LEAF" "$EXPECTED_LEAF_SHA" frozen_leaf
    [[ -f "$CORE" && ! -L "$CORE" ]] || \
        design_fail product_core "product core is absent, non-regular, or a symlink"
    local expected_runner_sha
    expected_runner_sha=$(read_readme_hash "Synthesis runner SHA-256") || \
        design_fail readme_synthesis_hash "could not read the unique synthesis runner hash"
    guard_hash "$RUNNER" "$expected_runner_sha" synthesis_runner
    python3 -I - "$CORE" <<'PY'
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
clean = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
clean = re.sub(r"//[^\n]*", "", clean)
if len(re.findall(r"\bmodule\s+opendvs_sync_product_encoder_core\b", clean)) != 1:
    raise SystemExit("product-core top declaration is not unique")
parameter = re.search(r"parameter\s+integer\s+QUEUE_DEPTH\s*=\s*(\d+)", clean)
if parameter is None or parameter.group(1) != "16":
    raise SystemExit("QUEUE_DEPTH default is not exactly 16")
instances = re.findall(
    r"\benc128\s*#\s*\((.*?)\)\s*([A-Za-z_$][\w$]*)\s*\((.*?)\)\s*;",
    clean,
    flags=re.S,
)
if len(instances) != 2:
    raise SystemExit(f"expected exactly two enc128 instances, observed {len(instances)}")
for parameters, name, ports in instances:
    for required in (
        r"\.NCOL\s*\(\s*128\s*\)",
        r"\.ROWW\s*\(\s*7\s*\)",
        r"\.THRESH\s*\(\s*15\s*\)",
    ):
        if re.search(required, parameters) is None:
            raise SystemExit(f"leaf instance {name} has non-frozen parameters")
    if re.search(r"\.in_dt\s*\(\s*32\s*'\s*d\s*0\s*\)", ports, re.I) is None:
        raise SystemExit(f"leaf instance {name} does not tie in_dt to 32'd0")
for forbidden in ("qdi", "event_link", "scanner", "chip_select", "wrapper"):
    if forbidden in clean.lower():
        raise SystemExit(f"forbidden source token remains: {forbidden}")
PY
}

remote_probe() {
    local evidence=$1 magic=$2
    local output
    set +e
    output=$(timeout --signal=TERM --kill-after=5s 60s \
        ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE_HOST" \
        bash -s -- "$REMOTE_EXPECTED_HOST" "$REMOTE_YOSYS" \
        "$REMOTE_LIBERTY" "$REMOTE_NO_SYNTH" "$REMOTE_DRC_EXCLUDE" \
        "$REMOTE_SCRATCH_PARENT" <<'REMOTE'
set -euo pipefail
expected_host=$1
yosys=$2
liberty=$3
no_synth=$4
drc_exclude=$5
scratch_parent=$6
[[ $(hostname) == "$expected_host" ]]
for tool in sha256sum timeout nice ionice python3 tar awk getconf pgrep cmp; do
    command -v "$tool" >/dev/null
done
[[ -x "$yosys" && ! -L "$yosys" ]]
for path in "$liberty" "$no_synth" "$drc_exclude"; do
    [[ -f "$path" && ! -L "$path" ]]
done
[[ -d "$scratch_parent" && ! -L "$scratch_parent" && -w "$scratch_parent" ]]
printf 'host\t%s\n' "$(hostname)"
printf 'yosys_sha256\t%s\n' "$(sha256sum "$yosys" | cut -d' ' -f1)"
printf 'yosys_version\t%s\n' "$("$yosys" -V)"
printf 'liberty_sha256\t%s\n' "$(sha256sum "$liberty" | cut -d' ' -f1)"
printf 'no_synth_sha256\t%s\n' "$(sha256sum "$no_synth" | cut -d' ' -f1)"
printf 'drc_exclude_sha256\t%s\n' "$(sha256sum "$drc_exclude" | cut -d' ' -f1)"
printf 'available_memory_kib\t%s\n' "$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
printf 'available_swap_kib\t%s\n' "$(awk '/^SwapFree:/ {print $2}' /proc/meminfo)"
printf 'logical_cpus\t%s\n' "$(getconf _NPROCESSORS_ONLN)"
python3 -I - <<'PY'
import pathlib
import re
rows = []
for entry in pathlib.Path('/proc').iterdir():
    if not entry.name.isdigit():
        continue
    try:
        cmd = (entry / 'cmdline').read_bytes().replace(b'\0', b' ').decode(errors='replace')
        stat = (entry / 'stat').read_text().split()
    except (FileNotFoundError, PermissionError, ProcessLookupError):
        continue
    if re.search(r'magic.*magicdnull', cmd, re.I):
        rows.append((int(entry.name), stat[21], cmd.strip()))
print(f"magic_count\t{len(rows)}")
for pid, start, cmd in sorted(rows):
    print(f"magic_identity\t{pid}:{start}:{cmd}")
PY
REMOTE
    )
    local rc=$?
    set -e
    [[ "$rc" -eq 0 ]] || \
        environment_block remote_environment "remote probe exited $rc: $output"
    printf '%s\n' "$output" >"$evidence"
    grep -E $'^magic_(count|identity)\t' "$evidence" >"$magic"
    [[ $(grep -Fxc $'host\t'"$REMOTE_EXPECTED_HOST" "$evidence" || true) -eq 1 ]] || \
        environment_block remote_host "unexpected remote host identity"
    [[ $(grep -Fxc $'yosys_sha256\t'"$EXPECTED_YOSYS_SHA" "$evidence" || true) -eq 1 ]] || \
        environment_block remote_yosys_hash "remote Yosys identity mismatch"
    [[ $(grep -Fxc $'yosys_version\t'"$EXPECTED_YOSYS_VERSION" "$evidence" || true) -eq 1 ]] || \
        environment_block remote_yosys_version "remote Yosys version mismatch"
    [[ $(grep -Fxc $'liberty_sha256\t'"$EXPECTED_LIBERTY_SHA" "$evidence" || true) -eq 1 ]] || \
        environment_block remote_liberty "remote Liberty identity mismatch"
    [[ $(grep -Fxc $'no_synth_sha256\t'"$EXPECTED_NO_SYNTH_SHA" "$evidence" || true) -eq 1 ]] || \
        environment_block remote_no_synth "remote no-synthesis identity mismatch"
    [[ $(grep -Fxc $'drc_exclude_sha256\t'"$EXPECTED_DRC_EXCLUDE_SHA" "$evidence" || true) -eq 1 ]] || \
        environment_block remote_drc_exclude "remote DRC-exclusion identity mismatch"
}

write_yosys_script() {
    local path=$1
    cat >"$path" <<'TCL'
yosys -import

proc read_exact_cell_list {path} {
    if {![file readable $path]} { error "cell exclusion file is not readable: $path" }
    set handle [open $path r]
    set cells {}
    while {[gets $handle line] >= 0} {
        set name [string trim $line]
        if {$name eq "" || [string match "#*" $name] || [string match "//*" $name]} { continue }
        lappend cells $name
    }
    close $handle
    return $cells
}

read_verilog -sv -noautowire $::env(PRODUCT_CORE_LEAF)
read_verilog -sv -noautowire $::env(PRODUCT_CORE_SOURCE)
hierarchy -check -top opendvs_sync_product_encoder_core
flatten
delete {t:$scopeinfo}
yosys proc
opt
fsm
opt -full
wreduce
opt_clean -purge
memory
opt
check -assert
select -assert-none {t:$dlatch} {t:$_DLATCH_*}
tee -q -o $::env(GENERIC_STAT_JSON) stat -json opendvs_sync_product_encoder_core
write_json $::env(GENERIC_JSON)
puts "OPENDVS_SYNC_PRODUCT_CORE_GENERIC_CHECK_PASS"

set exclusions [lsort -unique [concat \
    [read_exact_cell_list $::env(NO_SYNTH_CELLS)] \
    [read_exact_cell_list $::env(DRC_EXCLUDE_CELLS)]]]
if {[llength $exclusions] != 236} {
    error "qualified exclusion union has [llength $exclusions] cells, expected 236"
}
set dont_use_args {}
foreach cell $exclusions { lappend dont_use_args -dont_use $cell }

read_liberty -lib $::env(SKY130_LIBERTY)
techmap
opt
check -assert
dfflibmap -liberty $::env(SKY130_LIBERTY) {*}$dont_use_args
check -assert
abc -liberty $::env(SKY130_LIBERTY) {*}$dont_use_args
clean
delete {t:$scopeinfo}
check -assert -mapped
select -assert-none {t:$dlatch} {t:$_DLATCH_*}
tee -q -o $::env(MAPPED_STAT_JSON) \
    stat -json -liberty $::env(SKY130_LIBERTY) opendvs_sync_product_encoder_core
write_json $::env(MAPPED_JSON)
write_verilog -noattr -noexpr $::env(MAPPED_VERILOG)
puts "OPENDVS_SYNC_PRODUCT_CORE_SKY130_MAP_PASS"
TCL
}

write_validator() {
    local path=$1
    cat >"$path" <<'PY'
from __future__ import annotations

import hashlib
import json
import math
import pathlib
import re
import sys
from collections import Counter

(
    generic_path, mapped_path, stat_path, liberty_path, no_synth_path,
    drc_exclude_path, source_list_path, leaf_path, core_path, result_path,
    metrics_path, expected_leaf_sha, expected_core_sha, expected_yosys_sha,
    yosys_identity_path,
) = sys.argv[1:]
yosys_identity_path = pathlib.Path(yosys_identity_path)
paths = [pathlib.Path(item) for item in sys.argv[1:12]]
(
    generic_path, mapped_path, stat_path, liberty_path, no_synth_path,
    drc_exclude_path, source_list_path, leaf_path, core_path, result_path,
    metrics_path,
) = paths

TOP = "opendvs_sync_product_encoder_core"
PREFIX = "sky130_fd_sc_hd__"
CELL_RE = re.compile(r'(?m)^\s*cell\s*\(\s*(?:"([^"]+)"|([^\s\)]+))\s*\)\s*\{')
AREA_RE = re.compile(r'(?m)^\s*area\s*:\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s*;')
FF_RE = re.compile(r'(?m)^\s*ff\s*\(')
LATCH_RE = re.compile(r'(?m)^\s*latch\s*\(')
TIMESTAMP_NAMES = ("dtx", "dt6_r", "dt_esc_r")


def digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def names(path: pathlib.Path) -> set[str]:
    return {
        line.strip() for line in path.read_text(errors="replace").splitlines()
        if line.strip() and not line.lstrip().startswith(("#", "//"))
    }


def liberty_cells(text: str) -> dict[str, str]:
    result = {}
    for match in CELL_RE.finditer(text):
        name = match.group(1) or match.group(2)
        depth, index, quote = 1, match.end(), None
        escaped = block_comment = line_comment = False
        while index < len(text) and depth:
            char = text[index]
            nxt = text[index + 1] if index + 1 < len(text) else ""
            if line_comment:
                line_comment = char != "\n"; index += 1; continue
            if block_comment:
                if char == "*" and nxt == "/": block_comment = False; index += 2
                else: index += 1
                continue
            if quote is not None:
                if escaped: escaped = False
                elif char == "\\": escaped = True
                elif char == quote: quote = None
                index += 1; continue
            if char == "/" and nxt == "*": block_comment = True; index += 2; continue
            if char == "/" and nxt == "/": line_comment = True; index += 2; continue
            if char in {'"', "'"}: quote = char
            elif char == "{": depth += 1
            elif char == "}": depth -= 1
            index += 1
        if depth: raise SystemExit(f"unterminated Liberty cell block: {name}")
        result[name] = text[match.end():index - 1]
    return result


errors = []
if digest(leaf_path) != expected_leaf_sha or digest(core_path) != expected_core_sha:
    errors.append("staged source hash differs")
rows = [line.split("\t") for line in source_list_path.read_text().splitlines()]
expected_rows = [
    ["SV", str(leaf_path.resolve()), expected_leaf_sha],
    ["SV", str(core_path.resolve()), expected_core_sha],
]
if rows != expected_rows:
    errors.append(f"source closure is not the exact ordered two-row leaf+core list: {rows!r}")

core_text = core_path.read_text(encoding="utf-8")
clean_core = re.sub(r"/\*.*?\*/|//[^\n]*", "", core_text, flags=re.S)
instances = re.findall(
    r"\benc128\s*#\s*\((.*?)\)\s*([A-Za-z_$][\w$]*)\s*\((.*?)\)\s*;",
    clean_core, flags=re.S,
)
constant_zero_instances = sum(
    re.search(r"\.in_dt\s*\(\s*32\s*'\s*d\s*0\s*\)", ports, re.I) is not None
    for _, _, ports in instances
)
if len(instances) != 2 or constant_zero_instances != 2:
    errors.append("both leaf instances do not have structural zero delta time")

generic = json.loads(generic_path.read_text())
mapped = json.loads(mapped_path.read_text())
stat = json.loads(stat_path.read_text())
generic_top = generic.get("modules", {}).get(TOP, {})
timestamp_bits = set()
timestamp_netnames = []
for name, net in generic_top.get("netnames", {}).items():
    if any(token in name.lower() for token in TIMESTAMP_NAMES):
        timestamp_netnames.append(name)
        timestamp_bits.update(bit for bit in net.get("bits", []) if isinstance(bit, int))
timestamp_cell_names = [
    name for name in generic_top.get("cells", {})
    if any(token in name.lower() for token in TIMESTAMP_NAMES)
]
connected_timestamp_bits = set()
for cell in generic_top.get("cells", {}).values():
    if not isinstance(cell, dict):
        continue
    for bits in cell.get("connections", {}).values():
        connected_timestamp_bits.update(bit for bit in bits if bit in timestamp_bits)
if connected_timestamp_bits or timestamp_cell_names:
    errors.append(
        "timestamp-extension state remains: "
        f"connected_bits={len(connected_timestamp_bits)} cells={timestamp_cell_names!r}"
    )

modules = mapped.get("modules", {})
top = modules.get(TOP)
if not isinstance(top, dict):
    errors.append(f"mapped JSON lacks top {TOP}"); top = {}
marked = []
for name, module in modules.items():
    value = module.get("attributes", {}).get("top") if isinstance(module, dict) else None
    try: is_top = int(str(value), 2) != 0
    except (TypeError, ValueError): is_top = value in (1, True, "1")
    if is_top: marked.append(name)
if marked != [TOP]: errors.append(f"mapped top markers differ: {marked!r}")

lib_cells = liberty_cells(liberty_path.read_text(errors="replace"))
areas, ff_types, latch_types = {}, set(), set()
for name, body in lib_cells.items():
    match = AREA_RE.search(body)
    if match: areas[name] = float(match.group(1))
    if FF_RE.search(body): ff_types.add(name)
    if LATCH_RE.search(body): latch_types.add(name)
excluded = names(no_synth_path) | names(drc_exclude_path)
if len(excluded) != 236: errors.append(f"exclusion union has {len(excluded)} cells")

histogram = Counter()
cells = top.get("cells", {})
if not isinstance(cells, dict) or not cells: errors.append("mapped top has no cells"); cells = {}
for instance, cell in sorted(cells.items()):
    cell_type = cell.get("type") if isinstance(cell, dict) else None
    if not isinstance(cell_type, str): errors.append(f"cell {instance} lacks type"); continue
    histogram[cell_type] += 1
    if cell_type.startswith("$"): errors.append(f"generic cell remains: {cell_type}")
    if not cell_type.startswith(PREFIX): errors.append(f"non-Sky130 cell remains: {cell_type}")
    if cell_type in excluded: errors.append(f"excluded cell remains: {cell_type}")
    if cell_type not in lib_cells: errors.append(f"cell absent from Liberty: {cell_type}")
    if cell_type not in areas: errors.append(f"cell lacks area: {cell_type}")
    if cell_type in latch_types: errors.append(f"mapped latch remains: {cell_type}")

total = sum(histogram.values())
sequential = sum(count for name, count in histogram.items() if name in ff_types)
area = sum(count * areas.get(name, 0.0) for name, count in histogram.items())
stat_modules = stat.get("modules", {})
matches = [value for name, value in stat_modules.items() if name.lstrip("\\") == TOP]
if len(stat_modules) != 1 or len(matches) != 1:
    errors.append(f"mapped stat is not one flattened top: {sorted(stat_modules)!r}")
else:
    stat_top = matches[0]
    if int(stat_top.get("num_cells", -1)) != total: errors.append("stat cell count differs")
    if not math.isclose(float(stat_top.get("area", -1)), area, rel_tol=1e-9, abs_tol=1e-6):
        errors.append("stat area differs")
    for key in ("num_processes", "num_memories", "num_memory_bits"):
        if int(stat_top.get(key, 0)) != 0: errors.append(f"final stat {key} is nonzero")
if total <= 0 or sequential <= 0 or area <= 0:
    errors.append(f"non-positive metrics cells={total} sequential={sequential} area={area}")

result = {
    "schema": "opendvs-sync-product-core-synthesis-v1",
    "status": "PASS" if not errors else "FAIL",
    "top": TOP,
    "queue_depth": 16,
    "sources": [
        {"path": "source/design/hardware_codec/sync/enc128_v2_vendored.sv", "sha256": expected_leaf_sha},
        {"path": "source/design/hardware_codec/sync/opendvs_sync_product_encoder_core.sv", "sha256": expected_core_sha},
    ],
    "tool": {
        "path": "/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin/yosys",
        "sha256": expected_yosys_sha,
        "identity": yosys_identity_path.read_text().strip(),
    },
    "liberty": {
        "sha256": digest(liberty_path),
        "qualified_exclusion_union_cells": len(excluded),
    },
    "closure": {
        "design_sources": 2, "unresolved_modules": 0, "generic_cells": 0,
        "inferred_or_mapped_latches": 0, "excluded_cells": 0,
        "forbidden_sources": 0, "generated_clocks": 0,
    },
    "timestamp_extension": {
        "constant_zero_leaf_instances": constant_zero_instances,
        "dynamic_state_bits": len(connected_timestamp_bits),
        "unconnected_optimized_net_bits": len(timestamp_bits - connected_timestamp_bits),
        "mapped_state_cells": len(timestamp_cell_names),
        "observed_generic_netnames": sorted(timestamp_netnames),
        "state_eliminated": not connected_timestamp_bits and not timestamp_cell_names,
    },
    "metrics": {
        "total_cells": total, "sequential_cells": sequential,
        "liberty_area_um2": round(area, 6),
        "cell_histogram": dict(sorted(histogram.items())),
    },
    "claims": {"timing_closure": "NOT_CLAIMED", "physical_feasibility": "NOT_CLAIMED"},
    "errors": errors,
}
result_path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
if errors:
    for error in errors: print(f"SYNTHESIS_VALIDATION_ERROR: {error}", file=sys.stderr)
    raise SystemExit(1)
metrics_path.write_text(f"{total}\t{sequential}\t{area:.6f}\n", encoding="ascii")
print(
    "OPENDVS_SYNC_PRODUCT_CORE_SYNTHESIS_VALIDATION_PASS "
    f"total_cells={total} sequential_cells={sequential} liberty_area_um2={area:.6f} "
    "timestamp_extension_state_bits=0"
)
PY
}

verify_no_owned_remote_processes() {
    local remote_scratch=$1 evidence=$2
    local output
    set +e
    output=$(timeout --signal=TERM --kill-after=5s 30s \
        ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE_HOST" \
        python3 -I - "$remote_scratch" <<'PY'
import os
import pathlib
import sys
scratch = sys.argv[1]
self_pid = os.getpid()
parent = os.getppid()
matches = []
for entry in pathlib.Path('/proc').iterdir():
    if not entry.name.isdigit() or int(entry.name) in {self_pid, parent}:
        continue
    try: cmd = (entry / 'cmdline').read_bytes().replace(b'\0', b' ').decode(errors='replace')
    except (FileNotFoundError, PermissionError, ProcessLookupError): continue
    if scratch in cmd and ('yosys' in cmd or 'product-core-remote-driver' in cmd):
        matches.append((entry.name, cmd.strip()))
for pid, cmd in matches: print(f"{pid}\t{cmd}")
raise SystemExit(1 if matches else 0)
PY
    )
    local rc=$?
    set -e
    printf '%s\n' "$output" >"$evidence"
    [[ "$rc" -eq 0 ]] || \
        environment_block remote_owned_processes \
            "campaign-owned remote process remains: $output"
}

preflight_remote() {
    verify_controller
    verify_local_sources
    local scratch
    scratch=$(mktemp -d "$SCRATCH_PARENT/sync-product-core-synthesis-preflight.XXXXXXXX")
    remote_probe "$scratch/remote-environment.tsv" "$scratch/magic.tsv"
    printf '%s route=%s controller=%s host=%s sources=2 top=%s depth=16 exclusions=236\n' \
        "$PREFLIGHT_MARKER" "$REMOTE_ROUTE_VERSION" "$CONTROLLER_EXPECTED_HOST" \
        "$REMOTE_EXPECTED_HOST" "$TOP"
}

run_remote() {
    verify_controller
    verify_local_sources
    local core_sha
    core_sha=$(hash_file "$CORE")
    local controller_scratch
    controller_scratch=$(mktemp -d \
        "$SCRATCH_PARENT/sync-product-core-synthesis-${REMOTE_ROUTE_VERSION}-controller.XXXXXXXX")
    remote_probe "$controller_scratch/remote-preflight.before.tsv" \
        "$controller_scratch/magic.before.tsv"

    local remote_scratch
    set +e
    remote_scratch=$(timeout --signal=TERM --kill-after=5s 30s \
        ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE_HOST" \
        bash -s -- "$REMOTE_EXPECTED_HOST" "$REMOTE_SCRATCH_PARENT" \
        "$REMOTE_ROUTE_VERSION" <<'REMOTE'
set -euo pipefail
[[ $(hostname) == "$1" ]]
[[ -d "$2" && ! -L "$2" && -w "$2" ]]
mktemp -d "$2/sync-product-core-synthesis-$3.XXXXXXXX"
REMOTE
    )
    local scratch_rc=$?
    set -e
    [[ "$scratch_rc" -eq 0 && \
       "$remote_scratch" == "$REMOTE_SCRATCH_PARENT/sync-product-core-synthesis-${REMOTE_ROUTE_VERSION}."* ]] || \
        environment_block remote_scratch \
            "unique HPelite scratch creation failed exit=$scratch_rc observed=$remote_scratch"
    printf '%s\n' "$remote_scratch" >"$controller_scratch/remote-scratch-path.txt"

    write_yosys_script "$controller_scratch/synthesize.tcl"
    write_validator "$controller_scratch/validate.py"
    printf 'SV\t%s/enc128_v2_vendored.sv\t%s\nSV\t%s/opendvs_sync_product_encoder_core.sv\t%s\n' \
        "$remote_scratch" "$EXPECTED_LEAF_SHA" \
        "$remote_scratch" "$core_sha" >"$controller_scratch/source-list.tsv"

    local driver_name="$REMOTE_DRIVER_VERSION.sh"
    local driver="$controller_scratch/$driver_name"
    {
        printf '#!/usr/bin/env bash\nset -euo pipefail\n'
        printf 'readonly SCRATCH=%q\n' "$remote_scratch"
        printf 'readonly EXPECTED_HOST=%q\n' "$REMOTE_EXPECTED_HOST"
        printf 'readonly YOSYS=%q\n' "$REMOTE_YOSYS"
        printf 'readonly LIBERTY=%q\n' "$REMOTE_LIBERTY"
        printf 'readonly NO_SYNTH=%q\n' "$REMOTE_NO_SYNTH"
        printf 'readonly DRC_EXCLUDE=%q\n' "$REMOTE_DRC_EXCLUDE"
        printf 'readonly EXPECTED_LEAF_SHA=%q\n' "$EXPECTED_LEAF_SHA"
        printf 'readonly EXPECTED_CORE_SHA=%q\n' "$core_sha"
        printf 'readonly EXPECTED_YOSYS_SHA=%q\n' "$EXPECTED_YOSYS_SHA"
        printf 'readonly EXPECTED_LIBERTY_SHA=%q\n' "$EXPECTED_LIBERTY_SHA"
        printf 'readonly EXPECTED_NO_SYNTH_SHA=%q\n' "$EXPECTED_NO_SYNTH_SHA"
        printf 'readonly EXPECTED_DRC_EXCLUDE_SHA=%q\n' "$EXPECTED_DRC_EXCLUDE_SHA"
        printf 'readonly EXPECTED_YOSYS_VERSION=%q\n' "$EXPECTED_YOSYS_VERSION"
        printf 'readonly LIMIT_SECONDS=%q\n' "$REMOTE_SYNTHESIS_LIMIT_SECONDS"
        printf 'readonly DRIVER_NAME=%q\n' "$driver_name"
        cat <<'REMOTE_DRIVER'

[[ $(hostname) == "$EXPECTED_HOST" ]]
[[ -d "$SCRATCH" && ! -L "$SCRATCH" ]]
cd "$SCRATCH"
shopt -s nullglob dotglob
entries=("$SCRATCH"/*)
[[ ${#entries[@]} -eq 6 ]]
for name in enc128_v2_vendored.sv opendvs_sync_product_encoder_core.sv \
        synthesize.tcl validate.py source-list.tsv "$DRIVER_NAME"; do
    [[ -f "$name" && ! -L "$name" ]]
done
hash_file() { sha256sum "$1" | cut -d' ' -f1; }
[[ $(hash_file enc128_v2_vendored.sv) == "$EXPECTED_LEAF_SHA" ]]
[[ $(hash_file opendvs_sync_product_encoder_core.sv) == "$EXPECTED_CORE_SHA" ]]
[[ $(hash_file "$YOSYS") == "$EXPECTED_YOSYS_SHA" ]]
[[ $("$YOSYS" -V) == "$EXPECTED_YOSYS_VERSION" ]]
[[ $(hash_file "$LIBERTY") == "$EXPECTED_LIBERTY_SHA" ]]
[[ $(hash_file "$NO_SYNTH") == "$EXPECTED_NO_SYNTH_SHA" ]]
[[ $(hash_file "$DRC_EXCLUDE") == "$EXPECTED_DRC_EXCLUDE_SHA" ]]
mapfile -t rows <source-list.tsv
[[ ${#rows[@]} -eq 2 ]]
[[ "${rows[0]}" == $'SV\t'"$SCRATCH/enc128_v2_vendored.sv"$'\t'"$EXPECTED_LEAF_SHA" ]]
[[ "${rows[1]}" == $'SV\t'"$SCRATCH/opendvs_sync_product_encoder_core.sv"$'\t'"$EXPECTED_CORE_SHA" ]]

printf '%s\n' "$EXPECTED_HOST" >remote-host.txt
printf '%s\n' "$EXPECTED_YOSYS_VERSION" >yosys-identity.txt
printf 'route\tremote-host-v3\nsource_count\t2\ntop\topendvs_sync_product_encoder_core\nqueue_depth\t16\n' \
    >route-identity.tsv
sha256sum enc128_v2_vendored.sv opendvs_sync_product_encoder_core.sv \
    synthesize.tcl validate.py source-list.tsv "$DRIVER_NAME" >staged.before.sha256

export PRODUCT_CORE_LEAF="$SCRATCH/enc128_v2_vendored.sv"
export PRODUCT_CORE_SOURCE="$SCRATCH/opendvs_sync_product_encoder_core.sv"
export SKY130_LIBERTY="$LIBERTY"
export NO_SYNTH_CELLS="$NO_SYNTH"
export DRC_EXCLUDE_CELLS="$DRC_EXCLUDE"
export GENERIC_STAT_JSON="$SCRATCH/generic-stat.json"
export GENERIC_JSON="$SCRATCH/generic.json"
export MAPPED_STAT_JSON="$SCRATCH/mapped-stat.json"
export MAPPED_JSON="$SCRATCH/mapped.json"
export MAPPED_VERILOG="$SCRATCH/mapped.v"

printf '%q ' timeout --signal=TERM --kill-after=10s "${LIMIT_SECONDS}s" \
    nice -n 19 ionice -c 3 "$YOSYS" -c "$SCRATCH/synthesize.tcl" \
    >yosys-command.txt
printf '\n' >>yosys-command.txt
printf '0\ttimeout\n1\t--signal=TERM\n2\t--kill-after=10s\n3\t%ss\n4\tnice\n5\t-n\n6\t19\n7\tionice\n8\t-c\n9\t3\n10\t%s\n11\t-c\n12\t%s\n' \
    "$LIMIT_SECONDS" "$YOSYS" "$SCRATCH/synthesize.tcl" >yosys-command.arguments.tsv
set +e
timeout --signal=TERM --kill-after=10s "${LIMIT_SECONDS}s" \
    nice -n 19 ionice -c 3 "$YOSYS" -c "$SCRATCH/synthesize.tcl" \
    >yosys.stdout.log 2>yosys.stderr.log
yosys_rc=$?
set -e
printf '%s\n' "$yosys_rc" >yosys.exit.txt
[[ "$yosys_rc" -eq 0 ]]
[[ -s generic-stat.json && -s generic.json && -s mapped-stat.json && \
   -s mapped.json && -s mapped.v ]]

for repeat in 1 2; do
    timeout --signal=TERM --kill-after=5s 60s python3 -I validate.py \
        generic.json mapped.json mapped-stat.json "$LIBERTY" "$NO_SYNTH" \
        "$DRC_EXCLUDE" source-list.tsv enc128_v2_vendored.sv \
        opendvs_sync_product_encoder_core.sv "result-$repeat.json" \
        "metrics-$repeat.tsv" "$EXPECTED_LEAF_SHA" "$EXPECTED_CORE_SHA" \
        "$EXPECTED_YOSYS_SHA" yosys-identity.txt \
        >"validator-$repeat.stdout.log" 2>"validator-$repeat.stderr.log"
done
cmp -s result-1.json result-2.json
cmp -s metrics-1.tsv metrics-2.tsv
cp result-1.json result.json
cp metrics-1.tsv metrics.tsv
[[ $(hash_file enc128_v2_vendored.sv) == "$EXPECTED_LEAF_SHA" ]]
[[ $(hash_file opendvs_sync_product_encoder_core.sv) == "$EXPECTED_CORE_SHA" ]]
printf 'PASS\n' >remote-status.txt
REMOTE_DRIVER
    } >"$driver"
    bash -n "$driver" || design_fail remote_driver_syntax "generated driver failed Bash syntax"

    local stage_files=(
        "$LEAF" "$CORE" "$controller_scratch/synthesize.tcl"
        "$controller_scratch/validate.py" "$controller_scratch/source-list.tsv" "$driver"
    )
    set +e
    timeout --signal=TERM --kill-after=10s 180s nice -n 19 ionice -c 3 \
        scp -q -o BatchMode=yes -o ConnectTimeout=10 \
        "${stage_files[@]}" "$REMOTE_HOST:$remote_scratch/" \
        >"$controller_scratch/stage.stdout.log" 2>"$controller_scratch/stage.stderr.log"
    local stage_rc=$?
    set -e
    [[ "$stage_rc" -eq 0 ]] || environment_block remote_stage \
        "exact six-file stage failed exit=$stage_rc remote=$remote_scratch"

    local remote_driver="$remote_scratch/$driver_name"
    printf '0\tbash\n1\t%s\n' "$remote_driver" \
        >"$controller_scratch/remote-command.arguments.tsv"
    printf '%q ' bash "$remote_driver" >"$controller_scratch/remote-command.txt"
    printf '\n' >>"$controller_scratch/remote-command.txt"
    set +e
    timeout --signal=TERM --kill-after=30s \
        "$((REMOTE_SYNTHESIS_LIMIT_SECONDS + 180))s" \
        ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE_HOST" \
        bash "$remote_driver" \
        >"$controller_scratch/remote-run.stdout.log" \
        2>"$controller_scratch/remote-run.stderr.log"
    local run_rc=$?
    set -e
    printf '%s\n' "$run_rc" >"$controller_scratch/remote-run.exit.txt"

    set +e
    timeout --signal=TERM --kill-after=10s 120s \
        ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE_HOST" \
        bash -s -- "$remote_scratch" "$EXPECTED_LEAF_SHA" "$core_sha" <<'REMOTE' \
        >"$controller_scratch/finalize.stdout.log" \
        2>"$controller_scratch/finalize.stderr.log"
set -euo pipefail
cd "$1"
[[ $(sha256sum enc128_v2_vendored.sv | cut -d' ' -f1) == "$2" ]]
[[ $(sha256sum opendvs_sync_product_encoder_core.sv | cut -d' ' -f1) == "$3" ]]
files=()
for name in source-list.tsv synthesize.tcl validate.py staged.before.sha256 \
        remote-host.txt route-identity.tsv yosys-identity.txt yosys-command.txt \
        yosys-command.arguments.tsv yosys.exit.txt yosys.stdout.log yosys.stderr.log \
        generic-stat.json generic.json mapped-stat.json mapped.json mapped.v \
        validator-1.stdout.log validator-1.stderr.log validator-2.stdout.log \
        validator-2.stderr.log result.json metrics.tsv remote-status.txt; do
    [[ -f "$name" ]] && files+=("$name")
done
sha256sum "${files[@]}" >evidence-manifest.sha256
tar -czf compact-evidence.tgz "${files[@]}" evidence-manifest.sha256
sha256sum compact-evidence.tgz >compact-evidence.sha256
REMOTE
    local finalize_rc=$?
    set -e
    [[ "$finalize_rc" -eq 0 ]] || environment_block remote_finalize \
        "remote evidence finalization failed exit=$finalize_rc"

    set +e
    timeout --signal=TERM --kill-after=10s 180s nice -n 19 ionice -c 3 \
        scp -q -o BatchMode=yes -o ConnectTimeout=10 \
        "$REMOTE_HOST:$remote_scratch/compact-evidence.tgz" \
        "$REMOTE_HOST:$remote_scratch/compact-evidence.sha256" \
        "$controller_scratch/" \
        >"$controller_scratch/retrieve.stdout.log" \
        2>"$controller_scratch/retrieve.stderr.log"
    local retrieve_rc=$?
    set -e
    [[ "$retrieve_rc" -eq 0 ]] || environment_block remote_retrieve \
        "remote evidence retrieval failed exit=$retrieve_rc"
    (cd "$controller_scratch" && sha256sum -c compact-evidence.sha256 >/dev/null)
    mkdir "$controller_scratch/retrieved"
    tar -xzf "$controller_scratch/compact-evidence.tgz" \
        -C "$controller_scratch/retrieved"
    (cd "$controller_scratch/retrieved" && sha256sum -c evidence-manifest.sha256 >/dev/null)

    remote_probe "$controller_scratch/remote-preflight.after.tsv" \
        "$controller_scratch/magic.after.tsv"
    cmp -s "$controller_scratch/magic.before.tsv" \
        "$controller_scratch/magic.after.tsv" || \
        environment_block magic_preservation \
            "Magic process identities changed during product-core mapping"
    verify_no_owned_remote_processes "$remote_scratch" \
        "$controller_scratch/owned-processes.after.tsv"
    verify_local_sources
    [[ $(hash_file "$CORE") == "$core_sha" ]] || \
        design_fail source_preservation "local product core changed during synthesis"

    local retrieved="$controller_scratch/retrieved"
    local yosys_rc=missing
    [[ -f "$retrieved/yosys.exit.txt" ]] && yosys_rc=$(<"$retrieved/yosys.exit.txt")
    if [[ "$run_rc" -ne 0 ]]; then
        if [[ "$run_rc" -eq 124 || "$yosys_rc" == 124 || "$yosys_rc" == 137 ]]; then
            environment_block remote_yosys_timeout \
                "single remote run timed out run_exit=$run_rc yosys_exit=$yosys_rc remote=$remote_scratch"
        fi
        design_fail remote_synthesis \
            "single remote run failed run_exit=$run_rc yosys_exit=$yosys_rc remote=$remote_scratch"
    fi
    [[ "$yosys_rc" == 0 && -s "$retrieved/result.json" && \
       -s "$retrieved/metrics.tsv" && $(<"$retrieved/remote-status.txt") == PASS ]] || \
        design_fail remote_outputs "mapped evidence is incomplete"
    grep -Fq 'OPENDVS_SYNC_PRODUCT_CORE_SKY130_MAP_PASS' \
        "$retrieved/yosys.stdout.log" || design_fail mapping_marker "mapped marker absent"
    grep -Fq 'OPENDVS_SYNC_PRODUCT_CORE_SYNTHESIS_VALIDATION_PASS' \
        "$retrieved/validator-1.stdout.log" || \
        design_fail validation_marker "validator marker absent"

    local total sequential area
    IFS=$'\t' read -r total sequential area <"$retrieved/metrics.tsv"
    [[ "$total" =~ ^[1-9][0-9]*$ && "$sequential" =~ ^[1-9][0-9]*$ && \
       "$area" =~ ^[0-9]+\.[0-9]+$ ]] || \
        design_fail mapped_metrics \
            "mapped metrics are malformed cells=$total sequential=$sequential area=$area"
    printf 'OPENDVS_SYNC_PRODUCT_CORE_SYNTHESIS_RESULT route=%s host=%s core_sha256=%s total_cells=%s sequential_cells=%s liberty_area_um2=%s timestamp_extension_state_bits=0 exclusions=236 remote_evidence=%s controller_evidence=%s\n' \
        "$REMOTE_ROUTE_VERSION" "$REMOTE_EXPECTED_HOST" "$core_sha" "$total" \
        "$sequential" "$area" "$remote_scratch" "$controller_scratch"
    printf '%s\n' "$PASS_MARKER"
}

resume_validation() {
    local remote_scratch=$1
    verify_controller
    verify_local_sources
    [[ "$remote_scratch" == "$REMOTE_SCRATCH_PARENT/sync-product-core-synthesis-${REMOTE_ROUTE_VERSION}."* ]] || \
        environment_block resume_remote_scratch \
            "validation resume path is not a product-core remote-host-v3 scratch"
    local core_sha
    core_sha=$(hash_file "$CORE")
    local controller_scratch
    controller_scratch=$(mktemp -d \
        "$SCRATCH_PARENT/sync-product-core-synthesis-validation-resume-controller.XXXXXXXX")
    remote_probe "$controller_scratch/remote-preflight.before.tsv" \
        "$controller_scratch/magic.before.tsv"
    write_validator "$controller_scratch/validate-resume.py"

    set +e
    timeout --signal=TERM --kill-after=10s 60s nice -n 19 ionice -c 3 \
        scp -q -o BatchMode=yes -o ConnectTimeout=10 \
        "$controller_scratch/validate-resume.py" \
        "$REMOTE_HOST:$remote_scratch/validate-resume.py" \
        >"$controller_scratch/stage.stdout.log" \
        2>"$controller_scratch/stage.stderr.log"
    local stage_rc=$?
    set -e
    [[ "$stage_rc" -eq 0 ]] || environment_block resume_validator_stage \
        "corrected validation-only script stage failed exit=$stage_rc"

    set +e
    timeout --signal=TERM --kill-after=10s 240s \
        ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE_HOST" \
        bash -s -- "$remote_scratch" "$REMOTE_EXPECTED_HOST" \
        "$REMOTE_LIBERTY" "$REMOTE_NO_SYNTH" "$REMOTE_DRC_EXCLUDE" \
        "$EXPECTED_LEAF_SHA" "$core_sha" "$EXPECTED_YOSYS_SHA" <<'REMOTE' \
        >"$controller_scratch/remote-validation.stdout.log" \
        2>"$controller_scratch/remote-validation.stderr.log"
set -euo pipefail
scratch=$1
expected_host=$2
liberty=$3
no_synth=$4
drc_exclude=$5
leaf_sha=$6
core_sha=$7
yosys_sha=$8
[[ $(hostname) == "$expected_host" ]]
[[ -d "$scratch" && ! -L "$scratch" ]]
cd "$scratch"
for name in enc128_v2_vendored.sv opendvs_sync_product_encoder_core.sv \
        source-list.tsv generic.json mapped.json mapped-stat.json \
        yosys-identity.txt yosys.exit.txt yosys.stdout.log \
        validator-1.stderr.log validate-resume.py; do
    [[ -f "$name" && ! -L "$name" ]]
done
[[ $(<yosys.exit.txt) == 0 ]]
grep -Fq 'OPENDVS_SYNC_PRODUCT_CORE_SKY130_MAP_PASS' yosys.stdout.log
grep -Fq "AttributeError: 'str' object has no attribute 'read_text'" \
    validator-1.stderr.log
[[ $(sha256sum enc128_v2_vendored.sv | cut -d' ' -f1) == "$leaf_sha" ]]
[[ $(sha256sum opendvs_sync_product_encoder_core.sv | cut -d' ' -f1) == "$core_sha" ]]
mapfile -t rows <source-list.tsv
[[ ${#rows[@]} -eq 2 ]]
[[ "${rows[0]}" == $'SV\t'"$scratch/enc128_v2_vendored.sv"$'\t'"$leaf_sha" ]]
[[ "${rows[1]}" == $'SV\t'"$scratch/opendvs_sync_product_encoder_core.sv"$'\t'"$core_sha" ]]
for repeat in 1 2; do
    timeout --signal=TERM --kill-after=5s 60s python3 -I validate-resume.py \
        generic.json mapped.json mapped-stat.json "$liberty" "$no_synth" \
        "$drc_exclude" source-list.tsv enc128_v2_vendored.sv \
        opendvs_sync_product_encoder_core.sv "result-resume-$repeat.json" \
        "metrics-resume-$repeat.tsv" "$leaf_sha" "$core_sha" "$yosys_sha" \
        yosys-identity.txt >"validator-resume-$repeat.stdout.log" \
        2>"validator-resume-$repeat.stderr.log"
done
cmp -s result-resume-1.json result-resume-2.json
cmp -s metrics-resume-1.tsv metrics-resume-2.tsv
cp result-resume-1.json result-resume.json
cp metrics-resume-1.tsv metrics-resume.tsv
printf 'PASS\n' >validation-resume-status.txt
files=(
    source-list.tsv yosys-identity.txt yosys.exit.txt yosys.stdout.log
    validator-1.stderr.log validate-resume.py result-resume.json
    metrics-resume.tsv validator-resume-1.stdout.log
    validator-resume-1.stderr.log validator-resume-2.stdout.log
    validator-resume-2.stderr.log validation-resume-status.txt
)
sha256sum "${files[@]}" >validation-resume-evidence-manifest.sha256
tar -czf validation-resume-evidence.tgz "${files[@]}" \
    validation-resume-evidence-manifest.sha256
sha256sum validation-resume-evidence.tgz >validation-resume-evidence.sha256
REMOTE
    local validation_rc=$?
    set -e
    printf '%s\n' "$validation_rc" >"$controller_scratch/remote-validation.exit.txt"
    [[ "$validation_rc" -eq 0 ]] || design_fail resumed_validation \
        "single validation-only correction failed exit=$validation_rc remote=$remote_scratch"

    set +e
    timeout --signal=TERM --kill-after=10s 120s nice -n 19 ionice -c 3 \
        scp -q -o BatchMode=yes -o ConnectTimeout=10 \
        "$REMOTE_HOST:$remote_scratch/validation-resume-evidence.tgz" \
        "$REMOTE_HOST:$remote_scratch/validation-resume-evidence.sha256" \
        "$controller_scratch/" >"$controller_scratch/retrieve.stdout.log" \
        2>"$controller_scratch/retrieve.stderr.log"
    local retrieve_rc=$?
    set -e
    [[ "$retrieve_rc" -eq 0 ]] || environment_block resume_retrieve \
        "validation-only evidence retrieval failed exit=$retrieve_rc"
    (cd "$controller_scratch" && \
        sha256sum -c validation-resume-evidence.sha256 >/dev/null)
    mkdir "$controller_scratch/retrieved"
    tar -xzf "$controller_scratch/validation-resume-evidence.tgz" \
        -C "$controller_scratch/retrieved"
    (cd "$controller_scratch/retrieved" && \
        sha256sum -c validation-resume-evidence-manifest.sha256 >/dev/null)

    remote_probe "$controller_scratch/remote-preflight.after.tsv" \
        "$controller_scratch/magic.after.tsv"
    cmp -s "$controller_scratch/magic.before.tsv" \
        "$controller_scratch/magic.after.tsv" || \
        environment_block resume_magic_preservation \
            "Magic process identities changed during validation-only correction"
    verify_no_owned_remote_processes "$remote_scratch" \
        "$controller_scratch/owned-processes.after.tsv"
    verify_local_sources
    [[ $(hash_file "$CORE") == "$core_sha" ]] || \
        design_fail resume_source_preservation \
            "local product core changed during validation-only correction"

    local retrieved="$controller_scratch/retrieved"
    [[ $(<"$retrieved/validation-resume-status.txt") == PASS ]] || \
        design_fail resume_status "validation-only status is not PASS"
    grep -Fq 'OPENDVS_SYNC_PRODUCT_CORE_SYNTHESIS_VALIDATION_PASS' \
        "$retrieved/validator-resume-1.stdout.log" || \
        design_fail resume_marker "validation-only PASS marker is absent"
    local total sequential area
    IFS=$'\t' read -r total sequential area <"$retrieved/metrics-resume.tsv"
    [[ "$total" =~ ^[1-9][0-9]*$ && "$sequential" =~ ^[1-9][0-9]*$ && \
       "$area" =~ ^[0-9]+\.[0-9]+$ ]] || design_fail resume_metrics \
        "mapped metrics are malformed cells=$total sequential=$sequential area=$area"
    printf 'OPENDVS_SYNC_PRODUCT_CORE_SYNTHESIS_RESULT route=%s host=%s core_sha256=%s total_cells=%s sequential_cells=%s liberty_area_um2=%s timestamp_extension_state_bits=0 exclusions=236 mapping_runs=1 validation_resume=1 remote_evidence=%s controller_evidence=%s\n' \
        "$REMOTE_ROUTE_VERSION" "$REMOTE_EXPECTED_HOST" "$core_sha" "$total" \
        "$sequential" "$area" "$remote_scratch" "$controller_scratch"
    printf '%s\n' "$PASS_MARKER"
}

mode=${1:---run-remote}
case "$mode" in
    --preflight-remote) [[ $# -eq 1 ]] || { usage; exit 2; }; preflight_remote ;;
    --run-remote) [[ $# -eq 1 ]] || { usage; exit 2; }; run_remote ;;
    --resume-validation)
        [[ $# -eq 2 ]] || { usage; exit 2; }
        resume_validation "$2"
        ;;
    *) usage; exit 2 ;;
esac
