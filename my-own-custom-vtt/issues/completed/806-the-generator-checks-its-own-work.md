# 806 -- The generator checks its own work

**Phase:** 8, content generation
**Blocked by:** [804](804-furnishing-asks-the-ruleset.md)
**Blocks:** [807](807-the-phase-eight-demo.md)
**Documents:** [content is generated](../../docs/013-content-is-generated.md)

## Current behaviour

The validator checks that a world is **well-formed**. Nothing checks that it is
**what was asked for**.

## Intended behaviour

A second checker, running after generation, comparing the output against the
description that requested it.

### These are different questions

`033-validate` asks "is this a coherent world" — indices in range, polygons
closed, regions nesting. It would happily pass a dungeon with three rooms when
somebody asked for eight.

This asks "is this the world that was described". Room count, required features,
connectivity, size bounds.

**A generator that ignores its description and produces noise is not a generator,
it is a random number visualiser** — and only this check can tell the difference.

### What it checks

| Check | Because |
| --- | --- |
| The room count matches | The most basic promise. |
| Every required feature exists | "This tavern has a cellar" is a statement, not a hope. |
| Everything is reachable | An unreachable room is a room nobody will ever see. |
| Sizes are within bounds | A "small room" forty metres across is a bug in the placer. |
| Nothing overlaps | Two rooms in the same place is a world that looks broken. |

### It fails loudly

Naming which constraint and what was produced instead. **Not repairing** — a
generator that patches its own output is a generator whose output nobody can
predict from its input, which retires the seed.

## Suggested implementation steps

1. Write each check as a function over the description and the finished world.
2. Report all failures together, like the wall in
   [801](801-a-description-is-validated-first.md).
3. Run it in the generator, always, not behind a flag.
4. Run it over a spread of seeds in the test, because a constraint that holds for
   one seed and not for others is exactly what this catches.
5. Write the companion `.info.md`.
6. Test: a satisfied description; a deliberately unsatisfiable one refused by
   name; fifty seeds all satisfying the same description.
