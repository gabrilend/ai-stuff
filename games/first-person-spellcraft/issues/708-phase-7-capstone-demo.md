# 708 — Phase 7 Capstone Demo (the settlement, end to end)

> **Phase:** 7 — Economy & Settlement Management
> **Depends on:** every prior Phase 7 issue (701–707). Recombines earlier phases'
> tools where available (Phase 5 NCP returns feed the loop).
> **Blocks:** nothing in Phase 7. It is the phase's deliverable capstone.
> **Concern:** demonstration — a deliverable, not merely an artifact.

The phase's capstone: a runnable demo that shows the whole economy turning — a
return comes in, treasure is deposited, templates stamp a request, the market
fulfills it, workshops make goods over time, service staff speed them up — and
that *foregrounds the statistics*, per the project's demo discipline (show the
datapoints, don't narrate the feature). It lives in `issues/completed/demos/` and
is reachable from the project-root demo launcher as the Phase 7 selection.

## Current Behavior

None of this exists yet. There is no Phase 7 demo and (until 701–707 land)
nothing to demonstrate.

## Intended Behavior

A single runnable demo that drives the finished economy and reports numbers:

- **Seed** a stockpile, place a couple of workshops (e.g. lumber shops) with
  different worker counts, hire some service staff, and set up a market with a
  stock policy.
- **Run production ticks** and show goods accumulating — and, as the headline
  statistic, **plot the room-vs-throughput tradeoff**: total output across a sweep
  of worker counts for one workshop, so the sweet spot is *visible*. Show the
  same workshop's output with and without service staff, so the speed bonus is a
  number on the screen.
- **Drive several returns** (synthetic return events, or real ones from Phase 5 if
  it is available) through the return-and-request loop: deposit treasure, stamp
  requests from templates, fulfill through the market. Report the **fulfillment
  rate** and list any refusals with their reasons (proving the explicit-refusal
  design).
- **Show the ledger** growing append-only, and stockpile balances over time.
- Ideally, present at least one panel of the config UI (707) editing a template
  or a worker allocation, so the viewing/editing side is shown alongside the
  simulation — the demo should exhibit both sides of the wall.

Per the demo convention, favor **statistics and datapoints** (throughput curves,
fulfillment rates, balance-over-time, staffed-vs-unstaffed deltas) over prose
description, and produce a **visual** where reasonable — a plotted throughput
curve or a rendered settlement panel rather than a wall of printed lines.

## Suggested Implementation Steps

1. Write a demo script that boots the economy from seed data (respecting the
   `input/` convention — read seed config from `input/` first).
2. Exercise, in one run: production ticks with a worker-count sweep, the
   service-staff on/off comparison, and several returns through 706.
3. Gather the statistics (throughput curve, fulfillment rate, ledger growth) and
   render them — a plotted curve or a graphical panel preferred over text.
4. Show one config-UI panel editing a mold and the previewed number matching the
   simulation, to demonstrate the separation-of-concerns wall in action.
5. Provide the runnable bash launcher with the project's `${DIR}` convention
   (hard-coded `${DIR}` at top, overridable by argument, all paths relative to
   it), ensure the `tmp/` symlink exists for any ephemeral output, and register
   this demo as the Phase 7 selection in the root demo launcher.
6. On finish, write a goodbye to `output/` per the project's start/stop
   convention.

## Files (proposed, by role)

- a Phase 7 demo script under `issues/completed/demos/` (drives 701–707 and
  reports statistics) plus its bash launcher with the `${DIR}` convention.
- any small plotting/rendering helper the demo needs to make the throughput curve
  visual.

## Design notes worth keeping

- The demo is part of the deliverable, not a throwaway. Keep it at the same
  quality as the game and update it when the economy changes — it is how the
  room-vs-throughput tradeoff and the fulfillment loop are *shown* to exist.
- It recombines earlier phases' tools: if Phase 5 is present, drive real NCP
  returns through it; if not, synthesize return events matching 706's inbound
  contract so the demo stands alone.

## Related Documents / Tools

- [datapath-economy-settlement.md](../docs/datapath-economy-settlement.md) —
  the full flow this demo walks end to end.
- [roadmap.md](../docs/roadmap.md) — the phase-demo / root-launcher convention.
- Exercises 701–707.
