# 305a — Effect resolution core (data generation)

> Phase 3 · Spell System · sub-issue of
> [305](305-effect-resolution-and-world-seam.md). The pure heart of the spell
> verb. Datapath: [datapath-spell-system.md](../docs/datapath-spell-system.md)
> Stage 4. Depends on:
> [304a](304a-casting-method-contract-and-registry.md) (resolved cast) and
> [302](302-spell-template-data-model.md) (the effect a template references).

## Current Behavior

None of this exists yet. Spell templates (302) reference an effect by key, but no
code turns "this spell, cast this way, aimed there" into a concrete description of
what should happen. This is the missing centre of the whole phase.

## Intended Behavior

A single **pure** function takes a resolved cast and returns a list of **effect
events** — the neutral, world-agnostic description of what should happen. It:
- reads the resolved cast (spell, caster, aim, any method parameters like charge
  level) and whatever **queryable** world state it needs (positions, geometry),
- returns **effect events** and nothing else — it does **not** mutate the world
  and does **not** draw. Purity is the point: the entire spell verb becomes
  testable with no running world and no renderer.

An **effect event** is one neutral thing-that-happens: its **kind** (fire damage,
wall-raise, magic-effect emission, ...), its **magnitude/parameters** (possibly
scaled by spell level from 301 and by charge level from 304b), and its **target
region** — a point, a **ray from the aim** (303), or an area.

Effect **kinds live in a dispatch table keyed by kind**: each kind maps to a
small resolver that expands the cast into that kind's events. Adding an effect is
adding a row. An effect kind referenced by a template but absent from the table is
**refused loudly** at resolution — no silent no-op fallback.

## Suggested Implementation Steps

1. Define the **effect-event structure** (kind, magnitude/parameters, target
   region) as plain data.
2. Build the **effect-kind dispatch table** and its lookup; write the top-level
   *resolve a cast into effect events* function that routes through it.
3. Implement a first handful of effect kinds spanning the shapes the datapath
   names: a point/area effect, a **ray-from-aim** effect (consuming the 303 aim),
   and a **magic-effect emission** kind (whose application in 305b is the Phase 4
   seam). Scale magnitude by level (301) and, where sensible, by charge (304b).
4. Keep resolution **side-effect-free**: pass world state in as a queryable
   argument, never reach out and mutate. Leave a comment at the boundary saying
   why (the generation/viewing + generation/application wall).
5. Write headless tests: feed resolved casts (built with the 303 stub aim source)
   and assert the exact effect events out — including that all three 304b methods
   on one spell yield the same events (modulo charge/aim).
6. Add a `.info.md` for the resolver and the effect-event shape.

## Data Structures / Functions / Files (by role)

- *Effect event* — kind, magnitude/parameters, target region.
- *Effect-kind dispatch table* — kind → resolver.
- *Resolve a cast into effect events* — the pure generation core.
- Files: an effect-resolution module + `.info.md`; effect-kind resolvers as data/
  functions registered into the table, kept separate from the routing core.

## Related Documents / Tools

- [datapath-spell-system.md](../docs/datapath-spell-system.md) — Stage 4.
- [301](301-spell-path-and-level-taxonomy.md) — level scales magnitude.
- [303](303-cast-request-and-aim-intent-seam.md) — aim shapes ray/area regions.
- Blocks: 305b (applies the events), 306 (renders the events).
