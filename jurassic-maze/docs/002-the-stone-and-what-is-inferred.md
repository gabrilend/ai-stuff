# The Stone And What Is Inferred

The entire world is one array of 32-bit integers, one per cell of a rectangular
grid. Everything else in this project is derived from that array or moves around
on top of it.

## The cell, and the column above it

Divide the ground into a grid of square cells, `width` cells one way and `depth`
cells the other. Above each cell rises a **column**: a vertical stack of slots,
each slot one layer tall, each slot either stone or air.

The column is stored as **one unsigned 32-bit integer**. Bit `L` of that integer
is 1 when layer `L` of that column is stone, and 0 when it is air. Layer 0 sits
on the ground; layer 31 is as high as the world goes.

| Thing | Type | Meaning |
| --- | --- | --- |
| `width` | integer | cells along the x axis |
| `depth` | integer | cells along the y axis |
| `layers` | integer, at most 32 | how many of the bits are allowed to be used |
| `column[i]` | unsigned 32-bit integer | the stack above cell `i`, one bit per layer |
| `i` | integer | `x + y * width`, x and y counting from 0 |

The array is allocated once, at world creation, at `width * depth` entries, and
never reallocated. There is no growing, no inserting, and no table of tables.

## Why a bitmask and not a height

A picture of stacked stone can be stored as a **height** — one small number per
cell saying how tall the pile is. That is simpler, and for the reference picture
it is sufficient, because in that picture no corridor ever passes over another.

It is rejected anyway, for one reason: a height cannot describe a hole. A height
says the pile is solid from the ground up to `h`, and that is a promise the
program can never break. The moment anything in this project wants a tunnel
bored through a wall, a bridge over a corridor, a chamber with a ceiling, or a
dungeon at all — and [the delve](021-the-delve.md) wants all four — a height has
to be thrown away and every piece of code that read one has to be rewritten.

A bitmask costs three more bytes per cell than a height does. On a 256 by 256
maze that is 192 kilobytes against 64, both of which fit in a modern processor's
last-level cache with room to spare, so the difference is not measurable in
anything anybody would notice. The bitmask buys the tunnel, and it buys it now,
before there is code that assumes it is impossible.

The height representation survives as a **special case**: a column whose bits
are `1` from bit 0 up to bit `h-1` and `0` above is exactly a pile of height
`h`. The generator produces only columns of that shape today. Nothing depends on
it, and a test asserts that nothing does.

## What "inferred" means

A cell whose column is `0b00000111` has stone in layers 0, 1 and 2. Three
blocks. The program will draw the **top face** of the block in layer 2, and it
will draw whichever **side faces** of those three blocks are exposed to air in
the neighbouring column. It will never draw or consider the blocks in layers 0
and 1 from above, or the inside of any of them, because none of that is visible
and none of it can be stood on or bumped into.

This is not an optimisation applied afterwards. There is no representation of a
block as an object anywhere in the program to optimise away. **A block is a set
bit; a face is a disagreement between two neighbouring bits.** Nothing is ever
allocated for either.

The consequences worth knowing:

- A maze of 256 by 256 by 8 has 524,288 stone blocks in it and the program never
  builds a list of them. It builds a list of the surfaces, which is far smaller.
- Two adjacent columns that are identical have no faces between them, so a large
  solid mass costs nothing extra to draw.
- There is no way to ask "which block is this" because the question has no
  answer. Ask instead which cell and which layer, which are two integers.

## Surfaces: the derived thing everything actually uses

Nothing walks on a bit. Things walk on **surfaces**, and a surface is defined
precisely:

> Layer `L` of column `i` is a surface when bit `L` of `column[i]` is 1 and bit
> `L+1` is 0.

In words: the top of a stone block with air above it. A column with a tunnel
through it has two surfaces — the floor of the tunnel and the roof of the
structure above it. A column that is entirely air has none. A column that is
solid to the top of the world has none either, which is correct: there is
nowhere on it to stand.

Finding surfaces is one bit operation per column. Given `c = column[i]`, the
surfaces are the set bits of `c & ~(c >> 1)`. Every set bit in that result is a
layer whose bit is 1 and whose neighbour above is 0, which is the definition
above, evaluated for all 32 layers at once.

That expression is the single most load-bearing line in the project and it is
worth reading twice. `c >> 1` slides the column down by one layer, so bit `L` of
the shifted value is what used to be bit `L+1`. Complementing it gives a 1
wherever the layer above was air. Anding with the original keeps only the layers
that were stone. What is left is exactly the standable tops.

The surface set for every column is computed once, when the maze is generated,
and stored in a parallel array `surfaces[i]`, also one 32-bit integer per cell.
It is recomputed only when the stone changes, which today is never and in the
delve will be when a golem walks through a wall.

## Headroom

Standing on a surface is not enough; a body also has to fit. **Headroom** at
layer `L` of column `i` is the number of consecutive air layers starting at
`L+1`. A body with a height of 2 layers needs headroom of at least 2.

Headroom is not stored. It is counted on demand from the column, which is a
handful of shifts, and it is only ever asked about for the specific cell a body
is trying to enter. Storing it would mean maintaining it, and it changes
whenever the stone does.

## What this array is not

**It is not a list of walls.** A wall in the picture is a place where a tall
column stands next to a short one. There is no wall object, no wall list, and no
wall identity. Code that wants to know whether something is blocked compares two
columns; see
[standing somewhere and going elsewhere](004-standing-somewhere-and-going-elsewhere.md).

**It is not where bodies are stored.** Bodies live in their own arrays and know
which cell they are in. The stone does not know what is standing on it. Asking
"who is on this cell" is a question for the body store's spatial index, not for
this array.

**It is not a table of tables.** `column` is one flat array indexed by
`x + y * width`. Slicing it across a thread pool is a pair of integer bounds. An
array of rows would be a pointer chase, and every sweep over the maze — the
surface computation, the renderer's culling pass, the generator's carving pass —
is exactly the kind of independent per-cell arithmetic that wants to be split
across cores without anybody thinking hard about it.

## Related documents and tools

- [Carving the maze](003-carving-the-maze.md) — how the bits get set
- [Standing somewhere and going elsewhere](004-standing-somewhere-and-going-elsewhere.md) —
  the rule for whether two surfaces are connected
- [Drawing a pile of stones](007-drawing-a-pile-of-stones.md) — how faces become pixels
- `./run-tests` — the invariants that hold the representation to the above
