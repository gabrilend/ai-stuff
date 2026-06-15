# 128 — Modifier-Ring Batching (documentory)

## Status

**PENDING REVIEW.** This file is a *documentory* — an issue-shaped
document describing a design pattern that has not yet been
reviewed, scoped, or committed to as work. It lives in
`issues/pending/` rather than `issues/` so it doesn't appear in the
active-work listing alongside issues that have been agreed-on.
Promote to `issues/` (or merge into 127 / a phase-2 ability issue)
when the design has been reviewed and a concrete first consumer is
in scope.

The pattern is currently captured in `docs/006-threading-walkthrough.md`
Part 5; this documentory is the discoverable issue-level pointer
back to that pattern, so a future reader scanning the issue tree
finds it without having to know to look in the walkthrough.

## Origin

User-described in conversation, 2026-05-01, while reviewing the
threading walkthrough:

> "each tick, the totals of modifiers being applied to each unit
> should be added together and prepared, and then at the start of
> the next one they are applied all at once. That way you can
> sorta 'sum' them, and keep track of their changes. Write to a
> different memory location ring buffer style and it works out
> easy."
>
> "also helps for things like 'add +20% modifier to their speed' or
> something similar. Batch the effects, then apply modifiers. Do
> this multithreaded, and the long ones will be done by the time
> it's back to the beginning of the ring buffer. Odds are, if they
> aren't completed, it's just a quick check to validate — are you
> done? if no, because it was one of the restricted ones, then
> they'll continue on their way. Long tasked projects of course
> ring-cycle quicker and sooner."

The pattern is the modifier-domain extension of the merge-step
described in `docs/004-architecture.md` — produce intents in a
parallel pass, apply single-threaded — delivered through the
frame ring from issue 127 instead of through a within-tick
collect-and-merge.

## Current behavior

There is no modifier system in the codebase. Phase 1 unit
behavior is unmodified: speed, turn rate, damage, regen rate are
all read directly from `010-config.h` constants at the moment
they are needed. There is no notion of a stackable buff, debuff,
or "+X% multiplier" anywhere.

The closest existing primitive is the merge-step pattern
documented in `docs/004-architecture.md`: per-task scratch buffers
of intents (damage, projectile-spawn) are folded
single-threaded at end-of-tick into authoritative state. That
pattern targets *single-field* writes ("subtract 1 HP from unit
B"), not accumulating modifiers ("contribute +10% to unit B's
speed multiplier").

## Intended behavior

A modifier-ring pattern that rides on issue 127's frame ring:

1. Each frame slot in the ring carries an intent buffer for
   modifier contributions, alongside its existing per-priority
   task queues:

   ```c
   struct frame_slot {
       /* (existing) ten priority queues for tasks scheduled this frame */
       /* ... */

       /* (new) modifier intents accumulated by tasks running in this frame */
       modifier_intent_t *intents;
       int                n_intents;
       int                cap_intents;
   };
   ```

2. A `modifier_intent_t` is a small record:

   ```c
   typedef struct {
       int  target_unit_id;
       int  modifier_kind;   /* MOD_SPEED, MOD_DAMAGE, MOD_REGEN, ... */
       float value;          /* additive contribution, e.g. +0.20 for +20% */
   } modifier_intent_t;
   ```

3. **Accumulation** happens during frame N execution: any task
   that wants to apply a modifier appends an intent into
   `frames[N].intents`. Tasks are slice-disjoint per the
   parallel-pass rules; the per-frame buffer is the only point
   of contention, and it can be sharded per-worker if profiling
   shows it matters.

4. **Application** happens at frame N+1 start, single-threaded,
   immediately after `pool_advance_frame` flips the current
   frame index. The sweep folds `frames[N].intents` into per-unit
   modifier sums, in canonical `(target_unit_id, modifier_kind)`
   order. Multiple `+X%` intents into the same target sum
   naturally; conflicts between kinds resolve by a fixed
   application order across kinds.

5. Frame N+1's tasks read the freshly-applied modifiers when
   they run their actions. They emit their *own* intents into
   `frames[N+1].intents` for frame N+2 to consume.

### The "long ones cycle around" property

The frame ring's slots are stable for `FRAME_RING_SIZE` frames.
Most modifier computations finish in well under one frame; some
unusual ones (an AoE damage modifier walking nearby units; a
buff that depends on a nontrivial pathfinding result) might span
multiple frames. By the time the ring has cycled back to the
same slot index, the slow computation is "probably done." The
apply sweep does a cheap "are you done?" check on each intent.
If yes, fold it in. If no, it continues into the next ring
revolution and slots in then. Long-tasked projects ring-cycle
quicker and sooner; short ones finish before their slot is
needed.

This is what makes the pattern multithreaded-friendly without
requiring locking: the ring buffer is the synchronization
discipline. Long-running modifier tasks don't block the apply
sweep; they just miss this revolution and catch the next.

### Why "+X%" specifically is the right shape

- **Commutative and associative within a frame.** Three sources
  of "+10% speed" applied in any order produce the same result.
  Accumulating into a sum is the natural operation; no
  tie-breaking needed.
- **Bounded blast radius per modifier kind.** A speed modifier
  doesn't interact with a damage modifier; per-kind sums in the
  apply sweep are independent.
- **Deterministic.** Sums of floats committed in the same
  application order produce the same result on every machine.
  The sweep applies in `(target_id, modifier_kind)` order;
  iterating intents is incidental, the *fold* is canonical.

## Suggested implementation steps

This is **pending review** scope. If promoted to active work, a
plausible breakdown:

1. Land issue 127 (frame ring) first. The modifier ring is a
   passenger on that data structure; building it before the
   frame ring exists is putting the wagon before the horse.
2. Add `modifier_intent_t` and the per-slot `intents[]` buffer
   to the frame slot struct in `libs/900-task-pool` (or in a
   new game-side wrapper if the modifier kinds are too
   game-specific to live in the library).
3. Add a public "emit modifier intent" API that takes the
   target unit, kind, and value. Tasks call this from inside
   their action bodies; the function appends to
   `frames[current_frame].intents`.
4. Add the apply sweep — runs once per `pool_advance_frame`,
   right after the frame index flips. Folds the *previous*
   frame's intents into per-unit modifier sums.
5. Add per-unit modifier accumulator fields (one float per kind:
   `speed_mod`, `damage_mod`, `regen_mod`, ...). Each tick
   the unit's effective speed is `UNIT_SPEED * (1 + speed_mod)`,
   etc. Modifiers reset to zero at the start of each apply
   sweep so they only persist the frames their sources are
   active.
6. Wire the first concrete consumer — likely a speed buff
   ability or 113's damage-multiplier system. The first
   consumer's needs will pin down the modifier-kind enum and
   any per-kind quirks (e.g. "damage modifier is multiplicative
   not additive"; "regen modifier saturates at +1.0").
7. Tests:
   - Single source applies the expected modifier next frame.
   - Multiple sources of the same kind sum.
   - Modifier expires the frame after its source stops emitting.
   - Apply order is deterministic across runs.
   - Long-running modifier task that misses a revolution still
     applies on the next.

## Related documents

- `docs/006-threading-walkthrough.md` — Part 5 is the design
  narrative. This documentory is the issue-tree pointer to it.
- `docs/004-architecture.md` — the merge-step pattern this
  generalizes.
- `issues/127-task-pool-frame-ring-scheduling.md` — the frame
  ring this rides on. **Blocker:** modifier-ring design assumes
  127 has landed.
- `issues/113-combat-targeting-and-firing.md` — likely first
  consumer (damage multipliers, accuracy bonuses).
- `issues/completed/114-coroutine-pool-library.md` — task pool
  iter4.5 design that this extends.

## Open questions for review

- **Where do modifier kinds live — library or game?** A pool
  library that knows about `MOD_SPEED` is a leaky abstraction;
  but a game-side wrapper that re-implements the ring buffer
  duplicates the frame-ring's data structure. Probable answer:
  the ring lives in the library (parameterized by intent size
  and kind count); the kind enum and the apply-sweep callback
  live in game code.
- **Sharding.** Should each worker thread have its own intent
  buffer that the apply sweep concatenates, or is a single
  per-frame buffer with a brief lock acceptable? Profile
  decides; default to single buffer.
- **Reset semantics.** Do modifiers reset every frame, or do
  buffs maintain state via continuous re-emission, or is there
  a separate "duration" field per intent? Cleanest: reset every
  frame, and an active buff is a periodic task that re-emits
  its intent every frame for its duration. Aligns with 127's
  periodics-as-`pool_spawn_in(1, ...)` idiom.
- **Float determinism.** If sums are taken in
  `(target_id, kind)` order, two clients running the same input
  log produce bit-identical modifiers. But if the per-frame
  intent list is sharded per worker and concatenated in worker
  finish order, summation order varies. The apply sweep must
  sort first if multiplayer determinism matters.

## Why this is a documentory and not yet a regular issue

- The first concrete consumer hasn't been identified. Designing
  for hypothetical future requirements is exactly what the
  user's CLAUDE.md cautions against.
- Issue 127 isn't landed yet; the data structure this rides on
  doesn't exist on disk.
- The pattern was described in a single paragraph during a doc
  review. It deserves a real review pass before being elevated
  to scoped, named, scheduled work.

When promoted to `issues/`, this file should be re-read in light
of whatever its first consumer needs and edited to match — the
"Suggested implementation steps" and "Open questions" sections
in particular will firm up around the consumer's actual
requirements.
