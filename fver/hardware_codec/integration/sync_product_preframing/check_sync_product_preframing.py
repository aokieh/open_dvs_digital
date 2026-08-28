#!/usr/bin/env python3
"""Fail-closed structural oracle for synchronous product pre-framing."""

from __future__ import annotations

import argparse
import hashlib
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
SPEC = Path(
    "/home/rpgraca/opencode-sessions/dvs-encoder/.ocs/artifacts/files/"
    "aed-codec-campaign-v0/work/hardware-codec-v1/"
    "digital-repository-integration/"
    "sync-product-preframing-integration-unit-v1.md"
)
EXPECTED_SPEC_SHA256 = "dd6a6d63198f39468f6c5357beda4fc9c51f3162f9a5b2901f68058c80fcf41e"
EXPECTED_CORE_SHA256 = "cc8aa66e33dbd5d9a88b14305efb5f275829b6a54d266c1cf507c2769a8c04cb"
EXPECTED_LEAF_SHA256 = "0c77fa83ec15af0c06df96b04dcfc67dd02cad23ffd075cf1f59f879a6cad54d"
EXPECTED_RST_SHA256 = "16027ca7e27717024d130b8bb767bfd9d960ac4da75eea4413cf953c9702ec40"

REL = {
    "col": "source/design/final_macros/col_readout_macro.sv",
    "fifo_macro": "source/design/final_macros/fifo_rows_cols_macro2.sv",
    "final": "source/design/final_macros/final_top3.sv",
    "spi": "source/design/regfile/spi_peripheral_re.sv",
    "core": "source/design/hardware_codec/sync/opendvs_sync_product_encoder_core.sv",
    "leaf": "source/design/hardware_codec/sync/enc128_v2_vendored.sv",
    "shell": "source/design/hardware_codec/control/opendvs_sync_mode_ownership_shell.sv",
    "rst": "source/design/common/rst_sync.sv",
    "product_manifest": "fver/hardware_codec/filelists/sync_mode_ownership_product.f",
    "macro_manifest": "fver/final_macros/scripts/xrun.f",
    "wrapper_manifest": "fver/user_project_wrapper/scripts/xrun.f",
}

PRODUCT_EXPECTED = (
    "source/design/common/defines.sv",
    "source/design/regfile/regfile_final.sv",
    "source/design/regfile/spi_peripheral_re.sv",
    "source/design/sync_fifo/sync_fifo.sv",
    "source/design/sync_fifo/fifo_intf3.sv",
    "source/design/sync_fifo/sync_fifo_top3.sv",
    "source/design/final_macros/col_readout_macro.sv",
    "source/design/roic/roic_sm2.sv",
    "source/design/roic/row_scanner.sv",
    "source/design/final_macros/row_decoder_macro2.sv",
    "source/design/final_macros/fifo_rows_cols_macro2.sv",
    "source/design/common/rst_sync.sv",
    "source/design/hardware_codec/sync/enc128_v2_vendored.sv",
    "source/design/hardware_codec/sync/opendvs_sync_product_encoder_core.sv",
    "source/design/hardware_codec/control/opendvs_sync_mode_ownership_shell.sv",
    "source/design/final_macros/final_top3.sv",
)

MACRO_EXPECTED = (
    "../../../source/design/common/defines.sv",
    "../../../source/design/regfile/regfile.sv",
    "../../../source/design/regfile/spi_peripheral_re.sv",
    "../../../source/design/sync_fifo/sync_fifo.sv",
    "../../../source/design/sync_fifo/fifo_intf3.sv",
    "../../../source/design/sync_fifo/sync_fifo_top3.sv",
    "../../../source/design/final_macros/col_readout_macro.sv",
    "../../../source/design/roic/roic_sm2.sv",
    "../../../source/design/roic/row_scanner.sv",
    "../../../source/design/final_macros/row_decoder_macro2.sv",
    "../../../source/design/final_macros/fifo_rows_cols_macro2.sv",
    "../../../source/design/common/rst_sync.sv",
    "../../../source/design/hardware_codec/sync/enc128_v2_vendored.sv",
    "../../../source/design/hardware_codec/sync/opendvs_sync_product_encoder_core.sv",
    "../../../source/design/hardware_codec/control/opendvs_sync_mode_ownership_shell.sv",
    "../../../source/design/final_macros/final_top3.sv",
    "../final_top_tb3.sv",
)

WRAPPER_EXPECTED = (
    "../../../source/design/common/defines.sv",
    "../verilog/user_defines.sv",
    "../../../source/design/regfile/regfile_final.sv",
    "../../../source/design/regfile/spi_peripheral_re.sv",
    "../../../source/design/sync_fifo/sync_fifo.sv",
    "../../../source/design/sync_fifo/fifo_intf3.sv",
    "../../../source/design/sync_fifo/sync_fifo_top3.sv",
    "../../../source/design/final_macros/col_readout_macro.sv",
    "../../../source/design/roic/roic_sm2.sv",
    "../../../source/design/roic/row_scanner.sv",
    "../../../source/design/final_macros/row_decoder_macro2.sv",
    "../../../source/design/final_macros/fifo_rows_cols_macro2.sv",
    "../../../source/design/common/rst_sync.sv",
    "../../../source/design/hardware_codec/sync/enc128_v2_vendored.sv",
    "../../../source/design/hardware_codec/sync/opendvs_sync_product_encoder_core.sv",
    "../../../source/design/hardware_codec/control/opendvs_sync_mode_ownership_shell.sv",
    "../../../source/design/final_macros/final_top3.sv",
    "../verilog/user_project_wrapper.sv",
    "../verilog/blackboxes.sv",
    "../verilog/user_project_wrapper_tb.sv",
)

FORBIDDEN_MANIFEST_PARTS = (
    "/hardware_codec/qdi/",
    "/hardware_codec/event_link/",
    "/hardware_codec/scanner/",
    "/async_fifo/",
    "/spi_async_fifo_reg/",
)

RED_REASONS = (
    (
        "product_core_and_manifest_closure",
        "final_top3_has_no_product_core_instance_and_product_manifests_omit_"
        "rst_sync_enc128_and_product_core",
    ),
    (
        "two_tier_source_observation",
        "top_and_bottom_exact_136_bit_records_and_independent_valid_pulses_"
        "are_not_exposed_to_final_top3",
    ),
    (
        "cycle15_beat_completion",
        "spi_peripheral_re_has_no_cycle15_final_beat_completion_witness_"
        "distinct_from_cycle13_consume",
    ),
)


class ContractError(RuntimeError):
    """A frozen harness prerequisite or acceptance contract was violated."""


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fail(message: str) -> None:
    print(f"@@SYNC_PRODUCT_PREFRAMING_STRUCTURE_FAIL@@ message={message}")
    raise SystemExit(2)


def require_regular(path: Path, label: str) -> None:
    if not path.is_file() or path.is_symlink():
        raise ContractError(f"{label}_missing_nonregular_or_symlink:{path}")


def strip_sv_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", "", text)


def compact_sv(text: str) -> str:
    return re.sub(r"\s+", "", strip_sv_comments(text))


def active_entries(text: str) -> tuple[str, ...]:
    entries: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith(("#", "//")):
            continue
        entries.append(line.split()[0])
    return tuple(entries)


def count_instance(text: str, module: str, instance: str) -> int:
    clean = strip_sv_comments(text)
    pattern = re.compile(
        rf"\b{re.escape(module)}\b\s*"
        rf"(?:#\s*\(.*?\)\s*)?\b{re.escape(instance)}\b\s*\(",
        flags=re.DOTALL,
    )
    return len(pattern.findall(clean))


def has_connection(text: str, port: str, expression: str) -> bool:
    clean = strip_sv_comments(text)
    return (
        re.search(
            rf"\.{re.escape(port)}\s*\(\s*{re.escape(expression)}\s*\)",
            clean,
        )
        is not None
    )


def manifest_defects(manifests: dict[str, tuple[str, ...]]) -> list[str]:
    defects: list[str] = []
    expected_by_name = {
        "product_manifest": PRODUCT_EXPECTED,
        "macro_manifest": MACRO_EXPECTED,
        "wrapper_manifest": WRAPPER_EXPECTED,
    }
    for name, expected in expected_by_name.items():
        entries = manifests[name]
        if entries != expected:
            defects.append(f"{name}_exact_active_entries")
        for entry in entries:
            lowered = entry.lower()
            if any(part in lowered for part in FORBIDDEN_MANIFEST_PARTS):
                defects.append(f"{name}_forbidden_source:{entry}")
    return defects


def topology_defects(final_text: str, core_text: str) -> list[str]:
    defects: list[str] = []
    if count_instance(final_text, "opendvs_sync_product_encoder_core", "i_sync_product_encoder_core") != 1:
        defects.append("final_top3_product_core_instance_count")
    if count_instance(final_text, "rst_sync", "i_sync_product_reset") != 1:
        defects.append("final_top3_reset_synchronizer_instance_count")
    if count_instance(core_text, "enc128", "u_top_enc128") != 1:
        defects.append("qualified_core_top_leaf_count")
    if count_instance(core_text, "enc128", "u_bottom_enc128") != 1:
        defects.append("qualified_core_bottom_leaf_count")
    if len(re.findall(r"\benc128\b\s*#\s*\(", strip_sv_comments(core_text))) != 2:
        defects.append("qualified_core_total_leaf_count")

    required_connections = (
        ("clk_i", "clk"),
        ("arst_ni", "sync_product_rst_n"),
        ("admit_enable_i", "1'b0"),
        ("top_record_valid_i", "top_record_valid"),
        ("top_record_i", "top_record"),
        ("top_record_accepted_o", "sync_top_record_accepted"),
        ("bottom_record_valid_i", "bottom_record_valid"),
        ("bottom_record_i", "bottom_record"),
        ("bottom_record_accepted_o", "sync_bottom_record_accepted"),
        ("top_fragment_ready_i", "1'b0"),
        ("bottom_fragment_ready_i", "1'b0"),
    )
    for port, expression in required_connections:
        if not has_connection(final_text, port, expression):
            defects.append(f"product_core_connection:{port}")

    for port, expression in (
        ("clk", "clk"),
        ("rst_n", "rst_n"),
        ("rst_sync_n", "sync_product_rst_n"),
    ):
        if not has_connection(final_text, port, expression):
            defects.append(f"reset_synchronizer_connection:{port}")

    for port, expression in (
        ("sync_ready_i", "1'b0"),
        ("sync_data_0_i", "16'b0"),
        ("sync_data_1_i", "16'b0"),
        ("sync_available_i", "1'b0"),
    ):
        if not has_connection(final_text, port, expression):
            defects.append(f"ownership_default_off_connection:{port}")
    return defects


def source_seam_defects(col_text: str, fifo_text: str, final_text: str) -> list[str]:
    defects: list[str] = []
    col = compact_sv(col_text)
    fifo = compact_sv(fifo_text)
    final = compact_sv(final_text)
    required_col = (
        "outputlogicsource_record_valid_o",
        "outputlogic[135:0]source_record_o",
        "assignsource_record_valid_o=fifo_wr_en;",
        "assignsource_record_o={event_mode,row_addr,col_left_m2,col_right_m2};",
        "assigninternal_wdata_fifo={event_mode,row_addr,col_left_m2,col_right_m2};",
    )
    for item in required_col:
        if item not in col:
            defects.append(f"column_source_contract:{item}")
    if "assignsource_record_valid_o=fifo_wr_en&&!full_fifo;" in col:
        defects.append("column_source_valid_is_gated_by_full")

    required_fifo = (
        "outputlogictop_record_valid_o",
        "outputlogic[135:0]top_record_o",
        "outputlogicbottom_record_valid_o",
        "outputlogic[135:0]bottom_record_o",
    )
    for item in required_fifo:
        if item not in fifo:
            defects.append(f"capture_hierarchy_contract:{item}")
    for port, expression in (
        ("source_record_valid_o", "top_record_valid_o"),
        ("source_record_o", "top_record_o"),
        ("source_record_valid_o", "bottom_record_valid_o"),
        ("source_record_o", "bottom_record_o"),
    ):
        if not has_connection(fifo_text, port, expression):
            defects.append(f"capture_hierarchy_connection:{port}:{expression}")

    required_final = (
        "logictop_record_valid;",
        "logic[135:0]top_record;",
        "logicbottom_record_valid;",
        "logic[135:0]bottom_record;",
    )
    for item in required_final:
        if item not in final:
            defects.append(f"final_top_source_signal:{item}")
    for port, expression in (
        ("top_record_valid_o", "top_record_valid"),
        ("top_record_o", "top_record"),
        ("bottom_record_valid_o", "bottom_record_valid"),
        ("bottom_record_o", "bottom_record"),
    ):
        if not has_connection(final_text, port, expression):
            defects.append(f"final_top_source_connection:{port}")
    return defects


def completion_defects(spi_text: str, final_text: str) -> list[str]:
    defects: list[str] = []
    spi_clean = strip_sv_comments(spi_text)
    spi = compact_sv(spi_text)
    final = compact_sv(final_text)
    if "outputlogicserial_beat_complete_o" not in spi:
        defects.append("spi_completion_output")
    if "serial_beat_complete_o<=1'b1;" not in spi:
        defects.append("spi_completion_high_assignment")
    if spi.count("serial_beat_complete_o<=1'b0;") < 2:
        defects.append("spi_completion_reset_and_default_low")
    if re.search(
        r"cycle_count\s*==\s*4'd15.{0,500}serial_beat_complete_o\s*<=\s*1'b1",
        spi_clean,
        flags=re.DOTALL,
    ) is None:
        defects.append("spi_completion_cycle15_binding")
    cycle13 = re.search(
        r"cycle_count\s*==\s*4'd13(.*?)cycle_count\s*==\s*4'd14",
        spi_clean,
        flags=re.DOTALL,
    )
    if cycle13 is None or re.search(
        r"serial_beat_complete_o\s*<=\s*1'b1", cycle13.group(1)
    ):
        defects.append("spi_cycle13_is_not_completion_free")
    if re.search(
        r"assign\s+serial_beat_complete_o\s*=\s*.*shift_en_fifo", spi_clean
    ):
        defects.append("spi_completion_aliases_consume")
    if "logicserial_beat_complete;" not in final:
        defects.append("final_top_completion_signal")
    if not has_connection(final_text, "serial_beat_complete_o", "serial_beat_complete"):
        defects.append("final_top_completion_connection")
    return defects


def load_live() -> tuple[dict[str, str], dict[str, tuple[str, ...]]]:
    texts: dict[str, str] = {}
    for name, relative in REL.items():
        path = ROOT / relative
        require_regular(path, name)
        texts[name] = path.read_text(encoding="utf-8")
    manifests = {
        name: active_entries(texts[name])
        for name in ("product_manifest", "macro_manifest", "wrapper_manifest")
    }
    return texts, manifests


def verify_frozen_prerequisites(texts: dict[str, str]) -> None:
    require_regular(SPEC, "frozen_specification")
    expected_hashes = (
        (SPEC, EXPECTED_SPEC_SHA256, "frozen_specification"),
        (ROOT / REL["core"], EXPECTED_CORE_SHA256, "qualified_product_core"),
        (ROOT / REL["leaf"], EXPECTED_LEAF_SHA256, "qualified_enc128_leaf"),
        (ROOT / REL["rst"], EXPECTED_RST_SHA256, "qualified_reset_synchronizer"),
    )
    for path, expected, label in expected_hashes:
        observed = sha256(path)
        if observed != expected:
            raise ContractError(
                f"{label}_sha256_mismatch:expected={expected}:observed={observed}"
            )

    col = compact_sv(texts["col"])
    if "assigninternal_wdata_fifo={event_mode,row_addr,col_left_m2,col_right_m2};" not in col:
        raise ContractError("legacy_136_bit_record_mapping_is_not_the_verified_interface")
    spi = strip_sv_comments(texts["spi"])
    if re.search(r"cycle_count\s*==\s*4'd13", spi) is None:
        raise ContractError("legacy_cycle13_consume_interface_is_absent")
    if count_instance(texts["final"], "opendvs_sync_mode_ownership_shell", "i_sync_mode_ownership") != 1:
        raise ContractError("verified_ownership_shell_instance_is_not_unique")


def classify(
    texts: dict[str, str], manifests: dict[str, tuple[str, ...]]
) -> dict[str, list[str]]:
    topology = topology_defects(texts["final"], texts["core"])
    topology.extend(manifest_defects(manifests))
    return {
        "product_core_and_manifest_closure": topology,
        "two_tier_source_observation": source_seam_defects(
            texts["col"], texts["fifo_macro"], texts["final"]
        ),
        "cycle15_beat_completion": completion_defects(
            texts["spi"], texts["final"]
        ),
    }


def run_preflight() -> int:
    texts, _ = load_live()
    verify_frozen_prerequisites(texts)
    harness = ROOT / "fver/hardware_codec/integration/sync_product_preframing"
    required = (
        "README.md",
        "check_sync_product_preframing.py",
        "fixture_sync_product_preframing.sv",
        "fixture_sources.f",
        "product_sources.f",
        "run_sync_product_preframing.sh",
        "tb_sync_product_preframing.sv",
        "test-source.sha256",
    )
    for name in required:
        require_regular(harness / name, f"harness_{name}")
    print(
        "@@SYNC_PRODUCT_PREFRAMING_STRUCTURE_PREFLIGHT_PASS@@ "
        "spec_hash=1 core_hash=1 leaf_hash=1 reset_hash=1 live_interfaces=1"
    )
    return 0


def run_expect_red() -> int:
    texts, manifests = load_live()
    verify_frozen_prerequisites(texts)
    defects = classify(texts, manifests)
    unexpected_green = [name for name, found in defects.items() if not found]
    if unexpected_green:
        fail("RED_capability_unexpectedly_present:" + ",".join(unexpected_green))

    # RED is accepted only while all three complete missing-capability groups are
    # absent. A partially implemented or malformed interface is not this baseline.
    if count_instance(texts["final"], "opendvs_sync_product_encoder_core", "i_sync_product_encoder_core") != 0:
        fail("RED_product_core_instance_is_partially_present")
    new_manifest_entries = {
        REL["rst"], REL["leaf"], REL["core"],
        "../../../" + REL["rst"],
        "../../../" + REL["leaf"],
        "../../../" + REL["core"],
    }
    for name, entries in manifests.items():
        present = sorted(set(entries) & new_manifest_entries)
        if present:
            fail(f"RED_{name}_has_partial_new_closure:{present}")
    if any(
        token in compact_sv(texts["col"] + texts["fifo_macro"] + texts["final"])
        for token in (
            "source_record_valid_o", "top_record_valid_o", "bottom_record_valid_o"
        )
    ):
        fail("RED_source_observation_interface_is_partially_present")
    if "serial_beat_complete_o" in strip_sv_comments(texts["spi"] + texts["final"]):
        fail("RED_beat_completion_interface_is_partially_present")

    for reason_id, message in RED_REASONS:
        print(
            "@@SYNC_PRODUCT_PREFRAMING_RED_REASON@@ "
            f"id={reason_id} observed={message}"
        )
    print(
        "@@SYNC_PRODUCT_PREFRAMING_RED_CONFIRMED@@ reasons=3 behavior_run=0 "
        f"core_sha256={EXPECTED_CORE_SHA256}"
    )
    return 0


def run_expect_green() -> int:
    texts, manifests = load_live()
    verify_frozen_prerequisites(texts)
    defects = classify(texts, manifests)
    flattened = [f"{name}:{item}" for name, items in defects.items() for item in items]
    if flattened:
        fail("GREEN_contract_defects:" + ";".join(flattened))
    print(
        "@@SYNC_PRODUCT_PREFRAMING_STRUCTURE_GREEN_PASS@@ core_instances=1 "
        "enc128_leaves=2 reset_synchronizers=1 source_tiers=2 completion_ports=1 "
        "product_manifests=3 forbidden_sources=0"
    )
    return 0


def run_self_test() -> int:
    ideal_manifests = {
        "product_manifest": PRODUCT_EXPECTED,
        "macro_manifest": MACRO_EXPECTED,
        "wrapper_manifest": WRAPPER_EXPECTED,
    }
    if manifest_defects(ideal_manifests):
        raise ContractError("self_test_ideal_manifest_rejected")
    missing_core = dict(ideal_manifests)
    missing_core["product_manifest"] = tuple(
        item for item in PRODUCT_EXPECTED if item != REL["core"]
    )
    if not manifest_defects(missing_core):
        raise ContractError("self_test_missing_core_manifest_plant_escaped")
    forbidden = dict(ideal_manifests)
    forbidden["product_manifest"] = PRODUCT_EXPECTED + (
        "source/design/hardware_codec/event_link/opendvs_event_spi_slave.sv",
    )
    if not any("forbidden_source" in item for item in manifest_defects(forbidden)):
        raise ContractError("self_test_forbidden_source_plant_escaped")

    ideal_col = """
      output logic source_record_valid_o; output logic [135:0] source_record_o;
      assign source_record_valid_o = fifo_wr_en;
      assign source_record_o = {event_mode, row_addr, col_left_m2, col_right_m2};
      assign internal_wdata_fifo = {event_mode, row_addr, col_left_m2, col_right_m2};
    """
    ideal_fifo = """
      output logic top_record_valid_o; output logic [135:0] top_record_o;
      output logic bottom_record_valid_o; output logic [135:0] bottom_record_o;
      x a(.source_record_valid_o(top_record_valid_o),.source_record_o(top_record_o));
      x b(.source_record_valid_o(bottom_record_valid_o),.source_record_o(bottom_record_o));
    """
    ideal_final_seam = """
      logic top_record_valid; logic [135:0] top_record;
      logic bottom_record_valid; logic [135:0] bottom_record;
      x d(.top_record_valid_o(top_record_valid),.top_record_o(top_record),
          .bottom_record_valid_o(bottom_record_valid),.bottom_record_o(bottom_record));
    """
    if source_seam_defects(ideal_col, ideal_fifo, ideal_final_seam):
        raise ContractError("self_test_ideal_source_seam_rejected")
    swapped = ideal_col.replace("col_left_m2, col_right_m2", "col_right_m2, col_left_m2")
    if not source_seam_defects(swapped, ideal_fifo, ideal_final_seam):
        raise ContractError("self_test_record_mapping_plant_escaped")
    gated = ideal_col.replace(
        "source_record_valid_o = fifo_wr_en",
        "source_record_valid_o = fifo_wr_en && !full_fifo",
    )
    if not source_seam_defects(gated, ideal_fifo, ideal_final_seam):
        raise ContractError("self_test_full_gated_valid_plant_escaped")

    ideal_spi = """
      output logic serial_beat_complete_o;
      if (CS_N) serial_beat_complete_o <= 1'b0;
      else begin serial_beat_complete_o <= 1'b0;
        if (cycle_count == 4'd13) shift_en_fifo <= 2'b11;
        else if (cycle_count == 4'd14) shift_en_fifo <= 2'b00;
        else if (cycle_count == 4'd15) begin
          serial_beat_complete_o <= 1'b1;
        end
      end
    """
    ideal_final_completion = """
      logic serial_beat_complete;
      spi_peripheral_re s(.serial_beat_complete_o(serial_beat_complete));
    """
    if completion_defects(ideal_spi, ideal_final_completion):
        raise ContractError("self_test_ideal_completion_rejected")
    early = ideal_spi.replace(
        "if (cycle_count == 4'd13) shift_en_fifo <= 2'b11;",
        "if (cycle_count == 4'd13) begin shift_en_fifo <= 2'b11; "
        "serial_beat_complete_o <= 1'b1; end",
    )
    if not completion_defects(early, ideal_final_completion):
        raise ContractError("self_test_cycle13_completion_plant_escaped")

    print(
        "@@SYNC_PRODUCT_PREFRAMING_STRUCTURE_SELF_TEST_PASS@@ controls=5 "
        "missing_core=1 forbidden_source=1 mapping_swap=1 full_gate=1 cycle13=1"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "mode",
        choices=("preflight", "expect-red", "expect-green", "self-test"),
    )
    args = parser.parse_args()
    try:
        if args.mode == "preflight":
            return run_preflight()
        if args.mode == "expect-red":
            return run_expect_red()
        if args.mode == "expect-green":
            return run_expect_green()
        return run_self_test()
    except ContractError as error:
        fail(str(error))
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
