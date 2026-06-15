# 005 — Roadmap

This document lays out the phases of development and points to the issue
files that decompose each phase. The ordering inside a phase is by
foundational dependency: lower-numbered issues are the ground others stand
on; higher-numbered issues lean on more pieces; the final issue of each
phase is a capstone demo.

The vision lists three phases:

1. **Basic movement options** (the current phase)
2. **Resources** (future)
3. **Advanced movement options** (future) — patrol, attack-move, etc.

Each phase has its own issues directory with a `phase-N-progress.md` file
in `issues/` tracking how far through the phase work has gone.

## Phase 1 — Basic movement options

The full vision feature set: terrain, units, projectiles, line of sight,
miss-variance memory, factory, single and chained orders, chain splitting,
rally points, and a phase demo.

============================ phase 1 issue files ============================

(The line above is the auto-interleave marker for the
`generate-readme-toc.lua` script. When this document is read by that
tool, the phase-1 issues are inserted here.)

A summary of the issue layout for a reader without the tool. Status
column is a pointer to the live truth in `phase-1-progress.md`, not a
duplicate of it — the table here is for *order* and *why*.

| ID  | Title                              | Why it sits here                          |
| --- | ---------------------------------- | ----------------------------------------- |
| 101 | Build system & raylib bootstrap    | Nothing compiles without it.              |
| 102 | Threading model (pthreads)         | Top-level thread layout. See note below.  |
| 103 | Window & 3D camera                 | Need a view before there is anything.     |
| 104 | Heightmap terrain                  | The world units stand on.                 |
| 105 | Terrain ray-pick                   | Mouse → world point, used everywhere.     |
| 106 | Unit entity & box rendering        | The thing the game is about.              |
| 107 | Unit movement on terrain surface   | Without movement, no orders mean anything.|
| 108 | Box selection                      | Required before issuing orders.           |
| 109 | Right-click single move order      | The simplest order.                       |
| 110 | Shift-chained waypoint orders      | Composes single orders into chains.       |
| 111 | Line of sight                      | Gates firing.                             |
| 112 | Javelin projectile                 | Cylinder, ballistic, no correction.       |
| 113 | Combat targeting, firing, HP, regen| Wires units → LoS → projectiles, adds HP. |
| 114 | Task pool library (action-array)   | Pool infrastructure; adopted by 107+.     |
| 115 | Aiming variance per (shooter,target)| Adds the miss-memory rule.                |
| 116 | Factory placement & production     | Adds a unit producer.                     |
| 117 | Single rally point with X/Y drag   | Direct factory output.                    |
| 118 | Shift-chained rally points         | Same chain primitive applied to factories.|
| 119 | Selected-unit chain splitting      | The half-split rule for new chains.       |
| 120 | Phase 1 demo capstone              | Visual demo combining everything.         |
| 121 | raylib build flag manifest         | Honest minimal-feature raylib link on 6.0.|
| 122 | Task pool: game-build integration  | Wires the pool into the game binary.      |
| 123 | Task pool: periodics               | Superseded by 127 (frame-ring schedules). |
| 124 | Task pool: stable indices          | Exploratory; no committed consumer yet.   |
| 125 | Task pool: API hardening           | Abort-on-bad-id, ref-ownership contract.  |
| 126 | Threading walkthrough document     | Single narrative across 102/114/107/127.  |
| 127 | Task pool: frame-ring scheduling   | Architectural fix for the 107 movement snap. |

The 121-127 cluster is build/threading infrastructure that surfaced
during Phase 1 work. They sit at the bottom of the table because they
post-date the original numbering, not because they are less foundational
— 127 in particular is gameplay-blocking for polished 107 movement.

### Note on issue 102 vs the task-pool reality

102 originally described a **two-thread** model: a main thread plus a
single dedicated sim thread, with a snapshot buffer and an input queue
between them. By the time movement landed (107) the project had instead
adopted the task pool from 114/122 — there is no dedicated sim thread,
the pool's workers run slice-batched and self-rescheduling tasks
directly. 102's plan and the implementation now describe different
worlds. 102 is still TODO in the table for transparency; the resolution
is to either re-scope it to the pool architecture or close it as
overtaken-by-114-and-107. Defer until the walkthrough doc (126) lands so
the comparison is in writing.

When an issue is completed, it moves to `issues/completed/` and
`phase-1-progress.md` is updated.

### Pending design notes (not committed work)

- [128 — modifier-ring batching](../issues/pending/128-modifier-ring-batching.md):
  documentory describing the per-tick-totals + ring-buffer pattern
  from `docs/006-threading-walkthrough.md` Part 5. Promoted to
  `issues/` only when a concrete first consumer is in scope.

## Phase 2 — Resources (placeholder)

Not yet broken into issues. Likely contents: a resource node, a harvester
behavior or a unit production cost, possibly storage. This phase exists
mostly to make the production cadence introduced in Phase 1 *cost*
something rather than be free.

## Phase 3 — Advanced movement options (placeholder)

Patrol orders (return to start when the chain ends), attack-move (units
walk a path but engage on sight), hold-position, possibly stance toggles
(fire while moving on/off). All of these are extensions of the order chain
primitive established in Phase 1.

The roadmap will be revisited at the end of Phase 1 to refine these.

## Phase 4 — Rendering polish (placeholder)

Visual enhancements that do not change gameplay. Seeded with one
issue today:

- [401](../issues/401-point-light-system.md) — movable point light
  system. Sits on top of the static sun-bake from 104. Requires a
  custom shader since raylib's default is unlit.

Future Phase 4 candidates: dynamic shadows, particle effects for
projectile hits, post-processing for the unit-selection silhouette.
None of these are commitments yet — Phase 4 will be revisited when
the gameplay phases are deep enough for polish to be the obvious
next move.
