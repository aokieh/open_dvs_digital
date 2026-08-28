#!/usr/bin/env python3
"""Check the maintained synchronous-only product source manifests."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
SHELL_RELATIVE = "source/design/hardware_codec/control/opendvs_sync_mode_ownership_shell.sv"
XRUN_ENTRY = "../../../source/design/hardware_codec/control/opendvs_sync_mode_ownership_shell.sv"
PRODUCT_LIST = ROOT / "fver/hardware_codec/filelists/sync_mode_ownership_product.f"
XRUN_LISTS = [
    ROOT / "fver/final_macros/scripts/xrun.f",
    ROOT / "fver/user_project_wrapper/scripts/xrun.f",
]
USER_WRAPPER_LIST = XRUN_LISTS[1]
FINAL_TOP_RELATIVE = "source/design/final_macros/final_top3.sv"
FINAL_TOP_XRUN_ENTRY = "../../../source/design/final_macros/final_top3.sv"


def fail(message: str) -> None:
    raise SystemExit(f"PRODUCT FILE-LIST CHECK FAILED: {message}")


def uncommented_entries(path: Path) -> list[str]:
    entries: list[str] = []
    for line in path.read_text().splitlines():
        entry = line.strip()
        if not entry or entry.startswith(("#", "//")):
            continue
        entries.append(entry.split()[0])
    return entries


def forbidden_codec_entries(entries: list[str]) -> list[str]:
    return [
        entry
        for entry in entries
        if "qdi" in entry.lower() or "async" in entry.lower()
    ]


def product_to_xrun_entry(entry: str) -> str:
    return f"../../../{entry}"


def main() -> int:
    shell = ROOT / SHELL_RELATIVE
    if not shell.is_file():
        fail(f"missing product shell {SHELL_RELATIVE}")

    if not PRODUCT_LIST.is_file():
        fail(f"missing explicit product list {PRODUCT_LIST.relative_to(ROOT)}")
    product_entries = uncommented_entries(PRODUCT_LIST)
    if product_entries.count(SHELL_RELATIVE) != 1:
        fail("the explicit product list must contain the shell exactly once")
    forbidden = forbidden_codec_entries(product_entries)
    if forbidden:
        fail(f"the synchronous-only product list contains forbidden sources: {forbidden}")
    if product_entries.index(SHELL_RELATIVE) > product_entries.index(
        FINAL_TOP_RELATIVE
    ):
        fail("the shell must be compiled before final_top3.sv")

    for path in XRUN_LISTS:
        entries = uncommented_entries(path)
        if entries.count(XRUN_ENTRY) != 1:
            fail(f"{path.relative_to(ROOT)} must contain the shell exactly once")
        if entries.index(XRUN_ENTRY) > entries.index(FINAL_TOP_XRUN_ENTRY):
            fail(f"{path.relative_to(ROOT)} compiles the shell after final_top3.sv")
        forbidden = forbidden_codec_entries(entries)
        if forbidden:
            fail(
                f"{path.relative_to(ROOT)} contains forbidden codec sources: "
                f"{forbidden}"
            )

    wrapper_entries = uncommented_entries(USER_WRAPPER_LIST)
    product_xrun_entries = [product_to_xrun_entry(entry) for entry in product_entries]
    wrapper_positions: list[int] = []
    for entry in product_xrun_entries:
        if wrapper_entries.count(entry) != 1:
            fail(
                "the user-project-wrapper list must contain each explicit product "
                f"entry exactly once: {entry}"
            )
        wrapper_positions.append(wrapper_entries.index(entry))
    if wrapper_positions != sorted(wrapper_positions):
        fail("the user-project-wrapper list changes explicit product entry order")

    top = (ROOT / "source/design/final_macros/final_top3.sv").read_text()
    if "opendvs_sync_mode_ownership_shell" not in top:
        fail("final_top3.sv does not instantiate the ownership shell")

    print(
        "@@SYNC_MODE_OWNERSHIP_FILELIST_PASS@@ explicit_product_list=1 "
        "xrun_lists=2 wrapper_order=1 qdi_sources=0 async_sources=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
