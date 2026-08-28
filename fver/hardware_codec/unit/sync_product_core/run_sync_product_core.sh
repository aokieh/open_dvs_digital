#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../../../.." && pwd -P)
TEST_DIR="$ROOT/fver/hardware_codec/unit/sync_product_core"
LEAF="$ROOT/source/design/hardware_codec/sync/enc128_v2_vendored.sv"
CORE="$ROOT/source/design/hardware_codec/sync/opendvs_sync_product_encoder_core.sv"
TESTBENCH="$TEST_DIR/tb_opendvs_sync_product_encoder_core.sv"
RUNNER="$TEST_DIR/run_sync_product_core.sh"
ARCHIVED_RUNNER="$TEST_DIR/frozen/run_sync_product_core_v1.sh"
README="$TEST_DIR/README.md"
SPEC="/home/rpgraca/opencode-sessions/dvs-encoder/.ocs/artifacts/files/aed-codec-campaign-v0/work/hardware-codec-v1/digital-repository-integration/sync-encoder-product-core-spec-v1.md"

TOOL_ROOT=/tmp/opencode/dvs-encoder/oss-cad-suite-20260824/oss-cad-suite/bin
IVERILOG="$TOOL_ROOT/iverilog"
VVP="$TOOL_ROOT/vvp"
TIMEOUT=/usr/bin/timeout
SHA256SUM=/usr/bin/sha256sum
SCRATCH_PARENT=/tmp/opencode/dvs-encoder
IVERILOG_LANGUAGE_FLAG=-g2005-sv
EXPECTED_IVERILOG_LANGUAGE_FLAG_USES=4
RUNNER_VERSION=behavioral-runner-v2

EXPECTED_SPEC_SHA=564c6eece59908d6ed047d0e8268ad344e770ba9bf279212dff22b729ed1bd30
EXPECTED_LEAF_SHA=0c77fa83ec15af0c06df96b04dcfc67dd02cad23ffd075cf1f59f879a6cad54d
EXPECTED_TESTBENCH_SHA=a03887d936fe53c905b5b7ae1b418bab31efc24896bb333e4809178d7f15a923
EXPECTED_ARCHIVED_RUNNER_SHA=c6cb6195143e5ff5a977ef810544f399d3f75307da4467d7e557bfb1f0cc0f1a

RED_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_RED_CONFIRMED@@ missing_module=opendvs_sync_product_encoder_core'
LEAF_PREFLIGHT_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_LEAF_ELABORATION_PREFLIGHT_PASS@@ parser=-g2005-sv'
PREFLIGHT_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_FIXTURE_PREFLIGHT_PASS@@'
PASS_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_PASS@@ mapping_cases=3096 tiers=2 sparse_boundary=15 raw_boundary=16 queue_depth_test=4'
FAIL_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_FAIL@@'
PLANT_MARKER='@@OPENDVS_SYNC_PRODUCT_CORE_PLANT_DETECTED@@'

fail() {
    local check=$1
    shift
    printf '%s check=%s message=%s\n' "$FAIL_MARKER" "$check" "$*" >&2
    exit 1
}

hash_file() {
    local output
    output=$($SHA256SUM "$1")
    printf '%s\n' "${output%% *}"
}

guard_hash() {
    local path=$1
    local expected=$2
    local label=$3
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

path = pathlib.Path(sys.argv[1])
label = re.escape(sys.argv[2])
text = path.read_text(encoding="utf-8")
matches = re.findall(rf"^- {label}: `([0-9a-f]{{64}})`$", text, re.MULTILINE)
if len(matches) != 1:
    raise SystemExit(f"README hash label {sys.argv[2]!r} occurs {len(matches)} times")
print(matches[0])
PY
}

guard_parser_mode() {
    python3 -I - "$RUNNER" "$IVERILOG_LANGUAGE_FLAG" \
        "$EXPECTED_IVERILOG_LANGUAGE_FLAG_USES" <<'PY'
from __future__ import annotations

import pathlib
import sys

path = pathlib.Path(sys.argv[1])
expected_flag = sys.argv[2]
expected_uses = int(sys.argv[3])
text = path.read_text(encoding="utf-8")
reference = '"' + '$' + 'IVERILOG_LANGUAGE_FLAG' + '"'
compiler = '"' + '$' + 'IVERILOG' + '"'
observed_uses = sum(
    compiler in line and reference in line for line in text.splitlines()
)
if observed_uses != expected_uses:
    raise SystemExit(
        f"parser flag reference count was {observed_uses}, expected {expected_uses}"
    )
if text.count(expected_flag) != 2:
    raise SystemExit("qualified parser flag must occur once in configuration and once in marker")
legacy_flag = "-" + "g2012"
if legacy_flag in text:
    raise SystemExit("legacy parser mode remains in the active runner")
PY
}

guard_frozen_inputs() {
    [[ -x "$IVERILOG" && ! -L "$IVERILOG" ]] || \
        fail pinned_iverilog "pinned executable is absent or a symlink: $IVERILOG"
    [[ -x "$VVP" && ! -L "$VVP" ]] || \
        fail pinned_vvp "pinned executable is absent or a symlink: $VVP"
    [[ -x "$TIMEOUT" ]] || fail timeout_tool "timeout executable is absent"
    [[ -x "$SHA256SUM" ]] || fail sha256_tool "sha256sum executable is absent"
    [[ -d "$SCRATCH_PARENT" && ! -L "$SCRATCH_PARENT" ]] || \
        fail scratch_parent "scratch parent is absent or a symbolic link"
    guard_hash "$SPEC" "$EXPECTED_SPEC_SHA" frozen_specification
    guard_hash "$LEAF" "$EXPECTED_LEAF_SHA" frozen_leaf
    guard_hash "$TESTBENCH" "$EXPECTED_TESTBENCH_SHA" frozen_testbench
    guard_hash "$ARCHIVED_RUNNER" "$EXPECTED_ARCHIVED_RUNNER_SHA" \
        archived_v1_runner
    guard_parser_mode || fail parser_mode_guard \
        "active runner parser-mode identity or use count differs"
    [[ -f "$README" && ! -L "$README" ]] || \
        fail frozen_readme "README is absent, non-regular, or a symbolic link"
    local readme_testbench_sha
    local readme_archived_runner_sha
    local readme_runner_sha
    readme_testbench_sha=$(read_readme_hash "Testbench SHA-256") || \
        fail readme_testbench_hash "could not read the unique testbench hash"
    readme_archived_runner_sha=$(read_readme_hash "Archived v1 runner SHA-256") || \
        fail readme_archived_runner_hash \
            "could not read the unique archived v1 runner hash"
    readme_runner_sha=$(read_readme_hash "Active v2 runner SHA-256") || \
        fail readme_runner_hash "could not read the unique runner hash"
    [[ "$readme_testbench_sha" == "$EXPECTED_TESTBENCH_SHA" ]] || \
        fail readme_testbench_hash "README and runner testbench hashes differ"
    [[ "$readme_archived_runner_sha" == "$EXPECTED_ARCHIVED_RUNNER_SHA" ]] || \
        fail readme_archived_runner_hash \
            "README and runner archived v1 hashes differ"
    guard_hash "$RUNNER" "$readme_runner_sha" active_v2_runner
}

write_leaf_elaboration_top() {
    local top=$1
    python3 -I - "$top" <<'PY'
from __future__ import annotations

import pathlib
import sys

pathlib.Path(sys.argv[1]).write_text(
    """`timescale 1ns/1ps
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
        .in_row(7'd0), .in_pol(1'b0), .in_mask(128'd0),
        .in_dt(32'd0),
        .out_val(out_val), .out_rdy(1'b0), .out_data(out_data)
    );
endmodule
`default_nettype wire
""",
    encoding="utf-8",
    newline="\n",
)
PY
}

write_exact_port_stub() {
    local stub=$1
    python3 -I - "$stub" <<'PY'
from __future__ import annotations

import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(
    """`timescale 1ns/1ps
`default_nettype none
module opendvs_sync_product_encoder_core #(
    parameter integer QUEUE_DEPTH = 16
) (
    input  logic         clk_i,
    input  logic         arst_ni,
    input  logic         admit_enable_i,
    input  logic         top_record_valid_i,
    input  logic [135:0] top_record_i,
    output logic         top_record_accepted_o,
    input  logic         bottom_record_valid_i,
    input  logic [135:0] bottom_record_i,
    output logic         bottom_record_accepted_o,
    output logic         top_fragment_valid_o,
    input  logic         top_fragment_ready_i,
    output logic         top_fragment_raw_o,
    output logic [4:0]   top_fragment_length_o,
    output logic [135:0] top_fragment_payload_o,
    output logic         bottom_fragment_valid_o,
    input  logic         bottom_fragment_ready_i,
    output logic         bottom_fragment_raw_o,
    output logic [4:0]   bottom_fragment_length_o,
    output logic [135:0] bottom_fragment_payload_o,
    output logic         quiescent_o,
    output logic [31:0]  accepted_count_o,
    output logic [31:0]  empty_suppressed_count_o,
    output logic [31:0]  illegal_label_count_o,
    output logic [31:0]  disabled_suppressed_count_o,
    output logic [31:0]  overflow_count_o,
    output logic [31:0]  sparse_count_o,
    output logic [31:0]  raw_count_o,
    output logic [31:0]  retired_count_o,
    output logic         sticky_fault_o
);
    always_comb begin
        top_record_accepted_o = 1'b0;
        bottom_record_accepted_o = 1'b0;
        top_fragment_valid_o = 1'b0;
        top_fragment_raw_o = 1'b0;
        top_fragment_length_o = 5'd0;
        top_fragment_payload_o = 136'd0;
        bottom_fragment_valid_o = 1'b0;
        bottom_fragment_raw_o = 1'b0;
        bottom_fragment_length_o = 5'd0;
        bottom_fragment_payload_o = 136'd0;
        quiescent_o = 1'b0;
        accepted_count_o = 32'd0;
        empty_suppressed_count_o = 32'd0;
        illegal_label_count_o = 32'd0;
        disabled_suppressed_count_o = 32'd0;
        overflow_count_o = 32'd0;
        sparse_count_o = 32'd0;
        raw_count_o = 32'd0;
        retired_count_o = 32'd0;
        sticky_fault_o = 1'b0;
    end
endmodule
`default_nettype wire
""",
    encoding="utf-8",
    newline="\n",
)
PY
}

show_log() {
    local log=$1
    python3 -I - "$log" <<'PY' >&2
from __future__ import annotations

import pathlib
import sys

sys.stderr.write(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace"))
PY
}

run_leaf_elaboration_preflight() {
    local announce=$1
    local top="$SCRATCH/leaf-elaboration-top.sv"
    local image="$SCRATCH/leaf-elaboration-preflight.vvp"
    local log="$SCRATCH/leaf-elaboration-preflight.log"
    write_leaf_elaboration_top "$top"
    set +e
    "$TIMEOUT" --signal=TERM --kill-after=5s 30s \
        "$IVERILOG" "$IVERILOG_LANGUAGE_FLAG" -Wall -Wimplicit \
        -s tb_enc128_leaf_elaboration \
        -o "$image" \
        "$LEAF" \
        "$top" >"$log" 2>&1
    local rc=$?
    set -e
    if [[ $rc -ne 0 ]]; then
        show_log "$log"
        fail leaf_elaboration_preflight \
            "qualified parser failed direct frozen-leaf elaboration with exit $rc"
    fi
    [[ -s "$image" ]] || \
        fail leaf_elaboration_preflight "compiler emitted no direct leaf image"
    if [[ "$announce" == yes ]]; then
        printf '%s\n' "$LEAF_PREFLIGHT_MARKER"
    fi
}

run_fixture_preflight() {
    local announce=$1
    local stub="$SCRATCH/exact-port-unresolved-stub.sv"
    local image="$SCRATCH/fixture-preflight.vvp"
    local log="$SCRATCH/fixture-preflight.log"
    write_exact_port_stub "$stub"
    set +e
    "$TIMEOUT" --signal=TERM --kill-after=5s 30s \
        "$IVERILOG" "$IVERILOG_LANGUAGE_FLAG" -Wall -Wimplicit \
        -s tb_opendvs_sync_product_encoder_core \
        -o "$image" \
        "$stub" \
        "$LEAF" \
        "$TESTBENCH" >"$log" 2>&1
    local rc=$?
    set -e
    if [[ $rc -ne 0 ]]; then
        show_log "$log"
        fail fixture_preflight "exact-port stub compilation failed with exit $rc"
    fi
    [[ -s "$image" ]] || fail fixture_preflight "compiler emitted no fixture image"
    if [[ "$announce" == yes ]]; then
        printf '%s\n' "$PREFLIGHT_MARKER"
    fi
}

validate_exact_red_log() {
    local log=$1
    python3 -I - "$log" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

module = "opendvs_sync_product_encoder_core"
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
lower = text.lower()
for forbidden in (
    "syntax error",
    "malformed",
    "unable to bind",
    "no top level modules",
    "not found",
    "no such file",
):
    if forbidden in lower:
        raise SystemExit(f"RED log contained non-module failure: {forbidden}")
unknown = re.findall(r"Unknown module type:\s*([A-Za-z_$][A-Za-z0-9_$]*)", text)
if not unknown:
    raise SystemExit("RED log did not contain an Unknown module type diagnostic")
if set(unknown) != {module}:
    raise SystemExit(f"RED log had unexpected unresolved modules: {sorted(set(unknown))}")
if "These modules were missing:" not in text or module not in text:
    raise SystemExit("RED log lacked the missing-module elaboration summary")
PY
}

run_expect_red() {
    local image="$SCRATCH/expect-red.vvp"
    local log="$SCRATCH/expect-red.log"
    run_leaf_elaboration_preflight no
    run_fixture_preflight no
    set +e
    "$TIMEOUT" --signal=TERM --kill-after=5s 30s \
        "$IVERILOG" "$IVERILOG_LANGUAGE_FLAG" -Wall -Wimplicit \
        -s tb_opendvs_sync_product_encoder_core \
        -o "$image" \
        "$LEAF" \
        "$TESTBENCH" >"$log" 2>&1
    local rc=$?
    set -e
    [[ $rc -ne 0 && $rc -ne 124 && $rc -ne 137 ]] || \
        fail expect_red "real closure compilation returned non-RED exit $rc"
    validate_exact_red_log "$log" || {
        show_log "$log"
        fail expect_red "failure was not the exact unresolved product-core module"
    }
    [[ ! -e "$image" || ! -s "$image" ]] || \
        fail expect_red "failed real closure left an executable simulation image"
    printf '%s\n' "$RED_MARKER"
}

validate_unplanted_log() {
    local log=$1
    python3 -I - "$log" "$PASS_MARKER" "$FAIL_MARKER" "$PLANT_MARKER" <<'PY'
from __future__ import annotations

import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
pass_marker, fail_marker, plant_marker = sys.argv[2:5]
lines = text.splitlines()
if lines.count(pass_marker) != 1:
    raise SystemExit(f"behavioral PASS marker count was {lines.count(pass_marker)}, expected 1")
if fail_marker in text or plant_marker in text:
    raise SystemExit("unplanted run emitted a failure or plant marker")
PY
}

validate_plant_log() {
    local log=$1
    local plant_name=$2
    local check_name=$3
    python3 -I - "$log" "$plant_name" "$check_name" \
        "$PASS_MARKER" "$FAIL_MARKER" "$PLANT_MARKER" <<'PY'
from __future__ import annotations

import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
plant, check, pass_marker, fail_marker, plant_marker = sys.argv[2:7]
expected = f"{plant_marker} plant={plant} check={check}"
lines = text.splitlines()
if lines.count(expected) != 1:
    raise SystemExit(f"named plant marker count was {lines.count(expected)}, expected 1")
if pass_marker in text or fail_marker in text:
    raise SystemExit("planted run emitted behavioral PASS or generic FAIL")
if sum(plant_marker in line for line in lines) != 1:
    raise SystemExit("planted run emitted an extra plant marker")
PY
}

run_expect_green() {
    [[ -f "$CORE" && ! -L "$CORE" ]] || \
        fail missing_product_core \
            "GREEN is closed until the regular production core exists: $CORE"

    local image="$SCRATCH/product-core.vvp"
    local compile_log="$SCRATCH/green-compile.log"
    local run_log="$SCRATCH/green-unplanted.log"
    local source_hashes="$SCRATCH/source-hashes.tsv"
    printf 'specification_sha256\t%s\n' "$(hash_file "$SPEC")" >"$source_hashes"
    printf 'leaf_sha256\t%s\n' "$(hash_file "$LEAF")" >>"$source_hashes"
    printf 'product_core_sha256\t%s\n' "$(hash_file "$CORE")" >>"$source_hashes"
    printf 'testbench_sha256\t%s\n' "$(hash_file "$TESTBENCH")" >>"$source_hashes"
    printf 'runner_sha256\t%s\n' "$(hash_file "$RUNNER")" >>"$source_hashes"
    printf 'runner_version\t%s\n' "$RUNNER_VERSION" >>"$source_hashes"
    printf 'iverilog_language_flag\t%s\n' \
        "$IVERILOG_LANGUAGE_FLAG" >>"$source_hashes"

    set +e
    "$TIMEOUT" --signal=TERM --kill-after=5s 30s \
        "$IVERILOG" "$IVERILOG_LANGUAGE_FLAG" -Wall -Wimplicit \
        -s tb_opendvs_sync_product_encoder_core \
        -o "$image" \
        "$LEAF" \
        "$CORE" \
        "$TESTBENCH" >"$compile_log" 2>&1
    local rc=$?
    set -e
    if [[ $rc -ne 0 ]]; then
        show_log "$compile_log"
        fail green_compile "exact leaf/core/testbench closure failed with exit $rc"
    fi

    set +e
    "$TIMEOUT" --signal=TERM --kill-after=5s 180s \
        "$VVP" "$image" >"$run_log" 2>&1
    rc=$?
    set -e
    if [[ $rc -ne 0 ]]; then
        show_log "$run_log"
        fail green_unplanted "unplanted behavioral run exited $rc"
    fi
    validate_unplanted_log "$run_log" || {
        show_log "$run_log"
        fail green_unplanted "unplanted marker contract failed"
    }

    local plant_name
    local check_name
    local plant_log
    while IFS=$'\t' read -r plant_name check_name; do
        plant_log="$SCRATCH/plant-${plant_name}.log"
        set +e
        "$TIMEOUT" --signal=TERM --kill-after=5s 30s \
            "$VVP" "$image" "+PLANT=$plant_name" >"$plant_log" 2>&1
        rc=$?
        set -e
        if [[ $rc -ne 10 ]]; then
            show_log "$plant_log"
            fail "plant_$plant_name" "named plant exited $rc, expected 10"
        fi
        validate_plant_log "$plant_log" "$plant_name" "$check_name" || {
            show_log "$plant_log"
            fail "plant_$plant_name" "named plant marker contract failed"
        }
    done <<'PLANTS'
half_order_swap	half_order_swap
ascending_sparse_positions	ascending_sparse_positions
launch_population_16	launch_population_16
nonzero_delta_time	nonzero_delta_time
raw_byte_reversal	raw_byte_reversal
retained_fragment_overwrite	retained_fragment_overwrite
duplicate_retirement	duplicate_retirement
lost_retirement	lost_retirement
overflow_without_sticky_fault	overflow_without_sticky_fault
PLANTS

    printf '%s\n' "$PASS_MARKER"
}

usage() {
    printf 'usage: %s --leaf-elaboration-preflight|--fixture-preflight|--expect-red|--expect-green\n' "$0" >&2
    exit 2
}

[[ $# -eq 1 ]] || usage
guard_frozen_inputs
SCRATCH=$(mktemp -d "$SCRATCH_PARENT/sync-product-core.XXXXXXXX")
trap 'rm -rf -- "$SCRATCH"' EXIT HUP INT TERM

case "$1" in
    --leaf-elaboration-preflight)
        run_leaf_elaboration_preflight yes
        ;;
    --fixture-preflight)
        run_fixture_preflight yes
        ;;
    --expect-red)
        run_expect_red
        ;;
    --expect-green)
        run_expect_green
        ;;
    *)
        usage
        ;;
esac
