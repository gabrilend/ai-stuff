# 109 — Memory and budget readout

**Phase:** 1
**Blocked by:** 107 and 108 (both hello-rumbles must exist before the
readout has anything to measure).
**Blocks:** 110 (phase 1 demo prints this readout).

## Current behavior

Both targets boot and run, but neither reports its resource usage. The
architecture commits to honoring DS budgets on both profiles
(`docs/004-architecture.md`) but nothing measures or enforces that.

## Intended behavior

Each frame loop ends with an optional debug readout — enabled via a
compile-time flag `SYMBELINE_DEBUG_BUDGETS` — that writes to
`tmp/<profile>-budget.log`:

```
frame=00012345  main_ram=128432/4194304  vram_tex=8192/524288  vram_3d=0/147456  tris=0/2048  audio_ch=0/16
```

The format is **identical across profiles**. On NDS the values are read
from libnds runtime queries where available, and from compile-time
asset/static-size accounting where not. On native, the values are
*simulated* — the native build tracks its own usage against the same
budgets and reports it in the same fields.

If any budget is exceeded, the readout includes a `OVER` marker on the
offending field, and `platform_log` raises a warning. (Warnings are
errors per the global rule — a budget overrun blocks the build in CI,
once CI exists.)

## Suggested implementation steps

1. Author `src/02-budget.h` and `src/02-budget.c`:
   - `budget_track_alloc(category, bytes)` / `budget_track_free`.
   - `budget_track_triangles(count)` per frame.
   - `budget_track_audio_channel(channel, on)`.
   - `budget_frame_emit(void)` — writes the readout line.
2. Wire `budget_track_alloc` into every allocator call site in the trunk.
   For phase 1 there are essentially none beyond the placeholder sprite
   load.
3. Define the budget constants in `src/02-budget.h` as
   `enum { BUDGET_MAIN_RAM = 4 * 1024 * 1024, ... }`. Both profiles
   share the constants — this is what makes parity testable.
4. Profile-specific value sources:
   - NDS: query libnds where available (`mallinfo`-equivalent if any),
     account statically otherwise.
   - Native: track everything in our own counters because the host
     allocator's numbers are not informative.
5. Add `--budget` flag to `scripts/symbeline-run` that prints a summary
   from the latest log on exit.

## Acceptance criteria

- Both hello-rumbles produce `tmp/<profile>-budget.log` files with
  matching schemas.
- A side-by-side diff of the two files at the same frame number shows
  identical *categories* and *budget caps*, with potentially different
  *current* values (because the rendering paths differ).
- Forcing an overrun (e.g., setting `BUDGET_MAIN_RAM` artificially low)
  produces an `OVER` marker and a logged warning on both profiles.

## Why the native build self-imposes DS budgets

If native can render scenes the DS cannot, the team will accidentally
design for native. The whole multi-target premise collapses. The budget
readout is the daily reminder that **the DS is the canonical target**
and the native build is a sister, not a parent.

## Deliverable artifacts

- `src/02-budget.h`
- `src/02-budget.c`
- `src/02-budget.info.md`
- `tests/02-budget-overrun.c` (the test that proves overruns are
  detected).

## Related documents

- `docs/004-architecture.md` — budget table.
