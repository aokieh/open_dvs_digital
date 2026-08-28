# Version-three synchronous product pre-framing acceptance correction

This package closes the six acceptance-envelope findings from the single Gate 2
review without changing production RTL, live manifests, wrappers, qualified core
sources, historical tests, or the version-one/version-two packages. It adds no
packet grammar, output-availability, frame-retirement, synthesis, timing, or
physical-fit claim.

The version-three runner validates the correction contract, the exact v1 archive
seal, the complete v2 test seal, and the reviewed v2 current-product seal before
it imports any v1/v2 source. The v3 current-product seal is a new path containing
an exact byte-for-byte copy of the reviewed 25-row v2 current-product seal. The
separate evidence seal pins 37 contracts, runners, checkers, testbenches, and
oracles, including the qualified core runner and product-filelist checker.

No sealed v1 execution transcript exists. The v2 GREEN result remains the
historical mechanically green execution. Version three is a verification
correction over the unchanged product and does not replace those historical
records.

## Commands

Run from the repository root:

```sh
bash -n fver/hardware_codec/integration/sync_product_preframing_v3/run_sync_product_preframing_v3.sh
python3 -I -c 'from pathlib import Path; paths=[Path("fver/hardware_codec/integration/sync_product_preframing_v3/check_sync_product_preframing_v3.py"),Path("fver/hardware_codec/integration/sync_product_preframing_v3/derive_sync_product_preframing_v3.py")]; [compile(p.read_text(),str(p),"exec") for p in paths]'
bash fver/hardware_codec/integration/sync_product_preframing_v3/run_sync_product_preframing_v3.sh --preflight
bash fver/hardware_codec/integration/sync_product_preframing_v3/run_sync_product_preframing_v3.sh --self-test
bash fver/hardware_codec/integration/sync_product_preframing_v3/run_sync_product_preframing_v3.sh --expect-green
```

Preflight performs real Xcelium fixture elaboration and makes no behavior claim.
Self-test executes all ten integration sensitivity plants, including forced
early product-core reset release and forced coupling of tier-valid observations;
all nine structural controls; and the contract, RTL, evidence, marker, core-log,
seal, strengthened-plant, and ownership-multiplicity adversarial controls.

GREEN runs the same ten plants against the real integration, all three maintained
manifest elaborations, the 11-check/four-equation reset test, archived ownership,
safety, and abort behavior, the qualified core runner, a second actual-log
evidence pass that proves each of the nine core plants, the pinned product-list
policy checker, all nine structural controls inside GREEN, and the full
mechanical/no-production/no-history closure. Every planted process must exit
nonzero at exactly its named assertion and must not emit an acceptance marker.

The exact final marker is:

```text
@@SYNC_PRODUCT_PREFRAMING_V3_GREEN_PASS@@ manifests=3 core_instances=1 enc128_leaves=2 reset_synchronizers=1 source_tiers=2 completion_ports=1 ownership_shell_instances=1 forbidden_sources=0 semantic_plants=10 core_plants=9 structural_controls=9
```
