# Issue 503b: Unit Visual Mappings

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 503
**Priority:** High
**Dependencies:** 503a

---

## Current Behavior

No mapping between WC3 unit type IDs and visual representations.

---

## Intended Behavior

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

## Suggested Implementation Steps

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

## Acceptance Criteria

- [ ] Common Human units have mappings
- [ ] Common Orc units have mappings
- [ ] Unknown units get default visuals
- [ ] Size categories produce correct sizes
- [ ] Heroes are visually distinct
- [ ] Buildings render as rectangles

---

## Notes

The WC3 unit ID format:
- 4 characters
- First char indicates race: h=human, o=orc, u=undead, e=elf, n=neutral
- Capital first letter usually means hero

**Extensibility:**
This mapping can be expanded as needed. Start with common units, add more over time.

---

## Related Documents

- issues/503a-core-sprite-system.md (uses these mappings)
- src/runtime/ecs/wc3_components.lua (unit type IDs)
- WC3 unit data files (reference)
