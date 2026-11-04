# 803 — Checksums catch divergence

**Phase:** 8 — Across the wire
**Blocked by:** 801

**Blocks**: 804
**Related documents:** docs/datapath-network.md

## Current Behavior

Machines could drift apart unnoticed.

## Intended Behavior

- Every 100 ticks each machine sends its world checksum (102) for that tick.
- Any mismatch stops the game on every machine with an error naming the tick
  and writes both machines' snapshots for that tick to `tmp/shared-memory/`
  for comparison. No attempt to resync silently.

## Suggested Implementation Steps

1. Checksum message; comparison; stop-with-error.
2. A test that deliberately perturbs one instance and expects the stop.
