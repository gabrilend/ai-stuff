# loader.lua

Any asset by its path (issue 601): the player's asset packs first, then
the map, then the player's own Warcraft III install; cached within a byte
limit (`cache.lua`).

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `loader.new(opts)` | `map` (a path) or `assets` (an `assets.open` handle); `packs` (names, first wins; default every pack in `<player data>/asset-packs/`, by name); `data` (the player data folder); `limit_mb` (default 256); `root`, `install`, `layers` | a loader; an error for a pack or map that isn't there |
| `L:get(path)` | a path as a map names it | the asset (decoded by extension, below) and its source; or nil and a message |
| `L:read(path)` | a path | the file's bytes and its source, not cached; or nil and a message naming where it looked |
| `L:exists(path)` | a path | true when a source has it (nothing decoded) |
| `L:preload(paths)` | a list | how many loaded, and the messages of the rest (loads now, in this thread) |
| `L:stats()` | — | `{loaded_count, loads, memory_bytes, memory_mb, limit_bytes, cache_hits, cache_misses, evictions, missing, failed, packs}` |
| `L:clear()` | — | empties the cache, forgets misses, re-reads the packs' file lists |
| `L:close()` | — | closes the map it opened |

Sources are `"pack:NAME"`, `"map"`, or the install's archive as
`gamedata/chain.lua` names it. Paths match without regard to case or slash
direction.

## What get gives

| Extension | Value | Charged to the cache |
|-----------|-------|----------------------|
| `.blp`, `.tga`, `.png` | `{width, height, rgba}`, top row first | the RGBA bytes |
| `.mdx` | the parsed model (`parsers/mdx.lua`) | the file's size (a Lua table can't be measured exactly) |
| anything else | the file's bytes | their length |

A miss is remembered (and counted in `missing`) until `clear()`; a file
found but refused by its reader is counted in `failed`.
