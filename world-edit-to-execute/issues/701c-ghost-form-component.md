# Issue 701c: Ghost Form Component

**Phase:** 7 - Gameplay: Core Mechanics
**Type:** Implementation
**Priority:** High
**Parent:** 701-death-and-resurrection-system.md
**Dependencies:** 701a (Death state), 701b (Spirit world)

---

## Current Behavior

When heroes die, they simply cease to exist in any meaningful form.
There is no ghost representation that the player can control or observe.

---

## Intended Behavior

Dead heroes create a ghost entity in the spirit world:
1. Ghost spawns at death location when hero dies
2. Ghost links back to the original unit data for revival
3. Ghost links to the corpse entity in mortal realm
4. Ghost can move in spirit world (player controlled for heroes)
5. Ghost visibility configurable (owner, allies, enemies)
6. Ghost disappears when hero is revived

---

## Suggested Implementation Steps

1. Register `ghost` component:
   ```lua
   ecs.register_component("ghost", {
       linked_corpse = nil,      -- Entity ID of corpse
       original_data = {},       -- Preserved unit state
       original_entity = nil,    -- Original unit entity ID
       owner = nil,              -- Player who owns this ghost
       movement_speed = 400,     -- Ghosts move faster
       visible_to_owner = true,
       visible_to_allies = false,
       visible_to_enemies = false,
   })
   ```

2. Create ghost spawning function:
   ```lua
   death.create_ghost(dead_entity, corpse_entity)
   ```

3. Preserve original unit data in ghost:
   - Hero level, experience, attributes
   - Inventory contents
   - Ability levels and cooldowns
   - Position at death

4. Add ghost to spirit world layer:
   - Add `world_layer` component with `layer = "spirit"`
   - Add movement component for ghost movement

5. Handle ghost cleanup on revival:
   - Remove ghost entity when hero revives
   - Restore preserved data to revived hero

---

## Component Definition

```lua
ecs.register_component("ghost", {
    -- Links
    linked_corpse = nil,      -- Entity ID of corpse in mortal realm
    original_entity = nil,    -- Original unit's entity ID (for reference)
    original_data = {},       -- Preserved unit state for revival

    -- Ownership
    owner_player = nil,       -- Player ID who owns this ghost

    -- Movement (overrides)
    movement_speed = 400,     -- Ghosts move 50% faster than base

    -- Visibility
    visible_to_owner = true,  -- Owner can always see their ghost
    visible_to_allies = false, -- Allies cannot see by default
    visible_to_enemies = false, -- Enemies cannot see by default

    -- State
    at_altar = false,         -- Ghost has reached an altar
    revival_started = false,  -- Revival is in progress
})
```

---

## Original Data Structure

The `original_data` field preserves everything needed for revival:

```lua
original_data = {
    -- Unit type
    type_id = "Hpal",         -- Hero type ID

    -- Position at death
    death_x = 0,
    death_y = 0,
    death_facing = 0,

    -- Hero stats
    level = 5,
    experience = 1200,
    strength = 25,
    agility = 18,
    intelligence = 22,

    -- Inventory (item entity IDs or item data)
    inventory = {nil, "item_1", nil, nil, "item_2", nil},

    -- Abilities
    ability_levels = {
        ["AHhb"] = 2,  -- Holy Light level 2
        ["AHds"] = 1,  -- Divine Shield level 1
    },
    ability_cooldowns = {
        ["AHhb"] = 0,
        ["AHds"] = 45.0,  -- 45 seconds remaining
    },
}
```

---

## API Design

```lua
local death = require("runtime.systems.death")

-- Ghost creation
death.create_ghost(dead_entity, corpse_entity)  -- Create ghost for dead hero

-- Ghost queries
death.is_ghost(entity)           -- Returns true if entity is a ghost
death.get_ghost(dead_entity)     -- Get ghost entity for a dead hero
death.get_linked_corpse(ghost)   -- Get corpse entity linked to ghost
death.get_original_data(ghost)   -- Get preserved unit data

-- Ghost visibility
death.can_see_ghost(player, ghost)  -- Check if player can see ghost
death.set_ghost_visibility(ghost, owner, allies, enemies)

-- Ghost state
death.ghost_at_altar(ghost, altar)  -- Mark ghost as at an altar
death.is_at_altar(ghost)            -- Check if ghost reached altar
```

---

## Ghost Movement

Ghosts use a simplified movement model:
- Faster base speed (400 vs 270)
- Fly pathing (ignore terrain)
- Player can right-click to move ghost

```lua
-- When creating ghost entity
ecs.add_component(ghost, "movement", {
    speed = 400,
    pathing_type = "fly",
})
ecs.add_component(ghost, "world_layer", {
    layer = "spirit",
})
```

---

## Visibility Rules

Ghost visibility follows these rules:
1. Owner always sees their own ghost (unless option disabled)
2. Allies only see if `visible_to_allies = true`
3. Enemies only see if `visible_to_enemies = true`
4. Render layer applies transparency/glow effect

```lua
function can_see_ghost(viewer_player, ghost)
    local g = ecs.get_component(ghost, "ghost")
    if not g then return false end

    if viewer_player == g.owner_player then
        return g.visible_to_owner
    elseif is_ally(viewer_player, g.owner_player) then
        return g.visible_to_allies
    else
        return g.visible_to_enemies
    end
end
```

---

## Acceptance Criteria

- [x] `ghost` component registered with ECS
- [x] `create_ghost()` spawns ghost at death location
- [x] Ghost preserves original unit data
- [x] Ghost links to corpse entity
- [x] Ghost exists in spirit world layer
- [x] Ghost movement works (faster, ignores terrain)
- [x] Visibility rules implemented
- [x] Ghost removed when hero revives
- [x] Unit tests for ghost creation
- [x] Unit tests for ghost visibility

---

## Notes

The ghost system is primarily for heroes, but the architecture supports
any entity having a ghost form. This could be extended for:
- Night Elf wisps (visible ghost scouts)
- Death Knight's army of the dead
- Custom map mechanics

The original_data preservation is critical for WC3 authenticity - heroes
must retain all their progress through death.

Rendering the ghost (transparency, glow, animation) is Phase 5 territory.
This issue only handles the data model and game logic.

---

## Implementation Notes

**Implemented:** 2026-01-07

### Integration with death.lua

The ghost system was integrated directly into `src/runtime/systems/death.lua`
alongside death and corpse systems for unified access.

### Components Added

- `ghost` - Tracks ghost state, links, visibility, and preserved hero data

### API Implemented

**Creation:**
- `create_ghost(dead_hero, corpse)` - Create ghost for dead hero
- `preserve_hero_data(entity)` - Capture hero state for revival

**Queries:**
- `is_ghost(entity)` - Check if entity is a ghost
- `get_ghost(dead_hero)` - Get ghost for dead hero
- `get_ghost_unit(ghost)` - Get original hero for ghost
- `get_linked_corpse(ghost)` - Get linked corpse
- `get_original_data(ghost)` - Get preserved hero data
- `count_ghosts()` - Count active ghosts

**Visibility:**
- `can_see_ghost(player, ghost)` - Check visibility
- `set_ghost_visibility(ghost, owner, allies, enemies)` - Set rules

**Altar State:**
- `ghost_at_altar(ghost, altar)` - Mark at altar
- `is_at_altar(ghost)` - Check altar state

**Cleanup:**
- `destroy_ghost(ghost)` - Remove ghost, clean links

### Ghost Creation Details

When `create_ghost()` is called:
1. Validates entity is dead hero
2. Preserves all hero data (level, stats, inventory, abilities)
3. Creates ghost entity with position/movement/selectable components
4. Places ghost in spirit world layer
5. Links ghost to corpse if provided
6. Sets up owner and visibility defaults

### Test Coverage

24 new tests for ghost system:
- Component registration
- Ghost creation (hero only, dead only)
- Position preservation
- Hero data preservation
- Query functions
- Visibility rules
- Altar state tracking
- Cleanup and unlinking

### Design Decisions

- Ghosts only created for heroes (non-heroes return nil)
- Ghost inherits owner from original hero
- Ghosts use fly pathing (ignore terrain)
- Movement speed 400 (faster than most units)
- Visibility defaults: owner=true, allies=false, enemies=false
- Two-way tracking between ghost and original hero
