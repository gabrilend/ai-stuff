# 407 — Composition & Outcome Seam for the Dungeon Master (+ Phase Demo)

> Phase 4 **capstone**. Everything below 407 built parts; this issue exposes the
> two edges that make the parts a *phase*: the **builder API / catalogue** the
> [Phase 6 generator](../docs/datapath-dungeon-master.md) composes through, and
> the **outcome bus** that [Phase 5's weak solver](../docs/datapath-ncp-characters.md)
> and Phase 6's capability memory read out of. It also ships the Phase 4 demo.

## Meta

- **Phase:** 4
- **Blocked by:** 401-406 (the capstone binds them into one surface).
- **Blocks:** nothing in Phase 4. Hands the clean seam to Phases 5 and 6.
- **Deliverable:** the Phase 4 demo in `issues/completed/demos/` and one more
  number on the project-root demo launcher.

## Current Behavior

None of this exists yet. The primitives and archetypes (once 401-406 land) can be
built and driven by hand, but there is no single published surface a generator
composes through, no bus the outcomes flow onto, and no demo.

## Intended Behavior

### The COMPOSE edge (what Phase 6 reaches in through)

A single **builder API** over the **primitive catalogue**: the four dispatch
tables (trigger families, mechanism kinds, trap types, archetypes) exposed as a
catalogue the generator queries, plus a `build-a-puzzle` entry that assembles a
validated definition from catalogue parts and **runs the equal-plausibility
auditor** before returning. This is the whole Phase 4 / Phase 6 contract: Phase 4
says "here are the parts and the assembly rules"; Phase 6 says "assemble these,
this many, this hard." Phase 4 must **not** contain any lair-level generation
logic (no puzzle-count choosing, no difficulty modelling, no capability memory) —
that all lives in Phase 6. Guard this line; it is the reason the phase exists.

### The OUT edge (what Phases 5 and 6 read)

An **outcome bus**: the runtime's terminal (and notable non-terminal) outcome
records are published on a small subscribe-able bus. Phase 4 only *emits* — it
never reaches into how a subscriber learns.

- [Phase 5's weak solver](../docs/datapath-ncp-characters.md) subscribes to steer
  the NCP's next guess and to know it has won or lost.
- [Phase 6's capability memory](../docs/datapath-dungeon-master.md) subscribes to
  remember the party "is that potentialed" and re-tune future difficulty.

### The demo (part of the deliverable, not a throwaway)

A runnable demo that **hand-composes a lair fragment** (a few archetype puzzles
wired to traps, standing in for what Phase 6 will later generate) and shows the
phase's statistics and outputs — leaning on the project's "demos show datapoints,
and ideally a visual output" rule:

- Recombine earlier phases where present: a puzzle solved by a Phase 3 magic
  effect, a puzzle solved by Phase 1 platforming, and a lever puzzle — showing
  Phase 4 sitting on top of 1 and 3.
- Foreground the **equal-plausibility** result: for each puzzle, display the
  auditor's per-cue spread between the real solution and the decoys, so a viewer
  can *see* that they "seem suitably equal in likely."
- Report outcomes off the bus: solved/failed, which triggers were tried, which
  red herrings were taken, time and cost.

## Suggested Implementation Steps

1. Create the composition/outcome source file (indexed name + `.info.md`),
   importing the whole Phase 4 stack.
2. Expose the **primitive catalogue** (the four dispatch tables as a queryable
   surface) and the validated `build-a-puzzle` entry that always audits before
   returning.
3. Build the **outcome bus** (publish + subscribe) and wire 404's runtime to
   publish onto it; define the subscriber-facing record shape (from 401) as the
   stable contract for Phases 5 and 6.
4. Write the **demo** (its own script under `issues/completed/demos/`, runnable via
   a simple bash launcher with the hard-coded overridable `${DIR}` convention;
   ensure the `tmp/` symlink exists before writing any demo logs). Hand-compose the
   lair fragment; render the per-puzzle plausibility spread and the streamed
   outcomes; prefer a visual window/HTML output over prose.
5. Register the demo number in the project-root demo launcher (append one more
   selectable phase; do not disturb earlier entries).
6. Tests: the catalogue lists every registered primitive; `build-a-puzzle` refuses
   to return an unbalanced puzzle; publishing an outcome reaches a test subscriber
   with the full record; the demo runs headless-enough to assert its puzzles reach
   their expected verdicts.
7. On completion, update `issues/phase-4-progress.md` and confirm the demo
   demonstrates Phase 4's tools recombined with Phases 1 and 3.

## Related Documents / Tools

- [datapath-puzzles-and-traps.md](../docs/datapath-puzzles-and-traps.md) — the
  "seams (where phases touch)" section (COMPOSE and OUT edges).
- Consumers: [dungeon master](../docs/datapath-dungeon-master.md) (COMPOSE +
  capability memory), [ncp characters](../docs/datapath-ncp-characters.md) (weak
  solver). Upstream: all of 401-406.
