# Baseline serializer abort acceptance gate

This frozen integration test drives the existing `final_top3` serial interface
and observes both real first-in, first-out buffers and serializers. It verifies
that raising active-low chip select during a partial streamed-buffer transaction
preserves storage while restarting serializer progress at chunk zero.

The test loads a primary pair and a distinct sentinel pair through the real top
and bottom synchronous buffers. The primary records are:

```text
top    = {8'hA5, 64'h7766554433221100, 64'hFFEEDDCCBBAA9988}
bottom = {8'h3C, 64'h6F5E4D3C2B1A09F8, 64'h8778695A4B3C2D1E}
```

The expected four-lane words, in transaction order, are fixed as:

```text
f81e0088 092d1199 1a3c22aa 2b4b33bb 3c5a44cc
4d6955dd 5e7866ee 6f8777ff 3c3ca5a5
```

Each return lane is sampled most-significant bit first one nanosecond after a
rising clock edge. Nine independent cases release chip select after zero through
eight complete data bursts, hold it high across at least two rising edges, and
issue a fresh streamed-buffer opcode. A passing boundary replays all nine words,
does not pop before the control burst, pops each tier exactly once on that burst,
and leaves the sentinel pair at the two buffer heads.

The same simulation checks one uninterrupted transaction and global reset during
a four-burst partial transaction. Three additional partial transactions release
chip select at clock midpoint and two picoseconds before and after a rising edge.
They require no immediate asynchronous serializer reset, one abort pulse sampled
at the opposite clock edge, and synchronous serializer restart on the following
rising edge while buffer storage, pointers, counts, and heads remain unchanged.
The runner also executes the existing focused no-encoder reset gate without
modifying it.

## Commands

Run the acceptance test after the production repair:

```sh
bash fver/hardware_codec/integration/baseline_abort/run_baseline_serial_abort.sh \
  --expect-green --sim iverilog
```

The GREEN aggregate markers are fixed as:

```text
@@BASELINE_SERIAL_ABORT_RELEASE_PHASE_PASS@@ cases=3 near_edge_ps=2 full_clock_abort_samples=3 asynchronous_resets=0
@@BASELINE_SERIAL_ABORT_ACCEPTANCE_PASS@@ boundaries=9 replay_bursts=81 normal_bursts=9 lane_bytes=360 premature_pops=0 global_reset_cases=1
@@BASELINE_SERIAL_ABORT_CONTROL_REJECTED@@ control=raw-CS_N-direct-asynchronous-reset check=release-phase-no-asynchronous-reset
@@NO_ENCODER_BASELINE_RESET_GATE_PASS@@ strict_parse=1 structure=1 behavior=1 controls=4 repository_unchanged=1
@@BASELINE_SERIAL_ABORT_GATE_PASS@@ simulator=iverilog boundaries=9 normal_identity=1 global_reset=1 software_reset=1 repository_unchanged=1
```

The runner builds the negative control only in its mode-0700 disposable
directory. That control reconnects raw `CS_N` to `stream_abort` and restores the
direct asynchronous serializer reset; the release-phase oracle must reject it
before it can emit the acceptance marker. The control is never written into the
repository.

## Execution isolation

The runner passes an explicit ordered array containing the twelve production
sources and this testbench directly to Icarus; it does not discover sources,
expand wildcards, or consume a mutable file list. GREEN verifies the exact
SHA-256 identity of all twelve corrected production sources, the testbench, and
this README before compiling. The runner cannot safely pin its own recursively
changing content; its exact SHA-256 identity is frozen externally by the
registered OpenCode Sessions specification and root gate.

Compilation, simulation, reset-gate logs, exits, and repository snapshots exist
only under a mode-0700 directory named
`/tmp/opencode/dvs-encoder/baseline-serial-abort.XXXXXXXXXX`. An exit trap removes
that unique directory. The runner compares the branch, head, index, tracked and
untracked content, staged diff, and unstaged diff before and after verification;
only an unchanged repository can emit a confirmation or gate marker.
