# Synchronous product encoder core behavioral acceptance

This directory contains the versioned RED-first behavioral apparatus, the
Xcelium v3 qualification route, and the product-core synthesis route for
`opendvs_sync_product_encoder_core`. It tests only the packet-grammar-independent
two-tier fragment core; host framing and chip integration remain separate units.

## Frozen authority and identities

- Specification SHA-256: `564c6eece59908d6ed047d0e8268ad344e770ba9bf279212dff22b729ed1bd30`
- Frozen `enc128` leaf SHA-256: `0c77fa83ec15af0c06df96b04dcfc67dd02cad23ffd075cf1f59f879a6cad54d`
- Testbench SHA-256: `a03887d936fe53c905b5b7ae1b418bab31efc24896bb333e4809178d7f15a923`
- Archived v1 runner SHA-256: `c6cb6195143e5ff5a977ef810544f399d3f75307da4467d7e557bfb1f0cc0f1a`
- Active v2 runner SHA-256: `6a2364b5a42447798e51806a74be0736b2edb05cb1305faffa1a49cf797e05e6`
- Archived v2 runner SHA-256: `6a2364b5a42447798e51806a74be0736b2edb05cb1305faffa1a49cf797e05e6`
- Archived v2 README SHA-256: `1e6f587ade9c9d5726c16a15e041f2c764b034a14ad6beaa303ab5a9a2aee6e5`
- Xcelium v3 runner SHA-256: `5ed76703b35c721026cfe589a5d271df72a5ffc440bc34a675dd31169036860f`
- Xcelium compatibility testbench SHA-256: `eaefb783b2408058c193ef3434a5877487e22600fd4c3e92da38170b79f9e38b`
- Synthesis runner SHA-256: `edbdc6be9f051287ec4a018bd2180207dbde8aa57cb17de525c5ecd38fa60852`

The exact v1 and v2 runners are archived at
`frozen/run_sync_product_core_v1.sh` and
`frozen/run_sync_product_core_v2.sh`; the README that described v2 is archived
at `frozen/README_v2.md`. The v1 RED result and v2 Icarus parser diagnosis remain
historical evidence. The v3 route does not claim or rerun RED. It leaves the
frozen leaf and oracle unchanged, creates only a hash-pinned scratch copy for
three Xcelium termination-call substitutions, elaborates the real closure once,
and reuses that snapshot for one unplanted run and all nine plants.

## Commands

Run from the repository root:

```bash
bash fver/hardware_codec/unit/sync_product_core/run_sync_product_core_xcelium_v3.sh --direct-preflight
bash fver/hardware_codec/unit/sync_product_core/run_sync_product_core_xcelium_v3.sh --fixture-preflight
bash fver/hardware_codec/unit/sync_product_core/run_sync_product_core_xcelium_v3.sh --expect-green
bash fver/hardware_codec/unit/sync_product_core/run_sync_product_core_synthesis.sh --preflight-remote
bash fver/hardware_codec/unit/sync_product_core/run_sync_product_core_synthesis.sh --run-remote
```

The two preflights are Xcelium elaboration-only checks for the direct leaf and
the exact 29-port fixture. `--expect-green` elaborates exactly the frozen leaf,
product core, and compatibility testbench, then requires the full 3,096-case
GREEN marker and nine independently detected plants. The remote synthesis route
maps exactly the leaf and product core at default queue depth 16 using the pinned
Yosys and Sky130 identities, with the qualified 236-cell exclusion union.

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
