# Issue 601: Asset Loader and Resolution

**Status:** Completed 2026-11-02 (`src/assets/loader.lua`, `src/assets/cache.lua`).

**Phase:** 6
**Type:** Implementation
**Priority:** Critical
**Dependencies:** Phase 1 (MPQ parser), Phase 5 (render interface)
**Blocks:** 602, 604, 605, 606, 608, W03

---

## Current Behavior

No unified asset loading system exists. The MPQ parser can extract files, but there's no:
- Standard directory structure for assets
- Resolution system to find assets by ID or path
- Caching layer for loaded assets
- Support for server-provided asset directories

> **2026-09-26 note: decisions made since this was written (2026-01-08).**
> - **Models are looked up in this order** (issue 516, owner): the player's
>   own override for that model path, then the model the map asks for
>   (imported into the map, or stock from the player's own WC3 install),
>   then a placeholder shape, counted. Nothing Blizzard-made is shipped.
>   Other asset types likely follow the same shape; not yet decided.
> - **The player's own install is a source**, read at run time: stock
>   object data (issue 112) and stock models (516). This issue's two sources
>   (map, community packs) need that third one.
> - **Files between people move over rmail** (609); files from public
>   sites are fetched by 603 and stored by hash (604, 605). Nothing is
>   "server-provided".
> - **The chooser's design comes from W03** (override, then source, then
>   placeholder, counted), shared by WC3 and WoW models once it exists.
> - **The folder name disagreed** (`~/.world-edit-engine/` here,
>   `~/.wc3-engine/` in the docs). Settled: the player data folder is
>   `player-data/` in the project, moved by `config/player-data.lua` (open
>   question 1). This issue and both docs now say so (2026-11-02).

## Intended Behavior

A unified asset loader that:
1. Loads assets from direct paths within map and community asset pack directories
2. Supports all asset types (textures, models, audio, UI, fonts)
3. Provides a simple API: `asset_loader.get("path/to/asset.png")`
4. Caches loaded assets in memory with configurable limits
5. Works seamlessly with both WC3 maps (MPQ-embedded) and community asset packs (directory-based)

### Directory Structure

In the player data folder: `player-data/` in the project, unless
`config/player-data.lua` moves it (`src/assets/player_data.lua`). Since
604/605, a map's or pack's folder holds links into `player-data/blobs/`,
where each file is stored once, and is named by the map or pack.

```
player-data/
├── maps/                          # WC3 custom maps
│   └── {map_hash}/
│       ├── map.w3x                # Original map file
│       └── extracted/             # Extracted assets (cached)
│           ├── textures/
│           ├── models/
│           └── sounds/
└── asset-packs/                   # Community asset packs
    └── {pack_id}/
        ├── manifest.lua           # Asset index
        ├── textures/
        ├── models/
        ├── sounds/
        └── ui/
```

### API Design

```lua
local loader = require("assets.loader")

-- Initialize for a map or asset pack
loader.init({
    source = "map",              -- or "asset-pack"
    path = "/path/to/map.w3x",   -- or asset pack directory
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

- [x] Assets load from WC3 map MPQ files via direct path
- [x] Assets load from server directories via direct path (asset packs: nothing is server-provided)
- [x] Memory cache with configurable size limit
- [x] Cache eviction when limit exceeded (LRU)
- [x] `loader.stats()` reports accurate memory usage (exact for images and bytes; a model is charged its file size, decision 4)
- [x] Graceful handling of missing assets (returns nil + error, triggers fallback)
- [x] Tests for loader, cache, and each extractor

## Related Documents

- `src/mpq/` - Existing MPQ parser
- `docs/render-architecture.md` - Render system integration
- Issue 602 - Wire-frame fallback (handles missing assets)

## Notes

- Model loading (MDX/M2) may be stubbed initially - full implementation depends on render system needs
- BLP texture format is Blizzard-specific; we may need a decoder or require PNG conversion
- Audio loading should integrate with whatever audio library Phase 5 chooses
- (2026-09-26) Model reading is now issue 116 and BLP1 textures issue 117 (in the shared texture reader); the two notes above are answered there.

## Open Questions

1. ~~Which folder holds the player's data?~~ Answered 2026-09-26: **the
   project directory**, "though they can config file it somewhere else". So
   the default is a folder inside the project, and a config file can point
   it anywhere. The `~/.world-edit-engine/` tree above and the
   `~/.wc3-engine/` paths in `docs/wc3-engine-architecture.md` and
   `docs/roadmap.md` are to be rewritten to that when this issue is built.
   (Rewritten 2026-11-02, ahead of the loader.)
   Still to choose: the folder's name inside the project, and where the
   config file itself lives.
   **Chosen 2026-11-02 while building 604:** `<project>/player-data/`, moved
   by `<project>/config/player-data.lua` returning `{ folder = "PATH" }`
   (both git-ignored); `src/assets/player_data.lua` reads it. The docs'
   paths are rewritten (2026-11-02).

---

## Implementation Notes

**Date:** 2026-11-02

- **`src/assets/loader.lua`:** `loader.new{map | assets, packs, data,
  limit_mb}` and `get`, `read`, `exists`, `preload`, `stats`, `clear`,
  `close`. The map and the install are read through the existing
  `assets.open` (`src/assets/init.lua`, issue 522d), so the loader adds the
  player's packs in front of them and the cache around them rather than a
  second way to read either.
- **`src/assets/cache.lua`:** the byte-limited LRU cache.
- **`src/tests/test_cache_loader.lua`** (34 tests): the cache's order,
  eviction, oversize entries, replacement and counts; on a test map, an
  override pack's texture comes before the map's (found under another case
  and slash direction), the map's when no pack has it, a model parsed, a
  sound kept as bytes, a missing file and an unreadable one each reported
  with where it looked and counted apart, a cache hit, memory equal to the
  pixels, file and bytes kept, a small limit evicting and reloading,
  `preload`, misses forgotten by `clear`, and the default pack order.
  `test_assets`, `test_ground`, `test_imports` and `test_dedup` still pass.

### Decisions made while building

1. **The order is packs, map, install**, the 2026-09-26 decision (516):
   the player's own overrides first, then the model or texture the map
   asks for, then the stock one from the player's install. Nothing found
   is nil and a message; the placeholder is 602's to draw.
2. **Asset packs replace server directories.** Nothing is server-provided
   since 2026-09-26; packs live in `<player data>/asset-packs/<name>/`, as
   605 keeps them. Packs are given in priority order; without an order,
   every pack is used, by name, so the result never depends on the order
   a folder lists in.
3. **Paths match without regard to case or slashes**, as the game's do: a
   map asks for `Textures\Footman.blp`, a pack may hold
   `textures/footman.blp`. Each pack's file list is read once, at start and
   on `clear()`.
4. **Memory is charged by what can be measured:** an image its RGBA bytes,
   a file kept as bytes its length, and a parsed model its file's size (a
   Lua table's own size can't be read exactly; the file's size grows with
   it).
5. **One decoder table, not four extractor files.** Textures (BLP, TGA,
   PNG) and models (MDX) decode through the existing readers; everything
   else (sounds, fonts, UI files) is returned as bytes until something
   needs it decoded (sounds wait on the audio library). A standalone
   `.jpg` is returned as bytes too: maps use BLP, and the JPEG reader
   gives components, not RGBA.
6. **`preload` loads at once, in the calling thread.** The loader has no
   thread of its own; a render thread can call it in the background.
7. **A miss is remembered until `clear()`**, so a map naming a missing file
   in every frame doesn't look it up every frame; `clear()` also re-reads
   the packs' lists, so a file added since is found.
8. **The existing callers keep `assets.open`.** The editor and renderer
   read through it today; moving them onto the loader is a change of its
   own, made when the packs matter to them (W03's chooser).
