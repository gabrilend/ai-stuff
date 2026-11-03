# hotreload.lua

Change a file in one of the player's asset packs and see it without a
restart (issue 606). A development tool: nothing watches unless a tool
makes a hot-reloader.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `hotreload.new(L, opts)` | an `assets.loader`; `poll_interval` (seconds, default 0.5, the poll watcher's), `quiet` (seconds a file must stay unchanged, default 0.1), `backend` (`"inotify"` or `"poll"`; default inotify where Linux allows it), `on_reload(path, value, source)`, `on_error(path, err, kept_old)`, `clock` (seconds; default the monotonic clock) | a hot-reloader watching the loader's packs |
| `H:poll()` | — (call once a frame) | how many assets were read again |
| `H:reload(path)` | a path | reads it now: the value and its source, or nil and the message (the callbacks are called) |
| `H:reload_all(kind)` | `"textures"`, `"models"`, `"sounds"`, a table of extensions, or nil / `"all"` | how many read, how many failed: every loaded asset of that kind, and every missing one a source now has |
| `H:pause()` / `H:resume()` | — | while paused changes are noted, not read; each is read once after |
| `H:status()` | — | `{enabled, paused, backend, watching, reloads, errors, changes, pending}` |
| `H:close()` | — | stops watching |
| `hotreload.now()` | — | seconds on the monotonic clock (`net/clock.lua`) |

## What is read again

| The changed file | What happens |
|------------------|--------------|
| loaded, and no pack above has it | read again after `quiet` seconds; `on_reload` |
| looked for and not found | read; `on_reload` (the placeholder can go) |
| broken (half-saved, refused by its reader) | the old value stays; `on_error(path, err, true)` |
| removed | the next source's (another pack, the map, the install); with none, the old value stays and `on_error` |
| nothing loaded it, or a pack above hides it | the pack's file list is updated, nothing read |

The callbacks run under `pcall`: an error in `on_reload` is counted and
handed to `on_error`.

## Watchers (`watch/`)

| Module | How | Notes |
|--------|-----|-------|
| `watch/inotify.lua` | Linux inotify through the FFI; read without waiting | every sub-folder watched, new ones too; a queue overflow reports every file |
| `watch/poll.lua` | lists every file (`find -L`) and compares time and size | works anywhere `find` does; follows links |

Both give `W:changes()`: a list of `{dir, rel, gone}` since the last call.

Edit a plain file in a pack. A pack filled by the storage manager holds
links into the shared store (`blobs/`); an editor that writes through such
a link changes the stored file for every map and pack that shares it, and
inotify (watching the pack's folder, not the store) doesn't see it.
Make it the pack's own copy first: `luajit src/cli/storage.lua edit pack
NAME PATH` (604a, where stored files are read-only).

## Onto the screen (606a)

`on_reload` callbacks that put a saved texture into the one already made
for it, by the same texture id:

| Callback | For |
|----------|-----|
| `gpu.on_reload(cache)` (`cache:retexture(path, img)`) | model textures (`assets/gpu.lua`) |
| `ground.on_reload(render, ids, terrain, report)` | the ground's tilesets (`assets/ground.lua`) |

Both need `render.tex_update(id, w, h, rgba)`, which `render/models.c`
doesn't have yet; without it they swap nothing and say so (false). Only
the Lua side is tested (`src/tests/test_renderer_loader.lua`, a fake
renderer); nothing here has been seen on a screen.
