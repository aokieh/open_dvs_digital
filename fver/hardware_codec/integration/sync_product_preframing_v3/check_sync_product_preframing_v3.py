#!/usr/bin/env python3
"""Fail-closed oracle for the v3 pre-framing acceptance correction."""

from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parents[4]
TEST_REL = "fver/hardware_codec/integration/sync_product_preframing_v3"
TEST_DIR = ROOT / TEST_REL
V1_REL = "fver/hardware_codec/integration/sync_product_preframing"
V2_REL = "fver/hardware_codec/integration/sync_product_preframing_v2"

CONTRACT_DIR = Path(
    "/home/rpgraca/opencode-sessions/dvs-encoder/.ocs/artifacts/files/"
    "aed-codec-campaign-v0/work/hardware-codec-v1/"
    "digital-repository-integration"
)
CONTRACT_V1 = CONTRACT_DIR / "sync-product-preframing-integration-unit-v1.md"
CONTRACT_V2 = CONTRACT_DIR / "sync-product-preframing-integration-unit-v2.md"
CONTRACT_V3 = CONTRACT_DIR / "sync-product-preframing-acceptance-correction-v3.md"

EXPECTED_CONTRACT_V1_SHA256 = (
    "dd6a6d63198f39468f6c5357beda4fc9c51f3162f9a5b2901f68058c80fcf41e"
)
EXPECTED_CONTRACT_V2_SHA256 = (
    "155829ba6baec17671ebb6deab2763e894c122469eae7cfe388132babde9e48f"
)
EXPECTED_CONTRACT_V3_SHA256 = (
    "5fbbd340cc1661b7be2e48a63656593b467dbdc84333da388656879731c30d3c"
)
EXPECTED_V1_SOURCE_SEAL_SHA256 = (
    "48952e752c8fc7fe03f0356480b63c26e6920296983050049c1a6c5f14649b50"
)
EXPECTED_V1_ARCHIVE_SEAL_SHA256 = (
    "a531a494a5544c3f6b1deb96fadde4c2d66a2e09fdf83c140341a97330e58260"
)
EXPECTED_V2_TEST_SEAL_SHA256 = (
    "03a7018b04cc852307d2af048bd611dd1010423b218c1a3b21c8ce787fa42782"
)
EXPECTED_V2_PRODUCT_SEAL_SHA256 = (
    "4a31fe3b4d89a3e86e377496d8fececa8cccdf8a3462d2b9f433491b6ad4bdee"
)
EXPECTED_V3_EVIDENCE_SEAL_SHA256 = (
    "34eacce81f810b587cb90285f9840f41bdf7ccbe1955256f2bfbc2bd65c7c133"
)
EXPECTED_DERIVED_TESTBENCH_SHA256 = (
    "d19854f4e38eada4b7edf2ec137f56159ce97610ec05f22ce720a8169e4f633c"
)

V1_SOURCE_SEAL = ROOT / V1_REL / "test-source.sha256"
V1_ARCHIVE_SEAL = ROOT / V2_REL / "v1-archive-seal.sha256"
V2_TEST_SEAL = ROOT / V2_REL / "test-source-v2.sha256"
V2_PRODUCT_SEAL = ROOT / V2_REL / "current-product-source-v2.sha256"
V2_CHECKER = ROOT / V2_REL / "check_sync_product_preframing_v2.py"
V3_TEST_SEAL = TEST_DIR / "test-source-v3.sha256"
V3_EVIDENCE_SEAL = TEST_DIR / "evidence-source-v3.sha256"
V3_PRODUCT_SEAL = TEST_DIR / "current-product-source-v3.sha256"

PACKAGE_FILES = (
    "README.md",
    "check_sync_product_preframing_v3.py",
    "current-product-source-v3.sha256",
    "derive_sync_product_preframing_v3.py",
    "evidence-source-v3.sha256",
    "fixture_sources_v3.f",
    "fixture_sync_product_preframing_v3.sv",
    "gate2-findings-v3.md",
    "product_sources_v3.f",
    "run_sync_product_preframing_v3.sh",
    "test-source-v3.sha256",
)
TEST_SEAL_FILES = (
    f"{TEST_REL}/README.md",
    f"{TEST_REL}/check_sync_product_preframing_v3.py",
    f"{TEST_REL}/derive_sync_product_preframing_v3.py",
    f"{TEST_REL}/fixture_sources_v3.f",
    f"{TEST_REL}/fixture_sync_product_preframing_v3.sv",
    f"{TEST_REL}/gate2-findings-v3.md",
    f"{TEST_REL}/product_sources_v3.f",
    f"{TEST_REL}/run_sync_product_preframing_v3.sh",
)

FOUR_RTL_HASHES = {
    "source/design/final_macros/col_readout_macro.sv":
        "91ac68b255fb52cedd4e4b3810501655e5fb4cb766974c01ad13901d2f3e58b7",
    "source/design/final_macros/fifo_rows_cols_macro2.sv":
        "c5ebe122e1cc3815a5e85d9afe77b9567240cad6591da975ecd7daf7c23d1a39",
    "source/design/final_macros/final_top3.sv":
        "29837863aaf58552d1db6d6f4189d3bab0d3301a994956155ca1d3b10bbfcced",
    "source/design/regfile/spi_peripheral_re.sv":
        "949ba4bb93c801573c29fdacdff294daa4d4be923a456d6fc5d159efb4685286",
}
FINAL_TOP = ROOT / "source/design/final_macros/final_top3.sv"

FIXTURE_ENTRIES = (
    "source/design/common/rst_sync.sv",
    "source/design/hardware_codec/sync/enc128_v2_vendored.sv",
    "source/design/hardware_codec/sync/opendvs_sync_product_encoder_core.sv",
    "source/design/hardware_codec/control/opendvs_sync_mode_ownership_shell.sv",
    f"{TEST_REL}/fixture_sync_product_preframing_v3.sv",
)
PRODUCT_ENTRIES = (
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

CORE_PASS_MARKER = (
    "@@OPENDVS_SYNC_PRODUCT_CORE_PASS@@ mapping_cases=3096 tiers=2 "
    "sparse_boundary=15 raw_boundary=16 queue_depth_test=4"
)
CORE_FAIL_MARKER = "@@OPENDVS_SYNC_PRODUCT_CORE_FAIL@@"
CORE_PLANT_MARKER = "@@OPENDVS_SYNC_PRODUCT_CORE_PLANT_DETECTED@@"
CORE_PLANTS = (
    "half_order_swap",
    "ascending_sparse_positions",
    "launch_population_16",
    "nonzero_delta_time",
    "raw_byte_reversal",
    "retained_fragment_overwrite",
    "duplicate_retirement",
    "lost_retirement",
    "overflow_without_sticky_fault",
)
CORE_SOURCE_HASHES = (
    (
        "leaf",
        "source/design/hardware_codec/sync/enc128_v2_vendored.sv",
        "0c77fa83ec15af0c06df96b04dcfc67dd02cad23ffd075cf1f59f879a6cad54d",
    ),
    (
        "core",
        "source/design/hardware_codec/sync/opendvs_sync_product_encoder_core.sv",
        "cc8aa66e33dbd5d9a88b14305efb5f275829b6a54d266c1cf507c2769a8c04cb",
    ),
    (
        "testbench",
        "fver/hardware_codec/unit/sync_product_core/tb_opendvs_sync_product_encoder_core.sv",
        "a03887d936fe53c905b5b7ae1b418bab31efc24896bb333e4809178d7f15a923",
    ),
    ("compatibility_testbench", "scratch", "eaefb783b2408058c193ef3434a5877487e22600fd4c3e92da38170b79f9e38b"),
)


class ContractError(RuntimeError):
    """A v3 acceptance prerequisite was violated."""


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fail(message: str) -> None:
    print(f"@@SYNC_PRODUCT_PREFRAMING_V3_CHECKER_FAIL@@ message={message}")
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
    if not rows:
        raise ContractError(f"empty_seal:{path}")
    return tuple(rows)


def seal_path(relative_or_absolute: str) -> Path:
    path = Path(relative_or_absolute)
    return path if path.is_absolute() else ROOT / path


def verify_seal(path: Path) -> tuple[tuple[str, str], ...]:
    rows = parse_seal(path)
    for relative, expected in rows:
        require_hash(seal_path(relative), expected, f"sealed_{Path(relative).name}")
    return rows


def active_entries(path: Path) -> tuple[str, ...]:
    require_regular(path, "filelist")
    entries: list[str] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line and not line.startswith(("#", "//")):
            entries.append(line.split()[0])
    return tuple(entries)


def strip_sv_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", "", text)


def ownership_shell_instances(text: str) -> int:
    clean = strip_sv_comments(text)
    pattern = re.compile(
        r"\bopendvs_sync_mode_ownership_shell\b\s*"
        r"(?:#\s*\(.*?\)\s*)?\bi_sync_mode_ownership\b\s*\(",
        flags=re.DOTALL,
    )
    return len(pattern.findall(clean))


def run_v2_checker(mode: str, expected_marker: str) -> None:
    result = subprocess.run(
        ["/usr/bin/python3", "-I", str(V2_CHECKER), mode],
        cwd=ROOT,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env={"HOME": "/tmp", "PATH": "/usr/bin:/bin", "LC_ALL": "C", "PYTHONDONTWRITEBYTECODE": "1"},
    )
    if result.returncode != 0:
        raise ContractError(f"v2_checker_{mode}_failed:{result.stdout.strip()}")
    if result.stdout.splitlines().count(expected_marker) != 1:
        raise ContractError(f"v2_checker_{mode}_marker_differs:{result.stdout.strip()}")


def verify_package() -> None:
    if TEST_DIR != ROOT / TEST_REL:
        raise ContractError("v3_package_is_not_at_fixed_path")
    observed = tuple(sorted(path.name for path in TEST_DIR.iterdir()))
    if observed != tuple(sorted(PACKAGE_FILES)):
        raise ContractError(f"v3_package_inventory_differs:{observed!r}")
    for name in PACKAGE_FILES:
        require_regular(TEST_DIR / name, f"v3_package_{name}")
    if active_entries(TEST_DIR / "fixture_sources_v3.f") != FIXTURE_ENTRIES:
        raise ContractError("v3_fixture_filelist_entries_differ")
    if active_entries(TEST_DIR / "product_sources_v3.f") != PRODUCT_ENTRIES:
        raise ContractError("v3_product_filelist_entries_differ")
    for path in TEST_DIR.rglob("*"):
        if path.is_dir() or path.name.endswith((".pyc", ".pyo")) or path.name == "__pycache__":
            raise ContractError(f"v3_generated_cache_or_directory_present:{path}")


def verify_test_seal() -> None:
    rows = parse_seal(V3_TEST_SEAL)
    if tuple(relative for relative, _ in rows) != TEST_SEAL_FILES:
        raise ContractError("v3_test_source_seal_inventory_differs")
    for relative, expected in rows:
        require_hash(ROOT / relative, expected, f"v3_test_source_{Path(relative).name}")


def verify_whitespace() -> None:
    for name in PACKAGE_FILES:
        path = TEST_DIR / name
        data = path.read_bytes()
        if not data.endswith(b"\n"):
            raise ContractError(f"v3_file_lacks_final_newline:{name}")
        text = data.decode("utf-8")
        for line_number, line in enumerate(text.splitlines(), start=1):
            if line.endswith((" ", "\t")):
                raise ContractError(f"v3_trailing_whitespace:{name}:{line_number}")


def verify_contracts_and_seals() -> None:
    for path, expected, label in (
        (CONTRACT_V1, EXPECTED_CONTRACT_V1_SHA256, "v1_contract"),
        (CONTRACT_V2, EXPECTED_CONTRACT_V2_SHA256, "v2_contract"),
        (CONTRACT_V3, EXPECTED_CONTRACT_V3_SHA256, "v3_contract"),
        (V1_SOURCE_SEAL, EXPECTED_V1_SOURCE_SEAL_SHA256, "v1_source_seal"),
        (V1_ARCHIVE_SEAL, EXPECTED_V1_ARCHIVE_SEAL_SHA256, "v1_archive_seal"),
        (V2_TEST_SEAL, EXPECTED_V2_TEST_SEAL_SHA256, "v2_test_seal"),
        (V2_PRODUCT_SEAL, EXPECTED_V2_PRODUCT_SEAL_SHA256, "v2_product_seal"),
        (V3_EVIDENCE_SEAL, EXPECTED_V3_EVIDENCE_SEAL_SHA256, "v3_evidence_seal"),
        (V3_PRODUCT_SEAL, EXPECTED_V2_PRODUCT_SEAL_SHA256, "v3_product_seal"),
    ):
        require_hash(path, expected, label)

    verify_seal(V1_SOURCE_SEAL)
    verify_seal(V1_ARCHIVE_SEAL)
    verify_seal(V2_TEST_SEAL)
    v2_product_rows = verify_seal(V2_PRODUCT_SEAL)
    v3_product_rows = verify_seal(V3_PRODUCT_SEAL)
    if V2_PRODUCT_SEAL.read_bytes() != V3_PRODUCT_SEAL.read_bytes():
        raise ContractError("v3_product_seal_is_not_exact_v2_current_product_seal")
    if v2_product_rows != v3_product_rows or len(v3_product_rows) != 25:
        raise ContractError("v3_product_seal_rows_differ")
    evidence_rows = verify_seal(V3_EVIDENCE_SEAL)
    if len(evidence_rows) != 37:
        raise ContractError(f"v3_evidence_program_count_differs:{len(evidence_rows)}")
    verify_test_seal()

    for relative, expected in FOUR_RTL_HASHES.items():
        require_hash(ROOT / relative, expected, f"frozen_rtl_{Path(relative).name}")

    run_v2_checker(
        "verify-v1-archive",
        "@@SYNC_PRODUCT_PREFRAMING_V2_V1_ARCHIVE_PASS@@ spec=1 harness_seal=1",
    )
    run_v2_checker(
        "verify-test-seal",
        "@@SYNC_PRODUCT_PREFRAMING_V2_TEST_SEAL_PASS@@ files=10",
    )
    run_v2_checker(
        "verify-current-product-seal",
        "@@SYNC_PRODUCT_PREFRAMING_V2_CURRENT_SOURCE_SEAL_PASS@@ files=25",
    )


def common_guards() -> None:
    verify_package()
    verify_contracts_and_seals()
    verify_whitespace()


def verify_derived_testbench(path: Path) -> None:
    require_hash(path, EXPECTED_DERIVED_TESTBENCH_SHA256, "v3_derived_testbench")
    text = path.read_text(encoding="utf-8")
    required = (
        "module tb_sync_product_preframing_v3;",
        "force dut.sync_product_rst_n = 1'b1;",
        "force dut.bottom_record_valid = dut.top_record_valid;",
    )
    if any(text.count(item) != 1 for item in required):
        raise ContractError("v3_derived_testbench_strengthened_anchors_differ")
    weak = (
        '''if (plant_is("early_reset_release"))\n                fail("synchronized-reset-first-release-edge")''',
        '''if (plant_is("couple_tier_valid"))\n                fail("top-pulse-independent-bottom-valid")''',
    )
    if any(item in text for item in weak):
        raise ContractError("v3_derived_testbench_retains_weak_direct_fail")


def core_source_rows() -> str:
    return "".join(f"{label}\t{expected}\n" for label, _, expected in CORE_SOURCE_HASHES)


def validate_core_evidence(directory: Path, *, emit: bool) -> None:
    if not directory.is_dir() or directory.is_symlink():
        raise ContractError(f"core_evidence_directory_invalid:{directory}")
    before = directory / "source-hashes.before.tsv"
    after = directory / "source-hashes.after.tsv"
    require_regular(before, "core_source_hashes_before")
    require_regular(after, "core_source_hashes_after")
    expected_rows = core_source_rows()
    if before.read_text(encoding="utf-8") != expected_rows:
        raise ContractError("core_source_hashes_before_differ")
    if after.read_bytes() != before.read_bytes():
        raise ContractError("core_source_hashes_changed_during_evidence")

    unplanted_log = directory / "run-unplanted.log"
    unplanted_exit = directory / "run-unplanted.exit.txt"
    require_regular(unplanted_log, "core_unplanted_log")
    require_regular(unplanted_exit, "core_unplanted_exit")
    if unplanted_exit.read_text(encoding="utf-8").strip() != "0":
        raise ContractError("core_unplanted_exit_is_not_zero")
    unplanted_text = unplanted_log.read_text(encoding="utf-8", errors="replace")
    if unplanted_text.splitlines().count(CORE_PASS_MARKER) != 1:
        raise ContractError("core_unplanted_3096_case_marker_count")
    if CORE_FAIL_MARKER in unplanted_text or CORE_PLANT_MARKER in unplanted_text:
        raise ContractError("core_unplanted_log_contains_failure_or_plant")

    observed_logs = tuple(sorted(path.name for path in directory.glob("run-plant-*.log")))
    expected_logs = tuple(sorted(f"run-plant-{plant}.log" for plant in CORE_PLANTS))
    if observed_logs != expected_logs:
        raise ContractError(f"core_plant_log_inventory_differs:{observed_logs!r}")

    for plant in CORE_PLANTS:
        log = directory / f"run-plant-{plant}.log"
        exit_path = directory / f"run-plant-{plant}.exit.txt"
        require_regular(exit_path, f"core_plant_{plant}_exit")
        try:
            returncode = int(exit_path.read_text(encoding="utf-8").strip())
        except ValueError as error:
            raise ContractError(f"core_plant_{plant}_exit_is_not_integer") from error
        if returncode in (0, 124, 137):
            raise ContractError(f"core_plant_{plant}_exit_is_not_ordinary_nonzero:{returncode}")
        text = log.read_text(encoding="utf-8", errors="replace")
        expected = f"{CORE_PLANT_MARKER} plant={plant} check={plant}"
        if text.splitlines().count(expected) != 1:
            raise ContractError(f"core_plant_{plant}_exact_record_count")
        if CORE_PASS_MARKER in text or CORE_FAIL_MARKER in text:
            raise ContractError(f"core_plant_{plant}_contains_acceptance_or_generic_failure")
        if sum(CORE_PLANT_MARKER in line for line in text.splitlines()) != 1:
            raise ContractError(f"core_plant_{plant}_has_extra_plant_record")
        if emit:
            print(
                "@@SYNC_PRODUCT_PREFRAMING_V3_CORE_PLANT_EVIDENCE@@ "
                f"plant={plant} check={plant} exit={returncode} log_sha256={sha256(log)}"
            )
    if emit:
        print(
            "@@SYNC_PRODUCT_PREFRAMING_V3_CORE_EVIDENCE_PASS@@ "
            f"mapping_cases=3096 core_plants={len(CORE_PLANTS)} actual_logs=10"
        )


def assert_rejected(action: Callable[[], None], label: str) -> None:
    try:
        action()
    except (ContractError, OSError, ValueError):
        return
    raise ContractError(f"adversarial_control_escaped:{label}")


def write_synthetic_core_evidence(directory: Path) -> None:
    (directory / "source-hashes.before.tsv").write_text(
        core_source_rows(), encoding="utf-8", newline="\n"
    )
    (directory / "source-hashes.after.tsv").write_text(
        core_source_rows(), encoding="utf-8", newline="\n"
    )
    (directory / "run-unplanted.log").write_text(
        CORE_PASS_MARKER + "\n", encoding="utf-8", newline="\n"
    )
    (directory / "run-unplanted.exit.txt").write_text(
        "0\n", encoding="utf-8", newline="\n"
    )
    for plant in CORE_PLANTS:
        (directory / f"run-plant-{plant}.log").write_text(
            f"{CORE_PLANT_MARKER} plant={plant} check={plant}\n",
            encoding="utf-8",
            newline="\n",
        )
        (directory / f"run-plant-{plant}.exit.txt").write_text(
            "1\n", encoding="utf-8", newline="\n"
        )


def run_adversarial_self_test() -> int:
    with tempfile.TemporaryDirectory(prefix="sync-product-preframing-v3-check-") as name:
        temporary = Path(name)

        mutated_contract = temporary / "contract.md"
        mutated_contract.write_bytes(CONTRACT_V3.read_bytes() + b"mutation\n")
        assert_rejected(
            lambda: require_hash(mutated_contract, EXPECTED_CONTRACT_V3_SHA256, "mutated_contract"),
            "contract_mutation",
        )

        for index, (relative, expected) in enumerate(FOUR_RTL_HASHES.items()):
            mutation = temporary / f"rtl-{index}.sv"
            mutation.write_bytes((ROOT / relative).read_bytes() + b"\n// mutation\n")
            assert_rejected(
                lambda path=mutation, digest=expected, item=index: require_hash(
                    path, digest, f"mutated_rtl_{item}"
                ),
                f"rtl_mutation_{index}",
            )

        evidence_relative, evidence_expected = parse_seal(V3_EVIDENCE_SEAL)[18]
        evidence_mutation = temporary / "evidence-program.py"
        evidence_mutation.write_bytes(seal_path(evidence_relative).read_bytes() + b"\n# mutation\n")
        assert_rejected(
            lambda: require_hash(evidence_mutation, evidence_expected, "mutated_evidence_program"),
            "evidence_program_mutation",
        )

        stale_target = temporary / "stale-target"
        stale_target.write_text("current\n", encoding="utf-8", newline="\n")
        stale_seal = temporary / "stale.sha256"
        stale_seal.write_text(
            f"{'0' * 64}  {stale_target}\n", encoding="utf-8", newline="\n"
        )
        assert_rejected(lambda: verify_seal(stale_seal), "stale_seal")

        forged = temporary / "forged"
        forged.mkdir()
        (forged / "run-unplanted.log").write_text(
            CORE_PASS_MARKER + "\n", encoding="utf-8", newline="\n"
        )
        assert_rejected(
            lambda: validate_core_evidence(forged, emit=False), "marker_forgery"
        )

        missing = temporary / "missing-core-plant"
        missing.mkdir()
        write_synthetic_core_evidence(missing)
        validate_core_evidence(missing, emit=False)
        (missing / f"run-plant-{CORE_PLANTS[-1]}.log").unlink()
        assert_rejected(
            lambda: validate_core_evidence(missing, emit=False),
            "missing_core_plant_evidence",
        )

        derived = temporary / "derived.sv"
        subprocess.run(
            [
                "/usr/bin/python3",
                "-I",
                str(TEST_DIR / "derive_sync_product_preframing_v3.py"),
                str(derived),
            ],
            cwd=ROOT,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env={"HOME": "/tmp", "PATH": "/usr/bin:/bin", "LC_ALL": "C", "PYTHONDONTWRITEBYTECODE": "1"},
        )
        verify_derived_testbench(derived)

        one = "opendvs_sync_mode_ownership_shell i_sync_mode_ownership();\n"
        if ownership_shell_instances(one) != 1:
            raise ContractError("ownership_shell_one_fixture_rejected")
        if ownership_shell_instances("") == 1 or ownership_shell_instances(one + one) == 1:
            raise ContractError("ownership_shell_multiplicity_control_escaped")

    print(
        "@@SYNC_PRODUCT_PREFRAMING_V3_ADVERSARIAL_SELF_TEST_PASS@@ "
        "contract_mutation=1 rtl_mutations=4 evidence_program_mutation=1 "
        "marker_forgery=1 missing_core_plant_evidence=1 stale_seal=1 "
        "strengthened_plants=2 ownership_shell_multiplicity=1"
    )
    return 0


def run_structural_self_test() -> int:
    run_v2_checker(
        "self-test",
        "@@SYNC_PRODUCT_PREFRAMING_V2_STRUCTURE_SELF_TEST_PASS@@ "
        "inherited_controls=5 closure_controls=3 controls=8 missing_core=1 "
        "forbidden_source=1 mapping_swap=1 full_gate=1 cycle13=1 "
        "wrong_register=1 missing_wrapper_dependency=1 illegal_inout=1",
    )
    current = FINAL_TOP.read_text(encoding="utf-8")
    if ownership_shell_instances(current) != 1:
        raise ContractError("current_ownership_shell_instance_count_is_not_one")
    print(
        "@@SYNC_PRODUCT_PREFRAMING_V3_STRUCTURE_SELF_TEST_PASS@@ "
        "inherited_controls=5 closure_controls=3 ownership_controls=1 "
        "structural_controls=9 ownership_shell_instances=1"
    )
    return 0


def run_expect_green() -> int:
    run_v2_checker(
        "expect-green",
        "@@SYNC_PRODUCT_PREFRAMING_V2_STRUCTURE_GREEN_PASS@@ manifests=3 "
        "core_instances=1 enc128_leaves=2 reset_synchronizers=1 "
        "source_tiers=2 completion_ports=1 forbidden_sources=0",
    )
    count = ownership_shell_instances(FINAL_TOP.read_text(encoding="utf-8"))
    if count != 1:
        raise ContractError(f"ownership_shell_instance_count_is_not_one:{count}")
    print(
        "@@SYNC_PRODUCT_PREFRAMING_V3_STRUCTURE_GREEN_PASS@@ manifests=3 "
        "core_instances=1 enc128_leaves=2 reset_synchronizers=1 "
        "source_tiers=2 completion_ports=1 ownership_shell_instances=1 "
        "forbidden_sources=0"
    )
    return 0


def run_scope_audit() -> int:
    result = subprocess.run(
        ["/usr/bin/git", "-C", str(ROOT), "diff", "--cached", "--name-only", "-z"],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.stdout:
        raise ContractError("staged_paths_are_not_absent")
    subprocess.run(
        ["/usr/bin/git", "-C", str(ROOT), "diff", "--check"],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    print(
        "@@SYNC_PRODUCT_PREFRAMING_V3_SCOPE_PASS@@ package_files=11 "
        "production_changed=0 v1_changed=0 v2_changed=0 protected_history_changed=0 "
        "staged_paths=0 whitespace=1 cache=0"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "mode",
        choices=(
            "preflight",
            "self-test",
            "structural-self-test",
            "expect-green",
            "scope-audit",
            "verify-core-evidence",
            "verify-derived-testbench",
        ),
    )
    parser.add_argument("path", nargs="?")
    args = parser.parse_args()
    try:
        # This guard is deliberately common to every v3 checker mode.
        common_guards()
        if args.mode == "preflight":
            if args.path is not None:
                raise ContractError("preflight_does_not_accept_a_path")
            print(
                "@@SYNC_PRODUCT_PREFRAMING_V3_CHECKER_PREFLIGHT_PASS@@ "
                "contracts=3 v1_archive=1 v2_test_seal=1 v2_product_seal=1 "
                "rtl_hashes=4 evidence_programs=37 package_files=11"
            )
            return 0
        if args.mode == "self-test":
            if args.path is not None:
                raise ContractError("self_test_does_not_accept_a_path")
            return run_adversarial_self_test()
        if args.mode == "structural-self-test":
            if args.path is not None:
                raise ContractError("structural_self_test_does_not_accept_a_path")
            return run_structural_self_test()
        if args.mode == "expect-green":
            if args.path is not None:
                raise ContractError("expect_green_does_not_accept_a_path")
            return run_expect_green()
        if args.mode == "scope-audit":
            if args.path is not None:
                raise ContractError("scope_audit_does_not_accept_a_path")
            return run_scope_audit()
        if args.path is None:
            raise ContractError(f"{args.mode}_requires_a_path")
        path = Path(args.path)
        if args.mode == "verify-derived-testbench":
            verify_derived_testbench(path)
            print(
                "@@SYNC_PRODUCT_PREFRAMING_V3_DERIVED_TESTBENCH_PASS@@ "
                f"sha256={EXPECTED_DERIVED_TESTBENCH_SHA256} strengthened_plants=2"
            )
            return 0
        validate_core_evidence(path, emit=True)
        return 0
    except (ContractError, OSError, subprocess.SubprocessError) as error:
        fail(str(error))
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
