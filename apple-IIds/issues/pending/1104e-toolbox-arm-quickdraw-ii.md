---
name: Toolbox in ARM — QuickDraw II
phase: 11
status: pending
blockedBy: [1104a]
parent: 1104
---

# 1104e — Toolbox in ARM: QuickDraw II

ARM-assembly port of QuickDraw II. The largest sub-port of 1104 by
code volume. The staging-ground native version from issue 604
(C-on-soramech) is the immediate predecessor; this issue takes that
and reimplements in pure ARM assembly for bare metal.

## current behavior

QuickDraw II runs as the phase 6 native rewrite (C-on-soramech)
during late staging, after running emulated 65C816 during phases
1–5.

## intended behavior

- Native ARM-assembly implementation of every QuickDraw II call,
  taking the same shape as the 604a-604e sub-issues but in
  assembly rather than C.
- Pixel-exact equivalence with both the emulated and the
  staging-ground native versions.
- Performance: at least matches the C-on-soramech version;
  benefits from NEON SIMD where applicable.

## suggested implementation steps

1. Study the staging-ground native QuickDraw (604a-604e).
2. Port each subsystem from C to ARM assembly. Order roughly
   matches 604: primitives, regions, blits, text, palette.
3. Use NEON intrinsics in the assembly for the inner loops where
   they help (mainly blits and text).
4. Regression-test against the staging-ground baseline.

## related documents

- `issues/1104-iigs-toolbox-arm.md` — parent issue
- `issues/604-quickdraw-ii-native.md` — staging-ground predecessor
  and its 604a-604e sub-issues

## notes

- This sub-issue, like 1104h (Toolbox Window Manager) and 1104g
  (Menu Manager), is itself sometimes worth further subdivision
  during implementation (1104e-a primitives, 1104e-b regions, ...).
  Defer that decision until the work begins.
