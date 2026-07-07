# 306 — Effect rendering (data viewing)

> Phase 3 · Spell System · what a spell *looks* like — kept behind a wall from
> what it *does*. Datapath:
> [datapath-spell-system.md](../docs/datapath-spell-system.md) Stage 6. Depends
> on: [305a](305a-effect-resolution-core.md) (effect events to view) and Phase 1
> (the renderer to draw through).

## Current Behavior

None of this exists yet. Effects resolve and apply (305a/305b) but nothing draws
them: a fireball damages a zombie invisibly. There is no viewing layer, and — the
point of this issue — the viewing layer must be built as a **separate module**,
not bolted onto resolution.

## Intended Behavior

Rendering is **data viewing**, walled off from generation. Given the same **effect
events** that resolution produced (or a viewing-friendly echo of them), the
renderer draws the flash, the beam, the impact — **through the Phase 1 renderer**.
It **reads**; it never resolves and never mutates. The wall's two guarantees,
stated as acceptance criteria:

- With rendering stubbed, every effect still **happens** (resolution/application
  are untouched by viewing).
- Recorded effect events replayed into the renderer with no caster and no world
  present still **show** — viewing depends only on the events, not on the machinery
  that made them.

Draw routines live in a **view dispatch table keyed by effect kind** — a new
effect's visuals are a new row, matching the resolution and application tables on
the other side of the wall. An effect kind with no view entry draws nothing but
**warns** (a missing visual is a gap to notice, per the warnings-are-errors
discipline), rather than crashing the frame.

An **effect-view descriptor** is a viewing-only record: what to draw, where, for
how long. Transient view state (a beam fading over a few frames) lives here, in
the viewing layer, never leaking back into spell meaning.

## Suggested Implementation Steps

1. Define the **effect-view descriptor** (what/where/how-long) and a small store
   of active views for time-limited visuals.
2. Build the **view dispatch table** keyed by effect kind; write *render effect
   views for this frame*, called from the Phase 1 loop's draw pass.
3. Decide the hand-off from Stage 5: either the renderer subscribes to the same
   effect events, or application emits a viewing-friendly echo. Whichever, keep it
   one-directional — events flow to viewing, nothing flows back. Comment the
   boundary and why.
4. Implement view routines for the first effect kinds from 305a (point/area flash,
   ray/beam from aim, magic-effect landing marker), drawing through Phase 1's
   renderer; isolate any not-yet-final Phase 1 draw surface behind a thin named
   adapter.
5. Provide a **headless/log renderer** variant (draws to a log instead of a
   screen) so tests and the far-future pico-8-style / cassette output path both
   have a seam — proving the renderer is swappable without touching spell meaning.
6. Test the two guarantees above: stub rendering → effects still resolve;
   replayed events → visuals still appear.
7. Add a `.info.md` for the rendering module.

## Data Structures / Functions / Files (by role)

- *Effect-view descriptor* — what/where/how-long (viewing-only).
- *Active-views store* — transient time-limited visuals.
- *View dispatch table* — effect kind → draw routine.
- *Render effect views for this frame* — the viewing core, called by Phase 1's
  draw pass.
- *Log/headless renderer variant* — the swappable-output proof + test seam.
- Files: an effect-rendering module + `.info.md`, kept wholly separate from the
  305 resolution/application modules.

## Related Documents / Tools

- [datapath-spell-system.md](../docs/datapath-spell-system.md) — Stage 6 and "The
  generation / viewing wall."
- [datapath-engine-foundation.md](../docs/datapath-engine-foundation.md) — Phase 1
  renderer and draw pass (planned; owned by Phase 1).
- Blocks: 307 (the demo renders through this).
