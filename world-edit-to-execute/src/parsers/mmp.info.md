# mmp.lua

Reads `war3map.mmp`, the minimap's icons: gold mines, neutral buildings
and players' start points on the map's preview (issue 119).

## File

int32 version (0), int32 count, then count entries of 16 bytes: int32 icon
type, int32 x, int32 y, then the colour's blue, green, red and alpha
bytes.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `parse(bytes)` | the file (string) | `{version, icons, by_kind}`; raises on an unknown version, a negative count, or a length that isn't the header plus 16 bytes an icon |

## An icon

| Field | Meaning |
|-------|---------|
| `type` | the number in the file |
| `kind` | `"gold_mine"` (0), `"neutral_building"` (1), `"player_start"` (2), or `"unknown"` for any other (kept, not refused) |
| `x`, `y` | on the 256 x 256 minimap, 0 at the left and the **top**; the minimap shows the playable area (the map less the margins in `war3map.w3i`) |
| `color` | `{r, g, b, a}`, 0-255: a start point's is its player's colour |

`by_kind` counts the icons of each kind.
