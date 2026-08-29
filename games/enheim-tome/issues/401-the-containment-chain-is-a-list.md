# 401 — The Containment Chain Is a List

| | |
| --- | --- |
| Phase | 4 — The Places |
| Blocked by | 201 |
| Blocks | 402, 403, 404, 408 |
| Reads | [the places of the city](../docs/003-the-places-of-the-city.md) |
| Open questions | — |

## Current behavior

Blocks exist. Nothing contains them and nothing is contained by them.

## Intended behavior

A place's containment is **a list of the levels it actually has**, walked from the
outside in. Never a record with a field per level.

```
   a block in the old city      a block beyond the wall
   ────────────────────────     ───────────────────────
   group     the city           group     the city
   quadrant  north-east         district  the river farms
   district  the shambles       block     Millstone Corner
   block     Tanner's Row
```

The second has three levels because **there is no quadrant beyond the wall** — the
wall is what makes a quadrant. Not an empty quadrant. Not a null one. The level
does not exist there.

### Why the shape matters more than it seems

The tempting structure is a record with a slot for every level, one of which is
sometimes empty. Then every piece of code that walks the hierarchy grows a test
for nothing-there, and those tests spread — into the tome, the selection logic,
the filters, the coverage report.

That is testing for absence instead of understanding it, which
[the shape of the code](../docs/010-the-shape-of-the-code.md) forbids for good
reason: **the absence has a cause**, and modelling the cause removes every check.

A list has no holes. Walking it from the outside in visits what is there. Nothing
asks whether a quadrant exists, because nothing assumes one does.

### What a chain is used for

- **Selection.** Hit-testing returns the finest place; the zoom says which
  ancestor to select. See [408](408-the-zoom-picks-the-level.md).
- **The tome.** Showing where you are, outward from here to the largest thing
  containing it.
- **Filters.** A reading may apply at any level, so a filter asks the chain rather
  than assuming blocks.

### It is derived, not stored

A block stores its district; a district stores its quadrant or nothing; a
quadrant stores its group. The chain is assembled by following those, so there is
one place each fact lives and no chain to keep in step when membership changes.

## Suggested implementation steps

1. Give each level's table a parent reference, allowed to be absent — meaning *no
   such level*, not *unknown*.
2. Write one function: given any place, return its chain outward as a list of
   (level, place) pairs.
3. Never write a function that returns "the quadrant of X" as though one always
   exists. Callers walk the chain and take what is there.
4. Distinguish **no such level** from **not yet assigned** in the tables, since
   [309](309-the-coverage-report.md) must tell finished from unstarted.
5. Test both fixture cases: a block inside the wall returning four levels, and one
   outside returning three, with no branch in the caller.

## Related documents and tools

- [The places of the city](../docs/003-the-places-of-the-city.md)
- [The shape of the code](../docs/010-the-shape-of-the-code.md)
