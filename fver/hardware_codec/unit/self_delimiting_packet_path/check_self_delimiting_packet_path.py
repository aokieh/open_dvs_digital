#!/usr/bin/env python3
"""Fail-closed contract and source preflight for the packet-path RED unit."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
TEST_REL = "fver/hardware_codec/unit/self_delimiting_packet_path"
TEST_DIR = ROOT / TEST_REL
FILELIST_REL = "fver/hardware_codec/filelists/self_delimiting_packet_path_unit.f"
REFERENCE_SEAL = TEST_DIR / "reference-source.sha256"
TEST_SEAL = TEST_DIR / "test-source.sha256"

ARTIFACT_BASE = Path(
    "/home/rpgraca/opencode-sessions/dvs-encoder/.ocs/artifacts/files/"
    "aed-codec-campaign-v0/work/hardware-codec-v1/"
    "digital-repository-integration"
)
CANDIDATE_BASE = (
    ARTIFACT_BASE
    / "framing-research-v1/candidates/self-delimiting-v1"
)

REFERENCE_ROWS = (
    (
        "c15a86a974794fbd3d98a0647bc9a5e82d4841996c34be952fe722cb975dd361",
        str(ARTIFACT_BASE / "self-delimiting-packet-path-unit-v1.md"),
    ),
    (
        "96767761f802e459e7fadb9087e236f184c7ae3a94b456dafb6361395aeedccd",
        str(
            ARTIFACT_BASE
            / "framing-research-v4-low-cost/framing-selection-freeze-v4.md"
        ),
    ),
    (
        "b414df65f9a83e7b8d8bd107149a384e68687c50199f38e85b02cf46f3a3408b",
        str(
            ARTIFACT_BASE
            / "framing-research-v4-low-cost/framing-low-cost-result-v4.json"
        ),
    ),
    (
        "6a0c4953a0d6a92820adb83a3479b5d5d0b1c187f8852e45dc2721f817558412",
        str(CANDIDATE_BASE / "expected-bytes-v1.json"),
    ),
    (
        "addd877170f19440276e341fd7b6ea066daea15e79ca4b22c6b8f59660322154",
        str(CANDIDATE_BASE / "malformed-controls-v1.json"),
    ),
    (
        "911324388ce0936c43d0c806b4f4914924351a84d112129bb38b2926712744c0",
        str(CANDIDATE_BASE / "self_delimiting_encoder_v1.py"),
    ),
    (
        "e09ee26f7c77cf14bd3430fb43e36e1f368c33ae29b00c9f7383480b9418f85c",
        str(CANDIDATE_BASE / "self_delimiting_decoder_v1.py"),
    ),
    (
        "4e4618db4530419f488edfb7bf1d853ab8699c7fd606eab1110d643fc4a71612",
        str(CANDIDATE_BASE / "test_self_delimiting_v1.py"),
    ),
    (
        "cc8aa66e33dbd5d9a88b14305efb5f275829b6a54d266c1cf507c2769a8c04cb",
        "source/design/hardware_codec/sync/opendvs_sync_product_encoder_core.sv",
    ),
    (
        "1b72277a01c83c9e2f259a78fb71d5423684c1ff52021c119b79b4192f781a12",
        "source/design/hardware_codec/control/opendvs_sync_mode_ownership_shell.sv",
    ),
    (
        "29837863aaf58552d1db6d6f4189d3bab0d3301a994956155ca1d3b10bbfcced",
        "source/design/final_macros/final_top3.sv",
    ),
    (
        "949ba4bb93c801573c29fdacdff294daa4d4be923a456d6fc5d159efb4685286",
        "source/design/regfile/spi_peripheral_re.sv",
    ),
    (
        "c5ebe122e1cc3815a5e85d9afe77b9567240cad6591da975ecd7daf7c23d1a39",
        "source/design/final_macros/fifo_rows_cols_macro2.sv",
    ),
    (
        "29cf88000132c5a84020e422fe89df59beb2c7ba301b51ef406334929597c948",
        "source/design/sync_fifo/fifo_intf3.sv",
    ),
    (
        "484efc729c0c542a729ca2c88ecdff8feb7dea1998370525c1dd7732df895455",
        "source/design/common/defines.sv",
    ),
)

PACKAGE_FILES = (
    "README.md",
    "check_self_delimiting_packet_path.py",
    "fixture_opendvs_self_delimiting_packet_path.sv",
    "reference-source.sha256",
    "run_self_delimiting_packet_path.sh",
    "run_self_delimiting_packet_path_synthesis.sh",
    "tb_opendvs_self_delimiting_packet_path.sv",
    "test-source.sha256",
)
TEST_SEAL_PATHS = (
    FILELIST_REL,
    f"{TEST_REL}/README.md",
    f"{TEST_REL}/check_self_delimiting_packet_path.py",
    f"{TEST_REL}/fixture_opendvs_self_delimiting_packet_path.sv",
    f"{TEST_REL}/reference-source.sha256",
    f"{TEST_REL}/run_self_delimiting_packet_path.sh",
    f"{TEST_REL}/run_self_delimiting_packet_path_synthesis.sh",
    f"{TEST_REL}/tb_opendvs_self_delimiting_packet_path.sv",
)

INTERFACE_PORTS = (
    "clk_i",
    "arst_ni",
    "sync_mode_active_i",
    "sync_mode_entry_i",
    "drain_i",
    "top_fragment_valid_i",
    "top_fragment_ready_o",
    "top_fragment_raw_i",
    "top_fragment_length_i",
    "top_fragment_payload_i",
    "bottom_fragment_valid_i",
    "bottom_fragment_ready_o",
    "bottom_fragment_raw_i",
    "bottom_fragment_length_i",
    "bottom_fragment_payload_i",
    "encoder_quiescent_i",
    "serial_boundary_quiescent_i",
    "serial_consume_i",
    "serial_beat_complete_i",
    "stream_abort_i",
    "core_admit_enable_o",
    "packet_ready_o",
    "serial_data_0_o",
    "serial_data_1_o",
    "quiescent_o",
    "sticky_fault_o",
    "sequence_o",
    "mode_epoch_o",
    "packet_bytes_o",
    "beat_index_o",
    "completion_pending_o",
)

PASS_MARKER = "@@OPENDVS_SELF_DELIMITING_PACKET_PATH_CONTRACT_PREFLIGHT_PASS@@"
FAIL_MARKER = "@@OPENDVS_SELF_DELIMITING_PACKET_PATH_FAIL@@"


class ContractError(RuntimeError):
    """The frozen package or one of its authorities changed."""


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require_regular(path: Path, label: str) -> None:
    if not path.is_file() or path.is_symlink():
        raise ContractError(f"{label}_missing_nonregular_or_symlink:{path}")


def resolved_seal_path(value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else ROOT / path


def parse_seal(path: Path) -> tuple[tuple[str, str], ...]:
    require_regular(path, "seal")
    rows: list[tuple[str, str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([^\0]+)", line)
        if match is None:
            raise ContractError(f"invalid_seal_row:{path}:{line!r}")
        rows.append((match.group(1), match.group(2)))
    if not rows:
        raise ContractError(f"empty_seal:{path}")
    return tuple(rows)


def verify_rows(
    path: Path,
    expected_rows: tuple[tuple[str, str], ...],
    label: str,
) -> None:
    rows = parse_seal(path)
    if rows != expected_rows:
        raise ContractError(f"{label}_inventory_or_digest_rows_differ")
    for expected, name in rows:
        target = resolved_seal_path(name)
        require_regular(target, f"{label}_{Path(name).name}")
        observed = sha256(target)
        if observed != expected:
            raise ContractError(
                f"{label}_sha256_mismatch:path={name}:"
                f"expected={expected}:observed={observed}"
            )


def verify_package() -> None:
    if TEST_DIR != ROOT / TEST_REL:
        raise ContractError("package_path_differs")
    observed = tuple(sorted(path.name for path in TEST_DIR.iterdir()))
    if observed != tuple(sorted(PACKAGE_FILES)):
        raise ContractError(f"package_inventory_differs:{observed!r}")
    for name in PACKAGE_FILES:
        require_regular(TEST_DIR / name, f"package_{name}")
    filelist = ROOT / FILELIST_REL
    require_regular(filelist, "filelist")
    if filelist.read_text(encoding="utf-8") != (
        "source/design/hardware_codec/sync/"
        "opendvs_self_delimiting_packet_path.sv\n"
    ):
        raise ContractError("filelist_is_not_exact_one_product_source")
    for path in (filelist, *(TEST_DIR / name for name in PACKAGE_FILES)):
        data = path.read_bytes()
        if not data.endswith(b"\n"):
            raise ContractError(f"missing_final_newline:{path}")
        text = data.decode("utf-8")
        for number, line in enumerate(text.splitlines(), start=1):
            if line.endswith((" ", "\t")):
                raise ContractError(f"trailing_whitespace:{path}:{number}")
    for path in TEST_DIR.rglob("*"):
        if path.is_dir() or path.suffix in {".pyc", ".pyo"}:
            raise ContractError(f"generated_cache_or_directory_present:{path}")


def verify_seals() -> None:
    verify_rows(REFERENCE_SEAL, REFERENCE_ROWS, "reference_source")
    test_rows = parse_seal(TEST_SEAL)
    if tuple(name for _, name in test_rows) != TEST_SEAL_PATHS:
        raise ContractError("test_source_inventory_differs")
    if len({name for _, name in test_rows}) != len(test_rows):
        raise ContractError("test_source_duplicate_path")
    for expected, name in test_rows:
        target = ROOT / name
        require_regular(target, f"test_source_{Path(name).name}")
        observed = sha256(target)
        if observed != expected:
            raise ContractError(
                f"test_source_sha256_mismatch:path={name}:"
                f"expected={expected}:observed={observed}"
            )


def crc8(data: bytes) -> int:
    value = 0
    for byte in data:
        value ^= byte
        for _ in range(8):
            value = ((value << 1) ^ 0x07) & 0xFF if value & 0x80 else (value << 1) & 0xFF
    return value


def columns(record: dict[str, object]) -> tuple[int, ...]:
    if "columns" in record:
        return tuple(int(value) for value in record["columns"])  # type: ignore[index]
    start, stop, step = (int(value) for value in record["columns_range"])  # type: ignore[index]
    return tuple(range(start, stop, step))


def record_bytes(record: dict[str, object]) -> bytes:
    positions = columns(record)
    population = len(positions)
    if len(set(positions)) != population or not all(0 <= value < 128 for value in positions):
        raise ContractError("fixture_columns_invalid")
    tier = int(record["tier"])
    row = int(record["row"])
    polarity = int(record["polarity"])
    if tier not in (0, 1) or polarity not in (0, 1) or not 0 <= row <= 63:
        raise ContractError("fixture_label_or_row_invalid")
    prefix = bytes(((0x80 if population <= 15 else 0) | (polarity << 6), (tier << 6) | row))
    if 1 <= population <= 15:
        ordered = sorted(positions, reverse=True)
        return prefix + bytes(
            value | (0x80 if index == population - 1 else 0)
            for index, value in enumerate(ordered)
        )
    if 16 <= population <= 128:
        mask = sum(1 << value for value in positions)
        return prefix + mask.to_bytes(16, "little")
    raise ContractError("fixture_population_invalid")


def packet_bytes(case: dict[str, object]) -> tuple[bytes, bytes]:
    body = b"".join(record_bytes(record) for record in case["records"])  # type: ignore[index]
    header = bytes((0x24 | int(case["epoch"]), int(case["sequence"]), len(body)))
    packet = header + bytes((crc8(header + body),)) + body + bytes((-len(body)) % 4)
    return body, packet


def verify_vectors() -> None:
    expected_path = CANDIDATE_BASE / "expected-bytes-v1.json"
    data = json.loads(expected_path.read_text(encoding="utf-8"))
    if data.get("schema") != "self-delimiting-expected-bytes-v1":
        raise ContractError("expected_vector_schema_differs")
    literals = data.get("literal_packets")
    if not isinstance(literals, list) or len(literals) != 7:
        raise ContractError("grammar_literal_count_differs")
    ids = tuple(case.get("id") for case in literals)
    if ids != (
        "position-p1",
        "position-p2",
        "position-p3",
        "position-p4",
        "raw-p16-direct-mask",
        "raw-p128-two-record-max",
        "twelve-singleton-max",
    ):
        raise ContractError("grammar_literal_ids_differ")
    for case in literals:
        body, packet = packet_bytes(case)
        if body.hex() != case.get("body_hex"):
            raise ContractError(f"literal_body_differs:{case.get('id')}")
        if packet.hex() != case.get("packet_hex"):
            raise ContractError(f"literal_packet_differs:{case.get('id')}")
        if f"{packet[3]:02x}" != case.get("crc_hex"):
            raise ContractError(f"literal_crc_differs:{case.get('id')}")
        if len(body) != case.get("body_length") or len(packet) != case.get("wire_bytes"):
            raise ContractError(f"literal_length_differs:{case.get('id')}")
        if len(packet) % 4 or not 8 <= len(packet) <= 40:
            raise ContractError(f"literal_wire_bound_differs:{case.get('id')}")
    if data["population_sweeps"]["position"]["populations"] != list(range(1, 16)):
        raise ContractError("position_population_sweep_differs")
    raw = data["population_sweeps"]["raw"]
    if (raw["population_first"], raw["population_last"]) != (16, 128):
        raise ContractError("raw_population_sweep_differs")
    residues = data.get("padding_residues")
    if not isinstance(residues, list) or {
        item.get("body_mod_4") for item in residues
    } != {0, 1, 2, 3}:
        raise ContractError("padding_residues_differ")
    if data["grammar"] != {
        "version": 2,
        "synchronous_mode": 1,
        "epoch_bits": 2,
        "sequence_bits": 8,
        "body_length_min": 3,
        "body_length_max": 36,
        "packet_bytes_max": 40,
        "lane_beats_max": 10,
        "record_count_max": 12,
        "position_population_min": 1,
        "position_population_max": 15,
        "raw_population_min": 16,
        "raw_population_max": 128,
        "raw_record_bytes": 18,
        "crc": "CRC-8 poly=0x07 init=0 refin=false refout=false xorout=0 over header[0:3]+body",
        "lane_order": [0, 1, 2, 3],
        "lane_bit_order": "most-significant-bit-first",
        "mask_order": "right-half bytes then left-half bytes; each half least-significant byte first",
    }:
        raise ContractError("grammar_mapping_differs")

    freeze = (
        ARTIFACT_BASE
        / "framing-research-v4-low-cost/framing-selection-freeze-v4.md"
    ).read_text(encoding="utf-8")
    for anchor in (
        "Header byte 0: version two",
        "Header byte 3: CRC-8 with polynomial `0x07`",
        "Raw masks are right-half then left-half",
        "sequence advances only after observed",
    ):
        if freeze.count(anchor) != 1:
            raise ContractError(f"framing_freeze_anchor_differs:{anchor}")


def strip_sv_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", " ", text)


def verify_interface_and_coverage() -> None:
    fixture_path = TEST_DIR / "fixture_opendvs_self_delimiting_packet_path.sv"
    bench_path = TEST_DIR / "tb_opendvs_self_delimiting_packet_path.sv"
    fixture = strip_sv_comments(fixture_path.read_text(encoding="utf-8"))
    match = re.search(
        r"\bmodule\s+opendvs_self_delimiting_packet_path\s*\((.*?)\)\s*;",
        fixture,
        flags=re.DOTALL,
    )
    if match is None:
        raise ContractError("fixture_module_header_missing")
    ports = tuple(
        item.group(1)
        for item in re.finditer(
            r"\b(?:input|output)\s+logic(?:\s*\[[^\]]+\])?\s+([A-Za-z_$][\w$]*)",
            match.group(1),
        )
    )
    if ports != INTERFACE_PORTS:
        raise ContractError(f"exact_interface_ports_differ:{ports!r}")
    if len(re.findall(r"\bmodule\s+opendvs_self_delimiting_packet_path\b", fixture)) != 1:
        raise ContractError("fixture_module_count_differs")

    bench = bench_path.read_text(encoding="utf-8")
    required_once = (
        "opendvs_self_delimiting_packet_path exact_31_port_guard",
        "for (population = 1; population <= 128; population = population + 1)",
        "for (prefix = 0; prefix < 319; prefix = prefix + 1)",
        "literal_case_count != 6",
        "if (population_case_count != 1024)\n",
        "if (abort_prefix_count != 319)\n",
        "320'h26fe24930000ffffffffffffffffffffffffffffffff407fffffffffffffffffffffffffffffffff",
        "look-ahead consume advanced or retired the packet",
        "abort/completion priority retired final pending beat",
        "malformed sparse fragment did not fail closed",
        "fully drained path was not quiescent",
        "@@OPENDVS_SELF_DELIMITING_PACKET_PATH_PASS@@ rtl_literals=6 grammar_literals=7 populations=128 padding_residues=4 abort_prefixes=319 banks=1 max_bytes=40 plants=12",
    )
    for anchor in required_once:
        if bench.count(anchor) != 1:
            raise ContractError(f"testbench_coverage_anchor_differs:{anchor}")
    plants = (
        "crc_corrupt",
        "lane_swap",
        "raw_half_swap",
        "pair_order_swap",
        "early_fragment_ack",
        "bank_overwrite",
        "retire_on_consume",
        "abort_drops_packet",
        "abort_loses_pending",
        "sequence_no_wrap",
        "malformed_ack",
        "drain_early_quiescent",
    )
    for plant in plants:
        if bench.count(f'plant_name == "{plant}"') != 1:
            raise ContractError(f"plant_mapping_differs:{plant}")
        if bench.count(f'plant == "{plant}"') != 1:
            raise ContractError(f"plant_witness_differs:{plant}")


def run_preflight() -> int:
    verify_package()
    verify_seals()
    verify_vectors()
    verify_interface_and_coverage()
    compile(
        (TEST_DIR / "check_self_delimiting_packet_path.py").read_text(encoding="utf-8"),
        str(TEST_DIR / "check_self_delimiting_packet_path.py"),
        "exec",
    )
    print(
        f"{PASS_MARKER} reference_sources=15 test_sources=8 ports=31 "
        "grammar_literals=7 rtl_literals=6 plants=12"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preflight", action="store_true")
    args = parser.parse_args()
    if not args.preflight:
        parser.error("--preflight is required")
    try:
        return run_preflight()
    except (ContractError, OSError, ValueError, json.JSONDecodeError) as error:
        print(f"{FAIL_MARKER} check=contract_preflight message={error}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
