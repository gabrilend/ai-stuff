# 120 — Phase 1 Demo Capstone

## Status

TODO

## Current behavior

Phase 1 features 101–118 are implemented and individually testable, but
no single demo exercises them in concert. There is no scripted scenario
that a viewer can run to see "the whole Phase 1."

## Intended behavior

A demo binary or scripted launch (driven from
`issues/completed/demos/phase-1-demo.sh`) starts the game in a
deliberate, narratable scenario:

- A heightmap with at least one ridge that meaningfully blocks LoS
  between two regions.
- ~6 units of team A on one side, ~6 units of team B on the other —
  some can see each other, some cannot.
- A factory pre-placed for team A with two rally chains already
  configured (one chain leads to a flank around the ridge, the other
  charges directly).
- A short text overlay (drawn by the demo, not the main game) that
  cycles through callouts: "watch line of sight," "click a unit to
  see its miss counters," "shift-drag rally chains," etc.

The demo is launched via a top-level `run-phase-demo.sh` script (in the
project root) that asks for a phase number and runs the matching
demo, per the mono-repo convention.

The demo prints a short statistics block to stdout on exit:
total ticks, average tick duration, peak projectile count, total
units spawned, total kills. These are the *datapoints* the user's
guidelines say phase demos should focus on.

## Suggested implementation steps

1. Add a `--demo=phase1` flag to the main binary. With this flag,
   skip the normal startup and enter a deterministic scenario:
   - Fixed terrain seed.
   - Pre-placed units, pre-placed factory, pre-built rally chains.
2. Add the on-exit stats block, gated on the demo flag.
3. Create `issues/completed/demos/phase-1-demo.sh`: a bash script with
   the standard `${DIR}` header that builds (if needed) and runs
   `build/3d-rts --demo=phase1`.
4. Create `run-phase-demo.sh` in the project root: prompts for a
   number, dispatches to `issues/completed/demos/phase-N-demo.sh`.
5. Confirm the demo runs without input — it should be observable hands-
   off, with optional manual interaction layered on top.
6. Update `issues/phase-1-progress.md` retrospective with what
   happened during construction.

## Related documents

- `docs/005-roadmap.md` — phase boundaries.
- All preceding Phase 1 issues — the demo is their intersection.

## Notes

The demo lives in `issues/completed/demos/` per mono-repo convention.
The phase-1 demo will be revisited at the end of Phase 2 (added to,
not replaced — the convention asks for new demos to *combine and
reconfigure* prior tools while introducing the new phase's tools).

## Task pool integration

The demo doesn't introduce new task types — it just runs the
existing systems (movement, combat, factory, rally chains) and
prints stats on exit. The stats-collection tasks are the only new
thing:

**Stats sampler — priority 8.** A self-rescheduling task that
samples per-tick datapoints (alive units, in-flight projectiles,
per-team kill counts) and accumulates them into a running buffer.

```
stats_sampler_task_actions = [
    [0] read_unit_count_alive_per_team
    [1] read_projectile_count_alive
    [2] append_to_running_stats_buffer
    [3] reschedule_self_at_priority_8
]
```

Priority 8 because the demo's stats are a posthumous summary; a
sample missed during a busy tick just means a slightly less smooth
graph at the end, not incorrect numbers (the totals come from
counters that other tasks already maintain). The sampler running
roughly once every 36 cycler steps is plenty for the 60Hz tick
rate.

**Final stats print on exit — runs on main thread, not pool.**
Once the window closes the pool is destroyed, then the main
thread prints the accumulated buffer. No task-pool involvement.

The text overlay callouts (per the suggested implementation) live
on the render thread alongside the rest of the HUD. Not pool.
