# 126 — Threading Architecture Walkthrough Document

## Status

IN PROGRESS

## Current behavior

`docs/004-architecture.md` is the design-of-record for the threading
model — modules, two threads, snapshot, slice-batched parallel pass,
data-flow per tick. It is comprehensive but reads like a spec: dense,
unstructured for first-time readers, no narrative thread, and (most
importantly) it describes the *design* without distinguishing what's
been built from what's still planned.

A reader who wants to understand the threading model has to:
- read `004-architecture.md` for the design,
- read issue `102-threading-model.md` for the two-thread plan,
- read issue `completed/114-coroutine-pool-library.md` for the task
  pool's design history (five iterations),
- read issue `completed/122-task-pool-game-build-integration.md` for
  how the pool was wired into the game build,
- read issue `completed/107-unit-movement-on-terrain.md` for which
  shape (A or B) the first pool adopter chose,
- read issues `123/124/125/127` for the open follow-ups and the
  bug-driven redesign currently in flight.

Seven files, each authoritative on its slice of the picture. No
single document threads them together for a new reader.

## Intended behavior

A single companion document at `docs/006-threading-walkthrough.md`
walks through the threading architecture in narrative order, as a
six-part guided tour. It is not a replacement for `004-architecture.md`
(the spec) or for the issue files (the historical record); it is the
*reading path* a new reader follows to build mental model.

The six parts cover:

1. The two-thread split and the boundary (status: designed in 102, not
   yet built).
2. The snapshot handoff — double-buffered struct, mutex-protected
   pointer swap (status: designed in 102, not yet built; render
   currently reads unit state directly with extrapolation per 107's
   completion log).
3. The input queue — semantic events, shift-chain IDs (status:
   designed in 102, not yet built).
4. The task pool reality — what's actually built in `libs/900-task-pool`
   (action arrays, GUID registry, ten-priority cycler, parking on
   waiters, self-rescheduling pattern), how it was integrated (122),
   which shape the first adopter chose (107 → Shape B), and the snap
   bug that motivates frame-ring scheduling (127).
5. Modifier-ring batching — a design pattern that generalizes the
   intent-records merge step from `004-architecture.md` to the modifier
   domain (e.g., "+20% speed"). Each frame's tasks accumulate modifier
   intents into a ring slot; the next frame applies them. The "long
   ones are done by the time the ring cycles back" property aligns
   naturally with frame-ring scheduling (127). Pattern is documented
   here; not yet implemented.
6. Implications and implementation — what the design enables
   (replay, headless sim, network rollback, save/load) and how to
   build / test / instrument it.

## Suggested implementation steps

1. Create `docs/006-threading-walkthrough.md` with the six-part
   structure above. Each part lays out *what's currently built*
   distinct from *what's planned*. Cross-references back to
   `004-architecture.md` for spec details and to the relevant issue
   files for historical context.
2. Update `docs/000-table-of-contents.md` to list the new doc under
   `docs/`.
3. Iterate: the first draft of this doc was written from issue 102
   alone and missed several substantive realities (action-array
   tasks vs coroutines; Shape B already adopted; 127's snap fix in
   flight; modifier-ring as the user's contribution). A rewrite
   incorporates the full issue context.

## Related documents

- `docs/004-architecture.md` — design-of-record for the threading
  model. The walkthrough doc is the narrative companion.
- `issues/102-threading-model.md` — two-thread split, snapshot,
  input queue.
- `issues/completed/114-coroutine-pool-library.md` — five-iteration
  design history of the task pool. Authoritative on what the pool
  actually does (action arrays + parking).
- `issues/completed/122-task-pool-game-build-integration.md` — pool
  wired into the game.
- `issues/completed/107-unit-movement-on-terrain.md` — first pool
  adopter; Shape B; the snap bug.
- `issues/127-task-pool-frame-ring-scheduling.md` — the redesign in
  flight to fix the snap. Also the natural home for modifier-ring
  delivery.
- `issues/123-task-pool-periodics.md` — superseded by 127.
- `issues/124-task-pool-stable-indices.md` — exploratory iter5.
- `issues/125-task-pool-api-hardening.md` — future hardening pass.

## Lessons (recorded for future doc work)

The first draft was written from issue 102 alone. It described the
pool as M:N coroutines with cooperative yield (iter1, replaced by
iter4.5 action arrays); described Phase 1 sim as fully serial (movement
is on the pool today); described slice-by-tenths as the adopted
parallel pattern (Shape A — Shape B won for movement); and missed
the snap / frame-ring redesign entirely. The rewrite read all seven
related issues plus the library header before structuring the
content.

Generalizable rule: an architecture doc written from the *design*
issue alone describes the plan, not the reality. The supporting
issues — design history, integration paper trail, adopter shape
decisions, bugs that forced redesigns — are the other half of the
picture and must be read before writing the narrative.

## Rewrite log (2026-05-01)

The rewrite at commit (this commit) replaces parts 4–6 of the
initial draft and threads explicit status markers through every
part. The user contributed the modifier-ring design pattern in the
same conversation that surfaced the gaps in the initial draft.

Concrete corrections applied:

- **Pool primitives.** Replaced the M:N coroutine description with
  the action-array + parking-on-waiters[] iter4.5 design from
  issue 114. Documented the priority cycler pattern, the
  `slot_status_t` result-slot semantics, the self-rescheduling
  idiom, and the design history's deletion of demote-on-block.
- **Phase 1 reality.** Removed claims that the sim is fully
  serial. Documented that issue 122 wired the pool into the game
  build and that issue 107 (Shape B) put movement on the pool.
- **Adopted parallel pattern.** Replaced slice-by-tenths-as-the-pattern
  with a Shape A vs Shape B framing. Slice-by-tenths is still the
  right shape for systems where every entity needs updating every
  tick (HP regen, LoS scan); per-unit self-rescheduling won for
  movement because stationary units consume zero scheduler time.
- **The snap and the fix.** Added a Part 4 subsection explaining
  the snap reproduction from 107's completion log (OS preempts
  worker between `now` capture and `last_update_t` write), the
  rejected band-aids, and the frame-ring redesign in issue 127.
- **Status markers.** Each part now opens with an explicit status
  line distinguishing designed-but-not-built (102), built and
  shipped (114, 122, 107), and bug-driven redesign in flight
  (127).
- **Part 5 (new).** Modifier-ring batching as the user described it:
  a frame-ring slot per modifier intent set, accumulated during
  frame N's parallel pass, applied single-threaded at frame N+1
  start, with the ring period providing a free deadline for
  long-running modifier computations. Positioned as the modifier-
  domain extension of the merge-step pattern from
  `004-architecture.md`.
- **Part 6 (compressed).** Combined the original parts 5–6 into a
  single tighter section. Kept the implications (replay,
  determinism, headless sim, sim-rate decoupling, snapshot as
  save format, intent pattern generalization). Replaced the
  serial-to-parallel migration code blocks (now wrong for
  movement) with a "what's actually been tested" table sourced
  from `tests/000-index.md`. Refreshed the instrumentation list
  with cadence-relevant counters (tick duration histogram,
  frame-budget overrun, parked-task census).

Files touched in the rewrite: only `docs/006-threading-walkthrough.md`
itself. No code changes; no other docs altered. Issue 126 (this
file) updated alongside.
