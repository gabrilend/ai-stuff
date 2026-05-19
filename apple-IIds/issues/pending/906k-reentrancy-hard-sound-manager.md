---
name: Sound Manager reentrancy fixes (structural)
phase: 9
status: pending (pending soramech)
blockedBy: [905k]
parent: 906
---

# 906k — Sound Manager reentrancy fixes (structural)

Structural refactor of Sound Manager. Audio-stream interaction
with the IRQ path is the main concern.

## current behavior

After 905k, Sound Manager is lock-correct. The IRQ path holds the
sound lock briefly each tick to drain the active-sound list.

## intended behavior

- If the IRQ-held lock proves to be a problem (audio dropouts
  under contention), refactor: the IRQ path uses lock-free
  primitives to drain the sound list; the program path uses the
  lock for mutation.
- Other audit-driven changes.

## suggested implementation steps

1. Wait for audit. Measure IRQ-induced audio dropouts first.
2. Refactor if measurements show a problem.

## related documents

- `issues/906-toolbox-reentrancy-fixes-hard.md` — parent

## notes

- Audio is the most timing-sensitive subsystem. A few dropped
  samples are audible. Get the IRQ-path latency right.
