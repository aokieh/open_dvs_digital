# The no-encoder baseline reset binding

This focused gate proves that the no-encoder dual-tier block derives both row
state-machine resets from its declared row-state-machine software-reset port
(`fsm_rst_n`) and both column/first-in, first-out resets from its declared
first-in, first-out software-reset port (`fifo_rst_n`). The active-high software
pulses remain combined with the active-low global reset as `rst_n & ~pulse`.

Run the complete gate from the repository root:

```sh
fver/hardware_codec/integration/baseline_reset/run_baseline_reset_binding.sh
```

The runner accepts no arguments. It uses only these explicit design inputs:

- `source/design/common/defines.sv`;
- `source/design/final_macros/fifo_rows_cols_macro2.sv`;
- `fver/hardware_codec/integration/baseline_reset/tb_baseline_reset_binding.sv`.

The parser, compiler, and runtime are pinned by absolute path, SHA-256 digest,
and exact version string. Every parse, compile, and simulation command has a
30-second wall-clock limit. Generated executables, mutant sources, commands,
logs, exits, and marker counts live only in a unique mode-0700 directory named
`/tmp/opencode/dvs-encoder/baseline-reset-run.XXXXXXXXXX`; the exit trap removes
that directory. The runner snapshots and hashes the source and complete visible
repository state before and after execution, and fails if any repository output
or content change appears.

The real source must emit exactly:

```text
@@NO_ENCODER_BASELINE_RESET_ACCEPTANCE_PASS@@ checks=11 reset_equations=4
```

No line containing `@@NO_ENCODER_BASELINE_RESET_FAIL@@` is allowed in the real
run. The same testbench must reject four scratch-only planted controls at their
named checks:

- swapped software-reset ports at `isolated-row-state-machine-pulse`;
- an ignored first-in, first-out pulse at `isolated-first-in-first-out-pulse`;
- inverted software-pulse polarity at `released-software-pulses`;
- a pulse connected to only the top row tier at
  `isolated-row-state-machine-pulse`.

The final runner marker is exactly:

```text
@@NO_ENCODER_BASELINE_RESET_GATE_PASS@@ strict_parse=1 structure=1 behavior=1 controls=4 repository_unchanged=1
```

This correction establishes the functional no-encoder golden baseline for later
selector equivalence. The original pinned commit remains the provenance
baseline, and the four reset-name substitutions remain a separately recorded
deviation from it.
