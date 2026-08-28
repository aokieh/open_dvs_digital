#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../../../.." && pwd -P)
TEST_DIR="$ROOT/fver/hardware_codec/unit/sync_product_core"
FROZEN_DIR="$TEST_DIR/frozen"
SPEC="/home/rpgraca/opencode-sessions/dvs-encoder/.ocs/artifacts/files/aed-codec-campaign-v0/work/hardware-codec-v1/digital-repository-integration/sync-encoder-product-core-spec-v1.md"
LEAF="$ROOT/source/design/hardware_codec/sync/enc128_v2_vendored.sv"
CORE="$ROOT/source/design/hardware_codec/sync/opendvs_sync_product_encoder_core.sv"
TESTBENCH="$TEST_DIR/tb_opendvs_sync_product_encoder_core.sv"
V1_ARCHIVE="$FROZEN_DIR/run_sync_product_core_v1.sh"
V2_RUNNER="$TEST_DIR/run_sync_product_core.sh"
V2_ARCHIVE="$FROZEN_DIR/run_sync_product_core_v2.sh"
V2_README_ARCHIVE="$FROZEN_DIR/README_v2.md"
RUNNER="$TEST_DIR/run_sync_product_core_xcelium_v3.sh"
README="$TEST_DIR/README.md"

XRUN=/opt/cadence/ius-21.09.006/lnx86/tools.lnx86/inca/bin/64bit/xrun
TIMEOUT=/usr/bin/timeout
SHA256SUM=/usr/bin/sha256sum
SCRATCH_PARENT=/tmp/opencode/dvs-encoder
LICENSE_VARIABLE=LM_LICENSE_FILE
LICENSE_VALUE=8152@lic-cadence-e.ethz.ch
ELABORATION_LIMIT_SECONDS=240
RUN_LIMIT_SECONDS=600

EXPECTED_SPEC_SHA=564c6eece59908d6ed047d0e8268ad344e770ba9bf279212dff22b729ed1bd30
EXPECTED_LEAF_SHA=0c77fa83ec15af0c06df96b04dcfc67dd02cad23ffd075cf1f59f879a6cad54d
EXPECTED_TESTBENCH_SHA=a03887d936fe53c905b5b7ae1b418bab31efc24896bb333e4809178d7f15a923
EXPECTED_V1_ARCHIVE_SHA=c6cb6195143e5ff5a977ef810544f399d3f75307da4467d7e557bfb1f0cc0f1a
EXPECTED_V2_SHA=6a2364b5a42447798e51806a74be0736b2edb05cb1305faffa1a49cf797e05e6
EXPECTED_V2_README_SHA=1e6f587ade9c9d5726c16a15e041f2c764b034a14ad6beaa303ab5a9a2aee6e5
EXPECTED_XRUN_SHA=c2fd01c847845bd35cd20cce428464934a7c42a65666dfc4929e81607989a8a9
EXPECTED_XRUN_VERSION=21.09-s006
EXPECTED_COMPAT_TESTBENCH_SHA=eaefb783b2408058c193ef3434a5877487e22600fd4c3e92da38170b79f9e38b

PASS_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_PASS@@ mapping_cases=3096 tiers=2 sparse_boundary=15 raw_boundary=16 queue_depth_test=4'
FAIL_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_FAIL@@'
PLANT_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_PLANT_DETECTED@@'
DIRECT_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_XCELIUM_LEAF_PREFLIGHT_PASS@@'
FIXTURE_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_XCELIUM_FIXTURE_PREFLIGHT_PASS@@'
XCELIUM_BLOCKED_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_XCELIUM_BLOCKED@@'

fail() {
    local check=$1
    shift
    printf '%s check=%s message=%s\n' "$FAIL_MARKER" "$check" "$*" >&2
    exit 1
}

block_xcelium() {
    local check=$1
    shift
    printf '%s check=%s message=%s\n' "$XCELIUM_BLOCKED_MARKER" "$check" "$*" >&2
    exit 4
}

hash_file() {
    local output
    output=$($SHA256SUM "$1")
    printf '%s\n' "${output%% *}"
}

guard_hash() {
    local path=$1 expected=$2 label=$3
    [[ -f "$path" && ! -L "$path" ]] || \
        fail "$label" "missing, non-regular, or symbolic-link path: $path"
    local observed
    observed=$(hash_file "$path")
    [[ "$observed" == "$expected" ]] || \
        fail "$label" \
            "SHA-256 mismatch expected=$expected observed=$observed path=$path"
}

read_readme_hash() {
    local label=$1
    python3 -I - "$README" "$label" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
label = re.escape(sys.argv[2])
matches = re.findall(rf"^- {label}: `([0-9a-f]{{64}})`$", text, re.MULTILINE)
if len(matches) != 1:
    raise SystemExit(f"README hash label {sys.argv[2]!r} occurs {len(matches)} times")
print(matches[0])
PY
}

guard_frozen_inputs() {
    [[ -x "$TIMEOUT" && -x "$SHA256SUM" ]] || \
        fail required_tools "timeout or sha256sum is absent"
    [[ -d "$SCRATCH_PARENT" && ! -L "$SCRATCH_PARENT" && -w "$SCRATCH_PARENT" ]] || \
        fail scratch_parent "scratch parent is absent, a symlink, or not writable"
    guard_hash "$SPEC" "$EXPECTED_SPEC_SHA" frozen_specification
    guard_hash "$LEAF" "$EXPECTED_LEAF_SHA" frozen_leaf
    guard_hash "$TESTBENCH" "$EXPECTED_TESTBENCH_SHA" frozen_testbench
    guard_hash "$V1_ARCHIVE" "$EXPECTED_V1_ARCHIVE_SHA" archived_v1_runner
    guard_hash "$V2_RUNNER" "$EXPECTED_V2_SHA" active_v2_runner
    guard_hash "$V2_ARCHIVE" "$EXPECTED_V2_SHA" archived_v2_runner
    guard_hash "$V2_README_ARCHIVE" "$EXPECTED_V2_README_SHA" archived_v2_readme
    local readme_runner_sha
    readme_runner_sha=$(read_readme_hash "Xcelium v3 runner SHA-256") || \
        fail readme_v3_hash "could not read the unique v3 runner hash"
    guard_hash "$RUNNER" "$readme_runner_sha" xcelium_v3_runner
}

write_command() {
    local path=$1
    shift
    printf '%q ' "$@" >"$path"
    printf '\n' >>"$path"
}

write_arguments() {
    local path=$1
    shift
    : >"$path"
    local index=0 argument
    for argument in "$@"; do
        printf '%d\t%s\n' "$index" "$argument" >>"$path"
        index=$((index + 1))
    done
}

show_logs() {
    local path
    for path in "$@"; do
        [[ -f "$path" ]] || continue
        printf '%s\n' "--- $path ---" >&2
        python3 -I - "$path" <<'PY' >&2
import pathlib
import sys
sys.stderr.write(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace"))
PY
    done
}

xcelium_license_failure() {
    local path
    for path in "$@"; do
        [[ -f "$path" ]] || continue
        if grep -Eiq 'NOLIC|license[^[:cntrl:]]*(fail|denied|unavailable|checkout)|FlexNet[^[:cntrl:]]*(fail|denied)' \
                "$path"; then
            return 0
        fi
    done
    return 1
}

select_xcelium() {
    [[ -x "$XRUN" && ! -L "$XRUN" ]] || \
        block_xcelium tool_xrun "exact Xcelium executable is absent or a symlink: $XRUN"
    guard_hash "$XRUN" "$EXPECTED_XRUN_SHA" xrun_executable
    local command=("$XRUN" -version)
    write_command "$SCRATCH/xrun-version.command.txt" \
        env "$LICENSE_VARIABLE=$LICENSE_VALUE" "${command[@]}"
    write_arguments "$SCRATCH/xrun-version.arguments.tsv" "${command[@]}"
    set +e
    env "$LICENSE_VARIABLE=$LICENSE_VALUE" \
        "$TIMEOUT" --signal=TERM --kill-after=5s 30s "${command[@]}" \
        >"$SCRATCH/xrun-version.stdout.log" 2>"$SCRATCH/xrun-version.stderr.log"
    local rc=$?
    set -e
    printf '%s\n' "$rc" >"$SCRATCH/xrun-version.exit.txt"
    if [[ "$rc" -ne 0 ]]; then
        if xcelium_license_failure "$SCRATCH/xrun-version.stdout.log" \
                "$SCRATCH/xrun-version.stderr.log"; then
            block_xcelium xrun_version_license "Xcelium version probe could not obtain a license"
        fi
        fail xrun_version "Xcelium version probe exited $rc"
    fi
    grep -Eq "^TOOL:[[:space:]]+xrun\(64\)[[:space:]]+$EXPECTED_XRUN_VERSION$" \
        "$SCRATCH/xrun-version.stdout.log" || \
        fail xrun_version "Xcelium version is not exactly $EXPECTED_XRUN_VERSION"
    printf 'path\t%s\nsha256\t%s\nversion\t%s\nlicense_variable\t%s\nlicense_value\t%s\n' \
        "$XRUN" "$EXPECTED_XRUN_SHA" "$EXPECTED_XRUN_VERSION" \
        "$LICENSE_VARIABLE" "$LICENSE_VALUE" >"$SCRATCH/xrun-identity.tsv"
}

generate_compatibility_testbench() {
    COMPAT_TESTBENCH="$SCRATCH/tb_opendvs_sync_product_encoder_core.xcelium.sv"
    COMPAT_MANIFEST="$SCRATCH/xcelium-testbench-transformation.tsv"
    python3 -I - "$TESTBENCH" "$COMPAT_TESTBENCH" "$COMPAT_MANIFEST" <<'PY'
from __future__ import annotations

import pathlib
import sys

source, destination, manifest = map(pathlib.Path, sys.argv[1:])
source_lines = source.read_text(encoding="utf-8").splitlines(keepends=True)
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
plain = [line.removesuffix("\n") for line in source_lines]
if sum("$finish_and_return" in line for line in plain) != 3:
    raise SystemExit("frozen testbench must contain exactly three $finish_and_return calls")
if len(source_lines) != 1372:
    raise SystemExit(f"frozen testbench line count differs: {len(source_lines)}")

derived = list(source_lines)
rows = []
for line_number, (old, new) in changes.items():
    if plain[line_number - 1] != old or plain.count(old) != 1:
        raise SystemExit(f"compatibility anchor differs or is non-unique at line {line_number}")
    ending = "\n" if source_lines[line_number - 1].endswith("\n") else ""
    derived[line_number - 1] = new + ending
    rows.append((line_number, old, new))

derived_plain = [line.removesuffix("\n") for line in derived]
differences = [
    (index + 1, old, new)
    for index, (old, new) in enumerate(zip(plain, derived_plain))
    if old != new
]
if differences != rows or len(rows) != 3 or len(derived) != len(source_lines):
    raise SystemExit(f"compatibility differences are not the exact three anchors: {differences!r}")
if sum("$finish_and_return" in line for line in derived_plain) != 0:
    raise SystemExit("derived testbench retained a $finish_and_return call")
destination.write_text("".join(derived), encoding="utf-8", newline="\n")
manifest.write_text(
    "".join(f"{line}\t{old}\t{new}\n" for line, old, new in rows),
    encoding="utf-8",
    newline="\n",
)
PY
    guard_hash "$COMPAT_TESTBENCH" "$EXPECTED_COMPAT_TESTBENCH_SHA" \
        xcelium_compatibility_testbench
    [[ $(wc -l <"$COMPAT_MANIFEST") -eq 3 ]] || \
        fail compatibility_manifest "transformation manifest is not exactly three rows"
}

write_leaf_top() {
    local path=$1
    python3 -I - "$path" <<'PY'
import pathlib
import sys
pathlib.Path(sys.argv[1]).write_text("""`timescale 1ns/1ps
`default_nettype none
module tb_enc128_leaf_elaboration;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    wire in_rdy;
    wire out_val;
    wire [7:0] out_data;
    enc128 #(.NCOL(128), .ROWW(7), .THRESH(15)) dut (
        .clk(clk), .rst_n(rst_n),
        .in_val(1'b0), .in_rdy(in_rdy),
        .in_row(7'd0), .in_pol(1'b0), .in_mask(128'd0), .in_dt(32'd0),
        .out_val(out_val), .out_rdy(1'b0), .out_data(out_data)
    );
endmodule
`default_nettype wire
""", encoding="utf-8", newline="\n")
PY
}

write_exact_port_stub() {
    local path=$1
    python3 -I - "$path" <<'PY'
import pathlib
import sys
pathlib.Path(sys.argv[1]).write_text("""`timescale 1ns/1ps
`default_nettype none
module opendvs_sync_product_encoder_core #(
    parameter integer QUEUE_DEPTH = 16
) (
    input logic clk_i, input logic arst_ni, input logic admit_enable_i,
    input logic top_record_valid_i, input logic [135:0] top_record_i,
    output logic top_record_accepted_o,
    input logic bottom_record_valid_i, input logic [135:0] bottom_record_i,
    output logic bottom_record_accepted_o,
    output logic top_fragment_valid_o, input logic top_fragment_ready_i,
    output logic top_fragment_raw_o, output logic [4:0] top_fragment_length_o,
    output logic [135:0] top_fragment_payload_o,
    output logic bottom_fragment_valid_o, input logic bottom_fragment_ready_i,
    output logic bottom_fragment_raw_o, output logic [4:0] bottom_fragment_length_o,
    output logic [135:0] bottom_fragment_payload_o,
    output logic quiescent_o, output logic [31:0] accepted_count_o,
    output logic [31:0] empty_suppressed_count_o,
    output logic [31:0] illegal_label_count_o,
    output logic [31:0] disabled_suppressed_count_o,
    output logic [31:0] overflow_count_o, output logic [31:0] sparse_count_o,
    output logic [31:0] raw_count_o, output logic [31:0] retired_count_o,
    output logic sticky_fault_o
);
endmodule
`default_nettype wire
""", encoding="utf-8", newline="\n")
PY
}

write_source_manifest() {
    local path=$1
    shift
    : >"$path"
    local source
    for source in "$@"; do
        printf 'SV\t%s\t%s\n' "$source" "$(hash_file "$source")" >>"$path"
    done
}

validate_elaboration_arguments() {
    local argument_path=$1 top=$2
    shift 2
    python3 -I - "$argument_path" "$XRUN" "$top" "$@" <<'PY'
from __future__ import annotations

import pathlib
import sys

argument_path = pathlib.Path(sys.argv[1])
xrun, top = sys.argv[2:4]
sources = list(sys.argv[4:])
arguments = []
for expected_index, line in enumerate(argument_path.read_text(encoding="utf-8").splitlines()):
    index, argument = line.split("\t", 1)
    if int(index) != expected_index:
        raise SystemExit("argument indices are not contiguous")
    arguments.append(argument)
if not arguments or arguments[0] != xrun:
    raise SystemExit("qualified Xcelium executable is not argument zero")
if "-sv" in arguments or "-v2001" in arguments:
    raise SystemExit("forbidden global parser switch")
if arguments.count("-sysv_ext") != 1:
    raise SystemExit("-sysv_ext must occur exactly once")
index = arguments.index("-sysv_ext")
if arguments[index + 1] != ".sv":
    raise SystemExit("-sysv_ext does not bind .sv")
if arguments.count("-top") != 1 or arguments[arguments.index("-top") + 1] != top:
    raise SystemExit("wrong or non-unique top")
if arguments.count("-elaborate") != 1:
    raise SystemExit("elaboration command must contain exactly one -elaborate")
if "-snapshot" in arguments:
    raise SystemExit("elaboration must use the unique library's fresh default snapshot")
observed = [item for item in arguments if item.endswith(".sv") and item != ".sv"]
if observed != sources or len(set(observed)) != len(sources):
    raise SystemExit(f"source order/count differs: {observed!r}")
PY
}

validate_run_arguments() {
    local argument_path=$1 plant=$2
    python3 -I - "$argument_path" "$XRUN" "$plant" <<'PY'
from __future__ import annotations

import pathlib
import sys

path, xrun, plant = sys.argv[1:]
arguments = []
for expected_index, line in enumerate(pathlib.Path(path).read_text().splitlines()):
    index, argument = line.split("\t", 1)
    if int(index) != expected_index:
        raise SystemExit("argument indices are not contiguous")
    arguments.append(argument)
if arguments[0] != xrun or arguments.count("-R") != 1:
    raise SystemExit("run command does not use exact Xcelium -R")
if "-snapshot" in arguments:
    raise SystemExit("run command must reuse the unique library's last fresh snapshot")
for forbidden in ("-elaborate", "-sysv_ext", "-sv", "-v2001", "-top"):
    if forbidden in arguments:
        raise SystemExit(f"run command contains forbidden elaboration/parser token: {forbidden}")
if any(item.endswith(".sv") for item in arguments):
    raise SystemExit("run command contains a source file")
plusargs = [item for item in arguments if item.startswith("+PLANT=")]
expected = [] if plant == "none" else [f"+PLANT={plant}"]
if plusargs != expected:
    raise SystemExit(f"run plusargs differ: {plusargs!r}")
PY
}

validate_elaboration_evidence() {
    local log=$1 top=$2
    shift 2
    local module
    for module in "$@"; do
        grep -Fq "module worklib.$module:sv" "$log" || \
            fail elaboration_evidence "SystemVerilog module evidence absent: $module"
    done
    grep -Fq "Writing initial simulation snapshot: worklib.$top:sv" "$log" || \
        fail elaboration_evidence "snapshot/top evidence absent for $top"
    if grep -Fq "$PASS_MARKER" "$log" || grep -Fq "$FAIL_MARKER" "$log" || \
       grep -Fq "$PLANT_MARKER" "$log"; then
        fail preflight_behavior "elaboration-only log emitted a behavioral marker"
    fi
}

run_elaboration() {
    local name=$1 top=$2
    shift 2
    local sources=("$@")
    local run_dir="$SCRATCH/$name"
    mkdir -p "$run_dir"
    local log="$run_dir/xrun.log"
    local command=(
        "$XRUN" -64bit -sysv_ext .sv -timescale 1ns/1ps
        -top "$top" -elaborate
        -xmlibdirname "$run_dir/xcelium.d" -l "$log"
        "${sources[@]}"
    )
    write_command "$run_dir/xrun.command.txt" \
        env "$LICENSE_VARIABLE=$LICENSE_VALUE" "${command[@]}"
    write_arguments "$run_dir/xrun.arguments.tsv" "${command[@]}"
    write_source_manifest "$run_dir/source-manifest.tsv" "${sources[@]}"
    validate_elaboration_arguments "$run_dir/xrun.arguments.tsv" \
        "$top" "${sources[@]}" || \
        fail xrun_arguments "$name argument vector violates the exact closure"
    set +e
    (cd "$run_dir" && env "$LICENSE_VARIABLE=$LICENSE_VALUE" \
        "$TIMEOUT" --signal=TERM --kill-after=10s "${ELABORATION_LIMIT_SECONDS}s" \
        "${command[@]}" >process.stdout.log 2>process.stderr.log)
    local rc=$?
    set -e
    printf '%s\n' "$rc" >"$run_dir/exit.txt"
    if [[ "$rc" -ne 0 ]]; then
        if xcelium_license_failure "$log" "$run_dir/process.stdout.log" \
                "$run_dir/process.stderr.log"; then
            block_xcelium "${name}_license" "Xcelium elaboration could not obtain a license"
        fi
        show_logs "$log" "$run_dir/process.stdout.log" "$run_dir/process.stderr.log"
        fail "${name}_elaboration" "Xcelium elaboration exited $rc"
    fi
    printf '%s\n' "$run_dir"
}

record_source_hashes() {
    local path=$1
    printf 'specification\t%s\nleaf\t%s\ntestbench\t%s\nv1_archive\t%s\nv2_archive\t%s\nv2_readme_archive\t%s\nproduct_core\t%s\ncompatibility_testbench\t%s\n' \
        "$(hash_file "$SPEC")" "$(hash_file "$LEAF")" \
        "$(hash_file "$TESTBENCH")" "$(hash_file "$V1_ARCHIVE")" \
        "$(hash_file "$V2_ARCHIVE")" "$(hash_file "$V2_README_ARCHIVE")" \
        "$(hash_file "$CORE")" "$(hash_file "$COMPAT_TESTBENCH")" >"$path"
}

validate_unplanted_log() {
    local log=$1
    python3 -I - "$log" "$PASS_MARKER" "$FAIL_MARKER" "$PLANT_MARKER" <<'PY'
import pathlib
import sys
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
passed, failed, planted = sys.argv[2:]
lines = text.splitlines()
if lines.count(passed) != 1:
    raise SystemExit(f"GREEN marker count was {lines.count(passed)}, expected one")
if failed in text or planted in text:
    raise SystemExit("unplanted run emitted a FAIL or plant marker")
PY
}

validate_plant_log() {
    local log=$1 plant=$2 check=$3
    python3 -I - "$log" "$plant" "$check" "$PASS_MARKER" "$FAIL_MARKER" \
        "$PLANT_MARKER" <<'PY'
import pathlib
import sys
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
plant, check, passed, failed, planted = sys.argv[2:]
expected = f"{planted} plant={plant} check={check}"
lines = text.splitlines()
if lines.count(expected) != 1:
    raise SystemExit(f"named plant marker count was {lines.count(expected)}, expected one")
if passed in text or failed in text:
    raise SystemExit("plant emitted PASS or generic FAIL")
if sum(planted in line for line in lines) != 1:
    raise SystemExit("plant emitted an extra plant marker")
PY
}

run_snapshot_once() {
    local real_dir=$1 name=$2 plant=$3
    local log="$real_dir/run-$name.log"
    local command=(
        "$XRUN" -64bit -R
        -xmlibdirname "$real_dir/xcelium.d" -l "$log"
    )
    [[ "$plant" == none ]] || command+=("+PLANT=$plant")
    write_command "$real_dir/run-$name.command.txt" \
        env "$LICENSE_VARIABLE=$LICENSE_VALUE" "${command[@]}"
    write_arguments "$real_dir/run-$name.arguments.tsv" "${command[@]}"
    validate_run_arguments "$real_dir/run-$name.arguments.tsv" "$plant" || \
        fail run_arguments "snapshot run argument vector differs for $name"
    set +e
    (cd "$real_dir" && env "$LICENSE_VARIABLE=$LICENSE_VALUE" \
        "$TIMEOUT" --signal=TERM --kill-after=10s "${RUN_LIMIT_SECONDS}s" \
        "${command[@]}" >"run-$name.stdout.log" 2>"run-$name.stderr.log")
    local rc=$?
    set -e
    printf '%s\n' "$rc" >"$real_dir/run-$name.raw-exit.txt"
    if [[ "$plant" == none ]]; then
        [[ "$rc" -eq 0 ]] || {
            show_logs "$log" "$real_dir/run-$name.stdout.log" "$real_dir/run-$name.stderr.log"
            fail green_unplanted "unplanted snapshot run exited $rc"
        }
        validate_unplanted_log "$log" || {
            show_logs "$log"
            fail green_unplanted "unplanted marker contract failed"
        }
        printf 'raw_exit\t0\nsemantic_status\t0\n' >"$real_dir/run-$name.status.tsv"
    else
        [[ "$rc" -ne 0 && "$rc" -ne 124 && "$rc" -ne 137 ]] || {
            show_logs "$log" "$real_dir/run-$name.stdout.log" "$real_dir/run-$name.stderr.log"
            fail "plant_$plant" "plant did not produce a verified ordinary nonzero exit: $rc"
        }
        if xcelium_license_failure "$log" "$real_dir/run-$name.stdout.log" \
                "$real_dir/run-$name.stderr.log"; then
            block_xcelium "plant_${plant}_license" \
                "Xcelium plant run could not obtain a license"
        fi
        local check=$plant
        validate_plant_log "$log" "$plant" "$check" || {
            show_logs "$log"
            fail "plant_$plant" "named plant marker contract failed"
        }
        printf 'raw_exit\t%s\nsemantic_status\t10\n' "$rc" \
            >"$real_dir/run-$name.status.tsv"
    fi
}

run_direct_preflight() {
    local leaf_top="$SCRATCH/tb_enc128_leaf_elaboration.sv"
    write_leaf_top "$leaf_top"
    local run_dir
    run_dir=$(run_elaboration direct-leaf tb_enc128_leaf_elaboration \
        "$LEAF" "$leaf_top")
    validate_elaboration_evidence "$run_dir/xrun.log" \
        tb_enc128_leaf_elaboration enc128 tb_enc128_leaf_elaboration
    guard_frozen_inputs
    printf '%s sources=2 sv=2 top=tb_enc128_leaf_elaboration tool=%s behavior_claim=0\n' \
        "$DIRECT_MARKER" "$EXPECTED_XRUN_VERSION"
}

run_fixture_preflight() {
    local stub="$SCRATCH/opendvs_sync_product_encoder_core_exact_29_port_stub.sv"
    write_exact_port_stub "$stub"
    local run_dir
    run_dir=$(run_elaboration exact-29-port-fixture \
        tb_opendvs_sync_product_encoder_core \
        "$LEAF" "$stub" "$COMPAT_TESTBENCH")
    validate_elaboration_evidence "$run_dir/xrun.log" \
        tb_opendvs_sync_product_encoder_core enc128 \
        opendvs_sync_product_encoder_core tb_opendvs_sync_product_encoder_core
    guard_frozen_inputs
    printf '%s sources=3 sv=3 ports=29 top=tb_opendvs_sync_product_encoder_core tool=%s behavior_claim=0\n' \
        "$FIXTURE_MARKER" "$EXPECTED_XRUN_VERSION"
}

run_green() {
    [[ -f "$CORE" && ! -L "$CORE" ]] || \
        fail missing_product_core "production core is absent, non-regular, or a symlink"
    record_source_hashes "$SCRATCH/source-hashes.before.tsv"
    local real_dir
    real_dir=$(run_elaboration real-closure tb_opendvs_sync_product_encoder_core \
        "$LEAF" "$CORE" "$COMPAT_TESTBENCH")
    validate_elaboration_evidence "$real_dir/xrun.log" \
        tb_opendvs_sync_product_encoder_core enc128 \
        opendvs_sync_product_encoder_core tb_opendvs_sync_product_encoder_core
    run_snapshot_once "$real_dir" unplanted none
    local plant
    for plant in half_order_swap ascending_sparse_positions launch_population_16 \
            nonzero_delta_time raw_byte_reversal retained_fragment_overwrite \
            duplicate_retirement lost_retirement overflow_without_sticky_fault; do
        run_snapshot_once "$real_dir" "plant-$plant" "$plant"
    done
    [[ $(find "$real_dir" -maxdepth 1 -name 'run-*.status.tsv' -type f | wc -l) -eq 10 ]] || \
        fail run_inventory "fresh snapshot was not used for exactly ten validated runs"
    printf 'real_elaborations\t1\nunplanted_runs\t1\nplant_runs\t9\nsemantic_plant_status\t10\n' \
        >"$real_dir/run-inventory.tsv"
    record_source_hashes "$SCRATCH/source-hashes.after.tsv"
    cmp -s "$SCRATCH/source-hashes.before.tsv" "$SCRATCH/source-hashes.after.tsv" || \
        fail source_preservation "source identity changed during behavioral qualification"
    guard_frozen_inputs
    printf 'OPENDVS_SYNC_PRODUCT_CORE_XCELIUM_RESULT compatibility_sha256=%s core_sha256=%s cases=3096 plants=9 semantic_plant_status=10\n' \
        "$EXPECTED_COMPAT_TESTBENCH_SHA" "$(hash_file "$CORE")"
    printf '%s\n' "$PASS_MARKER"
}

resume_green() {
    local preserved=$1
    [[ "$preserved" == "$SCRATCH_PARENT/sync-product-core-xcelium-v3."* && \
       -d "$preserved" && ! -L "$preserved" ]] || \
        fail resume_scratch "resume path is not a preserved v3 scratch directory"
    SCRATCH=$preserved
    COMPAT_TESTBENCH="$SCRATCH/tb_opendvs_sync_product_encoder_core.xcelium.sv"
    COMPAT_MANIFEST="$SCRATCH/xcelium-testbench-transformation.tsv"
    guard_hash "$COMPAT_TESTBENCH" "$EXPECTED_COMPAT_TESTBENCH_SHA" \
        resume_compatibility_testbench
    [[ $(wc -l <"$COMPAT_MANIFEST") -eq 3 ]] || \
        fail resume_compatibility_manifest "preserved manifest is not exactly three rows"
    local real_dir="$SCRATCH/real-closure"
    [[ -d "$real_dir/xcelium.d" && ! -L "$real_dir/xcelium.d" ]] || \
        fail resume_snapshot "preserved fresh snapshot library is absent"
    validate_elaboration_evidence "$real_dir/xrun.log" \
        tb_opendvs_sync_product_encoder_core enc128 \
        opendvs_sync_product_encoder_core tb_opendvs_sync_product_encoder_core
    [[ $(find "$real_dir" -maxdepth 1 -name 'run-*.status.tsv' -type f | wc -l) -eq 7 ]] || \
        fail resume_inventory "preserved run inventory is not one GREEN plus six plants"
    local completed=(
        unplanted half_order_swap ascending_sparse_positions launch_population_16
        nonzero_delta_time raw_byte_reversal retained_fragment_overwrite
    )
    local name
    for name in "${completed[@]}"; do
        if [[ "$name" == unplanted ]]; then
            [[ -f "$real_dir/run-unplanted.status.tsv" ]] || \
                fail resume_inventory "unplanted status is absent"
        else
            [[ -f "$real_dir/run-plant-$name.status.tsv" ]] || \
                fail resume_inventory "completed plant status is absent: $name"
        fi
    done
    [[ ! -e "$real_dir/run-plant-duplicate_retirement.status.tsv" ]] || \
        fail resume_inventory "failed license-only plant unexpectedly has validated status"
    xcelium_license_failure "$real_dir/run-plant-duplicate_retirement.log" \
        "$real_dir/run-plant-duplicate_retirement.stdout.log" \
        "$real_dir/run-plant-duplicate_retirement.stderr.log" || \
        fail resume_reason "preserved stop was not the diagnosed license-only failure"
    record_source_hashes "$SCRATCH/source-hashes.resume.tsv"
    cmp -s "$SCRATCH/source-hashes.before.tsv" "$SCRATCH/source-hashes.resume.tsv" || \
        fail resume_source_preservation "sources changed since the fresh snapshot was created"
    printf 'resume_reason\tlicense_only\nprior_validated_runs\t7\nremaining_plants\t3\n' \
        >"$real_dir/resume-manifest.tsv"
    run_snapshot_once "$real_dir" plant-duplicate_retirement duplicate_retirement
    run_snapshot_once "$real_dir" plant-lost_retirement lost_retirement
    run_snapshot_once "$real_dir" plant-overflow_without_sticky_fault \
        overflow_without_sticky_fault
    [[ $(find "$real_dir" -maxdepth 1 -name 'run-*.status.tsv' -type f | wc -l) -eq 10 ]] || \
        fail run_inventory "resumed fresh snapshot does not have exactly ten validated runs"
    printf 'real_elaborations\t1\nunplanted_runs\t1\nplant_runs\t9\nsemantic_plant_status\t10\nresume_after_license_only_stop\t1\n' \
        >"$real_dir/run-inventory.tsv"
    record_source_hashes "$SCRATCH/source-hashes.after.tsv"
    cmp -s "$SCRATCH/source-hashes.before.tsv" "$SCRATCH/source-hashes.after.tsv" || \
        fail source_preservation "source identity changed during resumed qualification"
    guard_frozen_inputs
    printf 'OPENDVS_SYNC_PRODUCT_CORE_XCELIUM_RESULT compatibility_sha256=%s core_sha256=%s cases=3096 plants=9 semantic_plant_status=10 real_elaborations=1\n' \
        "$EXPECTED_COMPAT_TESTBENCH_SHA" "$(hash_file "$CORE")"
    printf '%s\n' "$PASS_MARKER"
}

usage() {
    printf 'usage: %s --direct-preflight|--fixture-preflight|--expect-green|--resume-green PRESERVED_SCRATCH\n' "$0" >&2
    exit 2
}

if [[ "${1:-}" == --resume-green ]]; then
    [[ $# -eq 2 ]] || usage
    guard_frozen_inputs
    SCRATCH=$2
    trap 'exit 130' HUP INT TERM
    select_xcelium
    resume_green "$SCRATCH"
    exit 0
fi

[[ $# -eq 1 ]] || usage
guard_frozen_inputs
SCRATCH=$(mktemp -d "$SCRATCH_PARENT/sync-product-core-xcelium-v3.XXXXXXXX")
cleanup() {
    local rc=$?
    trap - EXIT
    if [[ "$rc" -eq 0 ]]; then
        rm -rf -- "$SCRATCH"
    else
        printf '%s check=scratch_preserved message=%s\n' \
            "$FAIL_MARKER" "$SCRATCH" >&2
    fi
    exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM
select_xcelium
generate_compatibility_testbench

case "$1" in
    --direct-preflight) run_direct_preflight ;;
    --fixture-preflight) run_fixture_preflight ;;
    --expect-green) run_green ;;
    *) usage ;;
esac
