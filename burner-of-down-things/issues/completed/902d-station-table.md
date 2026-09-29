# 902d — The station table

The fourth piece of 902.

## Current Behavior

Built. `src/093-the-station-table.lua`'s `TABLE` holds only stations
actually built today (currently one: 807a's `table` word); `find(rows,
input_shape, output_shape)` is generic and works against any rows of that
shape, which is how 905a's shape graph was proven against it before this
piece existed (strategems/build-to-the-shape-not-the-neighbor.md — its
first example). A shape no row covers returns `nil` plus the names of any
partial matches, never silently dropped. Checked by
`tests/094-checking-the-station-table.lua`, which also proves the real
`TABLE` now feeds `shape_graph.build` (083) unchanged. 902b and 902c
(structured and remaining types) are not yet built; `find` itself does not
need them.

## Intended Behavior

The station table: one row per station — name, the shape it takes, the
shape it gives, and the command or step that runs it (a studio end, a
machine step, running a program) — and a shape-matching function.

## Suggested Implementation Steps

1. The table's rows for the stations that already exist (804's `.png`
   end, 807's `.txt` end, …). Done, for what exists so far: 807a's `table`
   word; more rows join as 804/806/808 land. 2. The matching function.
   Done: `093-the-station-table.lua`'s `find`. **Test:** `integer-array +
   text → image` finds the chart station (exercised with a fixture, since
   the real chart station is not built); a shape no station gives is said
   plainly, not silently dropped. Done.

## Blocked by

- 902c
- 804
- 807
