# 034-the-body-store

Flat arrays, a free list, generation counters, and the spatial buckets.

Read this page rather than the source.

## What it is for

A body is an integer. It is not a table, it is not an object, and there is
nowhere in the program you can hold one in your hand. Body twelve is the twelfth
entry of every array.

Two reasons, and the second decides it: the move pass touches six fields out of
thirty and an array of tables would drag the other twenty-four through cache
alongside them; and **slicing a flat array across a thread pool is a pair of
integer bounds**, where slicing an array of tables is a pointer chase.

The full field list is in
[a body and what it carries](../docs/011-a-body-and-what-it-carries.md); the
authoritative one is `M.FIELDS` in the source, and the store is built from it, so
adding a field is adding a row and no constructor can forget to zero one.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `new(capacity, cells)` | integers | the store, allocated once |
| `spawn(store)` | | an id and its generation. **Raises** when full rather than growing. |
| `kill(store, id)` | | returns the slot to the free list |
| `is_valid(store, id, generation)` | | the only sanctioned way to follow a stored id |
| `set_locomotion(store, id, row)` | | moves it between rosters, in constant time |
| `join_roster` / `leave_roster` | | the halves of that, if a caller needs them apart |
| `reindex(store, footprint_of)` | | rebuilds the spatial buckets |
| `for_each_in(store, cell, fn)` | | every body in one cell |
| `for_each_near(store, width, x, y, fn)` | | the nine-cell neighbourhood |

## Nothing is ever nil

Empty is the integer zero, and body zero does not exist and never will, so
`partner == 0` reads as "nobody" without ambiguity. A nil check is a question
about whether some earlier code did its job, and that question belongs in a
validator at load time rather than in the inner loop.

`spawn` zeroes **every** field. A slot that kept its old partner or its old
velocity hands them to whoever moves in next, and the resulting body is fighting
somebody who has never heard of it, at a speed it never accelerated to.

## Generations

Every slot carries a counter bumped when the slot is reused, and any stored id is
followed only after `is_valid`. One comparison. It is what stops a fencer
duelling the stranger who moved into its dead opponent's slot — which does
happen, is entirely silent, and looks from the outside like a body attacking
somebody at random.

## Rosters

One contiguous array of ids per locomotion row, so the move pass hands a range to
a thread pool rather than walking every body asking what kind it is. Maintained
by swap-remove, in constant time, on the rare event of a body changing how it
moves rather than on the common one of it moving.

## The spatial buckets

A counting sort over cell index: two linear sweeps and a prefix sum into arrays
that were allocated once. No lists, no tables, nothing allocated per tick.

Rebuilt rather than maintained incrementally, for two reasons. An incrementally
maintained index can be subtly wrong for a while and nobody can say since when.
And the renderer reads these same buckets to draw bodies in the right order, so
they have to be exactly right at the moment the frame is drawn.

The property that makes the population a knob rather than a cliff — bounded work
per body — depends on bodies being **spread out**. A hundred of them in one cell
puts them all in one bucket and every question about them is quadratic again, on
the tick where things are already going badly. That is what `largest_bucket` is
in the report for.
