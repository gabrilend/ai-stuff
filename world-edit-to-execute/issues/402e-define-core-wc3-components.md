# Issue 402e: Define Core WC3 Components

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** High
**Dependencies:** 402b-implement-component-registry
**Parent Issue:** 402-build-entity-component-system

---

## Current Behavior

The component registry exists but no WC3-specific component types are defined.
Game entities cannot be created with proper WC3 attributes like health, mana,
movement speed, or player ownership.

---

## Intended Behavior

A set of core component definitions that match WC3's entity model:
- Position and facing in world space
- Health, mana, and regeneration (stats)
- Movement with pathing type and speed
- Player ownership and alliance
- Unit type reference
- Selection state
- Abilities and buffs containers

```lua
-- Example: Creating a footman
local ecs = require("runtime.ecs")
local wc3 = require("runtime.ecs.wc3_components")

local footman = ecs.create_entity()
ecs.add_component(footman, "position", {x = 100, y = 200, facing = 0})
ecs.add_component(footman, "unit_type", {type_id = "hfoo"})
ecs.add_component(footman, "stats", {hp = 420, hp_max = 420, armor = 2})
ecs.add_component(footman, "movement", {speed = 270, pathing = "foot"})
ecs.add_component(footman, "owner", {player_id = 0})
ecs.add_component(footman, "selectable", {selection_scale = 1.2})
```

---

## Suggested Implementation Steps

1. **Create WC3 components module**
   ```lua
   -- {{{ src/runtime/ecs/wc3_components.lua
   -- Core WC3 component definitions
   -- Registers all standard components used by WC3 entities

   local wc3 = {}

   local component = require("runtime.ecs.component")
   -- }}}
   ```

2. **Define position component**
   ```lua
   -- {{{ Position Component
   -- World position and facing direction
   -- All units, buildings, items, doodads have position
   component.register("position", {
       x = 0.0,              -- World X coordinate
       y = 0.0,              -- World Y coordinate
       z = 0.0,              -- World Z coordinate (height)
       facing = 0.0,         -- Facing angle in radians (0 = East, counter-clockwise)
   })

   -- Note: WC3 uses degrees in JASS (0-360) but radians internally
   -- Conversion: radians = degrees * (math.pi / 180)
   -- }}}
   ```

3. **Define stats component**
   ```lua
   -- {{{ Stats Component
   -- Health, mana, and combat statistics
   -- Used by units, buildings, and destructibles
   component.register("stats", {
       -- Health
       hp = 100,             -- Current hit points
       hp_max = 100,         -- Maximum hit points
       hp_regen = 0.0,       -- HP regeneration per second

       -- Mana
       mp = 0,               -- Current mana points
       mp_max = 0,           -- Maximum mana points
       mp_regen = 0.0,       -- MP regeneration per second

       -- Combat
       armor = 0,            -- Armor value (reduces physical damage)
       armor_type = "normal",-- Armor type: unarmored, light, medium, heavy, fortified, hero, divine
       damage_min = 0,       -- Minimum attack damage
       damage_max = 0,       -- Maximum attack damage
       damage_type = "normal",-- Attack type: normal, pierce, siege, magic, chaos, spells, hero
       attack_speed = 1.0,   -- Attacks per second base
       attack_range = 128,   -- Attack range in units

       -- State
       invulnerable = false, -- Cannot take damage
       ethereal = false,     -- Cannot be targeted by physical attacks
   })
   -- }}}
   ```

4. **Define movement component**
   ```lua
   -- {{{ Movement Component
   -- Movement capability and pathing
   -- Units and some buildings (uproot) have movement
   component.register("movement", {
       speed = 270,          -- Base movement speed (units per second)
       speed_current = 270,  -- Current speed (after buffs/debuffs)
       speed_min = 100,      -- Minimum speed (hard floor)
       speed_max = 522,      -- Maximum speed (hard cap, WC3 limit)

       pathing = "foot",     -- Pathing type: foot, horse, fly, float, amphibious, buildingblocked
       collision_size = 32,  -- Collision radius in units

       -- Movement state
       moving = false,       -- Currently moving
       move_target_x = 0,    -- Move destination X
       move_target_y = 0,    -- Move destination Y
       turn_rate = 0.6,      -- Radians per second for turning

       -- Flight (if pathing == "fly")
       fly_height = 0,       -- Current fly height
       fly_height_default = 0,-- Default fly height
   })
   -- }}}
   ```

5. **Define owner component**
   ```lua
   -- {{{ Owner Component
   -- Player ownership and team
   -- Units, buildings, items (when held)
   component.register("owner", {
       player_id = 0,        -- Owning player (0-15, or -1 for neutral)
       -- Note: Neutral hostile = player 12 (PLAYER_NEUTRAL_AGGRESSIVE)
       --       Neutral passive = player 13 (PLAYER_NEUTRAL_PASSIVE)
       --       Neutral victim = player 14

       -- Cached alliance info (updated when alliances change)
       team = 0,             -- Team number for quick alliance checks
   })
   -- }}}
   ```

6. **Define unit_type component**
   ```lua
   -- {{{ Unit Type Component
   -- Reference to unit type definition
   -- All units and buildings
   component.register("unit_type", {
       type_id = "",         -- Four-character type ID (e.g., "hfoo", "hpea", "htow")
       -- This references the unit data loaded from SLK files

       -- Cached type info (from SLK data)
       name = "",            -- Display name
       is_hero = false,      -- Is this a hero unit
       is_building = false,  -- Is this a building
       is_summoned = false,  -- Is this summoned (not trained)
       food_used = 0,        -- Food cost
       food_made = 0,        -- Food provided (farms, halls)
       level = 1,            -- Unit level
   })
   -- }}}
   ```

7. **Define selectable component**
   ```lua
   -- {{{ Selectable Component
   -- Selection and UI state
   -- Most interactable entities
   component.register("selectable", {
       selected = false,     -- Currently selected by local player
       selection_scale = 1.0,-- Selection circle scale factor
       selection_priority = 0,-- Priority for group selection (higher = more likely to be primary)

       -- UI hints
       show_healthbar = true,-- Show health bar when selected/hovered
       show_manabar = true,  -- Show mana bar if unit has mana
       can_select = true,    -- Can be selected at all (some units cannot)
   })
   -- }}}
   ```

8. **Define abilities component**
   ```lua
   -- {{{ Abilities Component
   -- Container for unit abilities
   -- Units with spells or passive abilities
   component.register("abilities", {
       ability_ids = {},     -- Array of ability type IDs
       cooldowns = {},       -- ability_id -> remaining cooldown time
       levels = {},          -- ability_id -> current level (for hero abilities)
       disabled = {},        -- ability_id -> true if disabled
   })

   -- Note: Ability definitions are separate; this just tracks which
   -- abilities the unit has and their current state.
   -- }}}
   ```

9. **Define buffs component**
   ```lua
   -- {{{ Buffs Component
   -- Active buffs and debuffs on the unit
   -- Units that can receive buffs
   component.register("buffs", {
       active = {},          -- Array of active buff instances
       -- Each buff: { buff_id, source_entity, remaining_duration, stacks }

       -- Cached modifiers (recalculated when buffs change)
       speed_modifier = 1.0, -- Multiplicative speed modifier
       damage_modifier = 1.0,-- Multiplicative damage modifier
       armor_modifier = 0,   -- Additive armor modifier
   })
   -- }}}
   ```

10. **Define hero-specific components**
    ```lua
    -- {{{ Hero Component
    -- Hero-specific stats (experience, attributes)
    -- Hero units only
    component.register("hero", {
        experience = 0,       -- Current experience points
        level = 1,            -- Hero level (1-10 typically)

        -- Primary attributes
        strength = 0,         -- Strength (HP, HP regen)
        agility = 0,          -- Agility (armor, attack speed)
        intelligence = 0,     -- Intelligence (mana, mana regen)
        primary_attribute = "strength", -- Which attribute provides damage bonus

        -- Attribute gains per level (from hero data)
        str_per_level = 0,
        agi_per_level = 0,
        int_per_level = 0,

        -- Inventory
        inventory = {},       -- Array of 6 item entity IDs (nil for empty slots)
    })
    -- }}}
    ```

11. **Define building-specific components**
    ```lua
    -- {{{ Building Component
    -- Building-specific state
    -- Buildings only
    component.register("building", {
        construction_progress = 1.0, -- 0.0 = just started, 1.0 = complete
        under_construction = false,

        -- Rally point
        rally_x = 0,
        rally_y = 0,
        rally_target = nil,   -- Entity ID to rally to (unit/building)

        -- Production queue
        queue = {},           -- Array of unit type IDs being trained
        queue_progress = 0.0, -- Progress on current item (0.0-1.0)
    })
    -- }}}
    ```

12. **Define item component**
    ```lua
    -- {{{ Item Component
    -- Item-specific data
    -- Items (on ground or in inventory)
    component.register("item", {
        item_id = "",         -- Item type ID (four-char)
        charges = 0,          -- Remaining charges (0 = no charges/infinite)
        charges_max = 0,      -- Maximum charges

        -- State
        on_ground = true,     -- Is the item on the ground
        carrier = nil,        -- Entity ID of carrying unit (if not on ground)
        slot = 0,             -- Inventory slot (1-6) if carried

        -- Loot
        can_be_picked_up = true,
        drop_on_death = true,
        sellable = true,
        pawnable = true,
    })
    -- }}}
    ```

13. **Define projectile component**
    ```lua
    -- {{{ Projectile Component
    -- Projectile data for missiles
    -- Projectile entities
    component.register("projectile", {
        source = nil,         -- Entity ID that fired this projectile
        target = nil,         -- Entity ID target (nil for point target)
        target_x = 0,         -- Target X (for point target or if target dies)
        target_y = 0,         -- Target Y

        speed = 900,          -- Projectile speed (units per second)
        arc = 0.0,            -- Arc height (0 = straight line)
        homing = true,        -- Does it follow the target

        -- Payload
        damage = 0,           -- Damage on impact
        damage_type = "normal",
        impact_ability = nil, -- Ability to trigger on impact

        -- State
        distance_traveled = 0,
    })
    -- }}}
    ```

14. **Define destructible component**
    ```lua
    -- {{{ Destructible Component
    -- Destructible object data (trees, rocks, gates)
    component.register("destructible", {
        type_id = "",         -- Destructible type ID

        -- State
        alive = true,         -- Not destroyed
        current_animation = "stand", -- Current animation state

        -- Resources
        lumber_amount = 0,    -- Lumber when harvested (trees)
        gold_amount = 0,      -- Gold when harvested (gold mines)
    })
    -- }}}
    ```

15. **Define doodad component**
    ```lua
    -- {{{ Doodad Component
    -- Non-interactive scenery
    component.register("doodad", {
        type_id = "",         -- Doodad type ID
        variation = 0,        -- Visual variation (0-n)
        scale = 1.0,          -- Size scale
        animation = "stand",  -- Current animation
    })
    -- }}}
    ```

16. **Create component documentation and helper functions**
    ```lua
    -- {{{ Helper functions
    -- Utility functions for common WC3 operations

    -- {{{ wc3.create_unit
    function wc3.create_unit(type_id, player_id, x, y, facing)
    -- }}}
    -- {{{ wc3.create_unit
    function wc3.create_unit(type_id, player_id, x, y, facing)
        -- Helper to create a unit with standard components
        -- Note: Does NOT load type data from SLK - just sets up structure

        local ecs = require("runtime.ecs")

        local entity = ecs.create_entity()

        ecs.add_component(entity, "position", {
            x = x or 0,
            y = y or 0,
            facing = facing or 0,
        })

        ecs.add_component(entity, "unit_type", {
            type_id = type_id,
        })

        ecs.add_component(entity, "owner", {
            player_id = player_id or 0,
        })

        ecs.add_component(entity, "stats")
        ecs.add_component(entity, "movement")
        ecs.add_component(entity, "selectable")
        ecs.add_component(entity, "abilities")
        ecs.add_component(entity, "buffs")

        return entity
    end
    -- }}}

    -- {{{ wc3.create_building
    function wc3.create_building(type_id, player_id, x, y, facing)
    -- }}}
    -- {{{ wc3.create_building
    function wc3.create_building(type_id, player_id, x, y, facing)
        local ecs = require("runtime.ecs")

        local entity = ecs.create_entity()

        ecs.add_component(entity, "position", {
            x = x or 0,
            y = y or 0,
            facing = facing or 0,
        })

        ecs.add_component(entity, "unit_type", {
            type_id = type_id,
            is_building = true,
        })

        ecs.add_component(entity, "owner", {
            player_id = player_id or 0,
        })

        ecs.add_component(entity, "stats")
        ecs.add_component(entity, "selectable")
        ecs.add_component(entity, "building")

        return entity
    end
    -- }}}

    -- {{{ wc3.create_item
    function wc3.create_item(item_id, x, y)
    -- }}}
    -- {{{ wc3.create_item
    function wc3.create_item(item_id, x, y)
        local ecs = require("runtime.ecs")

        local entity = ecs.create_entity()

        ecs.add_component(entity, "position", {
            x = x or 0,
            y = y or 0,
        })

        ecs.add_component(entity, "item", {
            item_id = item_id,
            on_ground = true,
        })

        ecs.add_component(entity, "selectable")

        return entity
    end
    -- }}}
    -- }}}
    ```

17. **Export and document**
    ```lua
    -- {{{ Component mapping documentation
    --[[
    WC3 Entity Type to Component Mapping:

    | WC3 Type     | Components                                              |
    |--------------|--------------------------------------------------------|
    | Unit         | position, unit_type, owner, stats, movement,            |
    |              | selectable, abilities, buffs                           |
    | Hero         | All Unit components + hero                              |
    | Building     | position, unit_type, owner, stats, selectable, building |
    | Item         | position, item, selectable                              |
    | Destructible | position, stats, destructible, selectable               |
    | Doodad       | position, doodad                                        |
    | Projectile   | position, movement, projectile                          |

    Component responsibilities:
    - position: Where the entity is in the world
    - stats: Health, mana, damage, armor
    - movement: Can move, how fast, pathing rules
    - owner: Which player controls this
    - unit_type: Reference to type definition (SLK data)
    - selectable: Can be selected, UI state
    - abilities: What abilities the unit has
    - buffs: Active temporary effects
    - hero: Hero-specific (XP, attributes, inventory)
    - building: Building-specific (construction, queue)
    - item: Item-specific (charges, carrier)
    - projectile: Missile tracking
    - destructible: Destroyable object (tree, rock)
    - doodad: Non-interactive scenery
    ]]
    -- }}}

    -- {{{ Module export
    return wc3
    -- }}}
    ```

18. **Create unit tests**
    ```lua
    -- {{{ src/tests/test_wc3_components.lua
    -- Tests for WC3 component definitions

    local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
    package.path = DIR .. "/src/?.lua;" .. package.path

    local entity = require("runtime.ecs.entity")
    local component = require("runtime.ecs.component")

    -- Load WC3 components (registers them)
    local wc3 = require("runtime.ecs.wc3_components")

    local test_count = 0
    local pass_count = 0

    local function test(name, condition, msg)
        test_count = test_count + 1
        if condition then
            pass_count = pass_count + 1
            print("  [PASS] " .. name)
        else
            print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
        end
    end

    local function test_section(name)
        print("\n=== " .. name .. " ===")
    end

    -- Reset
    entity.reset()

    test_section("Component Registration")
    local types = component.get_registered_types()
    test("Position registered", component.get_defaults("position") ~= nil)
    test("Stats registered", component.get_defaults("stats") ~= nil)
    test("Movement registered", component.get_defaults("movement") ~= nil)
    test("Owner registered", component.get_defaults("owner") ~= nil)
    test("Unit_type registered", component.get_defaults("unit_type") ~= nil)
    test("Selectable registered", component.get_defaults("selectable") ~= nil)
    test("Abilities registered", component.get_defaults("abilities") ~= nil)
    test("Buffs registered", component.get_defaults("buffs") ~= nil)
    test("Hero registered", component.get_defaults("hero") ~= nil)
    test("Building registered", component.get_defaults("building") ~= nil)
    test("Item registered", component.get_defaults("item") ~= nil)
    test("Projectile registered", component.get_defaults("projectile") ~= nil)
    test("Destructible registered", component.get_defaults("destructible") ~= nil)
    test("Doodad registered", component.get_defaults("doodad") ~= nil)

    test_section("Default Values")
    local pos_def = component.get_defaults("position")
    test("Position x default", pos_def.x == 0)
    test("Position facing default", pos_def.facing == 0)

    local stats_def = component.get_defaults("stats")
    test("Stats hp default", stats_def.hp == 100)
    test("Stats armor_type default", stats_def.armor_type == "normal")

    local mov_def = component.get_defaults("movement")
    test("Movement speed default", mov_def.speed == 270)
    test("Movement pathing default", mov_def.pathing == "foot")

    test_section("Create Unit Helper")
    entity.reset()
    local unit = wc3.create_unit("hfoo", 0, 100, 200, 1.57)

    test("Unit created", entity.exists(unit))
    test("Has position", component.has(unit, "position"))
    test("Has unit_type", component.has(unit, "unit_type"))
    test("Has owner", component.has(unit, "owner"))
    test("Has stats", component.has(unit, "stats"))
    test("Has movement", component.has(unit, "movement"))
    test("Has selectable", component.has(unit, "selectable"))
    test("Has abilities", component.has(unit, "abilities"))
    test("Has buffs", component.has(unit, "buffs"))

    local pos = component.get(unit, "position")
    test("Position x set", pos.x == 100)
    test("Position y set", pos.y == 200)
    test("Position facing set", math.abs(pos.facing - 1.57) < 0.01)

    local ut = component.get(unit, "unit_type")
    test("Unit type set", ut.type_id == "hfoo")

    local owner = component.get(unit, "owner")
    test("Owner set", owner.player_id == 0)

    test_section("Create Building Helper")
    entity.reset()
    local bldg = wc3.create_building("htow", 1, 500, 600, 0)

    test("Building created", entity.exists(bldg))
    test("Building has position", component.has(bldg, "position"))
    test("Building has building component", component.has(bldg, "building"))
    test("Building no movement", not component.has(bldg, "movement"))

    local ut = component.get(bldg, "unit_type")
    test("Building type set", ut.type_id == "htow")
    test("Building flag set", ut.is_building == true)

    test_section("Create Item Helper")
    entity.reset()
    local item = wc3.create_item("rst1", 300, 400)

    test("Item created", entity.exists(item))
    test("Item has position", component.has(item, "position"))
    test("Item has item component", component.has(item, "item"))
    test("Item on ground", component.get(item, "item").on_ground == true)

    test_section("Component Inheritance")
    entity.reset()
    local unit = wc3.create_unit("hkni", 0, 0, 0, 0)

    -- Override some stats
    local stats = component.get(unit, "stats")
    stats.hp = 500
    stats.hp_max = 500

    -- Check inheritance still works for non-overridden
    test("Overridden hp", stats.hp == 500)
    test("Inherited mp (default 0)", stats.mp == 0)
    test("Inherited armor_type", stats.armor_type == "normal")

    print("\n" .. string.rep("=", 40))
    print(string.format("Tests: %d passed, %d failed",
                        pass_count, test_count - pass_count))
    if pass_count == test_count then
        print("ALL TESTS PASSED")
    else
        os.exit(1)
    end
    -- }}}
    ```

---

## Technical Notes

### Component Design Philosophy

Components are pure data with sensible defaults. They do NOT contain:
- Methods or behavior (that's in systems)
- References to other entities (use entity IDs instead)
- Mutable shared state

### WC3 Data Types

| WC3 Type | Lua Representation |
|----------|-------------------|
| integer | number |
| real | number |
| boolean | boolean |
| string | string |
| handle | entity ID (number) |
| player | player_id (0-15) |
| fourcc | string ("hfoo") |

### Coordinate System

WC3 uses a 2D coordinate system:
- X increases to the East
- Y increases to the North
- Z is height (terrain + fly height)
- Facing is in radians, 0 = East, counter-clockwise

### Speed Values

WC3 movement speeds:
- Minimum: 100 (very slow)
- Average: 270 (footman)
- Fast: 320 (knight)
- Maximum: 522 (hard cap)

### Armor Types and Damage Types

The WC3 damage system uses a matrix of armor types vs damage types.
This component just stores the types; the combat system (future issue)
handles the calculations.

---

## Related Documents

- issues/402-build-entity-component-system.md (parent issue)
- issues/402b-implement-component-registry.md (registers components)
- issues/206-design-game-object-types.md (type system design)
- docs/wc3-data-formats.md (SLK format for unit definitions)
- src/runtime/ecs/wc3_components.lua (implementation)

---

## Acceptance Criteria

- [x] Module created at src/runtime/ecs/wc3_components.lua
- [x] `position` component registered with x, y, z, facing
- [x] `stats` component registered with hp, mp, armor, damage
- [x] `movement` component registered with speed, pathing, collision
- [x] `owner` component registered with player_id
- [x] `unit_type` component registered with type_id reference
- [x] `selectable` component registered with selection state
- [x] `abilities` component registered with ability list
- [x] `buffs` component registered with active buffs
- [x] `hero` component registered with XP, attributes, inventory
- [x] `building` component registered with construction, queue
- [x] `item` component registered with charges, carrier
- [x] `projectile` component registered with target, speed
- [x] `destructible` component registered with alive state
- [x] `doodad` component registered with type and variation
- [x] `create_unit()` helper creates unit with standard components
- [x] `create_building()` helper creates building with correct components
- [x] `create_item()` helper creates item on ground
- [x] Component mapping table documented
- [x] All defaults match WC3 sensible values
- [x] All code uses vimfold markers
- [x] Unit tests pass for all functionality

---

## Notes

These components form the vocabulary for WC3 entity representation. They
should match WC3's concepts closely but don't need to be identical.

Some WC3 features that are NOT components (handled elsewhere):
- Abilities themselves (separate ability definition system)
- Unit type data (loaded from SLK files)
- Player resources (gold, lumber, food - player system)
- Alliances (player alliance matrix)

The helper functions (`create_unit`, etc.) are convenience wrappers.
The actual data loading from map files will populate these components
with real values from SLK data.

---

## Implementation Notes

### Files Created
- `src/runtime/ecs/wc3_components.lua` (~350 lines) - 14 component definitions + 7 helper functions
- `src/tests/test_wc3_components.lua` (~350 lines) - 207 tests covering all components and helpers

### Components Implemented (14 total)
1. **position** - World position and facing (x, y, z, facing)
2. **stats** - Health, mana, combat stats (hp, mp, armor, damage, attack speed)
3. **movement** - Movement capability (speed, pathing, collision, turn rate, fly height)
4. **owner** - Player ownership (player_id, team)
5. **unit_type** - Type reference (type_id, is_hero, is_building, food cost)
6. **selectable** - Selection state (selected, selection_scale, priority)
7. **abilities** - Ability container (ability_ids, cooldowns, levels, disabled)
8. **buffs** - Active buffs (active list, cached modifiers)
9. **hero** - Hero-specific (experience, level, attributes, inventory)
10. **building** - Building-specific (construction_progress, rally point, queue)
11. **item** - Item-specific (item_id, charges, carrier, slot)
12. **projectile** - Projectile data (source, target, speed, arc, damage)
13. **destructible** - Destroyable objects (type_id, alive, lumber/gold amounts)
14. **doodad** - Non-interactive scenery (type_id, variation, scale)

### Helper Functions Implemented (7 total)
- `create_unit(type_id, player_id, x, y, facing)` - Creates unit with standard components
- `create_hero(type_id, player_id, x, y, facing)` - Creates hero with hero component
- `create_building(type_id, player_id, x, y, facing)` - Creates building (no movement)
- `create_item(item_id, x, y)` - Creates item on ground
- `create_destructible(type_id, x, y, facing, hp)` - Creates destroyable object
- `create_doodad(type_id, x, y, facing, scale, variation)` - Creates scenery
- `create_projectile(source, target, target_x, target_y, speed, damage)` - Creates missile

### Test Coverage
- 207 tests covering all component defaults, helper functions, and entity creation
- Total ECS + WC3 tests: 564 (64 entity + 99 component + 62 query + 132 system + 207 wc3)

