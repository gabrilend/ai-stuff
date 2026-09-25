# map_wrapper.lua

Reads the 512-byte `HM3W` header in front of a Warcraft III map's archive:
the map's name and player count as the game's map list shows them. It isn't
part of MPQ, so StormLib doesn't read it.

| Function | Takes | Gives |
|----------|-------|-------|
| `parse(data)` | the first 512 bytes of a map file (string) | `{map_name (string), map_flags (uint32), max_players (uint32)}`, or `nil` and a reason |
| `read(path)` | a map file's path (string) | the same, read from the file |

`map_name` may be a `TRIGSTR_` reference into `war3map.wts`.
