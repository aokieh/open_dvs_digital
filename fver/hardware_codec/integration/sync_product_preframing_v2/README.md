# Corrected synchronous product pre-framing acceptance package

This version-two package authenticates the current synchronous product
pre-framing integration without changing the frozen version-one package or any
historical reset, ownership, or abort test. It remains default-off and makes no
packet-grammar, timing, synthesis, physical-fit, or synchronous-output claim.

The fixture and semantic testbench are verified imports of the frozen
version-one sources. Every runner validates `v1-archive-seal.sha256` before an
import can reach Xcelium. The archive seal covers the version-one contract and
the seven sources represented by the version-one source seal. It does not claim
that a historical version-one execution transcript exists or is sealed.

## Frozen checks

Run from the repository root, in this order:

```sh
bash -n fver/hardware_codec/integration/sync_product_preframing_v2/run_sync_product_preframing_v2.sh
bash -n fver/hardware_codec/integration/sync_product_preframing_v2/run_current_product_reset_binding_v2.sh
python3 -I -c 'from pathlib import Path; p=Path("fver/hardware_codec/integration/sync_product_preframing_v2/check_sync_product_preframing_v2.py"); compile(p.read_text(), str(p), "exec")'
python3 -I fver/hardware_codec/integration/sync_product_preframing_v2/check_sync_product_preframing_v2.py verify-v1-archive
bash fver/hardware_codec/integration/sync_product_preframing_v2/run_sync_product_preframing_v2.sh --preflight
bash fver/hardware_codec/integration/sync_product_preframing_v2/run_sync_product_preframing_v2.sh --self-test
bash fver/hardware_codec/integration/sync_product_preframing_v2/run_sync_product_preframing_v2.sh --expect-red
```

Preflight performs a real Xcelium elaboration with
`tb_sync_product_preframing_v2` as the top and makes no behavior claim. The
self-test executes the unplanted fixture and all ten inherited semantic plants.
Its eight structural controls comprise the five inherited controls and one
control for each version-two closure defect.

RED is accepted only when the inherited integration contract, exact paths,
Xcelium identity, fixture, qualified hashes, archive, test seal, protected
history, whitespace, and scope are valid and the live product has exactly these
three defects:

1. the final-macros manifest uses `regfile.sv` rather than `regfile_final.sv`;
2. the wrapper manifest omits `open_dvs_top.sv` between `final_top3.sv` and
   `user_project_wrapper.sv`;
3. `open_dvs_top.sv` declares `pad_bias` and `rx` as variable `inout logic`
   ports rather than net `inout wire` ports.

The RED command performs only the qualified tool probe and fixture elaboration
before the exact structural classification. It does not run current-product
behavior.

## Current-product source seal and GREEN

`current-product-source-v2.sha256` is deliberately unfinalized in the RED
package. It must not be generated over the known-bad product. After a separate
production fixer makes only the three contract-authorized corrections, run:

```sh
python3 -I fver/hardware_codec/integration/sync_product_preframing_v2/check_sync_product_preframing_v2.py generate-current-product-seal
```

The command refuses to write unless the two manifests have their exact corrected
inventories, the wrapper differs from the RED source by exactly the two `logic`
to `wire` declaration changes, all inherited structure passes, the four
qualified dependency hashes match, and protected history remains unchanged. It
then atomically inventories every active source resolved from all three live
manifests plus the manifests themselves. GREEN fails closed if this seal is
unfinalized, absent, malformed, or stale.

The final commands are:

```sh
bash fver/hardware_codec/integration/sync_product_preframing_v2/run_current_product_reset_binding_v2.sh
bash fver/hardware_codec/integration/sync_product_preframing_v2/run_sync_product_preframing_v2.sh --expect-green
```

The reset gate compiles the complete sealed current source set and proves the
four effective-reset equations with eleven behavior checks. It emits:

```text
@@SYNC_PRODUCT_PREFRAMING_V2_RESET_PASS@@ checks=11 reset_equations=4
```

GREEN elaborates the exact product and final-macros manifests at `final_top3`
and the exact wrapper manifest at `user_project_wrapper`. It runs the current
integration behavior and ten plants; compiles the archived ownership,
ownership-safety, and abort testbenches against the complete sealed source set;
runs the qualified 3,096-case core regression and nine core plants; runs the new
current reset gate; and rechecks source seals, archive, scope, staged-path
absence, and whitespace before emitting the contract marker.

Imported scanner, private event-link, asynchronous, and QDI sources are excluded
from every live manifest. `test-source-v2.sha256` freezes the ten immutable v2
test/package inputs, including the archive seal. It excludes itself and the
post-correction current-product seal.
