# Issue 606: Hot-Reload System

**Phase:** 6
**Type:** Implementation
**Priority:** Medium
**Dependencies:** Issue 601 (asset loader), Phase 5 (render interface)
**Blocks:** 606a, 608

---

## Current Behavior

No hot-reload capability exists. Content creators must:
- Close the engine
- Modify assets externally
- Restart the engine
- Navigate back to where they were testing

This creates a slow iteration loop for asset development.

## Intended Behavior

A development-only hot-reload system that:
1. Watches asset directories for changes
2. Automatically reloads modified assets
3. Updates in-game visuals without restart
4. Preserves game state during reload

### Scope

| Asset Type | Hot-Reload Support |
|------------|-------------------|
| Textures | Full - swap in place |
| Models | Partial - may reset animations |
| Audio | Full - swap in place |
| UI layouts | Full - rebuild UI tree |
| Scripts (Lua) | Careful - may affect state |

### Workflow

```
CONTENT CREATOR                    ENGINE
      │                              │
      │   [Modifying grass.png       │
      │    in external editor]       │
      │                              │
      │                              │◀─── File watcher detects change
      │                              │
      │                              ├───▶ Invalidate cache for grass.png
      │                              │
      │                              ├───▶ Reload texture from disk
      │                              │
      │                              ├───▶ Update all references
      │                              │
      │◀─────────────────────────────┤     [grass.png updated in-game]
      │   [Sees change immediately]  │
```

### API Design

```lua
local hotreload = require("assets.hotreload")

-- Enable hot-reload (development only)
hotreload.enable({
    watch_dirs = {
        "./assets/",
        "./mods/my-asset-pack/",
    },
    poll_interval = 0.5,  -- Check every 500ms
    on_reload = function(path)
        print("Reloaded: " .. path)
    end,
    on_error = function(path, err)
        print("Failed to reload " .. path .. ": " .. err)
    end,
})

-- Disable hot-reload
hotreload.disable()

-- Check status
local status = hotreload.status()
-- { enabled = true, watching = 2, reloads = 15, errors = 0 }

-- Manual reload (force)
hotreload.reload("textures/terrain/grass.png")

-- Reload all assets of a type
hotreload.reload_all("textures")

-- Pause/resume (e.g., during batch operations)
hotreload.pause()
hotreload.resume()
```

### File Watching Implementation

Options (in order of preference):

1. **inotify (Linux)** - Kernel-level, instant notification
2. **FSEvents (macOS)** - Native file events
3. **ReadDirectoryChangesW (Windows)** - Native directory monitoring
4. **Polling fallback** - Check mtime periodically

```lua
-- Platform detection
local watcher
if jit.os == "Linux" then
    watcher = require("assets.watch.inotify")
elseif jit.os == "OSX" then
    watcher = require("assets.watch.fsevents")
elseif jit.os == "Windows" then
    watcher = require("assets.watch.windows")
else
    watcher = require("assets.watch.poll")
end
```

## Suggested Implementation Steps

1. Create `src/assets/hotreload.lua` with enable/disable API
2. Implement polling-based watcher (fallback, always works)
3. Implement inotify watcher for Linux (LuaJIT FFI)
4. Integrate with asset loader cache invalidation
5. Implement texture hot-swap (update GPU resources)
6. Implement audio hot-swap
7. Implement UI layout reload
8. Add console overlay showing reload events
9. Create tests (mock file changes)

## Acceptance Criteria

- [x] File changes detected within configurable interval
- [ ] Modified textures update in-game without restart (moved to 606a: the
      new picture reaches `on_reload`; the renderer has no texture update yet)
- [ ] Modified audio updates without restart (moved to 606a: no audio library yet)
- [x] Cache properly invalidated on reload
- [x] Error in asset doesn't crash engine (shows error, keeps old)
- [x] Callback fires on successful reload
- [x] Can pause/resume watching (for batch updates)
- [x] Works on Linux (inotify preferred, poll fallback)
- [x] Development-only (disabled in release builds): nothing watches unless
      a tool makes a hot-reloader; there are no release builds to strip it from

## Related Documents

- Issue 601 - Asset loader (cache invalidation)
- Phase 5 - Render interface (texture updates)

## Notes

- This is **development-only** - production builds should not include file watching overhead
- Consider debouncing: if file changes rapidly, wait for "quiet period" before reloading
- Some assets may require full reload (complex models with skeleton changes)
- Script hot-reload is dangerous - Lua state may become inconsistent. Consider "soft reload" that re-runs initialization
- Could add visual indicator (corner flash) when asset reloads
- May want "reload all" keybind (F5 or Ctrl+R) for manual refresh

## Implementation Notes

**Date:** 2026-11-02

- **`src/assets/hotreload.lua`:** `hotreload.new(loader, opts)` and
  `poll`, `reload`, `reload_all`, `pause`, `resume`, `status`, `close`.
  It watches the loader's asset packs, waits for a changed file to stay
  unchanged for `quiet` seconds, and reads it again through the loader.
- **`src/assets/watch/inotify.lua`:** Linux inotify through the FFI,
  read without waiting; every sub-folder watched, new ones as they appear
  (with the files already in them reported); a queue overflow reports
  every file.
- **`src/assets/watch/poll.lua`:** lists every file with `find -L` and
  compares time and size; the fallback everywhere.
- **`src/assets/loader.lua`:** `reload` (a broken new file keeps the old
  value), `wants`, `file_changed` (keeps a pack's file list right and says
  whether a change matters), `reindex`, `loader.key_of`.
  **`src/assets/cache.lua`:** `peek`.
- **`src/tests/test_hotreload.lua`** (69 tests): the cache's peek; the
  loader's reload and file list; and with each watcher (inotify where
  available), a save read within the interval and the quiet time, read
  once, a broken save keeping the old picture, the next good save read, a
  file nothing loaded and a file a higher pack hides left alone, a lower
  pack's file in use read, a missing file added in a new folder found, an
  override removed falling back and then kept, two quick saves read once,
  pause and resume, by-hand reloads, `reload_all` by kind, an error in the
  caller's callback contained, and closing. `test_cache_loader` still
  passes.

The renderer, sound and UI swaps (steps 5 to 8) are issue
[606a](../606a-hot-reload-swaps-in-renderer-sound-and-ui.md).

### Decisions made while building

1. **One hot-reloader per loader, not a module-wide switch.** The issue's
   sketch had `hotreload.enable()`; a loader is an object (601), so the
   hot-reloader is too, made from the loader whose packs it watches.
2. **It watches the asset packs only.** They are the player's own
   folders and the only source an artist edits; the map is one archive
   and the install is stock. A change to a pack lower in the order than
   one that has the same file changes nothing on screen, so it isn't read.
3. **The game loop drives it (`H:poll()` once a frame).** The engine has
   no threads of its own here; inotify is read without waiting, and the
   poll watcher lists the folders only once per `poll_interval`.
4. **Debounced:** a file is read once it has stayed unchanged for `quiet`
   seconds (0.1), so an editor that saves in several writes is read once,
   at the end.
5. **A broken file keeps the old value**, and so does a removed file with
   no other source left; `on_error` says which (`kept_old`). A file that
   was looked for and missing is read when it appears, so a placeholder
   can be replaced.
6. **Swapping into the GPU, a sound or the UI is the caller's part**, by
   `on_reload(path, value, source)`: the loader hands out values, and
   only the renderer knows which of its textures came from which path.
   The callbacks run under `pcall`, so a mistake there is reported, not
   carried into the game loop.
7. **Development-only by construction:** nothing watches unless a tool
   makes a hot-reloader. There is no release build to switch it off in.
8. **inotify where Linux allows it, else polling.** FSEvents and
   ReadDirectoryChangesW aren't written: the project runs on Linux.
9. **Edit plain files, not links.** Packs filled by the storage manager
   (605) hold links into the shared store; writing through one changes
   the stored file for everything sharing it, and inotify (watching the
   pack's folder) doesn't see it. The poll watcher does (it follows
   links). Making stored files read-only, and a command that turns a link
   into a copy for editing, are in 606a.
10. **Lua script reloading is left out.** The issue marks it dangerous;
    nothing in the loader reads scripts.
