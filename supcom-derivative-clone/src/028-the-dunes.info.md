# 028-the-dunes

Raises the field from a seed.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

The field is the whole map: one height per cell and a water line, plus the few
things derived from the heights once so nothing derives them again. This file
raises it from a seed and a table of shape parameters, checks it can be played
on, and prints it as text. Two machines given the same seed and parameters raise
the same field to the last bit, which is what lets a match be sent as a number.

A cell's height is a pure function of the seed and the cell's own coordinates:
every layer's value at a lattice point is a thirty-two-bit hash of seed, layer
and point (MurmurHash3's finaliser, using only `bit`-library operations and a
split multiply, so C's `uint32_t` arithmetic gives the same bits), blended
between the four surrounding lattice points with a smooth-step weight. No stream
is drawn from, so no draw order can change the field.

The height of cell (x, y), with `H` the dune height and the shares from `SHAPE`:

    swell    = layer 1 at (x, y) / (dune_wavelength * swell_wavelength)
    ridge    = layer 2 at the cell turned by the ridge angle, divided by
               dune_wavelength across the crest and dune_wavelength * ridge_stretch
               along it, then folded: 1 - |2 * ridge - 1|
    rough    = layer 3 at (x, y) / rough_wavelength
    causeway = 0.5 - |x - y| / size
    height   = H * (swell * (swell_share * swell + ridge_share * ridge)
                    + causeway_share * causeway)
             + roughness * H * rough_share * rough

Hydrocarbon is a fourth, unsmoothed layer: a land cell holds a pocket when its
hash is below `hydrocarbon_rate`.

Each team's start cell is the highest land cell in its start region -- a square
`start_share` of the side, in the corner at (0, 0) for team one and mirrored
through the centre for team two -- the first in row order on a tie. The causeway
lifts the ground along the diagonal between the two start corners and lowers it
toward the other two, which is what makes nearly every seed playable: without it
a third of seeds drowned a start corner or cut the two apart.

The validator refuses rather than repairs. `raise` validates before it returns,
so a field that fails is never handed out.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `raise(parameters, seed)` | the shape table below; a whole-number seed | a validated field record, or raises naming the problem |
| `validate(field)` | a field record | nothing; raises naming the cell, the team, or the region that is wrong |
| `dump(field)` | a field record | one string, one line per row, top row first: `~` water, `. : - = + * # % @` land by ninths of the height above the water, `1` and `2` the start cells |
| `index(field, x, y)` | a field; a cell's integer coordinates from zero | the one-based array index of that cell -- the only place this is computed |
| `cell_of(field, x, y)` | a field; a position in cell units | the cell the position stands in, held to the field's edge |
| `coarse(field, region)` | a field; cells per region side | the number of regions per side, and the tallest height in each region, row-major |
| `RECORD` | | the field record's layout, below |
| `PARAMETERS` | | the names of the required parameters |
| `SHAPE` | | the shape ratios, below |

The shape parameters, every one required and refused by name when missing:

| Parameter | Type | Meaning |
| --- | --- | --- |
| `size` | integer | cells per side, at least two |
| `dune_height` | double | `H` above |
| `dune_wavelength` | double | cells between dune crests, above zero |
| `roughness` | double | how strong the fine surface is |
| `water_line` | double | every cell below it is water |
| `hydrocarbon_rate` | double | the share of land cells holding a pocket |

The validator's refusals:

- a height that is absent or not a number, naming the cell's index and coordinates;
- a hydrocarbon entry that is not zero or one, naming the cell;
- water over the whole field;
- a start cell outside its start region, or a start region with no land;
- start cells not joined by a path over land (a four-neighbour flood fill);
- a coarse region without a tallest height.

## Data structures it owns

The field record. Lists are Lua arrays, one-based and row-major, because the
field is never written after it is raised.

| Field | Type | Holds |
| --- | --- | --- |
| `size` | integer | cells per side; the field is square |
| `height` | double per cell | the ground |
| `water_line` | double | every cell below it is water |
| `hydrocarbon` | integer per cell | one where the ground holds bonus energy, zero elsewhere |
| `region` | integer | cells per side of one coarse region |
| `regions` | integer | coarse regions per side |
| `tallest` | double per region | the highest cell in each region, for the sightline's coarse pass |
| `start_x`, `start_y` | integer, two each | each team's starting cell |

`SHAPE`, the ratios that make a dune field out of the parameters:

| Ratio | Value | Meaning |
| --- | --- | --- |
| `swell_wavelength` | 2.5 | the swell's wavelength, in dune wavelengths |
| `swell_share` | 0.6 | the swell's share of the dune height |
| `ridge_share` | 0.4 | the ridges' share |
| `ridge_stretch` | 3 | how much longer a crest is than the gap between crests |
| `ridge_angle_sin`, `ridge_angle_cos` | 0.5, 0.866 | the ridges lie thirty degrees across the field |
| `rough_wavelength` | 2 | cells between bumps of the fine surface |
| `rough_share` | 0.1 | the fine surface's share, before `roughness` |
| `causeway_share` | 0.5 | how much the diagonal between the start corners is lifted |
| `start_share` | 0.25 | a start region's side, as a share of the field's |
| `region` | 8 | cells per side of a coarse region |
