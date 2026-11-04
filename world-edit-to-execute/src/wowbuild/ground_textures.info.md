# ground_textures.lua

Data only, read in an empty environment. For each stock WC3 tileset (keyed
by its letter: `A` Ashenvale ... `Z` Sunken Ruins, 18 in all), the WoW
3.3.5a texture path each of its ground types becomes in a converted map's
ADTs, and the texture its blighted ground uses.

| Field | Type | Meaning |
|-------|------|---------|
| `tilesets[T].name` | string | the tileset's name in WC3's World Editor |
| `tilesets[T].blight` | row | blighted ground on a map whose main tileset is `T` |
| `tilesets[T].grounds[id]` | row | a ground type by its 4-letter id (`Ldrt`; `c<T>c1`/`c<T>c2` are the cliff textures, which maps may paint as ground) |
| `fallback` | row | what an id with no row gets; counted as unmapped in the conversion report |

A row: `name` (string), `wow` (the texture path, backslashes), `rgb` (the
WC3 ground's colour, 0-255 each: a chunk with more than four textures folds
each extra one into the kept texture nearest by this colour), `checked`
(boolean).

**Every row is `checked = false`:** the paths were written from memory of
the 3.3.5a archives and have not been looked up in the owner's client. Only
paths are kept; Blizzard's textures are never copied into the repository or
a build.

Issue: `issues/W02a-terrain-to-adt-writer.md`
