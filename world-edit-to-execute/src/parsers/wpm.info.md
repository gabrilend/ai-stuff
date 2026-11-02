# wpm.lua

Reads `war3map.wpm`, the pathing map: one byte of flags for each 32 x 32
world-unit cell, four cells per terrain cell each way (issue 119).
`demo/wc3map/footprint.lua`'s `parse_wpm` reads through it.

## File

`MP3W`, int32 version (0), int32 width, int32 height, then width x height
bytes: row 0 the south edge, each row west to east.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `parse(bytes)` | the file (string) | a pathing map; raises on a bad start, an unknown version, a size outside 1-2,048 a side, or a length that isn't the header plus width x height |
| `size_for(w, h)` | the terrain's tilepoint counts (`w3e.parse`'s `width`, `height`) | the pathing map's width and height: `(w - 1) * 4`, `(h - 1) * 4` |
| `map:flags(x, y)` | a cell, from 0 at the south-west | the byte, or nil outside the map |
| `map:walkable`, `flyable`, `buildable`, `water`, `blighted` `(x, y)` | a cell | true or false, or nil outside the map |
| `map:counts()` | — | `{cells, NO_WALK, NO_FLY, NO_BUILD, BLIGHT, NO_WATER, UNKNOWN}`: how many cells have each flag |

## Flags (`wpm.FLAGS`)

| Bit | Name | Set means |
|-----|------|-----------|
| 0x02 | `NO_WALK` | ground units can't walk here |
| 0x04 | `NO_FLY` | air units can't fly here |
| 0x08 | `NO_BUILD` | nothing can be built here |
| 0x20 | `BLIGHT` | blighted ground |
| 0x40 | `NO_WATER` | land (clear: water) |
| 0x80 | `UNKNOWN` | set on cliff faces and the map's edge; no published meaning |

0x01 and 0x10 are never set by the editor.
