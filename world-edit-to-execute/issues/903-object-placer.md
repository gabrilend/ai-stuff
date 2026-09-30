# Issue 903: Object Placer

**Phase:** 9
**Type:** Implementation
**Priority:** Critical
**Dependencies:** 901 (Editor core), 110 (Object parsers), Phase 2 (Game objects)

---

## Current Behavior

Objects can be parsed and rendered but not placed or edited in an editor.

## Intended Behavior

Full object placement with feature parity to WC3 World Editor:

### Object Types

| Type | Parser | Description |
|------|--------|-------------|
| **Units** | war3mapUnits.doo | Heroes, creeps, workers, buildings |
| **Doodads** | war3map.doo | Trees, rocks, props, decorations |
| **Items** | war3mapUnits.doo | Droppable items on ground |
| **Destructibles** | war3map.doo | Breakable objects (crates, barrels) |

### Placement Modes

```
PLACEMENT TOOLS
┌────────────────────────────┐
│ ● Single     ○ Brush       │
│ ○ Line       ○ Fill        │
│ ○ Random     ○ Pattern     │
└────────────────────────────┘

Single: Click to place one
Brush:  Paint objects in area
Line:   Place along a path
Fill:   Fill region with objects
Random: Random placement with density
Pattern: Grid/custom patterns
```

### Object Palette

```
UNITS
┌─────────────────────────────────────────┐
│ Player: [Player 1 (Red) ▼]             │
├─────────────────────────────────────────┤
│ Race: [Human ▼]  Filter: [________]    │
├─────────────────────────────────────────┤
│ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐       │
│ │ 🧑  │ │ ⚔️  │ │ 🏹  │ │ 🏇  │       │
│ │Peas │ │Foot │ │Rifle│ │Knigh│       │
│ └─────┘ └─────┘ └─────┘ └─────┘       │
│ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐       │
│ │ 🧙  │ │ 🦅  │ │ 🔨  │ │ 🏰  │       │
│ │Sorc │ │Grph │ │Mortr│ │Town │       │
│ └─────┘ └─────┘ └─────┘ └─────┘       │
│                                         │
│ [Custom Objects...]                     │
└─────────────────────────────────────────┘

DOODADS
┌─────────────────────────────────────────┐
│ Category: [Trees ▼]                     │
├─────────────────────────────────────────┤
│ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐       │
│ │ 🌲  │ │ 🌳  │ │ 🌴  │ │ 🪨  │       │
│ │Pine │ │Oak  │ │Palm │ │Rock │       │
│ └─────┘ └─────┘ └─────┘ └─────┘       │
│                                         │
│ [x] Random rotation                     │
│ [x] Random scale (80%-120%)            │
│ [ ] Random variation                    │
└─────────────────────────────────────────┘
```

### Selection and Manipulation

```
SELECTION TOOLS
┌────────────────────────────┐
│ ● Select    ○ Marquee      │
│ ○ Add       ○ Subtract     │
└────────────────────────────┘

TRANSFORM
┌────────────────────────────┐
│ Position:                  │
│   X: [1234.56] Y: [789.01] │
│                            │
│ Rotation:  [45.0°]         │
│ Scale:     [100%]          │
│                            │
│ [Copy] [Paste] [Delete]    │
│ [Duplicate] [To Clipboard] │
└────────────────────────────┘

MULTI-SELECT
┌────────────────────────────┐
│ Selected: 15 objects       │
│                            │
│ [Align X] [Align Y]        │
│ [Distribute] [Group]       │
│ [Rotate All] [Scale All]   │
└────────────────────────────┘
```

### API Design

```lua
local placer = require("editor.placer")

-- Select object type from palette
placer.set_object_type("hfoo")  -- Footman

-- Placement mode
placer.set_mode("single")  -- single, brush, line, fill, random, pattern

-- Place object at position
local obj = placer.place(x, y, {
    player = 1,
    rotation = 45,
    scale = 1.0,
})

-- Selection
placer.select(obj)
placer.select_all()
placer.select_in_rect(x1, y1, x2, y2)
placer.deselect_all()

-- Get selection
local selected = placer.get_selection()

-- Transform selected
placer.move_selection(dx, dy)
placer.rotate_selection(angle)
placer.scale_selection(factor)

-- Alignment
placer.align_selection("left")  -- left, right, top, bottom, center_h, center_v
placer.distribute_selection("horizontal")  -- horizontal, vertical

-- Clipboard
placer.copy_selection()
placer.paste()
placer.delete_selection()
placer.duplicate_selection()

-- Brush placement
placer.set_brush({
    density = 0.5,
    random_rotation = true,
    random_scale = {0.8, 1.2},
    spacing = 64,
})

-- Query
local objects_at = placer.query_position(x, y, radius)
local obj = placer.pick(screen_x, screen_y)  -- Raycast from camera
```

### Unit Properties

```lua
-- Unit-specific properties
unit.player = 2          -- Owner
unit.level = 5           -- Hero level
unit.items = {...}       -- Carried items
unit.abilities = {...}   -- Learned abilities
unit.gold_cost = 0       -- Cost override
unit.mana = 100          -- Starting mana
unit.hit_points = 500    -- Starting HP
unit.acquirable = false  -- Can be acquired (for items)
unit.waygate_dest = nil  -- For waygates
```

## Suggested Implementation Steps

1. Create `src/editor/placer/` module structure
2. Implement object palette UI (units, doodads, items)
3. Implement single placement mode
4. Implement selection system (click, marquee, add/subtract)
5. Implement transform tools (move, rotate, scale)
6. Implement brush placement mode
7. Implement alignment and distribution
8. Implement clipboard operations
9. Implement unit-specific properties editor
10. Integrate with undo/redo
11. Create tests

## Acceptance Criteria

- [ ] All object types placeable (units, doodads, items, destructibles)
- [ ] Palette shows objects filtered by race/category
- [x] Player assignment works for units
- [ ] All placement modes work (single, brush, line, fill, random)
- [x] Selection works (click, marquee, shift+click)
- [x] Transform tools work (move, rotate, scale)
- [ ] Multi-select alignment/distribution works
- [x] Clipboard operations work
- [ ] Unit properties editable
- [x] All operations support undo/redo
- [ ] Object preview follows cursor before placement

## Related Documents

- `src/parsers/unitsdoo.lua` - Unit placement data
- `src/parsers/doo.lua` - Doodad placement data
- `src/gameobjects/` - Game object classes
- Issue 110 - Object data parsers

## Notes

- Placement should respect pathing (optional snap-to-valid)
- Consider "smart placement" for buildings (auto-align to grid)
- Doodad randomization important for natural-looking forests
- May want "object lock" to prevent accidental selection
- Consider "layers" for organizing objects

## Implementation Notes

*(2026-09-30, first pass)*

`src/editor/objects.lua` holds every object as one kind of record.

- **Doodads and destructibles** (war3map.doo).
- **Placed units** (war3mapUnits.doo; a new one copies the bytes of a unit of its kind).
- **Units the script makes with literal CreateUnit calls:**
  - moving one writes new numbers into its call;
  - deleting takes the call out ("set u = null", else DoNothing());
  - found by position in the script, which DAoW's protected script allows.
- **Units placed in the editor:** made by an added EditorPlacedUnits function called at the end of main.
- **Selection and editing:** click, Shift-click and box select; move (drag), turn, scale (doodads) and delete, each one undo step; copy and paste at the pointer.
- **Palettes:** the map's own doodad and unit types, in pages; a player for new units.
- **Checked end to end:** DAoW 5.4b saved with a script unit moved, one deleted and a footman placed. Its own script then made the moved unit at its new place, didn't make the deleted one, and made the footman.

**Not done yet:**
- **Placing:** items, and brush, line, fill and random placement.
- **Palette:** filtering by race and category.
- **Arranging:** alignment and distribution.
- **Unit properties:** hit points, items, abilities.
- **Preview:** a model or design following the pointer (there's a ring).
