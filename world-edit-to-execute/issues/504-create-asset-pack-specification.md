# Issue 504: Create Asset Pack Specification

**Phase:** 5 - Rendering
**Type:** Design/Architecture
**Priority:** Medium
**Dependencies:** 501-create-abstract-render-interface

---

## Current Behavior

No asset loading system exists. All visuals would need to be hardcoded or use primitive placeholders. There's no way for the community to supply visual content.

---

## Intended Behavior

Asset pack specification that:
- Defines manifest format for community asset packs
- Specifies how assets map to WC3 content IDs
- Supports multiple resolution variants
- Enables asset pack stacking (fallback chains)
- Documents requirements for asset creators

**Core Concept:** Like emulator "ROM packs" or game mod systems - community creates visual packs that the engine loads, separate from game logic.

**Manifest Example:**
```lua
-- asset_pack/manifest.lua
return {
    name = "Community Classic",
    version = "1.0.0",
    author = "Community Contributors",
    description = "WC3-inspired placeholder art",

    -- Asset mappings
    units = {
        ["hfoo"] = {  -- Human Footman
            sprite = "units/human/footman.png",
            icon = "icons/human/footman.png",
            size = {64, 64},
            animations = {
                idle = {frames = 4, fps = 8},
                walk = {frames = 8, fps = 12},
                attack = {frames = 6, fps = 15},
            },
        },
        -- More units...
    },

    terrain = {
        ["Ldrt"] = "terrain/dirt.png",
        ["Lgrs"] = "terrain/grass.png",
        -- More tiles...
    },

    ui = {
        command_panel = "ui/command_panel.png",
        minimap_frame = "ui/minimap_frame.png",
        -- More UI elements...
    },
}
```

---

## Suggested Implementation Steps

1. **Design manifest schema**
   - Required fields vs optional
   - Version compatibility rules
   - Validation requirements

2. **Define asset categories**
   - Units (sprites, animations, icons)
   - Buildings (sprites, construction stages)
   - Terrain (tiles, transitions)
   - Effects (particles, projectiles)
   - UI (frames, buttons, fonts)
   - Audio (sounds, music) - future

3. **Create asset loader module**
   ```lua
   -- src/render/assets.lua
   local assets = {}

   function assets.load_pack(path) end
   function assets.get_unit_sprite(unit_id) end
   function assets.get_terrain_tile(tile_id) end
   function assets.set_pack_priority(pack_name, priority) end
   ```

4. **Implement fallback system**
   - Pack priority ordering
   - Missing asset → next pack → placeholder
   - Logging for missing assets

5. **Document asset creation guide**
   - Required formats (PNG, etc.)
   - Size/resolution requirements
   - Animation frame layout
   - Naming conventions

---

## Design Questions for User

1. **Manifest format?**
   - Lua table (easy for modders)
   - JSON (standard, tooling support)
   - YAML (human readable)
   - Custom format

2. **Asset resolution?**
   - Single resolution (simpler)
   - Multiple variants (@1x, @2x)
   - Dynamic scaling

3. **Pack structure?**
   - Flat (all files in directories)
   - Archive (zip/custom format)
   - Hybrid (development vs release)

4. **Copyright handling?**
   - How to clearly document legal status
   - Metadata for attribution
   - License field in manifest

---

## Acceptance Criteria

- [ ] Manifest schema documented
- [ ] Asset loader can read manifests
- [ ] Fallback chain works correctly
- [ ] Missing assets log warnings
- [ ] At least one example pack created
- [ ] Asset creation guide written

---

## Notes

This is critical for the project's legal strategy - community supplies visuals, we supply the engine. The specification must be clear enough for contributors to create compatible packs.

**May need successor issues for:**
- Asset validation tool
- Pack creation wizard/tool
- Hot-reload during development
- Compressed pack format

---

## Sub-Issue Analysis

**Analysis Date:** 2025-12-29

### Recommendation: Keep as Single Issue

This issue does not benefit from splitting. While it has multiple steps, they are tightly coupled:

1. **Documentation-driven**: The manifest schema design (step 1) drives everything else
2. **Linear dependency**: Asset loader (step 3) requires schema (step 1) and categories (step 2)
3. **Small code scope**: The actual code (loader + fallback) is relatively straightforward
4. **Coherent deliverable**: A spec without example packs or docs is incomplete

**Alternative structure if scope grows:**

If implementation reveals complexity, consider:
- 504a: Design manifest schema and document categories
- 504b: Implement asset loader and fallback system
- 504c: Create example pack and asset creation guide

For now, keep as single issue and split only if implementation exceeds expected scope.

---

## Related Documents

- notes/vision (legal philosophy)
- issues/503-*.md (placeholder system this replaces)
- Phase 6 issues (asset system expansion)
