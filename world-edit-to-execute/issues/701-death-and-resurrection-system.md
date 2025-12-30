# Issue 701: Death and Resurrection System

**Phase:** 7 - Gameplay: Core Mechanics
**Type:** Feature
**Priority:** Critical (life or death, literally)
**Dependencies:** 402 (ECS), 404 (Movement), 308 (Events)

---

## Current Behavior

Units can exist. Units cannot un-exist gracefully. There is no death state,
no spirit world, no resurrection mechanic. Heroes fall in battle and simply
cease to be, with no path back to the mortal realm.

---

## Intended Behavior

A complete death and resurrection system supporting:

1. **Death States** - Units transition to "dead" state, triggering events
2. **Spirit World** - Ethereal plane where spirits exist after death
3. **Ghost Form** - Visible-but-intangible representation of dead units
4. **Resurrection Mechanics** - Multiple paths back to life
5. **Hero Revival** - WC3-style altar revival with gold cost and timer

---

## The Spirit World Model

```
┌─────────────────────────────────────────────────────────┐
│                    MORTAL REALM                         │
│                                                         │
│   [Living Unit] ──death──▶ [Corpse] ──decay──▶ ∅       │
│         ▲                      │                        │
│         │                      │ soul                   │
│    resurrect                   ▼                        │
│         │              ┌──────────────┐                 │
│         │              │ SPIRIT WORLD │                 │
│         │              │              │                 │
│         └──────────────│   [Ghost]    │                 │
│                        │      │       │                 │
│                        │  movement    │                 │
│                        │      ▼       │                 │
│                        │  [At Altar]  │                 │
│                        └──────────────┘                 │
└─────────────────────────────────────────────────────────┘
```

### WC3 Mechanics

- **Heroes**: Die → Ghost at death location → Player clicks altar → Revival timer
- **Units**: Die → Corpse → Decay timer → Gone (or Raise Dead target)
- **Undead Special**: Corpses are resources (Raise Dead, Cannibalize, Meat Wagon)

### WoW Mechanics (for reference/optional mode)

- **Players**: Die → Ghost at graveyard → Run to corpse → Resurrect at corpse
- **Wisps**: Night Elf ghosts are visible wisps that can scout
- **Spirit Healer**: Instant resurrect with resurrection sickness debuff

---

## Suggested Implementation Steps

### Sub-Issue 701a: Death State and Events
- Add `dead` component to ECS
- Add `corpse` component with decay timer
- Fire `EVENT_UNIT_DEATH` when unit dies
- Fire `EVENT_HERO_DEATH` for heroes specifically
- Implement `unit.kill()` and `unit.is_dead()` API

### Sub-Issue 701b: Spirit World Layer
- Create spirit world as parallel coordinate space
- Ghost entities exist in spirit world, invisible to mortal realm
- Spirit world has own movement (faster? floating?)
- Collision disabled between ghosts and living units

### Sub-Issue 701c: Ghost Form Component
- Add `ghost` component with:
  - `linked_corpse`: Entity ID of corpse in mortal realm
  - `linked_unit`: Original unit data (for resurrection)
  - `visible_to`: Who can see this ghost (owner, allies, all)
  - `can_move`: Whether ghost can relocate
- Render ghosts with transparency/glow effect (visual layer concern)

### Sub-Issue 701d: Resurrection Mechanics
- Altar revival system:
  - `altar.begin_revival(hero, gold_cost)`
  - Revival timer based on hero level
  - `EVENT_HERO_REVIVED` on completion
- Spell-based resurrection:
  - `resurrection.cast(caster, target_corpse)`
  - Mana cost, cast time, range
- Item-based resurrection:
  - Ankh of Reincarnation (auto-revive on death)
  - Scroll of Resurrection

### Sub-Issue 701e: Corpse System
- Corpse decay timers (default: 88 seconds for heroes, varies for units)
- Corpse as targetable entity (for Raise Dead, Animate Dead)
- Corpse visibility (bones vs fresh)
- Meat Wagon corpse collection

---

## Component Definitions

```lua
-- Death state
ecs.register_component("dead", {
    death_time = 0,      -- Game time when died
    killer = nil,        -- Entity that dealt killing blow
    cause = "damage",    -- "damage", "spell", "trigger", "remove"
})

-- Corpse (physical remains)
ecs.register_component("corpse", {
    decay_timer = 88.0,  -- Seconds until corpse disappears
    raiseable = true,    -- Can be targeted by raise dead
    flesh_remaining = true, -- false = skeleton only
    original_unit_type = nil,
})

-- Ghost (spirit form)
ecs.register_component("ghost", {
    linked_corpse = nil, -- Entity ID
    original_data = {},  -- Preserved unit state for revival
    in_spirit_world = true,
    visible_to_owner = true,
    visible_to_allies = false,
    visible_to_enemies = false,
    movement_speed = 400, -- Ghosts move faster
})

-- Revival in progress
ecs.register_component("reviving", {
    altar = nil,         -- Altar entity handling revival
    time_remaining = 0,  -- Seconds until revived
    gold_cost = 0,       -- Gold locked for revival
})
```

---

## Event Types

```lua
events.register("EVENT_UNIT_DEATH")      -- Any unit dies
events.register("EVENT_HERO_DEATH")      -- Hero specifically dies
events.register("EVENT_UNIT_DECAY")      -- Corpse finishes decay
events.register("EVENT_HERO_REVIVE_START") -- Altar begins revival
events.register("EVENT_HERO_REVIVED")    -- Hero returns to life
events.register("EVENT_UNIT_RESURRECTED") -- Non-hero brought back
```

---

## API Design

```lua
local death = require("runtime.systems.death")

-- Query
death.is_dead(entity)
death.is_ghost(entity)
death.get_corpse(entity)
death.get_ghost(entity)
death.time_since_death(entity)

-- Actions
death.kill(entity, killer, cause)
death.create_corpse(entity, position)
death.create_ghost(entity, corpse)
death.revive(entity, position, health_percent)
death.destroy_corpse(entity)

-- Altar
death.begin_altar_revival(altar, hero)
death.cancel_altar_revival(altar)
death.get_revival_time(hero_level)
death.get_revival_cost(hero_level)
```

---

## Technical Notes

### Revival Time Formula (WC3)
```lua
function get_revival_time(hero_level)
    -- Base 55 seconds + 5 per level after 1
    return 55 + (hero_level - 1) * 5
end
```

### Revival Gold Cost (WC3)
```lua
function get_revival_cost(hero_level)
    -- 100 gold per level (approximately)
    return hero_level * 100
end
```

### Corpse Decay Times
- Hero corpses: 88 seconds
- Normal unit corpses: 60-88 seconds (varies)
- Summoned unit corpses: Usually don't leave corpses

### Spirit World Coordinate Mapping
The spirit world uses the same (x, y) coordinates as the mortal realm,
but on a separate "layer". Entities in spirit world don't interact with
mortal entities. This could be implemented as:
1. A `layer` field in position component
2. Separate collision queries per layer
3. Visibility filtering in rendering

---

## Related Documents

- issues/402-build-entity-component-system.md (ECS foundation)
- issues/308-build-event-dispatch-system.md (death events)
- issues/015-wow-style-combat-system.md (health/damage)
- WC3 Reforged death mechanics documentation

---

## Acceptance Criteria

- [ ] Units can die and transition to dead state
- [ ] Death events fire correctly (unit death, hero death)
- [ ] Corpses exist for configurable decay time
- [ ] Ghosts created for heroes upon death
- [ ] Ghost movement works in spirit world
- [ ] Altar revival with timer and gold cost
- [ ] Resurrection spells can target corpses
- [ ] Ankh-style auto-revive items work
- [ ] Corpses targetable for necromancy abilities
- [ ] Unit tests for all death/revival mechanics

---

## Notes

*"Death is merely a setback." - Kael'thas Sunstrider*

The death system is foundational for:
- Hero permanence (heroes matter because they can return)
- Undead faction identity (death is a resource)
- Strategic depth (altar placement, revival timing)
- Drama and tension (hero down! revive or fight?)

The spirit world concept elegantly separates ghost logic from combat logic.
Ghosts are essentially in a parallel dimension - same map, different rules.

Consider: Should ghost movement leave a trail? Can ghosts see each other?
Can ghosts communicate? These are polish questions for later phases.

---

## Open Questions

1. **Multiplayer ghosts**: Can enemies see your ghost location? (Probably no)
2. **Ghost abilities**: Can ghosts have any abilities? (WC3: no, WoW: scouting)
3. **Multiple deaths**: What if hero dies during revival? (Cancel revival, new death)
4. **Corpse stacking**: Can multiple corpses occupy same tile? (Yes, for Raise Dead)
