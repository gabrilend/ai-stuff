---
name: Sound Manager reentrancy fixes (lock wrappers)
phase: 9
status: pending (pending soramech)
blockedBy: [902, 904]
parent: 905
---

# 905k — Sound Manager reentrancy fixes (easy)

Lock-wrapper fixes to the Sound Manager. Per-oscillator state and
the active-sounds list are the shared state.

## current behavior

The Sound Manager has interrupt-driven oscillator updates plus
program-initiated start/stop calls. Concurrency between the IRQ
and the program is real and needs synchronization.

## intended behavior

- `sound_lock` held during: oscillator assignment changes, the
  active-sounds list mutations.
- The lock is interrupt-safe (interrupt context can acquire,
  briefly).

## suggested implementation steps

1. Wait for audit.
2. Add lock wrappers, interrupt-safe.
3. Group as `patches/210-sound-locks.gsos.s.patch`.

## related documents

- `issues/905-toolbox-reentrancy-fixes-easy.md` — parent

## notes

- Interrupt-safety is the subtle part. The lock primitive (issue
  902) supports it via interrupt-disable.
