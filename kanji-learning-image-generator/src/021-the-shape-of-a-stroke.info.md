# 021-the-shape-of-a-stroke — info

Measures one stroke: which way it goes, how long it is, how much it bends, whether it ends in a flick, and where in the frame it sits.

For a general: the picture this project describes puts an object along every stroke -- a trunk along a vertical, a fallen log along a low horizontal, a bird on a dot. Choosing which object needs a description of the stroke that is coarser than its coordinates and finer than "it is a stroke". This produces that description.

Every number in the tables below was measured off the archive rather than chosen, and the thing that measured them is still here:

which prints, for every calligraphic class the archive uses, the average direction of strokes in that class and how sharply they turn at the end. The boundaries are set between the clusters that report shows.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `021-the-shape-of-a-stroke.lua` and
run the sweep again.*

## Invocation

```
luajit src/021-the-shape-of-a-stroke.lua --calibrate
```

## What it offers

| | |
|---|---|
| `M.terminal_turn(flat)` | How far the stroke swings in its last stretch, in degrees. |
| `M.measure(flat, class, whole)` | One flattened stroke, described. |
| `M.measure_record(record)` | Every stroke of one character, flattened and measured, in writing order. |
| `M.structural(measured, howmany)` | The strokes that decide the composition, heaviest first. |

### `M.terminal_turn(flat)`

How far the stroke swings in its last stretch, in degrees.

The direction over the final fifth compared against the direction of the very last piece. A stroke that runs straight out to its end scores near zero; one that flicks scores upward of a hundred.

### `M.measure(flat, class, whole)`

One flattened stroke, described.

`class` is the archive's own label for the stroke, or nil. `whole` is the total distance travelled by every stroke of the character, used to work out this one's share; leave it out and the share comes back as nil.

Returns a table holding:   direction   horizontal, vertical, falling_left, falling_right, rising,               reversing   angle       the same thing in degrees, for anything that wants it finer   size        dot, short or long   length      end to end, as a fraction of the frame   travel      the distance actually walked, same units   bend        travel divided by length; one is straight, more is curved   hooked      whether it ends in a flick   turn        how many degrees it swings at the end   place       { column, row, name }   weight      this stroke's share of the character's ink   class       the archive's label, carried through untouched

### `M.measure_record(record)`

Every stroke of one character, flattened and measured, in writing order.

The flattened line is kept alongside the measurement, because everything that consumes a measurement also needs to draw the stroke it describes and flattening it twice would be work done twice.

### `M.structural(measured, howmany)`

The strokes that decide the composition, heaviest first.

By share of ink rather than by end-to-end length, because a long curling stroke occupies more of the picture than a straight one of the same span -- and the picture is what is being composed.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `pick(table, value)` | The first row whose range contains this value. |
| `calibrate()` | The report the tables above were built from. |
| `main(argv)` |  |

## Where it sits

Used by `022-the-structure-field`, `024-the-scene-grammar`, `026-arrows-that-teach-the-order`, `027-test-the-meaning`.
