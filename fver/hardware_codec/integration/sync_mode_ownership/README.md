# Default-off synchronous ownership scaffold

This gate covers the pre-framing product scaffold. Register-file word 31 stores
the requested two-bit mode. Its readback is status rather than raw storage:

- `0x00000010`: reset/default raw owner;
- `0x00000051`: synchronous mode requested, pending, raw owner retained;
- `0x00000112`: unavailable mode requested, sticky unavailable status, raw owner;
- `0x00000213`: illegal mode requested, sticky illegal status, raw owner.

Only byte lane zero changes the mode request. Other byte writes remain stored in
the existing register file. Synchronous availability is tied low in this unit,
so no request may consume raw records, acknowledge a FIFO, or drive the four
return lanes. Mode 00 is cycle-identical for the four-lane raw data and consume
path and for every register address except newly assigned word 31. Word 31 is
the explicit mode/status carve-out and therefore returns `0x00000010`, not the
underlying reset storage value. The explicit product file list excludes
asynchronous and quasi-delay-insensitive codec sources.

Ownership is registered and can change only after the synchronized chip-select
path has observed release, emitted the serializer abort pulse, and reached two
settled high stages. A mode-01 request remains pending while that boundary has
not been reached. Availability loss and raw, unavailable, or illegal requests
cannot tear a live transaction; they return ownership to raw only at the same
quiescent boundary.

The user-project-wrapper Xcelium list is the authoritative product list and
contains every explicit product implementation entry in the same order. The
final-macros Xcelium list is a verification manifest: it intentionally retains
the pre-existing `regfile.sv` choice, while the user-project-wrapper and explicit
product lists use `regfile_final.sv`.

The historical abort source and the exact pre-migration runner are archived in
`../baseline_abort/frozen/`. The active historical runner now compiles and
mutates the frozen source, so later ownership integration in the live
`final_top3.sv` cannot invalidate the earlier hash-pinned evidence.

Run the failing baseline before implementation:

```sh
fver/hardware_codec/integration/sync_mode_ownership/run_sync_mode_ownership.sh --expect-red
```

After implementation, run:

```sh
fver/hardware_codec/integration/sync_mode_ownership/run_sync_mode_ownership.sh --expect-green
fver/hardware_codec/integration/sync_mode_ownership/run_sync_mode_ownership_safety.sh
fver/hardware_codec/integration/sync_mode_ownership/run_patched_product_abort.sh
```

The completed hash-pinned abort gate is historical evidence for the preceding
product version and is not edited. The patched-product replay applies the same
nine-boundary, normal-transaction, reset, and release-phase behavior to the new
source version.
