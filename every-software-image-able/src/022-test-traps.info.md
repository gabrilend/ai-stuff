# 022-test-traps — info

Runs every machine over every landmine and says whether the tripwires did what
they claim. Three architectures times two payloads: one that behaves, one that
deliberately writes where it must not.

Also the phase 7 demo — the same machine with the discipline held and with it
broken, side by side, with the difference shown rather than described.

## Invocation

```
luajit src/022-test-traps.lua [--dir ROOT] [--seconds N]
```

Builds every payload first, so a build failure is never mistaken for a machine
misbehaving. Exit status zero only when every case came out as expected.

## Why both halves of the matrix

A test suite containing only reckless machines proves the traps fire. It does
not prove they stay quiet — and a trap that fires on a well-behaved machine is
worse than no trap, because it makes the discipline unfalsifiable. Both
directions or neither.

## What it prints that a passing run should not let you forget

Every run ends by saying what it does **not** prove: that traps cover only
addresses somebody wrote down, and that a write which truly ends the machine
cannot be reported by a watchpoint at all. A clean sweep invites the wrong
conclusion, so the caveats are printed on success rather than filed in a
document.

## Result on 2026-08-02

Six of six as expected, on x86-64, 64-bit ARM and RISC-V.
