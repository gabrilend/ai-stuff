# 802 -- The layout is a graph

**Phase:** 8, content generation
**Blocked by:** [801](801-a-description-is-validated-first.md)
**Blocks:** [803](803-the-graph-becomes-geometry.md)
**Documents:** [content is generated](../../docs/013-content-is-generated.md)

## Current behaviour

A description is validated and nothing is built from it.

## Intended behaviour

Rooms and corridors as an **abstract graph** — nodes with sizes and edges between
them — before any coordinate exists.

### This is the load-bearing split of the whole phase

Nearly every question worth asking about a generated dungeon is a question about
the graph:

| Question | Against the graph | Against geometry |
| --- | --- | --- |
| Is it connected? | A walk | A flood fill over what, exactly? |
| Is there a loop? | Count edges against nodes | Effectively unanswerable |
| Is the treasure behind the guard? | A path check | Unanswerable |
| Are two rooms adjacent? | An edge | Compare wall coordinates and hope |

**A few lines against the graph; nearly impossible against a pile of segments.**
So the graph is produced first, checked, and only then turned into coordinates.

### Deterministic, from a seed

Same description, same seed, same graph. Through a named stream
(`"dungeon-layout"`), so that adding a draw somewhere else in the project does
not silently produce a different dungeon.

That is what lets a map be **referred to** rather than stored: a description plus
a seed is a few hundred bytes naming a whole dungeon exactly. A GM can hand that
to somebody. A test can assert against it. A bug report can include it.

### Mostly constraints, not dice

"This tavern has a cellar", "the forest has exactly one clearing", "no corridor is
longer than this" are statements in the description, and the generator's job is to
produce something satisfying them, using randomness only where the description
does not care.

**A generator that ignores its description and produces noise is not a generator,
it is a random number visualiser.**

## Suggested implementation steps

1. Define the graph: nodes with a kind and a wanted size, edges with a kind.
2. Grow it from the description — the room count, the connectivity, the required
   features.
3. Write the checks as functions over the graph: connected, loops, required
   features present, no node isolated.
4. Fail loudly if a description cannot be satisfied, naming which constraint.
   **Not "produce something close"** — a dungeon quietly missing the cellar
   somebody asked for is worse than an error.
5. Write the companion `.info.md`.
6. Test: same seed same graph; different seeds different graphs; every constraint
   honoured; an unsatisfiable description refused by name.
