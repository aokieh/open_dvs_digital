# Standalone self-delimiting packet-path acceptance

This directory is the resealed RED-first acceptance package for the
uninstantiated `opendvs_self_delimiting_packet_path` product module. Product RTL
remains separate under `source/design`; this package does not modify the raw
serializer, the ownership shell, `final_top3`, the serial peripheral, or the
qualified product encoder core.

## Exact interface

The frozen 31-port interface accepts the two retained fragment channels from
`opendvs_sync_product_encoder_core`, exposes commit-only ready pulses, and
returns the existing two 16-bit serializer words. It also accepts the existing
two-bit look-ahead consume, final-beat completion, synchronized abort, mode
entry, drain, encoder-quiescent, and serial-boundary signals. Public lifecycle
outputs expose packet readiness, core-admission enable, quiescence, sticky
fault, sequence, epoch, packet byte count, beat index, and completion-pending
state. The exact names and order are sealed in the fixture and checked before
every runner mode.

The product file list contains exactly:

```text
source/design/hardware_codec/sync/opendvs_self_delimiting_packet_path.sv
```

The test-only fixture has the same module name and interface but is never in the
product file list or synthesis closure.

## Frozen behavior

The package independently checks the version-two synchronous grammar, CRC-8,
all seven software literals, all six literals reachable by immediate one- or
two-fragment closure, populations 1 through 128, both tiers and legal labels,
rows zero and 63, four padding residues, exact 17-to-18-byte raw conversion,
the 40-byte maximum, atomic acknowledgement, persistent paired round-robin
order, late-fragment exclusion, one-bank backpressure, serializer lane and bit
order, consume-versus-completion retirement, all 319 pre-final abort prefixes,
abort coincident with pending non-final and final completion, mode entry
coincident with final completion, sequence and epoch wrap, drain boundaries,
malformed fail-closed behavior, and reset from every represented lifecycle
state. Every abort prefix observes each actual serializer output bit before the
abort and immutable replay check.

The executable fixture preflight runs the unplanted suite and twelve named
fixture behavior mutations. Each mutation changes a real observation or state
transition and must be caught by an ordinary lifecycle assertion; a name never
directly invokes a testbench failure or pass. A fixture pass proves only that
the apparatus is executable; it is not product evidence.

## Source seals

`reference-source.sha256` hash-pins the decision-complete unit specification,
the authoritative framing freeze and result, expected and malformed vectors,
candidate encoder, decoder, and test sources, current product core, ownership
shell, `final_top3`, serial peripheral, legacy readout macro and serializer, and
the legacy width/depth macro definitions.

`test-source.sha256` seals the exact file list and all acceptance files except
itself. Every command first verifies both seals, regular-file identity, package
inventory, whitespace, the exact interface, and independent reconstruction of
all frozen literal bytes and CRC values. The preflight also extracts all six
reachable SystemVerilog literal vectors and compares their exact lengths and
bytes with the sealed software vector source.

## Commands and expected results

Run from the repository root:

```sh
python3 -I fver/hardware_codec/unit/self_delimiting_packet_path/check_self_delimiting_packet_path.py --preflight
bash fver/hardware_codec/unit/self_delimiting_packet_path/run_self_delimiting_packet_path.sh --fixture-preflight
bash fver/hardware_codec/unit/self_delimiting_packet_path/run_self_delimiting_packet_path.sh --expect-red
bash fver/hardware_codec/unit/self_delimiting_packet_path/run_self_delimiting_packet_path.sh --expect-green
bash fver/hardware_codec/unit/self_delimiting_packet_path/run_self_delimiting_packet_path_synthesis.sh --preflight
bash fver/hardware_codec/unit/self_delimiting_packet_path/run_self_delimiting_packet_path_synthesis.sh --run
```

The first three commands must emit exactly one corresponding marker:

```text
@@OPENDVS_SELF_DELIMITING_PACKET_PATH_CONTRACT_PREFLIGHT_PASS@@
@@OPENDVS_SELF_DELIMITING_PACKET_PATH_FIXTURE_PREFLIGHT_PASS@@
@@OPENDVS_SELF_DELIMITING_PACKET_PATH_RED_CONFIRMED@@ missing_module=opendvs_self_delimiting_packet_path
```

In a product-free tree, `--expect-green` must return nonzero and end with:

```text
@@OPENDVS_SELF_DELIMITING_PACKET_PATH_FAIL@@ check=missing_product_module
```

Wrong paths, seal drift, syntax failures, fixture failures, timeouts, or any
other unresolved module invalidate RED.

With product RTL present, `--expect-green` emits the frozen PASS marker. The
synthesis gate rejects environment source/tool injection, uses fixed absolute
tool paths and a hash-pinned Yosys, and inspects generated JSON structure. It
requires exactly one flip-flop-retained 320-bit `packet_bank_q`, no second
retained 320-bit bank, no unresolved hierarchy, and no latches.
