# Issue 602: Wire-frame Fallback Renderer

**Phase:** 6
**Type:** Implementation
**Priority:** High
**Dependencies:** Phase 5 (render interface), Issue 601 (asset loader)
**Blocks:** 608, W03

---

## Current Behavior

No fallback visuals exist when assets are missing. The engine would either:
- Crash on missing asset
- Show nothing (invisible objects)
- Display error texture (not implemented)

When creating a new blank map, there's nothing to show.

## Intended Behavior

**Where wire-frames are drawn (2026-11-04).** In two places, each with its
own renderer. This issue is the **editor's**: world-edit-to-execute's Lua
renderer, which the editor keeps (the owner: "the lua renderer is only for
the editor, not the client"). The **player's** wire-frames are the W
client's, in C, as the last step of its asset lookup (its issue 105a, step
4). The owner: "The wire-frame rendering should be in the custom-client for
when we don't have a model, but that should be only for when the map
doesn't provide one, or when the map provides one that's from a
proprietary source and the viewer/player doesn't have access to it."
Asked whether the editor draws them too: "Wire-frame too."

Both follow the same lookup order: the user's own packs, the map's own
files, the user's Blizzard install if they plugged it in, the project's
baseline model set (made by the asset forge, W05-W06), then the wire-frame.
So a wire-frame means nothing at all matched. Playing a map is the W
client's (issue 913), so this project's map viewer, where play happened
until now, needs no wire-frames of its own once it retires; the editor
does.

A wire-frame/debug rendering mode that:
1. Displays geometric shapes with placeholder colors when assets are missing
2. Shows grid lines for terrain when no terrain textures exist
3. Provides useful visual debugging information
4. Serves as the default view for blank/new maps

### Visual Language

```
TERRAIN (no texture):
┌─────────────────────────────────┐
│  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  │  Grid lines (dark gray)
│  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  │  Vertices marked with dots
│  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  │  Height shown via line thickness
└─────────────────────────────────┘

UNITS (no model):
    ╭───╮
    │ U │     Colored box with type indicator
    ╰───╯     U = Unit, B = Building, H = Hero
      │       Line to ground (shows height)
      ▼

DOODADS (no model):
      *       Star/asterisk for doodads
     /|\      Tree-like shape for trees
      │       Color indicates doodad type

REGIONS:
┌ ─ ─ ─ ─ ┐   Dashed rectangle outline
│  REGION │   Label with region name
└ ─ ─ ─ ─ ┘   Semi-transparent fill

SELECTION:
╔═════════╗   Bold outline for selected
║ UNIT    ║   Different color (green/yellow)
╚═════════╝
```

### Color Coding

| Object Type | Wire-frame Color |
|-------------|------------------|
| Ground unit | Blue |
| Flying unit | Cyan |
| Building | Brown |
| Hero | Gold |
| Tree | Green |
| Doodad | Gray |
| Item | Purple |
| Region | Orange (transparent) |
| Camera | Red |
| Waypoint | Yellow |

### API Design

```lua
local fallback = require("assets.fallback")

-- Register fallback renderer for object types
fallback.register("unit", function(unit, render_ctx)
    local color = fallback.color_for(unit.type)
    render_ctx:draw_box(unit.position, unit.size, color)
    render_ctx:draw_label(unit.position, unit.type_id)
end)

-- Check if using fallback
if fallback.is_active("textures/terrain/grass.png") then
    -- Asset is missing, fallback in use
end

-- Toggle debug overlay
fallback.set_debug_overlay(true)  -- Show extra info (IDs, coordinates)

-- Force fallback mode (even if assets exist)
fallback.force_wireframe(true)    -- Useful for debugging
```

## Suggested Implementation Steps

1. Create `src/assets/fallback.lua` with registration API
2. Implement primitive renderers:
   - Box (units, buildings)
   - Cylinder (for round objects)
   - Star/tree shapes (doodads)
   - Grid (terrain)
   - Dashed rectangles (regions)
3. Implement color scheme mapping
4. Implement label rendering (object IDs, names)
5. Integrate with asset loader (trigger fallback on missing asset)
6. Add debug overlay toggle (coordinates, handles, etc.)
7. Create visual test demonstrating all fallback types

## Acceptance Criteria

- [ ] Missing textures show colored placeholder instead of crash/invisible
- [ ] Missing models show wire-frame box with type indicator
- [ ] Terrain without textures shows grid with height visualization
- [ ] Regions display as labeled dashed rectangles
- [ ] Color scheme distinguishes object types at a glance
- [ ] Debug overlay shows object IDs and coordinates when enabled
- [ ] Force-wireframe mode works even when assets are available
- [ ] Blank/new maps display a usable grid

## Related Documents

- Issue 601 - Asset loader (triggers fallback)
- `docs/wow-client-bridge.md` ("Who sees a wire-frame", "Our own models are the default")
- W client: `/mnt/mtwo/games/azeroth-core/custom-client/issues/105a-loose-overlays-and-asset-resolver.md` (the player's wire-frames, step 4)
- Issue 913 - Test map opens the W client (where playing happens now)
- `docs/render-architecture.md` - Render primitives
- Phase 5 issues - Render interface

## Notes

- Wire-frame mode should be fast - it's the fallback, shouldn't slow things down
- Consider adding "bounding sphere" visualization for collision debugging
- Labels should use a built-in bitmap font (no asset dependency)
- This mode doubles as a useful map editor visualization
