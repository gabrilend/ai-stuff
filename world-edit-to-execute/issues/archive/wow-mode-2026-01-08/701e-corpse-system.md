# Issue 701e: Corpse System

**Phase:** 7 - Gameplay: Core Mechanics
**Type:** Implementation
**Priority:** High
**Parent:** 701-death-and-resurrection-system.md
**Dependencies:** 701a (Death state)

---

## Current Behavior

When units die, they simply have a `dead` component attached. There is no
corpse representation - no decay timer, no visual remains, no targetability
for necromancy spells.

---

## Intended Behavior

Dead units leave corpses:
1. Corpse spawns at death location when unit dies
2. Corpse has decay timer (88 seconds for heroes, varies for units)
3. Corpse is targetable for Raise Dead, Animate Dead, Cannibalize
4. Corpse transitions through decay stages (fresh → skeleton → gone)
5. Some units don't leave corpses (summoned units, mechanical)

---

## Suggested Implementation Steps

1. Register `corpse` component:
   ```lua
   ecs.register_component("corpse", {
       decay_timer = 88.0,       -- Seconds until corpse disappears
       decay_max = 88.0,         -- Original decay time
       raiseable = true,         -- Can be targeted by Raise Dead
       unit_type_id = nil,       -- Original unit's type
       flesh_remaining = true,   -- false = skeleton only
       raised = false,           -- Has been raised as undead
   })
   ```

2. Create corpse when unit dies:
   - Hook into death.kill()
   - Create corpse entity at death position
   - Link corpse to ghost (for heroes)

3. Implement decay system:
   - Each tick, decrement decay_timer for all corpses
   - When timer hits 0, remove corpse entity
   - Fire EVENT_UNIT_DECAY

4. Add corpse queries:
   - `death.get_corpse(dead_entity)`
   - `death.find_corpses_in_range(x, y, radius)`

5. Implement corpse targeting:
   - Corpses are selectable but not attackable
   - Add ability target validation for corpse-only spells

6. Handle no-corpse units:
   - Summoned units (no corpse)
   - Mechanical units (no corpse)
   - Buildings (no corpse)

---

## Component Definition

```lua
ecs.register_component("corpse", {
    -- Decay
    decay_timer = 88.0,       -- Seconds remaining until decay
    decay_max = 88.0,         -- Original decay time (for progress bar)

    -- Targeting
    raiseable = true,         -- Can be targeted by Raise Dead
    cannibalizable = true,    -- Can be targeted by Cannibalize

    -- State
    flesh_remaining = true,   -- true = fresh corpse, false = skeleton
    raised = false,           -- Has been raised (prevents re-raise)

    -- Reference
    unit_type_id = nil,       -- Original unit's type ID
    original_owner = nil,     -- Player who owned the unit

    -- Link (for heroes)
    linked_ghost = nil,       -- Ghost entity in spirit world
})
```

---

## Decay Timers (WC3)

```lua
death.DECAY_TIME = {
    HERO = 88,           -- Hero corpses last longest
    NORMAL = 60,         -- Standard units
    SUMMONED = 0,        -- Summoned units don't leave corpses
    MECHANICAL = 0,      -- Mechanical units don't leave corpses
    BUILDING = 0,        -- Buildings don't leave corpses
}

-- Flesh-to-skeleton transition at 50% decay
death.SKELETON_THRESHOLD = 0.5
```

---

## Event Definitions

```lua
-- Add to events.lua
events.EVENT.UNIT_DECAY = 25      -- Corpse finished decaying
events.EVENT.CORPSE_RAISED = 26   -- Corpse raised as undead

-- Decay event context
{
    event_id = events.EVENT.UNIT_DECAY,
    corpse = corpse_entity,
    unit_type = original_type_id,
    x = corpse_x,
    y = corpse_y,
}

-- Raised event context
{
    event_id = events.EVENT.CORPSE_RAISED,
    corpse = corpse_entity,
    raised_unit = new_undead_entity,
    raiser = casting_unit,
}
```

---

## API Design

```lua
local death = require("runtime.systems.death")

-- Corpse creation
death.create_corpse(dead_entity)           -- Create corpse for dead unit
death.create_corpse_at(x, y, unit_type)    -- Create corpse at position

-- Corpse queries
death.get_corpse(dead_entity)              -- Get corpse for dead entity
death.find_corpses_in_range(x, y, radius)  -- Find nearby corpses
death.is_corpse(entity)                    -- Check if entity is corpse
death.is_raiseable(corpse)                 -- Can be raised
death.is_fresh(corpse)                     -- Has flesh remaining

-- Corpse modification
death.raise_corpse(corpse, raiser)         -- Mark as raised
death.consume_corpse(corpse)               -- Remove (Cannibalize)
death.destroy_corpse(corpse)               -- Remove without events

-- Decay queries
death.get_decay_remaining(corpse)          -- Seconds remaining
death.get_decay_progress(corpse)           -- 0.0 (fresh) to 1.0 (gone)
```

---

## Corpse Creation Rules

```lua
-- Determine if unit should leave a corpse
function should_create_corpse(entity)
    local unit_type = ecs.get_component(entity, "unit_type")
    if not unit_type then return false end

    -- No corpse for summoned units
    if unit_type.is_summoned then return false end

    -- No corpse for buildings
    if unit_type.is_building then return false end

    -- No corpse for mechanical (check unit data)
    -- if is_mechanical(unit_type.type_id) then return false end

    return true
end

-- Get decay time for unit
function get_decay_time(entity)
    local unit_type = ecs.get_component(entity, "unit_type")
    if not unit_type then return death.DECAY_TIME.NORMAL end

    if unit_type.is_hero then
        return death.DECAY_TIME.HERO
    end

    return death.DECAY_TIME.NORMAL
end
```

---

## Corpse System Flow

```
1. Unit dies (death.kill called)
   └─▶ if should_create_corpse(entity):
       ├─▶ Create corpse entity at death position
       ├─▶ Add corpse component with decay timer
       ├─▶ Add position component (same as death position)
       ├─▶ Add selectable component (for targeting)
       └─▶ If hero: link corpse to ghost

2. Each tick, decay system updates
   └─▶ For each entity with corpse component:
       ├─▶ Decrement decay_timer by dt
       ├─▶ If decay_timer < decay_max * 0.5:
       │   └─▶ Set flesh_remaining = false (skeleton)
       └─▶ If decay_timer <= 0:
           ├─▶ Fire EVENT_UNIT_DECAY
           ├─▶ If linked ghost: notify ghost corpse is gone
           └─▶ Destroy corpse entity

3. Raise Dead / Animate Dead cast
   └─▶ Find valid corpse target
       ├─▶ Check raiseable = true
       ├─▶ Check raised = false
       ├─▶ Mark corpse as raised
       ├─▶ Create undead unit from corpse
       ├─▶ Fire EVENT_CORPSE_RAISED
       └─▶ Destroy corpse entity
```

---

## Undead Faction: Corpse as Resource

The Undead faction treats corpses as a resource:

```lua
-- Raise Dead: Summon skeletons from corpses
-- Requires corpse target, creates 2 skeleton warriors

-- Animate Dead: Raise corpses as temporary units
-- Corpse becomes same unit type, invulnerable, timed life

-- Cannibalize: Consume corpse to heal
-- Ghoul eats corpse, restores HP over time

-- Meat Wagon: Collect and launch corpses
-- Stores corpses, can launch at location, creates corpse pile
```

---

## Acceptance Criteria

- [x] `corpse` component registered with ECS
- [x] `create_corpse()` spawns corpse at death location
- [x] Corpse has decay timer that counts down
- [x] Corpse transitions to skeleton at 50% decay
- [x] Corpse removed when decay timer reaches 0
- [x] `EVENT_UNIT_DECAY` fires on decay complete
- [x] Summoned units don't leave corpses
- [x] Corpses targetable by necromancy spells
- [x] `raise_corpse()` marks corpse as raised
- [x] Raised corpses can't be raised again
- [x] Heroes' corpses link to their ghosts
- [x] Unit tests for corpse creation
- [x] Unit tests for decay system

---

## Notes

Corpses are a unique entity type in WC3 - they're not living units, not
items, but targetable objects with timers. This implementation treats
them as full ECS entities with specialized components.

The flesh_remaining flag enables visual distinction in rendering:
- Fresh corpse: full model, blood, etc.
- Skeleton: bones only

Meat Wagon corpse collection is a stretch goal - it requires a "corpse
inventory" mechanic that's unique to that unit.

The corpse system integrates closely with the ghost system (701c) -
hero ghosts need to know where their corpse is for revival positioning.

---

## Implementation Notes

**Implemented:** 2026-01-07

### Integration with death.lua

The corpse system was integrated directly into `src/runtime/systems/death.lua`
rather than creating a separate module. This provides:
- Single require for all death-related functionality
- Shared access to event firing
- Unified tracking between dead units and corpses

### Components Added

- `corpse` - Tracks decay state, targeting flags, and unit origin

### API Implemented

**Creation:**
- `create_corpse(dead_entity)` - Create corpse from dead unit
- `create_corpse_at(x, y, type_id, decay_time)` - Create corpse at position

**Queries:**
- `is_corpse(entity)` - Check if entity is a corpse
- `is_raiseable(corpse)` - Check if can be raised
- `is_fresh(corpse)` - Check if has flesh (not skeleton)
- `get_corpse(dead_entity)` - Get corpse for dead unit
- `get_corpse_unit(corpse)` - Get original unit for corpse
- `find_corpses_in_range(x, y, radius, filter)` - Spatial query

**Decay:**
- `get_decay_remaining(corpse)` - Seconds until decay
- `get_decay_progress(corpse)` - Progress 0.0-1.0

**Modification:**
- `raise_corpse(corpse, raiser)` - Mark as raised
- `consume_corpse(corpse)` - Remove (Cannibalize)
- `link_corpse_to_ghost(corpse, ghost)` - Link for revival

### Systems Registered

- `corpse_decay` (priority 60) - Decrements timers, transitions to skeleton, removes on complete

### Test Coverage

25 additional tests added for corpse system:
- Component registration
- Corpse creation (from unit and at position)
- Summoned unit filtering
- Query functions
- Decay timer and progress
- Raise and consume operations
- Spatial queries with filters
- Ghost linking

### Design Decisions

- Corpses are separate entities from dead units (allows independent lifetime)
- Two-way tracking via module tables (cleared on reset_tracking())
- Corpse decay system fires EVENT_UNIT_DECAY before removal
- Flesh-to-skeleton transition at 50% decay for visual feedback
