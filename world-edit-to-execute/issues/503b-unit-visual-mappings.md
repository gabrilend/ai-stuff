# Issue 503b: Unit Visual Mappings

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 503
**Priority:** High
**Dependencies:** 110 (object data), 112 (stock tables)
**Blocks:** 516 (the model chooser needs each unit type's model path)
**Re-cut:** 2026-09-26, from "Unit Visual Mappings"

---

## Current Behavior

A unit's placeholder shape and size are set by the demo scripts, not from
the map. Nothing reads a unit type's art fields.

## Intended Behavior

For each unit type on a map, its visual fields read from object data, the
map's own changes over the stock row (112): the model path (`umdl`), scale
(`usca`), tint (`uclr`, `uclg`, `uclb`), selection circle size (`ussc`),
and whether it is a building. The result, one row per unit type, is what
516's chooser looks up a model by, and what 503a falls back on: a building
gets a cube, a flyer a triangle, the rest by selection size. This replaces
the January plan's hand-made table of sizes and colours.

## Suggested Implementation Steps

1. Read the art fields for every unit type through 112's merged rows.
2. Hand them to the renderer at map load, with each unit's type.
3. Choose the placeholder shape from them.

## Acceptance Criteria

- [ ] Every unit type on a test map has its model path, scale and tint from object data
- [ ] A map's changed scale or tint shows in game
- [ ] Placeholder shapes follow building, flyer and size

---

## Earlier Design (January 2026, for a Lua renderer interface)

Kept as the record; not built as written.

### Current Behavior

No mapping between WC3 unit type IDs and visual representations.

---

### Intended Behavior

Map WC3 unit types to placeholder visuals:

```lua
-- src/render/unit_visuals.lua
local unit_visuals = {}

-- Size categories
local SIZES = {
    tiny = 8,      -- Critters
    small = 12,    -- Workers, light infantry
    medium = 16,   -- Standard units
    large = 24,    -- Cavalry, siege
    huge = 32,     -- Heroes, large monsters
    building = 48, -- Structures
}

-- Unit type mappings
local MAPPINGS = {
    -- Human
    ["hfoo"] = {shape = "circle", size = "medium", race = "human"},   -- Footman
    ["hkni"] = {shape = "circle", size = "large", race = "human"},    -- Knight
    ["hpea"] = {shape = "circle", size = "small", race = "human"},    -- Peasant
    ["Hpal"] = {shape = "circle", size = "huge", race = "human", hero = true}, -- Paladin

    -- Orc
    ["ogru"] = {shape = "circle", size = "medium", race = "orc"},     -- Grunt
    ["opeo"] = {shape = "circle", size = "small", race = "orc"},      -- Peon
    ["Obla"] = {shape = "circle", size = "huge", race = "orc", hero = true},   -- Blademaster

    -- Buildings
    ["htow"] = {shape = "rect", size = "building", race = "human"},   -- Town Hall
    ["ogre"] = {shape = "rect", size = "building", race = "orc"},     -- Great Hall

    -- Neutral
    ["ngol"] = {shape = "diamond", size = "small", race = "neutral"}, -- Gold Mine
}

-- Race colors (base colors before team color applied)
local RACE_COLORS = {
    human = {200, 180, 140, 255},   -- Tan
    orc = {140, 180, 140, 255},     -- Greenish
    undead = {140, 120, 160, 255},  -- Purple-gray
    nightelf = {120, 140, 180, 255}, -- Blue-ish
    neutral = {180, 180, 180, 255}, -- Gray
}
```

---

### Suggested Implementation Steps

1. **Define size categories**
   - Map descriptive names to pixel sizes
   - Consistent with WC3 unit scale

2. **Create unit type database**
   - Map 4-char unit IDs to visual configs
   - Include common units from each race
   - Mark heroes distinctly

3. **Handle unknown units**
   ```lua
   function unit_visuals.get(type_id)
       return MAPPINGS[type_id] or {
           shape = "circle",
           size = "medium",
           race = "neutral",
       }
   end
   ```

4. **Integrate with sprite system**
   - On unit creation, look up visual config
   - Register with sprites.register()

5. **Add building visuals**
   - Larger rectangular shapes
   - Different fill patterns (future)

6. **Support custom units**
   - Allow map-defined unit visuals
   - Override system for modding

---

### Acceptance Criteria

- Common Human units have mappings
- Common Orc units have mappings
- Unknown units get default visuals
- Size categories produce correct sizes
- Heroes are visually distinct
- Buildings render as rectangles

---

### Notes

The WC3 unit ID format:
- 4 characters
- First char indicates race: h=human, o=orc, u=undead, e=elf, n=neutral
- Capital first letter usually means hero

**Extensibility:**
This mapping can be expanded as needed. Start with common units, add more over time.

---

### Related Documents

- issues/503a-core-sprite-system.md (uses these mappings)
- src/runtime/ecs/wc3_components.lua (unit type IDs)
- WC3 unit data files (reference)

---

## Decisions (2026-11-06)

Made without the owner; each one theirs to overturn.

1. **The rows are built and tested; handing them to the window is left.**
   `src/gamedata/unit_visuals.lua` reads each unit type's art fields from
   112's rows (`stock_rows.load` and `merge`) and needs neither raylib nor
   the install to test. Giving each placed unit its row's shape, scale and
   tint at map load changes the window's map scene (`demo/wc3map/`, which
   draws with 517's designs) and can only be seen there, so it waits on
   raylib, and checking real maps waits on the install. None of the three
   boxes is ticked yet for that reason.
2. **Each field's table and column come from the metadata row for its
   code**, as `stock_rows` lays a map's changes over a stock row, not from
   column names written here. A version that keeps the model path in
   `UnitUI.slk` (`file`) and one that keeps it in a profile file both work.
   The codes: `umdl` model, `usca` scale, `uclr`/`uclg`/`uclb` tint,
   `ussc` selection scale, `ubdg` building, `umvt` move type.
3. **A type the map doesn't change is read straight from the stock
   tables**; one it changes (a custom type, or a stock type changed in
   place) from its merged row, where the map's values win. Each row says
   which fields the map set (`from_map`), so "a map's changed scale or
   tint shows" can be checked field by field.
4. **The placeholder rule:** a building is a cube, a flyer (move type
   `fly`) a triangle, a ground unit with a selection scale of 1.5 or more
   a cylinder, any other a circle. Building wins over flying, and flying
   over size. The 1.5 is a guess at "large" (WC3's footman is 1, its
   tauren about 1.75), kept as `LARGE_SELECTION`.
5. **Missing values fall back, and are reported:** no model path (blank or
   `_`, the tables' "nothing") means no model, so 516's chooser falls back
   to the placeholder; scale and selection default to 1, tint to 255 (no
   tint). A type in neither the map nor the tables is a problem
   (`unknown_type`); a code the metadata lacks is one problem per code
   (`no_metadata`), not one per type.

## What happened (2026-11-06)

- `src/gamedata/unit_visuals.lua` (with its `.info.md`): `of`,
  `for_types`, `placeholder`, `CODES`, `LARGE_SELECTION`.
- `src/tests/test_unit_visuals.lua` (51 checks, with its `.info.md`): the
  real `stock_rows.load` and `merge` over a stand-in chain of hand-written
  tables; a model kept in a profile file; problems; the rule alone; values
  written as text. Through the real chain when the install and the 1.29.2
  layer are present (skipped here: no install in this checkout).
- Mutation check of `unit_visuals.lua`: 84 mutants, 81 caught. The 3 left
  are equivalent: `return nil` for `return false` where the caller only
  tests for truth (2), and a missing selection scale read as 1 instead of
  0, both under the 1.5 threshold (1).

## Follow-up (needs raylib and the install, not built)

- At map load (`src/demo/wc3map/game.lua`, beside `classify.unit`), read
  `unit_visuals.for_types` for the placed unit types and give each unit
  its row's scale and tint, and its shape where no design or model is
  found.
- 516's chooser looks models up by `row.model`.
