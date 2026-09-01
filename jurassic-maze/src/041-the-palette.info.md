# 041-the-palette

Three tones, a per-cell mottle, and every colour in the project.

Read this page rather than the source.

## What it is for

**The only file that names a colour.** Anything drawn anywhere asks here for its
shade, so the whole thing can be re-lit by editing one file.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `stone(cell, layer, layers, face)` | | three numbers in zero to one |
| `mossy_top(cell, layer, layers, mossiness)` | | the same, greened |
| `creature(kind_name, team)` | | a creature's colour, with its team as a tint |
| `TONE`, `TOP`, `LEFT`, `RIGHT` | | the three face orientations and their multipliers |
| `STONE_LOW`, `STONE_HIGH`, `MOSS`, `OUTLINE`, `SKY`, `CREATURE`, `TEAM` | | |

## Three tones and no lighting model

Every face in this world has one of exactly three orientations, and which three
was decided when the projection was chosen. So the shading is a lookup with three
entries. A lighting model here — normals, dot products, a light vector — would be
arithmetic performed to rediscover a constant.

## The mottle is a hash, not a stream

The per-cell brightness offset comes from a hash of the cell index rather than
from a named stream. Three reasons, and the third decides it: it costs no memory,
it is identical on every frame and every run so the stone does not shimmer, and
**the renderer must not be able to move the simulation**. A stream read here would
make the world depend on how many cells happened to be on screen.

## Moss marks floor

Only floor gets it, never a wall top. In the reference picture the greenery is in
the walked places and the crevices; putting it on the wall tops as well flattens
everything into one texture and the moss stops marking anything.

## Higher is paler

A tint by layer, which separates a wall from the wall behind it when both would
otherwise be the same tone, and reads as the upper terraces being more weathered.
Without it a maze twenty layers deep is a field of one grey with invisible seams.

## An unnamed creature is magenta

`creature` returns magenta for a kind it does not know. A colour nobody chose is
the fastest way to see that a creature has been added to the table and not to the
palette.
