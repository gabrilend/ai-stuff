# Issue 701a: Death State and Events

**Phase:** 7 - Gameplay: Core Mechanics
**Type:** Implementation
**Priority:** Critical
**Parent:** 701-death-and-resurrection-system.md
**Dependencies:** 402 (ECS), 308 (Events)

---

## Current Behavior

Units exist with health in the stats component but have no formal death state.
When health reaches zero, nothing happens - the unit continues to exist.
There are no death events fired to notify triggers.

---

## Intended Behavior

Units can transition to a formal "dead" state:
1. When hp <= 0, unit is marked dead via the `dead` component
2. `EVENT_UNIT_DEATH` fires with killer context
3. `EVENT_HERO_DEATH` fires additionally for heroes
4. Dead units are excluded from normal queries (combat, selection, etc.)
5. The `kill()` API provides programmatic death

---

## Suggested Implementation Steps

1. Register the `dead` component in ECS:
   ```lua
   ecs.register_component("dead", {
       death_time = 0,      -- Game time when died
       killer = nil,        -- Entity that dealt killing blow
       cause = "damage",    -- "damage", "spell", "trigger", "remove"
   })
   ```

2. Add hero-specific death event to events.lua:
   ```lua
   events.EVENT.HERO_DEATH = 21  -- After UNIT_DEATH = 20
   ```

3. Add `hero_died()` helper to events.lua that fires both events

4. Create `src/runtime/systems/death.lua` with:
   - `death.kill(entity, killer, cause)` - mark entity dead and fire events
   - `death.is_dead(entity)` - check if entity has dead component
   - `death.time_since_death(entity)` - get time elapsed since death
   - `death.get_killer(entity)` - get the killing entity

5. Register death system to run each tick:
   - Check entities with `stats` component
   - If hp <= 0 and not dead, call kill()

6. Add query helper to exclude dead entities:
   - Modify common queries to skip dead entities
   - Or provide `query_living()` variant

---

## Component Definition

```lua
-- Death state (attached when unit dies)
ecs.register_component("dead", {
    death_time = 0,      -- Game time when died (from gameloop.get_time())
    killer = nil,        -- Entity ID that dealt killing blow (nil for environment)
    cause = "damage",    -- Death cause: "damage", "spell", "trigger", "remove", "decay"
})
```

---

## API Design

```lua
local death = require("runtime.systems.death")

-- Query functions
death.is_dead(entity)           -- Returns true if entity has dead component
death.time_since_death(entity)  -- Seconds since death, or nil if alive
death.get_killer(entity)        -- Entity that killed this one, or nil
death.get_cause(entity)         -- Death cause string, or nil if alive

-- Action functions
death.kill(entity, killer, cause)  -- Mark entity as dead, fire events
death.remove(entity)               -- Remove entity without death events (cleanup)
```

---

## Event Definitions

```lua
-- Already exists in events.lua:
events.EVENT.UNIT_DEATH = 20

-- Add to events.lua:
events.EVENT.HERO_DEATH = 21

-- Context for death events:
{
    event_id = events.EVENT.UNIT_DEATH,  -- or HERO_DEATH
    unit = dying_entity,
    triggering_unit = dying_entity,
    dying_unit = dying_entity,
    killing_unit = killer_entity,  -- may be nil
    killer = killer_entity,
    cause = "damage",  -- "damage", "spell", "trigger", "remove"
}
```

---

## Acceptance Criteria

- [x] `dead` component registered with ECS
- [x] `death.kill()` adds dead component and fires events
- [x] `death.is_dead()` correctly identifies dead entities
- [x] UNIT_DEATH event fires for all unit deaths
- [x] HERO_DEATH event fires additionally for heroes
- [x] Death system auto-kills entities when hp <= 0
- [x] Unit tests validate death state transitions
- [x] Unit tests validate event firing

---

## Notes

The death system deliberately separates "marking dead" from "creating corpse" and
"creating ghost". This allows:
- Units that die without leaving corpses (summoned units)
- Deaths that don't create ghosts (non-heroes)
- Custom death handling in triggers (e.g., prevent death, resurrect immediately)

The `cause` field enables different handling:
- "damage" - normal combat death
- "spell" - killed by spell effect (Death Coil, etc.)
- "trigger" - killed by map trigger (instakill)
- "remove" - removed from game (doesn't fire events)
- "decay" - corpse finished decaying (cleanup)

---

## Implementation Notes

**Implemented:** 2026-01-07

### Files Created

- `src/runtime/systems/death.lua` - Core death system module
- `src/tests/test_death.lua` - 36 test cases (all passing)

### Implementation Details

1. **Components Registered:**
   - `dead` - Tracks death state (death_time, killer, cause)
   - `world_layer` - Tracks mortal/spirit layer (for 701b integration)

2. **Event Types Added:**
   - `HERO_DEATH = 21` - Fires additionally for heroes
   - `HERO_REVIVE_START = 22` - For 701d integration
   - `HERO_REVIVED = 23` - For 701d integration
   - `UNIT_RESURRECTED = 24` - For 701d integration
   - `UNIT_DECAY = 25` - For 701e integration
   - `CORPSE_RAISED = 26` - For 701e integration

3. **API Implemented:**
   - Query: `is_dead()`, `is_alive()`, `time_since_death()`, `get_killer()`, `get_cause()`
   - Layer: `get_layer()`, `is_in_spirit_world()`, `send_to_spirit_world()`, `return_to_mortal_world()`
   - Actions: `kill()`, `remove()`, `revive()`
   - Helpers: `query_living()`, `count_dead()`, `count_living()`

4. **Death Check System:**
   - Registered as ECS system with priority 50
   - Auto-kills entities when stats.hp <= 0
   - Combat system should call `death.kill()` directly for killer attribution

### Design Decisions

- Layer system integrated early for 701b compatibility
- Events added proactively for 701d/701e integration
- `revive()` basic implementation included (full altar system in 701d)
- REMOVE cause skips events for silent cleanup
