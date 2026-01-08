# Issue 701d: Resurrection Mechanics

**Phase:** 7 - Gameplay: Core Mechanics
**Type:** Implementation
**Priority:** High
**Parent:** 701-death-and-resurrection-system.md
**Dependencies:** 701a (Death state), 701c (Ghost form)

---

## Current Behavior

Dead units stay dead forever. There is no mechanism to bring them back.
Heroes cannot be revived at altars. Resurrection spells don't exist.

---

## Intended Behavior

Multiple resurrection paths:
1. **Altar Revival** - Click altar, pay gold, wait timer, hero revives
2. **Spell Resurrection** - Cast spell on corpse (Resurrection, Animate Dead)
3. **Item Auto-Revive** - Ankh of Reincarnation triggers on death
4. All paths fire appropriate events and restore unit state

---

## Suggested Implementation Steps

1. Register `reviving` component for altar revival:
   ```lua
   ecs.register_component("reviving", {
       altar = nil,           -- Altar entity handling revival
       time_remaining = 0,    -- Seconds until revived
       gold_cost = 0,         -- Gold committed to revival
       hero_level = 1,        -- Hero level (affects time/cost)
   })
   ```

2. Implement altar revival system:
   - `death.begin_altar_revival(altar, hero_ghost)`
   - Validate altar owned by same player
   - Deduct gold cost immediately
   - Start revival timer
   - Fire `EVENT_HERO_REVIVE_START`

3. Implement revival timer system:
   - Each tick, decrement `time_remaining`
   - When timer hits 0, complete revival
   - Fire `EVENT_HERO_REVIVED`
   - Remove ghost, restore hero

4. Implement instant resurrection:
   - `death.revive(entity, x, y, hp_percent)`
   - For spell-based resurrection
   - Fire `EVENT_UNIT_RESURRECTED`

5. Implement auto-revive items:
   - Hook into death event
   - Check for Ankh in inventory
   - Consume item and revive immediately

6. Add revival cost/time formulas:
   ```lua
   function get_revival_time(hero_level)
       return 55 + (hero_level - 1) * 5
   end
   function get_revival_cost(hero_level)
       return hero_level * 100
   end
   ```

---

## Component Definition

```lua
-- Revival in progress (attached to ghost during altar revival)
ecs.register_component("reviving", {
    altar = nil,           -- Entity ID of altar handling revival
    time_remaining = 0,    -- Seconds until revived
    time_total = 0,        -- Total revival time (for progress bar)
    gold_cost = 0,         -- Gold locked for revival
    hero_level = 1,        -- Hero level at death
})
```

---

## Event Definitions

```lua
-- Add to events.lua
events.EVENT.HERO_REVIVE_START = 22
events.EVENT.HERO_REVIVED = 23
events.EVENT.UNIT_RESURRECTED = 24

-- Hero revive start context
{
    event_id = events.EVENT.HERO_REVIVE_START,
    unit = hero_entity,         -- Original hero entity
    ghost = ghost_entity,       -- Ghost being revived
    altar = altar_entity,       -- Altar performing revival
    time = revival_time,        -- Total revival time
    gold = gold_cost,           -- Gold spent
}

-- Hero revived context
{
    event_id = events.EVENT.HERO_REVIVED,
    unit = hero_entity,         -- Revived hero
    altar = altar_entity,       -- Altar that revived (nil for spell)
    revive_x = x,
    revive_y = y,
}

-- Unit resurrected (non-altar, spell-based)
{
    event_id = events.EVENT.UNIT_RESURRECTED,
    unit = resurrected_entity,
    reviver = casting_unit,
    ability_id = resurrection_spell,
}
```

---

## API Design

```lua
local death = require("runtime.systems.death")

-- Altar revival
death.begin_altar_revival(altar, ghost)  -- Start revival process
death.cancel_altar_revival(altar)         -- Cancel and refund gold
death.get_revival_progress(ghost)         -- Returns 0.0-1.0 progress
death.get_revival_time_remaining(ghost)   -- Seconds remaining

-- Instant revival
death.revive(entity, x, y, hp_percent)  -- Revive at position with HP%
death.revive_at_corpse(entity)          -- Revive at corpse location

-- Formula queries
death.get_revival_time(hero_level)      -- Base time for level
death.get_revival_cost(hero_level)      -- Gold cost for level

-- Altar queries
death.is_altar(entity)                  -- Check if entity is an altar
death.can_revive_at(altar, ghost)       -- Check if altar can revive ghost
death.get_altar_queue(altar)            -- Get revival queue for altar
```

---

## Revival Formulas (WC3)

```lua
-- Revival time in seconds
-- Base 55 seconds + 5 per level after 1
function death.get_revival_time(hero_level)
    return 55 + (hero_level - 1) * 5
end

-- Revival gold cost
-- 100 gold per hero level
function death.get_revival_cost(hero_level)
    return hero_level * 100
end

-- Example:
-- Level 1: 55 seconds, 100 gold
-- Level 5: 75 seconds, 500 gold
-- Level 10: 100 seconds, 1000 gold
```

---

## Altar Revival Flow

```
1. Player right-clicks altar with hero ghost selected
   └─▶ death.begin_altar_revival(altar, ghost)
       ├─▶ Validate: altar owned by player
       ├─▶ Validate: player has enough gold
       ├─▶ Deduct gold from player
       ├─▶ Add "reviving" component to ghost
       ├─▶ Fire EVENT_HERO_REVIVE_START
       └─▶ Start revival timer

2. Each tick, revival system updates
   └─▶ Decrement time_remaining
       └─▶ If time_remaining <= 0:
           ├─▶ Get original_data from ghost
           ├─▶ Remove dead component from hero
           ├─▶ Restore hero stats from original_data
           ├─▶ Position hero at altar
           ├─▶ Remove ghost entity
           ├─▶ Fire EVENT_HERO_REVIVED
           └─▶ Hero is alive again!
```

---

## Auto-Revive Items

Items that trigger on death (Ankh of Reincarnation):

```lua
-- In death event handler
events.register(events.EVENT.UNIT_DEATH, function(ctx)
    local unit = ctx.dying_unit
    local hero = ecs.get_component(unit, "hero")
    if not hero then return end

    -- Check inventory for auto-revive items
    for slot, item_entity in ipairs(hero.inventory) do
        if item_entity then
            local item = ecs.get_component(item_entity, "item")
            if item and item.item_id == "ankh" then
                -- Consume item and revive immediately
                death.consume_item(item_entity)
                death.revive(unit, ctx.death_x, ctx.death_y, 1.0)
                return  -- Cancel normal death
            end
        end
    end
end)
```

---

## Acceptance Criteria

- [x] `reviving` component registered with ECS
- [x] `begin_altar_revival()` starts revival with timer
- [x] `cancel_altar_revival()` refunds gold
- [x] Revival timer counts down each tick
- [x] Hero revives when timer reaches 0
- [x] `EVENT_HERO_REVIVE_START` fires when revival begins
- [x] `EVENT_HERO_REVIVED` fires on completion
- [x] `revive()` for instant spell-based resurrection
- [x] Revival time/cost formulas match WC3
- [x] Ghost and corpse cleaned up on revival
- [x] Unit tests for revival flow
- [x] Unit tests for cancellation and refund

---

## Notes

Altar revival is the primary hero resurrection path in WC3. The timer
creates strategic tension - protect your altar, time your revivals.

Multiple altars can queue revivals, but each hero can only be reviving
at one altar at a time.

The auto-revive item system hooks into death events, allowing it to
intercept and cancel normal death processing. This is similar to how
WC3's Ankh works - the hero appears to die but immediately returns.

Spell-based resurrection (Paladin's Resurrection, etc.) uses the instant
revive path without altar involvement.

---

## Implementation Notes

**Implemented:** 2026-01-07

### Integration with death.lua

The resurrection mechanics were integrated directly into `src/runtime/systems/death.lua`
alongside death, corpse, and ghost systems for unified access.

### Components Added

- `reviving` - Tracks altar revival state (altar, time_remaining, time_total, gold_cost, hero_level)

### API Implemented

**Formula Functions:**
- `get_revival_time(hero_level)` - Base 55 + (level-1) * 5 seconds
- `get_revival_cost(hero_level)` - Level * 100 gold

**Altar Functions:**
- `is_altar(entity)` - Check if entity can revive heroes
- `can_revive_at(altar, ghost)` - Validate revival prerequisites
- `get_altar_queue(altar)` - Get ghosts being revived at altar

**Revival Functions:**
- `begin_altar_revival(altar, ghost, gold_paid)` - Start timed revival
- `cancel_altar_revival(ghost)` - Cancel and get gold refund
- `get_revival_progress(ghost)` - Progress 0.0-1.0
- `get_revival_time_remaining(ghost)` - Seconds until complete
- `is_reviving(ghost)` - Check if reviving
- `get_reviving_altar(ghost)` - Get altar ghost is at

**Hero Revival:**
- `revive_hero(hero, x, y, hp_percent)` - Instant spell-based revival
- `revive_at_corpse(hero, hp_percent)` - Revive at corpse location

### Systems Registered

- `revival` (priority 65) - Decrements revival timers, completes revival when timer hits 0

### Test Coverage

32 new tests for resurrection mechanics:
- Component registration
- Revival formula tests (level 1, 5, 10)
- Altar identification and validation
- Ownership checks (same player requirement)
- Begin altar revival (adds component, fires event, sets timer)
- Cancel revival (gold refund, queue cleanup)
- Revival progress queries
- Hero revival (position, HP, ghost/corpse cleanup)
- Revive at corpse position

### Design Decisions

- Altar detection via `is_altar` flag in unit_type or explicit altar component
- Revival uses ghost's preserved data for hero level
- Gold tracking passed in for validation (deduction handled by economy system)
- Revival queue per altar supports multiple heroes (WC3 behavior)
- `revive_hero()` cancels any in-progress altar revival
- Corpse and ghost both destroyed on successful revival
- Revival system priority 65 runs after corpse decay (60)
