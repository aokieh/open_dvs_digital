# Synchronous product encoder core behavioral acceptance

This directory contains the versioned RED-first behavioral apparatus for
`opendvs_sync_product_encoder_core`. It tests only the packet-grammar-independent
two-tier fragment core. It does not provide the production module, host framing,
chip integration, or a synthesis runner.

## Frozen authority and identities

- Specification SHA-256: `564c6eece59908d6ed047d0e8268ad344e770ba9bf279212dff22b729ed1bd30`
- Frozen `enc128` leaf SHA-256: `0c77fa83ec15af0c06df96b04dcfc67dd02cad23ffd075cf1f59f879a6cad54d`
- Testbench SHA-256: `a03887d936fe53c905b5b7ae1b418bab31efc24896bb333e4809178d7f15a923`
- Archived v1 runner SHA-256: `c6cb6195143e5ff5a977ef810544f399d3f75307da4467d7e557bfb1f0cc0f1a`
- Active v2 runner SHA-256: `6a2364b5a42447798e51806a74be0736b2edb05cb1305faffa1a49cf797e05e6`
- Active runner identity: `behavioral-runner-v2`, Icarus parser mode
  `-g2005-sv`, with four guarded compiler invocations

The exact v1 runner is archived at
`frozen/run_sync_product_core_v1.sh`. The active runner verifies the archive,
its own v2 identity, the parser-mode invocation count, and all frozen source
identities before compiling. The v2 repair leaves the legal frozen leaf and
testbench unchanged, selects the requested pinned Icarus SystemVerilog-2005
frontend, and adds a fail-closed direct leaf-elaboration preflight. On the live
pinned Icarus 14 build, that direct preflight still reports the same three
enum-cast errors at frozen leaf lines 55, 57, and 62, so fixture, RED, GREEN, and
synthesis qualification remain closed. The production core hash is recorded in
disposable GREEN metadata only when that preflight succeeds.

## Commands

Run from the repository root:

```bash
bash fver/hardware_codec/unit/sync_product_core/run_sync_product_core.sh --leaf-elaboration-preflight
bash fver/hardware_codec/unit/sync_product_core/run_sync_product_core.sh --fixture-preflight
bash fver/hardware_codec/unit/sync_product_core/run_sync_product_core.sh --expect-red
bash fver/hardware_codec/unit/sync_product_core/run_sync_product_core.sh --expect-green
```

`--leaf-elaboration-preflight` instantiates and attempts to elaborate the exact
frozen leaf under `-g2005-sv`. It closes the v1 blind spot in which RED could
compile an uninstantiated leaf without exercising the pinned parser's
elaboration path, and currently fails before any behavioral attempt.

`--fixture-preflight` creates an exact-interface stub only in a unique temporary
directory and compiles, but never runs, the explicit stub/leaf/testbench source
list. It proves testbench syntax, source-list parsing, top selection, and both
the named and positional 29-port bindings. It cannot emit behavioral GREEN.

`--expect-red` first performs the quiet fixture preflight, then compiles the real
frozen closure containing only the leaf and testbench. It passes only when
Icarus reports `opendvs_sync_product_encoder_core` as the sole unresolved module
and prints:

```text
@@OPENDVS_SYNC_PRODUCT_CORE_RED_CONFIRMED@@ missing_module=opendvs_sync_product_encoder_core
```

`--expect-green` fails closed while the production core is absent. Once that
source exists, the runner compiles exactly the frozen leaf, production core, and
frozen testbench. It runs the unplanted design and all semantic plants, enforces
each process exit and exact marker count, forbids GREEN from every planted run,
and emits the contract PASS marker only after the entire batch succeeds.

## Behavioral coverage

The testbench independently serializes expected fragments and separately
decodes observed fragments. The deterministic corpus has exactly 3,096 cases:
two tiers, two legal polarities, rows 0 and 63, populations 0 through 128, and
low/high/alternating masks. It checks the sparse/raw boundary at populations 15
and 16, all raw byte lanes, descending sparse positions, zero delta time,
payload zero-fill, and both tier/row mappings.

Additional witnesses cover simultaneous tier admission, independent and
simultaneous stalls, retained-payload stability, four-entry queue overflow,
admission-priority accounting, all saturating counters, asynchronous reset while
queued/encoding/retained/stalled, conservation, quiescence, and exactly-once
retirement. Counter saturation is reached in bounded simulation by depositing
the penultimate value into each public counter state variable and then applying
two normal interface events; the checks require max followed by max, never wrap.

Compiled semantic plants and their unique checks are:

| Plant | Required failing check |
|---|---|
| `half_order_swap` | `half_order_swap` |
| `ascending_sparse_positions` | `ascending_sparse_positions` |
| `launch_population_16` | `launch_population_16` |
| `nonzero_delta_time` | `nonzero_delta_time` |
| `raw_byte_reversal` | `raw_byte_reversal` |
| `retained_fragment_overwrite` | `retained_fragment_overwrite` |
| `duplicate_retirement` | `duplicate_retirement` |
| `lost_retirement` | `lost_retirement` |
| `overflow_without_sticky_fault` | `overflow_without_sticky_fault` |

Plants alter only the observed test path or an oracle boundary selected by the
`PLANT` simulation plusarg. They do not modify or bind into production RTL.
