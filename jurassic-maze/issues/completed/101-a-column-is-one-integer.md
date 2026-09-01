# 101 — A Column Is One Integer

| | |
| --- | --- |
| Phase | 1 — The Stone |
| Blocked by | nothing. This is the foundation. |
| Blocks | 102, 104, 105, 106, 107, 108, 201, 202, 304, 305, 602, 704 |
| Reads | [the stone and what is inferred](../../docs/002-the-stone-and-what-is-inferred.md) |
| Open questions | 4 (how big is a maze) — does not block, it is a knob |

## Current behavior

The world is one flat array of unsigned 32-bit integers, `width * depth` entries,
allocated once at creation and never reallocated. Bit `L` of entry `x + y * width`
is set when layer `L` of that column is stone.

Plain Lua tables rather than FFI arrays. The benchmark in step 2 was not needed to
decide it: a whole maze generates and validates in under a tenth of a second at
the default size, which is two orders of magnitude away from anything that would
justify the ceremony. The measurement is still the right way to settle it if the
maze ever gets much bigger, and the accessors are all one-liners, so swapping the
storage underneath them touches one file.

`is_stone` answers for layers outside the range too: below the ground is stone
forever, above the world is air forever. Saying so in one place means no caller
needs a bounds test, and a caller that forgot one gets a sensible answer rather
than a nil.

## Intended behavior

The world is **one flat array of unsigned 32-bit integers**, `width * depth`
entries, allocated once at creation and never reallocated. Entry `x + y * width`
is the vertical stack above cell `(x, y)`: bit `L` is set when layer `L` of that
column is stone, clear when it is air.

The index is `x + y * width` and not `y + x * depth`. That is not arbitrary —
it makes the array's memory order identical to the renderer's correct
back-to-front draw order, so the hottest loop in the program walks memory
forwards. See [the projection](../../docs/006-the-isometric-projection.md).

A bitmask rather than a height per cell. A height cannot describe a hole, and
the moment anything wants a tunnel, a bridge, or a ceiling, every piece of code
that read a height has to be rewritten. Three extra bytes per cell buys that
now, before there is code assuming it is impossible. The generator produces only
*height-shaped* columns — bits contiguous from zero — and a test asserts that,
so the day something else appears, somebody finds out.

Nothing in this file knows what a maze is, what a body is, or that a screen
exists. It is storage and bit arithmetic.

## Suggested implementation steps

1. Write the constructor: takes width, depth and a layer count of at most 32;
   returns a table holding the dimensions and the column array. Refuse a layer
   count above 32 with a message, rather than silently truncating — a maze that
   quietly lost its top four layers is a maze whose validator will report
   something baffling.
2. Decide plain Lua tables against LuaJIT FFI `uint32_t` arrays. Measure both
   with a throwaway benchmark that sweeps a hundred thousand columns doing the
   surface computation from issue 102. Keep the benchmark marked deprecated for
   one commit if it has no further use, so it appears in the record once.
3. Write the accessors: index from x and y, x and y from index, is-stone at a
   layer, set and clear a layer. All of them one-liners, all of them folded.
4. Write `height_shaped(column)` — whether the set bits are contiguous from bit
   zero — for the validator to use.
5. Write `top_of(column)` — the highest set bit, or minus one for an empty
   column. Used constantly by the renderer and the generator.
6. Write the test: build a store, set and clear bits at random from a seeded
   stream, assert every accessor agrees with a slow reference implementation
   that uses a plain two-dimensional table of booleans.

## Related documents and tools

- [The stone and what is inferred](../../docs/002-the-stone-and-what-is-inferred.md)
- `./run-tests`

## Still open

Whether the store should be FFI-backed. Step 2 decides it by measurement, not by
argument. Until it is measured, plain tables, because they are what the rest of
the project can read without ceremony.
