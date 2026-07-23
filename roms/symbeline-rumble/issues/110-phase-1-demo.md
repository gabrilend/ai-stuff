# 110 — Phase 1 capstone demo

**Phase:** 1
**Blocked by:** 101–109 (all of phase 1).
**Blocks:** nothing in phase 1. Unblocks phase 2.

## Current behavior

All phase-1 pieces exist independently. There is no single artifact that
demonstrates them working together.

## Intended behavior

A single command from the project root:

```
./run-phase-demo
```

asks the user to pick a phase number; entering `1` runs
`issues/completed/demos/phase-1-demo/run.sh`, which:

1. Builds both profiles via `scripts/symbeline-build both`.
2. Launches the native build in one window and melonDS-loaded NDS build
   in another, side by side. (If a display server is unavailable, the
   script logs both runs and produces a screenshot pair instead.)
3. Both targets run for ~30 seconds: the chibi knight bobs, the player
   may press A (Space on native, A on DS) to pause.
4. Both targets emit `tmp/<profile>-budget.log` and
   `tmp/<profile>-frame.log`. The demo script then runs
   `scripts/compare-logs <nds-log> <native-log>` and prints a
   side-by-side diff focused on:
   - Frame count parity (within ±2 frames over the 30 seconds).
   - Bob-position parity (same `fx_t` values frame-by-frame, since
     gameplay is fixed-point and deterministic).
   - Budget-category parity (same categories, same caps).
5. The script prints a one-screen **statistics readout** (per the global
   rule on phase demos: stats over prose):
   - Total build time per profile.
   - Lines of trunk source code touched by patches per profile.
   - Number of divergence grid rows currently active.
   - Memory budget headroom per category per profile.
   - Trig-table accuracy delta (max error).

## Suggested implementation steps

1. Create `issues/completed/demos/phase-1-demo/`. Populate with `run.sh`,
   `README.md`, and a `screenshots/` placeholder.
2. Author `scripts/compare-logs` (likely Lua, since it's a build-time
   tool): reads two log files, emits a side-by-side report, exits
   non-zero on parity violation.
3. Author `run-phase-demo` in the project root: prompts for a phase
   number from 1 to N (where N is the count of `phase-*-demo/`
   subdirectories), then invokes the chosen demo.
4. Take side-by-side screenshots (NDS in melonDS, native window).
   Commit the screenshots to `screenshots/` for documentation.
5. Update `issues/phase-1-progress.md` with completion notes.

## What the demo is meant to prove

- The two profiles share one source tree.
- The patch system applies and unapplies cleanly per build.
- The fixed-point math layer produces identical values on both
  profiles.
- The memory budget discipline is observable.
- The native build observes DS constraints voluntarily.

## What the demo is **not** meant to prove

It is not a game. It is one bobbing sprite. Phase 1 is the *foundation*;
the foundation is the deliverable.

## Deliverable artifacts

- `issues/completed/demos/phase-1-demo/run.sh`
- `issues/completed/demos/phase-1-demo/README.md`
- `issues/completed/demos/phase-1-demo/screenshots/nds.png`
- `issues/completed/demos/phase-1-demo/screenshots/native.png`
- `scripts/compare-logs`
- `run-phase-demo`
- `issues/phase-1-progress.md` (final update for phase 1).

## Related documents

- `docs/009-roadmap.md` — phase 1 capstone description.
- All of phase 1's issues.
