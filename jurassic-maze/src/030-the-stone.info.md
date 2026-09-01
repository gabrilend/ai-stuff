# 030-the-stone

The column array, the surface bits, and the arithmetic on them.

Read this page rather than the source.

## What it is for

The entire world is one flat array of unsigned 32-bit integers, one per cell.
Bit `L` of entry `x + y * width` is set when layer `L` of that column is stone.
Nothing buried inside a stack is ever represented: a block is a set bit, a face
is a disagreement between two neighbouring bits, and neither is ever allocated.

The full argument is in
[the stone and what is inferred](../docs/002-the-stone-and-what-is-inferred.md).

## The store

| Field | Type | Meaning |
| --- | --- | --- |
| `width`, `depth` | integers | the footprint in cells |
| `layers` | integer, at most 32 | how many bits are in use |
| `cells` | integer | `width * depth` |
| `column[i]` | 32-bit integer | the stack above cell `i`, one bit per layer |
| `surfaces[i]` | 32-bit integer | which layers of that column are standable |
| `version` | integer | bumped when the stone changes. Nothing caches anything derived from the stone yet; the counter is here so the first thing that does cannot be silently wrong. |
| `height[i]` | integer | added by the generator: the plain pile height, for the fast paths that assume one |
| `walkable[i]` | boolean | added by the generator: floor rather than wall |

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `new(width, depth, layers)` | integers | a store. Raises above 32 layers. |
| `index(store, x, y)` / `coords(store, i)` | | the two directions of `x + y * width` |
| `in_bounds(store, x, y)` | | whether a coordinate pair is on the map |
| `is_stone(store, i, layer)` | | below the ground is stone forever, above the world is air forever, so no caller needs a bounds test |
| `set_stone` / `clear_stone` | | one bit |
| `fill_to(store, i, height)` | | make the column a plain pile up to `height` |
| `surfaces_of(column)` | integer | every standable top, as a mask, in three operations |
| `recompute_surfaces(store, first, last)` | | fills the parallel array over a range |
| `is_surface(store, i, layer)` | | one bit test |
| `top_of(store, i)` | | the highest stone layer, or -1 |
| `highest_surface_at_or_below(store, i, layer)` | | the nearest place to stand, looking down |
| `lowest_surface_above(store, i, layer)` | | the same, looking up |
| `headroom(store, i, layer)` | | consecutive air layers above a surface, or `OPEN_SKY` |
| `height_shaped(column)` | | whether the set bits are contiguous from zero |
| `runs_of(column, layers, into)` | | breaks a column into runs of stone, into a reused array |
| `highest_bit(m)` / `lowest_bit(m)` | | five-branch bit searches, no loops |

## Two things worth knowing before changing anything

**`surfaces_of` is `c & ~(c >> 1)`** and it is the most load-bearing line in the
project. Shifting the column down by one puts what was above each layer into that
layer's position; complementing gives a 1 wherever the layer above was air;
anding keeps only the layers that were stone. All thirty-two layers at once, no
loop, no branch — and it finds both surfaces of a column with a tunnel through it
without knowing tunnels exist.

**`headroom` returns `OPEN_SKY`, not zero, when nothing is above.** Counting only
as far as the last layer treats the top of the array as a ceiling. A surface at
the world's highest layer then reports no headroom, so nothing may step onto it,
so the staircase that reached it is severed, so the maze validates as two pieces
for reasons that have nothing at all to do with the maze. That happened.
