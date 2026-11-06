# 202 — The Field Is A Grid Of Cells

| | |
| --- | --- |
| Phase | 2 — Bodies on the field |
| Blocked by | 101 |
| Blocks | 205, 301, 305 |
| Files | `src/005-battlefield.lua` |
| Reads | `docs/datapath-battle-tick.md` |

## Current behavior

Built in `src/005-battlefield.lua`, with a swap operation added for the
ally-yield rule. Tested in tests/032-bodies-on-the-field.lua.

## Intended behavior

A battlefield is a rectangle of cells, `width` by `height` (configuration),
each one soldier wide. Positions are continuous (a soldier at x = 10.4,
y = 7.9 stands in cell 10, 7); occupancy is by cell: an array of
`width × height` slots, each holding the soldier record standing there or
`false`. (False rather than nil, so the array never has holes and its length
is fixed when it is allocated.)

It answers: which cell a point is in; who holds a cell; whether a cell is
inside the field; claim and release a cell; the soldiers within a radius of a
point (by scanning the cells in the square around it, so the cost depends on
the radius, not on the army size).

The eight compass directions are a table of unit vectors keyed by name, with
"N" pointing toward smaller y (up on the commander's map).

## Suggested implementation steps

1. Allocate the occupancy array at creation; never grow it.
2. Test: claiming a held cell is refused; releasing frees; the radius query
   finds exactly the soldiers within the radius.
