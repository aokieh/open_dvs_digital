#!/usr/bin/env python3
"""Derive the v3 semantic bench from the seal-validated v1 oracle."""

from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
CONTRACT = Path(
    "/home/rpgraca/opencode-sessions/dvs-encoder/.ocs/artifacts/files/"
    "aed-codec-campaign-v0/work/hardware-codec-v1/"
    "digital-repository-integration/"
    "sync-product-preframing-acceptance-correction-v3.md"
)
V1_TESTBENCH = (
    ROOT
    / "fver/hardware_codec/integration/sync_product_preframing/"
    "tb_sync_product_preframing.sv"
)
V1_ARCHIVE_SEAL = (
    ROOT
    / "fver/hardware_codec/integration/sync_product_preframing_v2/"
    "v1-archive-seal.sha256"
)

EXPECTED_CONTRACT_SHA256 = (
    "5fbbd340cc1661b7be2e48a63656593b467dbdc84333da388656879731c30d3c"
)
EXPECTED_V1_TESTBENCH_SHA256 = (
    "1c7b23e2f7f27a39ecc1bcfbfa93031b91c61a55d6230ae70ea6199da524a197"
)
EXPECTED_V1_ARCHIVE_SEAL_SHA256 = (
    "a531a494a5544c3f6b1deb96fadde4c2d66a2e09fdf83c140341a97330e58260"
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require_hash(path: Path, expected: str, label: str) -> None:
    if not path.is_file() or path.is_symlink():
        raise SystemExit(f"{label} is absent, non-regular, or a symbolic link")
    observed = sha256(path)
    if observed != expected:
        raise SystemExit(
            f"{label} SHA-256 mismatch: expected={expected} observed={observed}"
        )


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if text.count(old) != 1:
        raise SystemExit(f"{label} anchor count is {text.count(old)}, expected one")
    return text.replace(old, new)


def derive(source: str) -> str:
    derived = replace_once(
        source,
        "module tb_sync_product_preframing;",
        "module tb_sync_product_preframing_v3;",
        "module-name",
    )
    derived = replace_once(
        derived,
        '''            if (plant_is("early_reset_release"))
                fail("synchronized-reset-first-release-edge");''',
        '''            if (plant_is("early_reset_release"))
                force dut.sync_product_rst_n = 1'b1;''',
        "early-reset-force",
    )
    derived = replace_once(
        derived,
        '''            if (plant_is("couple_tier_valid"))
                fail("top-pulse-independent-bottom-valid");''',
        '''            if (plant_is("couple_tier_valid"))
                force dut.bottom_record_valid = dut.top_record_valid;''',
        "tier-valid-force",
    )

    forbidden = (
        '''if (plant_is("early_reset_release"))
                fail("synchronized-reset-first-release-edge")''',
        '''if (plant_is("couple_tier_valid"))
                fail("top-pulse-independent-bottom-valid")''',
    )
    if any(item in derived for item in forbidden):
        raise SystemExit("a weak inherited direct-fail plant remains")
    if len(re.findall(r"\bmodule\s+tb_sync_product_preframing_v3\s*;", derived)) != 1:
        raise SystemExit("derived v3 testbench top is not unique")
    return derived


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {Path(sys.argv[0]).name} DESTINATION")
    destination = Path(sys.argv[1])
    if destination.exists() or destination.is_symlink():
        raise SystemExit(f"refusing to overwrite destination: {destination}")

    # No v1 source is read until its contract and archive identities are valid.
    require_hash(CONTRACT, EXPECTED_CONTRACT_SHA256, "v3 contract")
    require_hash(V1_ARCHIVE_SEAL, EXPECTED_V1_ARCHIVE_SEAL_SHA256, "v1 archive seal")
    require_hash(V1_TESTBENCH, EXPECTED_V1_TESTBENCH_SHA256, "v1 testbench")
    source = V1_TESTBENCH.read_text(encoding="utf-8")
    destination.write_text(derive(source), encoding="utf-8", newline="\n")
    print(
        "@@SYNC_PRODUCT_PREFRAMING_V3_TESTBENCH_DERIVED@@ "
        f"sha256={sha256(destination)} strengthened_plants=2"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
