# 1001 — A Plan Is Polygons At Elevations

| | |
| --- | --- |
| Phase | 10 — The Tracing Table |
| Blocked by | 901 |
| Blocks | 1002, 1003 |
| Reads | `src/077-the-scene-file.info.md`, `src/069-the-map.info.md` |
| Open questions | two, at the bottom |

## Current behavior

A world is either generated or written as plates and stairs in Lua. Neither can
describe a world that already exists as a picture, which is what the reference
painting is: a mountain covered in a maze that somebody drew, with a real shape,
which the simulation has to agree with.

Tracing that by typing rectangles is not the job. The painting is **forty to two
hundred structures**, and a structure is a shape with corners rather than a
rectangle.

## Intended behavior

A **plan** is what a person draws over a picture, and it is the source that a
scene is built from.

| | |
| --- | --- |
| **A vertex** | a point in the world, at cell coordinates that may be fractional |
| **A structure** | a closed loop of vertices, at one elevation, with a tag |
| **The header** | the picture it is drawn over, the footprint in cells, and the five numbers that map the world onto the picture |

A structure is flat. That is not a limitation of the format, it is what the
painting is made of: every surface in it is either a flat top or the vertical side
of a higher flat top, and the sides follow from the tops without being drawn.

**Where two structures overlap, the higher wins**, and the order they were drawn
in does not matter. A block standing on a plaza is the plaza and then the block,
rather than the plaza cut into a ring — and somebody adding a structure must not
have to work out where in the list it belongs. That is the same rule the plate
format uses and for the same reason.

**Cells no structure covers are holes**, and they are reported rather than filled.
A plan of a painting is finished when nothing is uncovered, so the count of
uncovered cells is the progress bar, and inventing a height for them would hide
exactly the thing somebody needs to see.

### Rasterising

A cell belongs to a structure when the structure's outline encloses the cell's
centre. Even-odd, which handles a shape with a hole in it without being told that
holes exist.

## Suggested implementation steps

1. Write the reader, the writer and the rasteriser in one file, and make the test
   a round trip plus a known shape. A square of four vertices covering nine cells
   is an answer nobody has to think about.
2. Keep the plan and the scene as separate files with the plan as the source. A
   scene is rasterised and cannot be edited back into shapes; throwing the shapes
   away after the first save would make every later correction a retrace.
3. Report the uncovered cells from the rasteriser rather than from the tool, so
   that the number is the same one a headless run would produce.

## Related documents and tools

- [1003](../1003-tracing-is-clicking-corners.md) — the thing that writes one
- `src/077-the-scene-file.info.md` — what a plan is rasterised into

## Open questions

**One. What are the tags for?** A structure carries a short word, and the obvious
uses are marking a shape as something other than a flat top — a vertical face
traced by accident, a staircase whose treads should be interpolated rather than
flat. Which words mean what is not decided, and the format deliberately does not
care: it stores the word.

**Two. Should a staircase be a structure?** A flight is a run of flat tops one
layer apart, and tracing each tread as its own polygon is a dozen structures where
one would do. A structure with two elevations and a direction would cover it. Not
answered, and the flat version works.
