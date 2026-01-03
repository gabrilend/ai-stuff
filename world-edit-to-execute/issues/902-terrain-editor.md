# Issue 902: Terrain Editor

**Phase:** 9
**Type:** Implementation
**Priority:** Critical
**Dependencies:** 901 (Editor core), 105 (W3E parser)

---

## Current Behavior

Terrain can be parsed and rendered (Phase 1, Phase 5) but not edited.

## Intended Behavior

Full terrain editing with feature parity to WC3 World Editor:

### Terrain Tools

| Tool | WC3 Equivalent | Description |
|------|----------------|-------------|
| **Raise** | Raise terrain | Increase height under brush |
| **Lower** | Lower terrain | Decrease height under brush |
| **Plateau** | Plateau | Set area to specific height |
| **Smooth** | Smooth | Average heights in area |
| **Noise** | Noise | Add random variation |
| **Ramp** | Ramp | Create walkable slope between cliffs |
| **Cliff** | Raise Cliff | Create cliff layer (unwalkable) |
| **Water** | Water | Set water level and type |
| **Paint** | Tile Palette | Apply terrain texture |
| **Blight** | Blight | Mark area as blighted (Undead) |
| **Pathing** | Pathing | Override pathability |

### Brush System

```
BRUSH SETTINGS
┌─────────────────────────┐
│ Shape:  ○ Circle  ● Square │
│ Size:   [====|====] 5   │
│ Falloff:[===|=====] 0.3 │
│ Strength:[=====|==] 0.7 │
│ Mode:   [Additive ▼]    │
└─────────────────────────┘

BRUSH PREVIEW
     · · · · ·
   · · ███ · · ·
  · ███████████ ·
  · ███████████ ·
  · ███████████ ·
   · · ███ · · ·
     · · · · ·
```

### Cliff System

```
CLIFF LAYERS
┌────────────────────────┐
│ Layer 2: █████████████ │  ← Higher ground
│          ║           ║ │
│ Layer 1: ▓▓▓▓▓▓▓▓▓▓▓▓▓ │  ← Mid-level
│          ║           ║ │
│ Layer 0: ░░░░░░░░░░░░░ │  ← Ground level
│                        │
│ [+] Add Layer          │
│ [Ramp] Connect Layers  │
└────────────────────────┘
```

### API Design

```lua
local terrain = require("editor.terrain")

-- Brush configuration
terrain.set_brush({
    shape = "circle",      -- circle, square
    size = 5,              -- tiles radius
    falloff = 0.3,         -- edge softness (0-1)
    strength = 0.7,        -- effect intensity (0-1)
})

-- Height editing
terrain.raise(x, y)        -- Apply raise brush at position
terrain.lower(x, y)
terrain.plateau(x, y, height)
terrain.smooth(x, y)
terrain.noise(x, y, amplitude)

-- Cliff editing
terrain.raise_cliff(x, y)  -- Increase cliff layer
terrain.lower_cliff(x, y)  -- Decrease cliff layer
terrain.create_ramp(x1, y1, x2, y2)  -- Connect cliff layers

-- Water
terrain.set_water_level(x, y, level)
terrain.set_water_type(x, y, "shallow")  -- shallow, deep

-- Texture painting
terrain.paint_tile(x, y, "grass_01")
terrain.fill_area(region, "dirt_02")

-- Blight and pathing
terrain.set_blight(x, y, true)
terrain.set_pathing(x, y, {
    walkable = false,
    flyable = true,
    buildable = false,
})

-- Queries
local height = terrain.get_height(x, y)
local tile = terrain.get_tile(x, y)
local cliff = terrain.get_cliff_level(x, y)
```

### Palette

```
TERRAIN TEXTURES
┌─────────────────────────────────┐
│ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ │
│ │Grs│ │Drt│ │Rck│ │Snd│ │Snw│ │
│ └───┘ └───┘ └───┘ └───┘ └───┘ │
│ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ │
│ │Cvn│ │Ice│ │Blg│ │Ash│ │Lva│ │
│ └───┘ └───┘ └───┘ └───┘ └───┘ │
│                                 │
│ Tileset: [Lordaeron Summer ▼]  │
└─────────────────────────────────┘
```

## Suggested Implementation Steps

1. Create `src/editor/terrain/` module structure
2. Implement brush system (shape, size, falloff, strength)
3. Implement height tools (raise, lower, plateau, smooth, noise)
4. Implement cliff system (layer management, ramps)
5. Implement water editor (level, type)
6. Implement texture painting (tile palette, brush application)
7. Implement blight and pathing tools
8. Create terrain palette UI
9. Integrate with undo/redo system
10. Create tests

## Acceptance Criteria

- [ ] All 11 terrain tools functional
- [ ] Brush preview shows affected area
- [ ] Brush settings (shape, size, falloff, strength) work
- [ ] Cliff layers can be raised/lowered
- [ ] Ramps connect cliff layers correctly
- [ ] Water level and type editable
- [ ] Texture painting with palette works
- [ ] Blight and pathing overrides work
- [ ] All operations support undo/redo
- [ ] Real-time preview in viewport

## Related Documents

- `src/parsers/w3e.lua` - Terrain data structure
- Issue 105 - W3E parser
- Issue 502 - Terrain rendering

## Notes

- Terrain modifications should be visible immediately (real-time update)
- Consider LOD for large brushes (performance)
- May want "symmetry" mode for balanced maps
- Tileset selection affects available textures
- Consider "terrain presets" for common patterns (hills, rivers)
