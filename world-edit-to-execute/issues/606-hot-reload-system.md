# Issue 606: Hot-Reload System

**Phase:** 6
**Type:** Implementation
**Priority:** Medium
**Dependencies:** Issue 601 (asset loader), Phase 5 (render interface)

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

- [ ] File changes detected within configurable interval
- [ ] Modified textures update in-game without restart
- [ ] Modified audio updates without restart
- [ ] Cache properly invalidated on reload
- [ ] Error in asset doesn't crash engine (shows error, keeps old)
- [ ] Callback fires on successful reload
- [ ] Can pause/resume watching (for batch updates)
- [ ] Works on Linux (inotify preferred, poll fallback)
- [ ] Development-only (disabled in release builds)

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
