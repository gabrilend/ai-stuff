# Issue 601: Asset Loader and Resolution

**Phase:** 6
**Type:** Implementation
**Priority:** Critical
**Dependencies:** Phase 1 (MPQ parser), Phase 5 (render interface)

---

## Current Behavior

No unified asset loading system exists. The MPQ parser can extract files, but there's no:
- Standard directory structure for assets
- Resolution system to find assets by ID or path
- Caching layer for loaded assets
- Support for server-provided asset directories

## Intended Behavior

A unified asset loader that:
1. Loads assets from direct paths within map/server directories
2. Supports all asset types (textures, models, audio, UI, fonts)
3. Provides a simple API: `asset_loader.get("path/to/asset.png")`
4. Caches loaded assets in memory with configurable limits
5. Works seamlessly with both WC3 maps (MPQ-embedded) and WoW servers (directory-based)

### Directory Structure

```
~/.world-edit-engine/
├── maps/                          # WC3 custom maps
│   └── {map_hash}/
│       ├── map.w3x                # Original map file
│       └── extracted/             # Extracted assets (cached)
│           ├── textures/
│           ├── models/
│           └── sounds/
└── servers/                       # WoW server assets
    └── {server_id}/
        ├── manifest.lua           # Asset index
        ├── textures/
        ├── models/
        ├── sounds/
        └── ui/
```

### API Design

```lua
local loader = require("assets.loader")

-- Initialize for a map or server
loader.init({
    source = "map",              -- or "server"
    path = "/path/to/map.w3x",   -- or server asset directory
})

-- Load assets by path
local texture = loader.get("textures/terrain/grass.png")
local model = loader.get("models/units/footman.mdx")
local sound = loader.get("sounds/combat/sword_hit.wav")

-- Check if asset exists
if loader.exists("textures/custom/logo.png") then
    -- ...
end

-- Preload assets (non-blocking)
loader.preload({"textures/ui/frame.png", "sounds/ui/click.wav"})

-- Get memory usage
local stats = loader.stats()
-- { loaded_count = 42, memory_mb = 128.5, cache_hits = 1000 }

-- Clear cache
loader.clear()
```

## Suggested Implementation Steps

1. Create `src/assets/` directory structure
2. Implement `src/assets/loader.lua` with core API
3. Implement `src/assets/cache.lua` for memory management
4. Implement `src/assets/extractors/` for each asset type:
   - `texture.lua` - PNG, TGA, BLP loading
   - `model.lua` - MDX/M2 loading (stub for Phase 6, full impl later)
   - `audio.lua` - WAV, MP3, OGG loading
   - `ui.lua` - Font, frame loading
5. Integrate with existing MPQ parser for WC3 maps
6. Create tests for each component

## Acceptance Criteria

- [ ] Assets load from WC3 map MPQ files via direct path
- [ ] Assets load from server directories via direct path
- [ ] Memory cache with configurable size limit
- [ ] Cache eviction when limit exceeded (LRU)
- [ ] `loader.stats()` reports accurate memory usage
- [ ] Graceful handling of missing assets (returns nil + error, triggers fallback)
- [ ] Tests for loader, cache, and each extractor

## Related Documents

- `src/mpq/` - Existing MPQ parser
- `docs/render-architecture.md` - Render system integration
- Issue 602 - Wire-frame fallback (handles missing assets)

## Notes

- Model loading (MDX/M2) may be stubbed initially - full implementation depends on render system needs
- BLP texture format is Blizzard-specific; we may need a decoder or require PNG conversion
- Audio loading should integrate with whatever audio library Phase 5 chooses
