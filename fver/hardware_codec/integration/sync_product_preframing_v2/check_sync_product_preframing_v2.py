#!/usr/bin/env python3
"""Fail-closed v2 oracle for synchronous product pre-framing acceptance."""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
TEST_REL = "fver/hardware_codec/integration/sync_product_preframing_v2"
TEST_DIR = ROOT / TEST_REL
V1_REL = "fver/hardware_codec/integration/sync_product_preframing"
V1_DIR = ROOT / V1_REL

SPEC_V2 = Path(
    "/home/rpgraca/opencode-sessions/dvs-encoder/.ocs/artifacts/files/"
    "aed-codec-campaign-v0/work/hardware-codec-v1/"
    "digital-repository-integration/"
    "sync-product-preframing-integration-unit-v2.md"
)
SPEC_V1 = SPEC_V2.with_name("sync-product-preframing-integration-unit-v1.md")
EXPECTED_SPEC_V2_SHA256 = "155829ba6baec17671ebb6deab2763e894c122469eae7cfe388132babde9e48f"
EXPECTED_SPEC_V1_SHA256 = "dd6a6d63198f39468f6c5357beda4fc9c51f3162f9a5b2901f68058c80fcf41e"
EXPECTED_V1_SOURCE_SEAL_SHA256 = "48952e752c8fc7fe03f0356480b63c26e6920296983050049c1a6c5f14649b50"

EXPECTED_CORE_SHA256 = "cc8aa66e33dbd5d9a88b14305efb5f275829b6a54d266c1cf507c2769a8c04cb"
EXPECTED_LEAF_SHA256 = "0c77fa83ec15af0c06df96b04dcfc67dd02cad23ffd075cf1f59f879a6cad54d"
EXPECTED_RST_SHA256 = "16027ca7e27717024d130b8bb767bfd9d960ac4da75eea4413cf953c9702ec40"
EXPECTED_SHELL_SHA256 = "1b72277a01c83c9e2f259a78fb71d5423684c1ff52021c119b79b4192f781a12"
EXPECTED_BAD_WRAPPER_SHA256 = "7cf1568e7e64841edff6dc7925a9534ce22df2791028df32b10a97571d7fe170"

PACKAGE_FILES = (
    "README.md",
    "check_sync_product_preframing_v2.py",
    "fixture_sources_v2.f",
    "fixture_sync_product_preframing_v2.sv",
    "product_sources_v2.f",
    "tb_sync_product_preframing_v2.sv",
    "run_sync_product_preframing_v2.sh",
    "tb_current_product_reset_binding_v2.sv",
    "run_current_product_reset_binding_v2.sh",
    "test-source-v2.sha256",
    "current-product-source-v2.sha256",
    "v1-archive-seal.sha256",
)

TEST_SEAL_FILES = (
    f"{TEST_REL}/README.md",
    f"{TEST_REL}/check_sync_product_preframing_v2.py",
    f"{TEST_REL}/fixture_sources_v2.f",
    f"{TEST_REL}/fixture_sync_product_preframing_v2.sv",
    f"{TEST_REL}/product_sources_v2.f",
    f"{TEST_REL}/run_current_product_reset_binding_v2.sh",
    f"{TEST_REL}/run_sync_product_preframing_v2.sh",
    f"{TEST_REL}/tb_current_product_reset_binding_v2.sv",
    f"{TEST_REL}/tb_sync_product_preframing_v2.sv",
    f"{TEST_REL}/v1-archive-seal.sha256",
)

V1_SOURCE_HASHES = {
    f"{V1_REL}/README.md": "6b5d5e3455c2686324a5eb5a4090ba6b18f459282b2f569aad49dd379c73d5d3",
    f"{V1_REL}/check_sync_product_preframing.py": "68cf57e6fb39dc38b953bed9090966329181ee0efc5d89e38958f061fd4ff483",
    f"{V1_REL}/fixture_sources.f": "2b68e8deb9f2ded393c0eff7a65db5bc39ebf49269b1d66e5e081a2901ec0bb8",
    f"{V1_REL}/fixture_sync_product_preframing.sv": "2ea74f391ee55f3a14293a6107caae5caf7a691cc3aa907bf9d07451622b10a2",
    f"{V1_REL}/product_sources.f": "e8f95317fe84aa95b8fd0d557496d4a7fc446587f86676eb515648ff60ff35bd",
    f"{V1_REL}/run_sync_product_preframing.sh": "cde1879433c2e8d0ba82857f5f06dbe77958859be9d76c1d5728499c5e21e0ec",
    f"{V1_REL}/tb_sync_product_preframing.sv": "1c7b23e2f7f27a39ecc1bcfbfa93031b91c61a55d6230ae70ea6199da524a197",
}

PROTECTED_HISTORY_HASHES = {
    "fver/hardware_codec/integration/baseline_reset/tb_baseline_reset_binding.sv":
        "82d4cf27c4d718b179712461dc970a56318bfa9ed2e0493b19924daf5252fa61",
    "fver/hardware_codec/integration/baseline_reset/run_baseline_reset_binding.sh":
        "95e740dee30cb5a23b46068e0022127df13625bfd69683a9bd18954a77dcab83",
    "fver/hardware_codec/integration/sync_mode_ownership/tb_sync_mode_ownership_product.sv":
        "31ede8b6345fed8e0ccace5b9f7f9e453caf08c4f00f1a9734aeea247a9140ab",
    "fver/hardware_codec/integration/sync_mode_ownership/tb_sync_mode_ownership_safety.sv":
        "8fc2f33805303fbb7505e1986e58c44e7302c6434d0c4d9a7d9c99efe2a35cdc",
    "fver/hardware_codec/integration/baseline_abort/tb_baseline_serial_abort.sv":
        "a70ae3fc11c7375dcae50be984e85bdb3bb760be497146b58420e80f6f680dec",
}

REL = {
    "col": "source/design/final_macros/col_readout_macro.sv",
    "fifo_macro": "source/design/final_macros/fifo_rows_cols_macro2.sv",
    "final": "source/design/final_macros/final_top3.sv",
    "spi": "source/design/regfile/spi_peripheral_re.sv",
    "core": "source/design/hardware_codec/sync/opendvs_sync_product_encoder_core.sv",
    "leaf": "source/design/hardware_codec/sync/enc128_v2_vendored.sv",
    "shell": "source/design/hardware_codec/control/opendvs_sync_mode_ownership_shell.sv",
    "rst": "source/design/common/rst_sync.sv",
    "wrapper": "fver/user_project_wrapper/verilog/open_dvs_top.sv",
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
    "../final_top_tb3.sv",
)
MACRO_RED = tuple(
    "../../../source/design/regfile/regfile.sv"
    if item == "../../../source/design/regfile/regfile_final.sv" else item
    for item in MACRO_EXPECTED
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
    "../verilog/open_dvs_top.sv",
    "../verilog/user_project_wrapper.sv",
    "../verilog/blackboxes.sv",
    "../verilog/user_project_wrapper_tb.sv",
)
WRAPPER_RED = tuple(
    item for item in WRAPPER_EXPECTED if item != "../verilog/open_dvs_top.sv"
)

FIXTURE_EXPECTED = (
    "source/design/common/rst_sync.sv",
    "source/design/hardware_codec/sync/enc128_v2_vendored.sv",
    "source/design/hardware_codec/sync/opendvs_sync_product_encoder_core.sv",
    "source/design/hardware_codec/control/opendvs_sync_mode_ownership_shell.sv",
    f"{TEST_REL}/fixture_sync_product_preframing_v2.sv",
    f"{TEST_REL}/tb_sync_product_preframing_v2.sv",
)
PRODUCT_TEST_EXPECTED = PRODUCT_EXPECTED + (
    f"{TEST_REL}/tb_sync_product_preframing_v2.sv",
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
        "wrong_final_macros_register_dependency",
        "final_macros_manifest_uses_regfile.sv_instead_of_regfile_final.sv",
    ),
    (
        "missing_wrapper_open_dvs_top_dependency",
        "wrapper_manifest_omits_open_dvs_top.sv_between_final_top3_and_user_project_wrapper",
    ),
    (
        "illegal_wrapper_variable_inout_declarations",
        "open_dvs_top_declares_pad_bias_and_rx_as_inout_logic_instead_of_inout_wire",
    ),
)


class ContractError(RuntimeError):
    """A package prerequisite or acceptance contract was violated."""


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fail(message: str) -> None:
    print(f"@@SYNC_PRODUCT_PREFRAMING_V2_STRUCTURE_FAIL@@ message={message}")
    raise SystemExit(2)


def require_regular(path: Path, label: str) -> None:
    if not path.is_file() or path.is_symlink():
        raise ContractError(f"{label}_missing_nonregular_or_symlink:{path}")


def require_hash(path: Path, expected: str, label: str) -> None:
    require_regular(path, label)
    observed = sha256(path)
    if observed != expected:
        raise ContractError(
            f"{label}_sha256_mismatch:expected={expected}:observed={observed}"
        )


def parse_seal(path: Path) -> tuple[tuple[str, str], ...]:
    require_regular(path, "seal")
    rows: list[tuple[str, str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([^\0]+)", line)
        if match is None:
            raise ContractError(f"invalid_seal_row:{path}:{line!r}")
        rows.append((match.group(2), match.group(1)))
    return tuple(rows)


def verify_v1_archive(*, emit: bool = True) -> None:
    require_hash(SPEC_V1, EXPECTED_SPEC_V1_SHA256, "v1_specification")
    source_seal = V1_DIR / "test-source.sha256"
    require_hash(source_seal, EXPECTED_V1_SOURCE_SEAL_SHA256, "v1_source_seal")
    source_rows = parse_seal(source_seal)
    if source_rows != tuple(V1_SOURCE_HASHES.items()):
        raise ContractError("v1_source_seal_inventory_or_hashes_differ")
    for relative, expected in V1_SOURCE_HASHES.items():
        require_hash(ROOT / relative, expected, f"v1_archive_{Path(relative).name}")

    archive_expected = (
        (str(SPEC_V1), EXPECTED_SPEC_V1_SHA256),
        *tuple(V1_SOURCE_HASHES.items()),
    )
    archive_rows = parse_seal(TEST_DIR / "v1-archive-seal.sha256")
    if archive_rows != archive_expected:
        raise ContractError("v1_archive_seal_inventory_or_hashes_differ")
    if emit:
        print("@@SYNC_PRODUCT_PREFRAMING_V2_V1_ARCHIVE_PASS@@ spec=1 harness_seal=1")


def verify_test_seal(*, emit: bool = True) -> None:
    rows = parse_seal(TEST_DIR / "test-source-v2.sha256")
    if tuple(relative for relative, _ in rows) != TEST_SEAL_FILES:
        raise ContractError("v2_test_source_seal_inventory_differs")
    for relative, expected in rows:
        require_hash(ROOT / relative, expected, f"v2_test_source_{Path(relative).name}")
    if emit:
        print(
            "@@SYNC_PRODUCT_PREFRAMING_V2_TEST_SEAL_PASS@@ "
            f"files={len(TEST_SEAL_FILES)}"
        )


def verify_qualified_dependencies() -> None:
    for relative, expected, label in (
        (REL["core"], EXPECTED_CORE_SHA256, "qualified_product_core"),
        (REL["leaf"], EXPECTED_LEAF_SHA256, "qualified_enc128_leaf"),
        (REL["rst"], EXPECTED_RST_SHA256, "qualified_reset_synchronizer"),
        (REL["shell"], EXPECTED_SHELL_SHA256, "qualified_ownership_shell"),
    ):
        require_hash(ROOT / relative, expected, label)


def verify_protected_history() -> None:
    for relative, expected in PROTECTED_HISTORY_HASHES.items():
        require_hash(ROOT / relative, expected, f"protected_history_{Path(relative).name}")


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
    return re.search(
        rf"\.{re.escape(port)}\s*\(\s*{re.escape(expression)}\s*\)",
        strip_sv_comments(text),
    ) is not None


def forbidden_manifest_defects(
    manifests: dict[str, tuple[str, ...]],
) -> list[str]:
    defects: list[str] = []
    for name, entries in manifests.items():
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

    for port, expression in (
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
    ):
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
    for item in (
        "outputlogicsource_record_valid_o",
        "outputlogic[135:0]source_record_o",
        "assignsource_record_valid_o=fifo_wr_en;",
        "assignsource_record_o={event_mode,row_addr,col_left_m2,col_right_m2};",
        "assigninternal_wdata_fifo={event_mode,row_addr,col_left_m2,col_right_m2};",
    ):
        if item not in col:
            defects.append(f"column_source_contract:{item}")
    if "assignsource_record_valid_o=fifo_wr_en&&!full_fifo;" in col:
        defects.append("column_source_valid_is_gated_by_full")
    for item in (
        "outputlogictop_record_valid_o",
        "outputlogic[135:0]top_record_o",
        "outputlogicbottom_record_valid_o",
        "outputlogic[135:0]bottom_record_o",
    ):
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
    for item in (
        "logictop_record_valid;",
        "logic[135:0]top_record;",
        "logicbottom_record_valid;",
        "logic[135:0]bottom_record;",
    ):
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
    if re.search(r"assign\s+serial_beat_complete_o\s*=\s*.*shift_en_fifo", spi_clean):
        defects.append("spi_completion_aliases_consume")
    if "logicserial_beat_complete;" not in final:
        defects.append("final_top_completion_signal")
    if not has_connection(final_text, "serial_beat_complete_o", "serial_beat_complete"):
        defects.append("final_top_completion_connection")
    return defects


def wrapper_port_defects(text: str) -> list[str]:
    clean = strip_sv_comments(text)
    defects: list[str] = []
    if len(re.findall(r"\binout\s+wire\s*\[9:0\]\s+pad_bias\b", clean)) != 1:
        defects.append("wrapper_pad_bias_is_not_exact_inout_wire_9_0")
    if len(re.findall(r"\binout\s+wire\s+rx\b", clean)) != 1:
        defects.append("wrapper_rx_is_not_exact_inout_wire")
    if re.search(r"\binout\s+logic\b", clean):
        defects.append("wrapper_retains_variable_inout_logic")
    return defects


def wrapper_is_exact_known_bad(text: str) -> bool:
    return hashlib.sha256(text.encode("utf-8")).hexdigest() == EXPECTED_BAD_WRAPPER_SHA256


def wrapper_is_exact_narrow_correction(text: str) -> bool:
    old_pad = "    inout wire [9:0] pad_bias,"
    old_rx = "    inout wire       rx"
    if text.splitlines().count(old_pad) != 1 or text.splitlines().count(old_rx) != 1:
        return False
    reconstructed = text.replace(old_pad, "    inout logic [9:0] pad_bias,")
    reconstructed = reconstructed.replace(old_rx, "    inout logic       rx")
    return hashlib.sha256(reconstructed.encode("utf-8")).hexdigest() == EXPECTED_BAD_WRAPPER_SHA256


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


def inherited_defects(
    texts: dict[str, str], manifests: dict[str, tuple[str, ...]]
) -> list[str]:
    defects = forbidden_manifest_defects(manifests)
    defects.extend(topology_defects(texts["final"], texts["core"]))
    defects.extend(source_seam_defects(texts["col"], texts["fifo_macro"], texts["final"]))
    defects.extend(completion_defects(texts["spi"], texts["final"]))
    if manifests["product_manifest"] != PRODUCT_EXPECTED:
        defects.append("product_manifest_exact_active_entries")
    return defects


def green_closure_defects(
    texts: dict[str, str], manifests: dict[str, tuple[str, ...]]
) -> list[str]:
    defects = inherited_defects(texts, manifests)
    if manifests["macro_manifest"] != MACRO_EXPECTED:
        defects.append("macro_manifest_exact_active_entries")
    if manifests["wrapper_manifest"] != WRAPPER_EXPECTED:
        defects.append("wrapper_manifest_exact_active_entries")
    defects.extend(wrapper_port_defects(texts["wrapper"]))
    if not wrapper_is_exact_narrow_correction(texts["wrapper"]):
        defects.append("wrapper_edit_is_not_exact_two_declaration_correction")
    return defects


def verify_package_paths() -> None:
    if TEST_DIR != ROOT / TEST_REL:
        raise ContractError("v2_package_is_not_at_fixed_path")
    observed = tuple(sorted(path.name for path in TEST_DIR.iterdir()))
    expected = tuple(sorted(PACKAGE_FILES))
    if observed != expected:
        raise ContractError(f"v2_package_inventory_differs:{observed!r}")
    for name in PACKAGE_FILES:
        require_regular(TEST_DIR / name, f"v2_package_{name}")
    for name, expected_entries in (
        ("fixture_sources_v2.f", FIXTURE_EXPECTED),
        ("product_sources_v2.f", PRODUCT_TEST_EXPECTED),
    ):
        observed_entries = active_entries((TEST_DIR / name).read_text(encoding="utf-8"))
        if observed_entries != expected_entries:
            raise ContractError(f"v2_{name}_exact_entries_differ")


def verify_whitespace() -> None:
    for relative in TEST_SEAL_FILES:
        path = ROOT / relative
        data = path.read_bytes()
        if not data.endswith(b"\n"):
            raise ContractError(f"v2_test_source_lacks_final_newline:{relative}")
        text = data.decode("utf-8")
        for line_number, line in enumerate(text.splitlines(), start=1):
            if line.endswith((" ", "\t")):
                raise ContractError(
                    f"v2_test_source_trailing_whitespace:{relative}:{line_number}"
                )


def verify_scope(*, emit: bool = True) -> None:
    verify_package_paths()
    verify_v1_archive(emit=False)
    verify_protected_history()
    verify_whitespace()
    result = subprocess.run(
        ["/usr/bin/git", "-C", str(ROOT), "diff", "--cached", "--name-only", "-z"],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.stdout:
        raise ContractError("staged_paths_are_not_absent")
    if emit:
        print(
            "@@SYNC_PRODUCT_PREFRAMING_V2_SCOPE_PASS@@ package_files=12 "
            "v1_changed=0 protected_history_changed=0 staged_paths=0"
        )


def current_source_paths(manifests: dict[str, tuple[str, ...]]) -> tuple[str, ...]:
    bases = {
        "product_manifest": ROOT,
        "macro_manifest": (ROOT / REL["macro_manifest"]).parent,
        "wrapper_manifest": (ROOT / REL["wrapper_manifest"]).parent,
    }
    paths = {REL[name] for name in bases}
    for name, base in bases.items():
        for entry in manifests[name]:
            candidate = (base / entry).resolve(strict=True)
            try:
                relative = candidate.relative_to(ROOT.resolve())
            except ValueError as error:
                raise ContractError(f"manifest_path_escapes_repository:{name}:{entry}") from error
            require_regular(candidate, f"current_product_source_{entry}")
            paths.add(relative.as_posix())
    return tuple(sorted(paths))


def verify_current_product_seal(*, emit: bool = True) -> None:
    texts, manifests = load_live()
    defects = green_closure_defects(texts, manifests)
    if defects:
        raise ContractError("current_product_is_not_green:" + ";".join(defects))
    expected_paths = current_source_paths(manifests)
    rows = parse_seal(TEST_DIR / "current-product-source-v2.sha256")
    if tuple(relative for relative, _ in rows) != expected_paths:
        raise ContractError("current_product_source_seal_inventory_differs_or_is_unfinalized")
    for relative, expected in rows:
        require_hash(ROOT / relative, expected, f"current_product_seal_{Path(relative).name}")
    if emit:
        print(
            "@@SYNC_PRODUCT_PREFRAMING_V2_CURRENT_SOURCE_SEAL_PASS@@ "
            f"files={len(rows)}"
        )


def generate_current_product_seal() -> int:
    verify_test_seal(emit=False)
    verify_v1_archive(emit=False)
    verify_qualified_dependencies()
    verify_protected_history()
    texts, manifests = load_live()
    defects = green_closure_defects(texts, manifests)
    if defects:
        raise ContractError("refusing_to_seal_non_green_current_product:" + ";".join(defects))
    paths = current_source_paths(manifests)
    content = "".join(f"{sha256(ROOT / relative)}  {relative}\n" for relative in paths)
    destination = TEST_DIR / "current-product-source-v2.sha256"
    require_regular(destination, "current_product_seal_destination")
    temporary = TEST_DIR / ".current-product-source-v2.sha256.tmp"
    if temporary.exists() or temporary.is_symlink():
        raise ContractError("current_product_seal_temporary_path_already_exists")
    try:
        temporary.write_text(content, encoding="utf-8", newline="\n")
        os.chmod(temporary, 0o600)
        os.replace(temporary, destination)
    finally:
        if temporary.exists():
            temporary.unlink()
    verify_current_product_seal(emit=False)
    print(
        "@@SYNC_PRODUCT_PREFRAMING_V2_CURRENT_SOURCE_SEAL_GENERATED@@ "
        f"files={len(paths)} sha256={sha256(destination)}"
    )
    return 0


def verify_reset_structure(*, emit: bool = True) -> None:
    path = ROOT / REL["fifo_macro"]
    require_regular(path, "current_reset_source")
    lines = path.read_text(encoding="utf-8").splitlines()
    expected = (
        "    assign fsm_row_rst_n_top = rst_n & ~fsm_rst_n;",
        "    assign fsm_row_rst_n_bot = rst_n & ~fsm_rst_n;",
        "    assign col_rst_n_top     = rst_n & ~fifo_rst_n;",
        "    assign col_rst_n_bot     = rst_n & ~fifo_rst_n;",
    )
    if tuple(line for line in lines if any(name in line for name in (
        "assign fsm_row_rst_n_top", "assign fsm_row_rst_n_bot",
        "assign col_rst_n_top", "assign col_rst_n_bot",
    ))) != expected:
        raise ContractError("current_product_reset_equations_differ")
    if any("fsm_rst_n_reg" in line or "fifo_rst_n_reg" in line for line in lines):
        raise ContractError("current_product_reset_uses_undeclared_registered_names")
    if emit:
        print(
            "@@SYNC_PRODUCT_PREFRAMING_V2_RESET_STRUCTURE_PASS@@ "
            "reset_equations=4 fsm=2 fifo=2"
        )


def run_preflight() -> int:
    require_hash(SPEC_V2, EXPECTED_SPEC_V2_SHA256, "v2_specification")
    verify_package_paths()
    verify_v1_archive(emit=False)
    verify_test_seal(emit=False)
    verify_qualified_dependencies()
    verify_protected_history()
    verify_reset_structure(emit=False)
    verify_scope(emit=False)
    print(
        "@@SYNC_PRODUCT_PREFRAMING_V2_STRUCTURE_PREFLIGHT_PASS@@ "
        "spec_hash=1 archive=1 test_seal=1 qualified_hashes=4 "
        "protected_history=1 paths=1 scope=1"
    )
    return 0


def run_expect_red() -> int:
    texts, manifests = load_live()
    verify_qualified_dependencies()
    defects = inherited_defects(texts, manifests)
    if defects:
        raise ContractError("RED_has_inherited_or_unrelated_defects:" + ";".join(defects))
    if manifests["macro_manifest"] != MACRO_RED:
        raise ContractError("RED_final_macros_inventory_is_not_exact_known_bad_inventory")
    if manifests["wrapper_manifest"] != WRAPPER_RED:
        raise ContractError("RED_wrapper_inventory_is_not_exact_known_bad_inventory")
    if not wrapper_is_exact_known_bad(texts["wrapper"]):
        raise ContractError("RED_wrapper_source_is_not_exact_known_bad_source")
    clean_wrapper = strip_sv_comments(texts["wrapper"])
    if len(re.findall(r"\binout\s+logic\s*\[9:0\]\s+pad_bias\b", clean_wrapper)) != 1:
        raise ContractError("RED_pad_bias_illegal_declaration_is_not_exact")
    if len(re.findall(r"\binout\s+logic\s+rx\b", clean_wrapper)) != 1:
        raise ContractError("RED_rx_illegal_declaration_is_not_exact")
    for reason_id, message in RED_REASONS:
        print(
            "@@SYNC_PRODUCT_PREFRAMING_V2_RED_REASON@@ "
            f"id={reason_id} observed={message}"
        )
    print(
        "@@SYNC_PRODUCT_PREFRAMING_V2_RED_CONFIRMED@@ reasons=3 behavior_run=0 "
        "inherited_contract=1 qualified_hashes=4"
    )
    return 0


def run_expect_green() -> int:
    texts, manifests = load_live()
    verify_qualified_dependencies()
    defects = green_closure_defects(texts, manifests)
    if defects:
        raise ContractError("GREEN_contract_defects:" + ";".join(defects))
    verify_current_product_seal(emit=False)
    print(
        "@@SYNC_PRODUCT_PREFRAMING_V2_STRUCTURE_GREEN_PASS@@ manifests=3 "
        "core_instances=1 enc128_leaves=2 reset_synchronizers=1 "
        "source_tiers=2 completion_ports=1 forbidden_sources=0"
    )
    return 0


def run_self_test() -> int:
    ideal_manifests = {
        "product_manifest": PRODUCT_EXPECTED,
        "macro_manifest": MACRO_EXPECTED,
        "wrapper_manifest": WRAPPER_EXPECTED,
    }
    if forbidden_manifest_defects(ideal_manifests):
        raise ContractError("self_test_ideal_manifest_rejected")
    missing_core = dict(ideal_manifests)
    missing_core["product_manifest"] = tuple(
        item for item in PRODUCT_EXPECTED if item != REL["core"]
    )
    if missing_core["product_manifest"] == PRODUCT_EXPECTED:
        raise ContractError("self_test_missing_core_manifest_plant_escaped")
    forbidden = dict(ideal_manifests)
    forbidden["product_manifest"] = PRODUCT_EXPECTED + (
        "source/design/hardware_codec/event_link/opendvs_event_spi_slave.sv",
    )
    if not forbidden_manifest_defects(forbidden):
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

    if MACRO_RED == MACRO_EXPECTED:
        raise ContractError("self_test_wrong_register_dependency_control_escaped")
    if WRAPPER_RED == WRAPPER_EXPECTED:
        raise ContractError("self_test_missing_wrapper_dependency_control_escaped")
    ideal_ports = "inout wire [9:0] pad_bias,\ninout wire       rx\n"
    illegal_ports = ideal_ports.replace("wire", "logic")
    if wrapper_port_defects(ideal_ports):
        raise ContractError("self_test_ideal_wrapper_ports_rejected")
    if not wrapper_port_defects(illegal_ports):
        raise ContractError("self_test_illegal_wrapper_ports_control_escaped")

    print(
        "@@SYNC_PRODUCT_PREFRAMING_V2_STRUCTURE_SELF_TEST_PASS@@ "
        "inherited_controls=5 closure_controls=3 controls=8 "
        "missing_core=1 forbidden_source=1 mapping_swap=1 full_gate=1 "
        "cycle13=1 wrong_register=1 missing_wrapper_dependency=1 illegal_inout=1"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "mode",
        choices=(
            "preflight",
            "self-test",
            "expect-red",
            "expect-green",
            "verify-v1-archive",
            "verify-test-seal",
            "verify-current-product-seal",
            "generate-current-product-seal",
            "verify-reset-structure",
            "scope-audit",
        ),
    )
    args = parser.parse_args()
    try:
        if args.mode == "preflight":
            return run_preflight()
        if args.mode == "self-test":
            return run_self_test()
        if args.mode == "expect-red":
            return run_expect_red()
        if args.mode == "expect-green":
            return run_expect_green()
        if args.mode == "verify-v1-archive":
            verify_v1_archive()
            return 0
        if args.mode == "verify-test-seal":
            verify_test_seal()
            return 0
        if args.mode == "verify-current-product-seal":
            verify_current_product_seal()
            return 0
        if args.mode == "generate-current-product-seal":
            return generate_current_product_seal()
        if args.mode == "verify-reset-structure":
            verify_reset_structure()
            return 0
        verify_scope()
        return 0
    except (ContractError, OSError, subprocess.SubprocessError) as error:
        fail(str(error))
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
