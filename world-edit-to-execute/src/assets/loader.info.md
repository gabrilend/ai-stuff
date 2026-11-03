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
| `L:reload(path)` | a path | reads it again as `get` would; the new value and its source, or nil, the message and `true` when the old value was kept in the cache (issue 606) |
| `L:wants(path)` | a path | true when it is loaded, or was looked for and not found |
| `L:file_changed(dir, rel)` | a pack's folder (`pack.dir`) and a file within it that was written, added or removed | the asset's key, and whether the change matters (wanted, and no pack above has it); keeps that pack's file list right |
| `L:reindex()` | — | reads every pack's file list again; the cache is kept |
| `L:push_layer(name, dir)` | a name and a folder | puts its files before every pack's (source `"layer:NAME"`) for one game; how many files it has; what it holds is read again (issue 609) |
| `L:pop_layer(name)` | a layer's name | takes it off; what it served is read again from the packs; true when it was on |
| `loader.key_of(path)` | a path | its key: lower case, forward slashes |

### The renderer's calls (issue 606a)

The same calls `assets.open`'s handle answers, so `gpu.lua`, `ground.lua`,
the map viewer and the editor can be handed a loader and draw the
player's packs first.

| Function | Takes | Gives |
|----------|-------|-------|
| `L:texture(path)` | a texture path | `{width, height, rgba}` or nil; a path with no extension, or a `.tga` nobody has, is tried again as `.blp` |
| `L:model(path)` | a model path (`.mdl`, `.mdx` or none) | the parsed `.mdx`, or nil |
| `L:table(path)` | a stock table's path | the handle's table (packs hold art, not tables); nil without a handle |
| `L:model_for(kind, id, variation, object_data)` | as the handle's | the handle's own `model_for`, run with the loader as `self`, so the model is looked up packs first; an error without a handle |
| `L:scale_for(kind, id, object_data)` | as the handle's | the same, for its scale |

One difference from the handle: a file with no extension is decoded only
under its `.blp` name; the handle also tried the bare name, guessing its
format from its first bytes.

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
