# Issue 702b: Gathering Professions

**Phase:** 7 - Gameplay: Core Mechanics
**Type:** Feature
**Priority:** High
**Dependencies:** 702a (Core), 406 (Resources), 701 (Death - corpses)

---

## Current Behavior

No gathering profession system. WC3 harvesting exists as unit abilities but
isn't abstracted into a profession framework.

---

## Intended Behavior

Gathering professions that extract resources from the world:

| Profession | Resource Type | Source | WC3 Equivalent |
|------------|--------------|--------|----------------|
| Mining | Ore, Stone, Gems | Mineral nodes | Gold Mine |
| Herbalism | Herbs, Plants | Herb nodes | (new) |
| Skinning | Leather, Hides | Beast corpses | (corpse loot) |
| Lumberjacking | Wood, Lumber | Trees | Tree harvesting |
| Fishing | Fish, Treasures | Water | (new) |

---

## Node System

```lua
-- Gatherable node component
ecs.register_component("gatherable", {
    resource_type = "mineral",  -- mineral, plant, corpse, wood, water
    profession_required = "mining",
    skill_required = 1,

    -- Yield
    resource_id = "copper_ore",
    yield_min = 1,
    yield_max = 3,
    bonus_chance = 0.1,  -- Chance for extra/rare drop
    bonus_resource = "rough_stone",

    -- Node state
    remaining_gathers = 3,  -- Times can be gathered before despawn
    respawn_time = 300,     -- Seconds to respawn (0 = never)

    -- Requirements
    tool_required = nil,    -- "mining_pick", nil = hands

    -- Skill gain
    gives_skillup = true,
    skillup_max = 50,       -- Stop giving skill after this level
})
```

---

## Gathering Action Flow

```
[Entity] ──attempts gather──▶ [Node]
    │
    ▼
┌──────────────────────────────────────┐
│ 1. Check profession requirement      │
│ 2. Check skill requirement           │
│ 3. Check tool requirement            │
│ 4. Check node has remaining gathers  │
└──────────────────────────────────────┘
    │
    ▼ (all pass)
┌──────────────────────────────────────┐
│ 5. Play gathering animation/channel  │
│ 6. Calculate yield (skill affects)   │
│ 7. Add resources to inventory        │
│ 8. Try skill-up                      │
│ 9. Decrement node remaining          │
│ 10. Fire EVENT_GATHER_SUCCESS        │
└──────────────────────────────────────┘
```

---

## Profession Definitions

### Mining
```lua
PROFESSION_MINING = {
    id = "mining",
    type = "gathering",
    category = "primary",
    resource_types = {"mineral"},
    tool = "mining_pick",

    -- Skill tiers and what they unlock
    tiers = {
        {skill = 1, nodes = {"copper_vein", "tin_vein"}},
        {skill = 65, nodes = {"silver_vein", "iron_deposit"}},
        {skill = 125, nodes = {"gold_vein", "mithril_deposit"}},
        {skill = 175, nodes = {"truesilver_deposit", "small_thorium"}},
        {skill = 250, nodes = {"rich_thorium_vein"}},
    },
}
```

### Herbalism
```lua
PROFESSION_HERBALISM = {
    id = "herbalism",
    type = "gathering",
    category = "primary",
    resource_types = {"plant"},
    tool = nil,  -- Bare hands

    tiers = {
        {skill = 1, nodes = {"peacebloom", "silverleaf", "earthroot"}},
        {skill = 50, nodes = {"mageroyal", "briarthorn", "swiftthistle"}},
        -- ... etc
    },
}
```

### Skinning
```lua
PROFESSION_SKINNING = {
    id = "skinning",
    type = "gathering",
    category = "primary",
    resource_types = {"corpse"},
    tool = "skinning_knife",

    -- Skinning uses mob level instead of node tiers
    -- skill_required = mob_level * 5
    level_formula = function(mob_level)
        return mob_level * 5
    end,

    -- Yield based on mob type
    yields = {
        beast = {"light_leather", "medium_leather", "heavy_leather"},
        dragonkin = {"dragonscale"},
        demon = {"felcloth"},  -- Not really skinning but...
    },
}
```

### Lumberjacking (WC3-focused)
```lua
PROFESSION_LUMBER = {
    id = "lumber",
    type = "gathering",
    category = "secondary",  -- Always available in WC3
    resource_types = {"wood"},
    tool = nil,  -- Unit ability

    -- WC3 trees have HP, not gather counts
    -- Higher skill = faster gathering
    gather_rate = function(skill_level)
        return 10 + skill_level  -- Lumber per trip
    end,
}
```

### Fishing
```lua
PROFESSION_FISHING = {
    id = "fishing",
    type = "gathering",
    category = "secondary",
    resource_types = {"water"},
    tool = "fishing_pole",

    -- Fishing pools vs open water
    pool_bonus = 3,  -- More fish from pools

    -- Skill affects catch quality
    catch_table = function(skill_level, zone_level)
        -- Returns weighted loot table
    end,
}
```

---

## API Design

```lua
local gathering = require("runtime.systems.gathering")

-- Check if entity can gather from node
gathering.can_gather(entity, node)

-- Perform gathering action
gathering.start_gather(entity, node)
gathering.cancel_gather(entity)
gathering.complete_gather(entity, node)

-- Node management
gathering.create_node(position, node_type, config)
gathering.deplete_node(node)
gathering.respawn_node(node)

-- Queries
gathering.find_nearest_node(entity, profession, max_range)
gathering.get_nodes_in_range(position, radius, profession)
```

---

## Events

```lua
events.register("EVENT_GATHER_START")     -- Begin gathering channel
events.register("EVENT_GATHER_SUCCESS")   -- Resource obtained
events.register("EVENT_GATHER_FAILED")    -- Interrupted or no skill
events.register("EVENT_NODE_DEPLETED")    -- Node used up
events.register("EVENT_NODE_RESPAWNED")   -- Node came back
```

---

## WC3 Mode Specifics

In WC3 mode, gathering is simplified:

```lua
-- WC3 gold gathering
WC3_MINING = {
    id = "gold_harvest",
    skill_required = 0,  -- Any worker can do it
    tool = nil,          -- Built into unit
    channel_time = 0,    -- Instant (travel time is the cost)
    yield = 10,          -- Gold per trip (upgradeable)
}

-- WC3 lumber gathering
WC3_LUMBER = {
    id = "lumber_harvest",
    skill_required = 0,
    tool = nil,
    yield = 10,  -- Lumber per trip
    upgrades = {
        "improved_lumber_harvesting",  -- +10
        "advanced_lumber_harvesting",  -- +10 more
    },
}
```

---

## Acceptance Criteria

- [x] Gatherable nodes can be placed in world
- [x] Entities with profession can gather from nodes
- [x] Skill requirements enforced
- [x] Yield calculated based on skill and node
- [x] Nodes deplete and respawn
- [x] Skill-ups occur on gather
- [x] Mining, Herbalism, Skinning, Lumber, Fishing all work (definitions provided)
- [x] WC3 simplified mode works (gold mine, tree templates)
- [x] Events fire correctly
- [x] Unit tests for gathering logic

---

## Implementation Notes

Implementation completed 2026-01-07.

### Files Created

- `src/runtime/systems/gathering.lua` - Gathering profession system
- `src/tests/test_gathering.lua` - Unit tests (31 tests, all passing)

### Features Implemented

1. **Gatherable Component**
   - `gatherable` component with resource type, profession/skill requirements
   - Yield configuration (min/max, bonus drops)
   - Node state (remaining gathers, depletion, respawn timing)
   - Channel time for gather actions

2. **Gathering State Component**
   - `gathering_state` component tracks current gather action
   - States: IDLE, GATHERING, INTERRUPTED
   - Progress tracking with timestamps

3. **Node Management**
   - `create_node(position, type, config)` - Create from template or custom
   - `deplete_node(node)` - Mark as depleted, schedule respawn
   - `respawn_node(node)` - Restore depleted node
   - `check_respawns()` - Periodic respawn check
   - `get_node_info(node)` - Query node state

4. **Gathering Flow**
   - `can_gather(entity, node)` - Validate profession, skill, availability
   - `start_gather(entity, node)` - Begin gather action
   - `cancel_gather(entity)` - Interrupt gather
   - `complete_gather(entity, node)` - Finish and yield resources
   - `update_progress(entity)` - Track gather progress
   - `is_gather_ready(entity)` - Check completion

5. **Profession Definitions**
   - Mining: 5 tiers, requires mining pick, mineral nodes
   - Herbalism: 5 tiers, bare hands, plant nodes
   - Skinning: Level-based formula (mob_level * 5), requires knife
   - Lumberjacking: WC3-focused, skill affects gather rate
   - Fishing: Pool bonus, catch table function

6. **Node Type Templates**
   - Mining: copper_vein, iron_deposit, mithril_deposit
   - Herbalism: peacebloom, mageroyal
   - Skinning: wolf_corpse
   - WC3: gold_mine (infinite gathers), tree

7. **Events**
   - `GATHER_START`, `GATHER_SUCCESS`, `GATHER_FAILED`, `GATHER_INTERRUPTED`
   - `NODE_DEPLETED`, `NODE_RESPAWNED`, `RARE_FIND`

### Test Summary

| Category | Tests |
|----------|-------|
| Node Management | 7 |
| Gathering Flow | 10 |
| Integration | 5 |
| Node Type Templates | 5 |
| Profession Definitions | 4 |
| **Total** | **31** |

### Deferred Items

- **Spatial queries**: find_nearest_node and get_nodes_in_range need spatial system
- **Tool checks**: Requires inventory system (Issue 406)

---

## Notes

The gathering system is where professions meet the world. Nodes are entities
with the `gatherable` component, making them first-class citizens in the ECS.

This means:
- Nodes can have positions, be targeted, take damage
- Nodes can be created/destroyed by triggers
- Nodes can have custom behavior (trapped herb, guarded mine)
