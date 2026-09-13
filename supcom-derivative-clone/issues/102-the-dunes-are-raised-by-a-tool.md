# 102 — The dunes are raised by a tool

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 101 |
| Blocks | 103, 110, 111, 112, 203, 602 |
| Reads | [the dunes and the sightlines](../docs/002-the-dunes-and-the-sightlines.md) |
| Open questions | B5 |

## Current behavior

Nothing. The field exists as a description in the dunes document and nowhere
else. The phase 1 test program looks for a source file whose stem is `the-dunes`
and reports its absence by name. The file-making tools from issue 101 are in
place, so the file can be claimed the moment somebody writes it.

## Intended behavior

A tool raises the whole field from a seed and a small table of shape
parameters, and two machines given the same seed and parameters raise the same
field to the last bit. There is no map editor and no hand-drawn map. **Never
raise a field by hand; make the tool that raises fields.**

The field is one record of flat arrays:

| Field | Type | Holds |
| --- | --- | --- |
| size | integer | cells per side; the field is square |
| height | double, one per cell | the ground, row-major |
| water_line | double | every cell below it is water |
| hydrocarbon | integer, one per cell | one where the ground holds bonus energy, zero elsewhere |
| region | integer | cells per side of the coarse grid below |
| tallest | double, one per region | the highest cell in each region, for the sightline's coarse pass |
| start_x, start_y | integer, two each | each team's starting cell |

Cell index arithmetic is written once, in one function, and nothing else in the
project computes it. Every other module asks.

**The noise is a hash of position, not a stream.** Each layer's value at a
lattice point is a hash of the seed, the layer number, and the point's integer
coordinates, smoothed between lattice points by bilinear interpolation. A cell's
height therefore depends on nothing but the seed and its own coordinates: no
iteration order, no shared generator, and every cell can be raised on a
different worker at once. Three layers are summed — a long low swell, a shorter
ridge-and-trough laid across it at an angle, and a fine roughness — each with an
amplitude and a wavelength from the parameters. Hydrocarbon is a fourth layer
thresholded by a rate parameter, on land cells only.

Starting cells are the highest land cell inside each team's start region, and
the two regions are mirrors of each other across the field's centre, so both
teams begin on equal ground even though the dunes between them are not
mirrored.

**The validator refuses rather than repairs.** It stops, naming what and where,
if: water covers the whole field; either start region holds no land; the two
start cells are not joined by a path over land; or any cell holds something
that is not a number. A field that fails is not returned.

The dump prints the field as text — one character per cell graded by height,
water marked — so the dunes can be looked at before anything can draw them.

## Suggested implementation steps

1. Claim the file with `./new-source-file --summary "Raises the field from a seed." the-dunes`.
2. Write the field record's layout as a table of names and types, and the one
   index function.
3. Write the lattice hash: seed, layer, x, y in, a double in the unit interval
   out, using only thirty-two-bit operations through the `bit` library so the
   handheld's C computes the same value.
4. Write the smoothed layer: lattice spacing from the wavelength, bilinear
   interpolation between the four surrounding lattice points, times amplitude.
5. Write `raise(parameters, seed)`: sum the three layers per cell, apply the
   water line, threshold the hydrocarbon layer on land, place the start cells,
   fill `tallest`.
6. Write `validate(field)` with the four refusals above, the reachability one by
   a flood fill over land cells.
7. Write `dump(field)` returning one string, one line per row.
8. Read the shape parameters from `input/field` in the runner, not here; the
   tool takes a table.
9. Fill the companion with the record's fields and the three exports.

## Related documents and tools

- [The dunes and the sightlines](../docs/002-the-dunes-and-the-sightlines.md)
- [The shape of the code](../docs/013-the-shape-of-the-code.md)
- The test program: [the dunes and the clock](../tests/019-the-dunes-and-the-clock.lua)
- `./new-source-file`, `./compile`

## Still open

- B5: the field's size and the shell's speed together decide how long a shot
  takes to cross the field, and are measured rather than argued.
- Whether the dunes themselves should be mirrored across the centre, and not
  only the start regions. Equal ground at the start is what the sibling
  projects learned to insist on; whether equal dunes everywhere is worth the
  loss of asymmetric routes is a proving-ground question.
