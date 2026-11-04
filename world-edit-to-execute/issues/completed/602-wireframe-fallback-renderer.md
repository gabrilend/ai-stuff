# Issue 602: Wire-frame Fallback Renderer

**Phase:** 6
**Type:** Implementation
**Priority:** High
**Dependencies:** Phase 5 (render interface), Issue 601 (asset loader)
**Blocks:** 602a, 608, W03

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

- [x] Missing textures show colored placeholder instead of crash/invisible
      (`F:texture`; the model renderer already draws grey for a missing texture)
- [x] Missing models show wire-frame box with type indicator
- [x] Terrain without textures shows grid with height visualization
- [x] Regions display as labeled dashed rectangles (no fill: see decision 4)
- [x] Color scheme distinguishes object types at a glance
- [x] Debug overlay shows object IDs and coordinates when enabled
- [x] Force-wireframe mode works even when assets are available
- [x] Blank/new maps display a usable grid

Checked by `src/tests/test_fallback.lua` as shapes, colours and calls;
**not yet seen on a screen** (raylib isn't built where this was made).
Using it in the editor is 602a. (Written 2026-11-02 as "the map viewer
and the editor"; since 2026-11-04 playing is the W client's, so the map
viewer needs none of its own, as this issue's "Where wire-frames are
drawn" says.)

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

## Implementation Notes

**Date:** 2026-11-02

- **`src/assets/fallback.lua`:** `fallback.new{loader, overlay, force,
  has_model}`, `F:build(scene)`, `F:texture`, `F:model`, `F:is_active`,
  `F:register`, `F:set_debug_overlay`, `F:force_wireframe`; `kind_of`,
  `color_for`, `texture` (a checkerboard placeholder), `blank`, `emit`,
  `draw_labels`.
- **`src/demo/fallback/main.lua`:** every shape on a blank map with a hill,
  for the scene viewer (O toggles the overlay). Unseen.
- **`src/tests/test_fallback.lua`** (43 tests): each kind's shape, line
  count, colour and letter; a flyer at fly height with its line down; the
  grid's line and dot counts, heights and widths, and `every`; a unit
  standing on a hill; selection and the overlay; `has_model` and forcing;
  a registered painter; placeholder textures and models through a real
  loader (found, missing, the loader's own misses, forced); painting
  through a recording `render`; labels centred and those behind the
  camera skipped; and the demo scene built and its interface drawn with a
  stand-in renderer.

### Decisions made while building

1. **Shapes are data, painted by what exists.** The renderer already
   paints flat-shaded boxes and quads from Lua (geometry painting, 544a),
   with backface culling off; a line is one thin quad, so no new C (which
   couldn't be built or seen here). The kit's primitive format is reused,
   so `geometry/kit.lua` places them.
2. **One quad per line:** flat for lines along the ground (seen from the
   RTS camera above), upright facing south for vertical edges. A box is 12
   quads; a 128 by 128 map's grid is about 33,000, inside the static
   layer's 400,000. `every` thins a large map.
3. **"Height shown via line thickness":** lines also sit at the ground's
   height, and are up to twice as wide where the ground is 512 high.
4. **Regions have no fill:** geometry painting takes no alpha, and an
   opaque fill would hide the units inside. The dashed outline and the
   name show the region.
5. **Labels use raylib's built-in font** through `render.ui_text`, at
   points `viewer.to_screen` gives: no font asset.
6. **A hero is a type id starting with a capital letter**, WC3's own
   convention (Hpal, Obla); buildings, flyers and trees are flagged by the
   caller from object data.
7. **One fallback per caller (`fallback.new`)**, not module-wide state, as
   with the loader and hot-reload.
8. **The map viewer and editor aren't switched over here** (602a): their
   scenes draw units through the model renderer with 503's placeholder
   shapes; replacing those is a visual change to check on a screen.

**After the editor-and-client split (2026-11-04).** What is built here is
the editor's half of "Where wire-frames are drawn", in the Lua renderer
the editor keeps. Two things in these notes read differently now:

- **The lookup before a wire-frame.** The loader (601) gives packs, the
  map, then the install; `F:model` and `F:texture` draw a placeholder when
  that comes back empty. The owner's order adds the project's baseline
  model set between the install and the wire-frame, so once that set
  exists a wire-frame means none of the four matched. Nothing here
  changes for it: the fallback draws whatever the loader couldn't find.
- **The map viewer** (decision 8, 602a) retires with play moving to the W
  client (913); the editor is where these shapes are drawn.
