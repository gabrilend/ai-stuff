# Phase 1 progress

**Goal of phase 1** (from `docs/009-roadmap.md`):

> By the end of Phase 1, the project can produce a `.nds` and a native ELF
> from the same source, with patches applied and reverted around each
> build. The trunk compiles a "hello rumble" scene with a single sprite, a
> fixed-point sin-wave bob, and a button-press logged through the
> platform input seam.

## Issues in phase 1

| ID  | Title                                        | Status   | Notes |
|-----|----------------------------------------------|----------|-------|
| 101 | Toolchain and environment setup              | pending  |       |
| 102 | Project structure and build script           | pending  |       |
| 103 | Patch system harness                         | pending  |       |
| 104 | Platform seam header                         | pending  |       |
| 105 | Fixed-point math module                      | pending  |       |
| 106 | Trig table generator                         | pending  |       |
| 107 | NDS "hello rumble"                           | pending  |       |
| 108 | Native "hello rumble"                        | pending  |       |
| 109 | Memory and budget readout                    | pending  |       |
| 110 | Phase 1 capstone demo                        | pending  |       |

## What "done" means for phase 1

- Both profiles build from one trunk.
- The patch system applies and unapplies cleanly.
- `fx_sin` produces the same frame-by-frame bob position on both targets.
- Memory budgets are tracked and equal-categoried on both targets.
- The capstone demo runs side-by-side and the log-comparison passes.

## Lessons learned

(To be filled in as issues complete.)

## Deprecated / temporary files

(To be filled in as issues complete.)

## Open questions raised during phase 1

(To be filled in as issues complete.)
