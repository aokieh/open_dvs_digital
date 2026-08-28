# Synchronous product pre-framing acceptance harness

This frozen harness is the RED acceptance boundary for connecting the qualified
synchronous product encoder to the live top and bottom capture records. It owns
only this directory. It neither implements packet framing nor enables
synchronous ownership.

## Frozen interface names

The implementation must expose these private integration seams without adding a
public `final_top3`, `open_dvs_top`, wrapper, or pad port:

- `col_readout_macro`: `source_record_valid_o` and
  `source_record_o[135:0]`. The record is exactly
  `{event_mode, row_addr, col_left_m2, col_right_m2}` and valid is exactly
  `fifo_wr_en`, before the legacy `wr_en && !full` suppression.
- `fifo_rows_cols_macro2`: independent `top_record_valid_o`,
  `top_record_o[135:0]`, `bottom_record_valid_o`, and
  `bottom_record_o[135:0]` paths.
- `final_top3`: private `top_record_valid`, `top_record[135:0]`,
  `bottom_record_valid`, and `bottom_record[135:0]` signals; one
  `i_sync_product_encoder_core`; one `i_sync_product_reset`; and private
  `serial_beat_complete`.
- `spi_peripheral_re`: private output `serial_beat_complete_o`, low by default
  and on chip-select abort, high for exactly the cycle-15 final four-lane bit.
  The existing cycle-13 `shift_en_fifo` remains consume look-ahead.

The product core instance keeps `admit_enable_i`, both fragment-ready inputs,
synchronous availability, synchronous ready, both synchronous words,
synchronous consume, and both accepted outputs at zero. The reset input is the
output of the existing `rst_sync` implementation. The qualified core remains
hash-identical and contains exactly the two qualified `enc128` leaves.

## Commands

Run from the repository root:

```sh
bash -n fver/hardware_codec/integration/sync_product_preframing/run_sync_product_preframing.sh
python3 -I -c 'from pathlib import Path; p=Path("fver/hardware_codec/integration/sync_product_preframing/check_sync_product_preframing.py"); compile(p.read_text(), str(p), "exec")'
bash fver/hardware_codec/integration/sync_product_preframing/run_sync_product_preframing.sh --preflight
bash fver/hardware_codec/integration/sync_product_preframing/run_sync_product_preframing.sh --self-test
bash fver/hardware_codec/integration/sync_product_preframing/run_sync_product_preframing.sh --expect-red
```

`--preflight` performs a real Xcelium elaboration of the contract fixture and
testbench without making a behavior claim. `--self-test` runs the fixture once
unplanted and rejects all ten named semantic plants. `--expect-red` performs no
behavior simulation: it succeeds only when the live product has all three exact
missing-capability groups and every hash/path prerequisite is sound.

After production implementation, the immutable command is:

```sh
bash fver/hardware_codec/integration/sync_product_preframing/run_sync_product_preframing.sh --expect-green
```

GREEN first requires structural closure, then uses Xcelium for the real
integration behavior and all plants. It elaborates all three maintained product
manifests. It reuses the existing frozen ownership, ownership-safety, and abort
testbenches as separate Xcelium regression commands, so no result depends on
Icarus Verilog elaborating `enc128`. It also runs the qualified product-core
Xcelium runner, baseline reset runner, product-list policy, and whitespace gate.

The behavior test exercises one serial beat and one aborted partial beat. It
does not count packets, frames, records per frame, or a ninth serial word. Raw
bytes, ninth-word retirement, abort replay, and word-31 status remain owned by
the reused frozen regressions rather than duplicated here.

## Fail-closed controls and telemetry

The test-source seal covers every harness source except the seal itself. The
runner checks it before and after each mode. RED is not accepted for syntax,
path, tool, license, fixture, hash, or partial-interface failures.

One worker built this harness, with no delegation and one editor. The ten
behavioral plants cover synchronized release, disabled admission, fragment
ready, synchronous visibility, record mapping, tier-pulse independence,
pre-full observation, cycle-13 versus cycle-15 timing, missing completion, and
abort suppression. Five structural controls cover manifest omission,
forbidden-source inclusion, mapping reversal, full-gated valid, and cycle-13
completion.
