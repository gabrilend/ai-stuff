# 305 — Effect resolution & world application (umbrella)

> Phase 3 · Spell System · what a spell *does*, and who it happens to. Datapath:
> [datapath-spell-system.md](../docs/datapath-spell-system.md) Stages 4–5.
> Depends on: [304a](304a-casting-method-contract-and-registry.md) (a resolved
> cast to expand). Split into
> [305a](305a-effect-resolution-core.md) and
> [305b](305b-magic-effect-world-application-seam.md).

## Current Behavior

None of this exists yet. A resolved cast (from 304a) knows the spell, caster, and
aim, but nothing turns it into consequences, and nothing applies those
consequences to the Phase 1 world or exposes them to Phase 4 puzzles.

## Intended Behavior

Two deliberately separated concerns turn a resolved cast into world change:

- **305a — effect resolution (generation, pure):** expand a resolved cast into
  neutral **effect events** — "deal N fire damage along this ray", "emit magic-
  effect FIRE here". Pure: reads the cast and queryable world state, returns
  events, mutates nothing, draws nothing. This is the closed, headlessly-testable
  heart of the spell verb.
- **305b — world application (the outward seams):** apply effect events to the
  Phase 1 world/monsters, **and** publish **magic-effects** to the seam Phase 4
  mechanisms subscribe to — the vision's "apply certain magic effects to certain
  puzzles ... create a mechanism that provides the solution" (notes/vision
  ~118-119).

The split matters: resolution must never mutate or draw, so it can be tested with
no world and no renderer; application owns all mutation and all seam-publishing.
Both use **dispatch tables keyed by effect kind** — a new effect is a new table
row on each side, never a new branch.

## Suggested Implementation Steps

See sub-issues. Build 305a's pure resolver first (testable in isolation against
the stub aim source), then 305b's application/seam on top; confirm the same
effect events can be applied to a world *and* observed on the magic-effect seam
without resolution knowing either exists.

## Related Documents / Tools

- [datapath-spell-system.md](../docs/datapath-spell-system.md) — Stages 4–5.
- [305a](305a-effect-resolution-core.md), [305b](305b-magic-effect-world-application-seam.md).
- Blocks: 306 (rendering reads effect events), 307 (demo), and Phase 4 (subscribes
  to the magic-effect seam).
