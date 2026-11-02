# shd.lua

Reads `war3map.shd`, the shadow map: the shadows the editor bakes onto the
ground, one byte per 32 x 32 world-unit cell, on the pathing map's grid
(issue 119). None of the 16 test maps has any shadow in it.

## File

No header: width x height bytes, row 0 the south edge, each row west to
east; 0x00 no shadow, 0xFF shadow. The size is not in the file: it comes
from the terrain (`wpm.size_for`) or the pathing map's header.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `parse(bytes, width, height)` | the file, and the grid's size if known | a shadow map; raises when the size is given and the file's length disagrees, or only one of the two is given |
| `map:shadowed(x, y)` | a cell, from 0 at the south-west | true or false; nil outside the map or when read without a size |

## Result fields

| Field | Meaning |
|-------|---------|
| `width`, `height` | as given (nil when not) |
| `cells` | the bytes |
| `shadowed_cells` | how many bytes aren't 0x00 |
| `odd_bytes` | how many are neither 0x00 nor 0xFF (counted as shadow, not refused) |
