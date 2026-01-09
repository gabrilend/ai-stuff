# Issue 702a: Core Profession Component and Skill System

**Phase:** 7 - Gameplay: Core Mechanics
**Type:** Feature
**Priority:** Critical
**Dependencies:** 402 (ECS), 406 (Resources)

---

## Current Behavior

No profession system exists. Entities cannot have professions, track skill
levels, or gain skill through actions.

---

## Intended Behavior

A core profession framework that provides:
- Profession component attachable to any entity
- Skill level tracking with configurable max
- Skill-up mechanics based on action difficulty
- Profession type registry for defining new professions
- Mode-agnostic design (works for both WoW and WC3 configurations)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    PROFESSION CORE                               │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                 Profession Registry                       │   │
│  │                                                          │   │
│  │  Defines profession types: mining, blacksmithing, etc.   │   │
│  │  Stores metadata: category, type, skill caps             │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                 Profession Component                      │   │
│  │                                                          │   │
│  │  Attached to entities (players, NPCs, buildings)         │   │
│  │  Tracks: learned professions, skill levels, cooldowns    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Skill System                           │   │
│  │                                                          │   │
│  │  Calculates skill-ups, difficulty colors, success rates  │   │
│  │  Configurable formulas for WoW vs WC3 vs custom          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Profession Registry

The registry defines all available profession types:

```lua
-- {{{ Profession type schema
local profession_schema = {
    -- Identity
    id = "blacksmithing",
    name = "Blacksmithing",
    description = "Forge weapons and armor from metal.",
    icon = "icon_blacksmithing",

    -- Classification
    type = "crafting",       -- gathering, crafting, service
    category = "primary",    -- primary, secondary (WoW concept)

    -- Skill configuration
    skill_max_default = 300, -- Default cap (mode can override)
    skill_start = 1,         -- Starting skill when learned

    -- Requirements to learn
    learn_requirements = {
        level = 5,           -- Entity level required
        cost = {gold = 10},  -- Cost to learn
        prerequisites = {},   -- Other professions required
    },

    -- Limits
    exclusive_with = {},     -- Can't have both (e.g., armorsmith/weaponsmith)

    -- Flags
    flags = {
        requires_trainer = true,   -- Must learn from trainer
        can_unlearn = true,        -- Can be forgotten
        has_specialization = true, -- Has spec choices
    },
}
-- }}}

-- {{{ Registry implementation
local profession_registry = {}
local registered_professions = {}

function profession_registry.register(definition)
    if registered_professions[definition.id] then
        error("Profession already registered: " .. definition.id)
    end

    -- Validate required fields
    assert(definition.id, "Profession requires id")
    assert(definition.name, "Profession requires name")
    assert(definition.type, "Profession requires type")

    -- Apply defaults
    definition.skill_max_default = definition.skill_max_default or 300
    definition.skill_start = definition.skill_start or 1
    definition.category = definition.category or "primary"

    registered_professions[definition.id] = definition
end

function profession_registry.get(profession_id)
    return registered_professions[profession_id]
end

function profession_registry.get_all()
    return registered_professions
end

function profession_registry.get_by_type(profession_type)
    local result = {}
    for id, def in pairs(registered_professions) do
        if def.type == profession_type then
            result[id] = def
        end
    end
    return result
end

function profession_registry.get_by_category(category)
    local result = {}
    for id, def in pairs(registered_professions) do
        if def.category == category then
            result[id] = def
        end
    end
    return result
end
-- }}}
```

---

## Profession Component

The ECS component attached to entities:

```lua
-- {{{ Profession component
ecs.register_component("professions", {
    -- Learned professions: profession_id -> profession_data
    learned = {},

    -- Configuration (set by mode)
    config = {
        primary_limit = 2,      -- Max primary professions (nil = no limit)
        secondary_limit = nil,  -- Max secondary professions
        skill_formula = "wow",  -- "wow", "wc3", "linear", "custom"
    },
})

-- {{{ Profession data structure (per learned profession)
--[[
learned["blacksmithing"] = {
    skill_current = 215,
    skill_max = 300,           -- Current cap (may be below absolute max)
    skill_tier = "artisan",    -- Current tier name

    -- Timestamps
    learned_at = 1234567890,
    last_skillup_at = 1234567900,

    -- Statistics
    total_skillups = 214,
    actions_performed = 1523,

    -- Specialization (if applicable)
    specialization = "armorsmith",

    -- Cooldowns (profession-wide)
    cooldowns = {
        transmute = 1234567890 + 86400,  -- Next available time
    },

    -- Flags
    is_active = true,          -- Currently selected/usable
}
]]
-- }}}
-- }}}
```

---

## Skill System

Core skill calculations:

```lua
-- {{{ Skill level operations
local skill_system = {}

-- {{{ get_skill
function skill_system.get_skill(entity, profession_id)
    local prof_comp = ecs.get_component(entity, "professions")
    if not prof_comp then return 0 end

    local learned = prof_comp.learned[profession_id]
    if not learned then return 0 end

    return learned.skill_current
end
-- }}}

-- {{{ set_skill
function skill_system.set_skill(entity, profession_id, new_skill)
    local prof_comp = ecs.get_component(entity, "professions")
    if not prof_comp then return false end

    local learned = prof_comp.learned[profession_id]
    if not learned then return false end

    -- Clamp to valid range
    new_skill = math.max(0, math.min(new_skill, learned.skill_max))
    learned.skill_current = new_skill

    return true
end
-- }}}

-- {{{ get_skill_max
function skill_system.get_skill_max(entity, profession_id)
    local prof_comp = ecs.get_component(entity, "professions")
    if not prof_comp then return 0 end

    local learned = prof_comp.learned[profession_id]
    if not learned then return 0 end

    return learned.skill_max
end
-- }}}

-- {{{ set_skill_max
function skill_system.set_skill_max(entity, profession_id, new_max)
    local prof_comp = ecs.get_component(entity, "professions")
    if not prof_comp then return false end

    local learned = prof_comp.learned[profession_id]
    if not learned then return false end

    learned.skill_max = new_max
    return true
end
-- }}}

-- {{{ modify_skill
function skill_system.modify_skill(entity, profession_id, delta)
    local current = skill_system.get_skill(entity, profession_id)
    return skill_system.set_skill(entity, profession_id, current + delta)
end
-- }}}
-- }}}
```

---

## Skill-Up Mechanics

The heart of profession progression:

```lua
-- {{{ Skill-up system
local skillup = {}

-- {{{ Difficulty thresholds (WoW-style)
-- Given action_skill (recipe/node skill), calculate difficulty color
function skillup.get_difficulty(current_skill, action_skill, difficulty_table)
    -- difficulty_table = {orange=X, yellow=Y, green=Z, gray=W}
    -- These are the skill levels at which color changes

    if not difficulty_table then
        -- Default: orange until +15, yellow until +30, green until +45, gray after
        difficulty_table = {
            orange = action_skill,
            yellow = action_skill + 15,
            green = action_skill + 30,
            gray = action_skill + 45,
        }
    end

    if current_skill < difficulty_table.orange then
        return "red", 0      -- Cannot perform
    elseif current_skill < difficulty_table.yellow then
        return "orange", 1.0  -- Always skill-up
    elseif current_skill < difficulty_table.green then
        return "yellow", 0.75 -- High chance
    elseif current_skill < difficulty_table.gray then
        return "green", 0.25  -- Low chance
    else
        return "gray", 0      -- No skill-up
    end
end
-- }}}

-- {{{ Attempt skill-up
function skillup.try_skillup(entity, profession_id, action_skill, difficulty_table)
    local current = skill_system.get_skill(entity, profession_id)
    local max = skill_system.get_skill_max(entity, profession_id)

    -- Already at cap
    if current >= max then
        return false, "at_cap"
    end

    local color, chance = skillup.get_difficulty(current, action_skill, difficulty_table)

    -- Cannot perform action
    if color == "red" then
        return false, "too_low"
    end

    -- No skill-up possible (gray)
    if chance <= 0 then
        return false, "gray"
    end

    -- Roll for skill-up
    if math.random() <= chance then
        skill_system.modify_skill(entity, profession_id, 1)

        -- Update statistics
        local prof_comp = ecs.get_component(entity, "professions")
        local learned = prof_comp.learned[profession_id]
        learned.total_skillups = (learned.total_skillups or 0) + 1
        learned.last_skillup_at = os.time()

        -- Fire event
        events.fire("EVENT_SKILL_UP", {
            entity = entity,
            profession = profession_id,
            old_skill = current,
            new_skill = current + 1,
            max_skill = max,
        })

        return true, "success"
    end

    return false, "failed_roll"
end
-- }}}

-- {{{ Alternative formulas
skillup.formulas = {
    -- WoW-style: orange/yellow/green/gray with chances
    wow = function(current, action_skill)
        return skillup.get_difficulty(current, action_skill)
    end,

    -- WC3-style: binary (can do or can't, always succeeds)
    wc3 = function(current, required_skill)
        if current >= required_skill then
            return "green", 0  -- Can do, no skill-up (upgrades grant levels)
        else
            return "red", 0    -- Cannot do
        end
    end,

    -- Linear: always skill-up until cap
    linear = function(current, action_skill)
        if current < action_skill then
            return "red", 0
        else
            return "yellow", 1.0
        end
    end,

    -- Custom: user-defined function
    custom = nil,
}
-- }}}
-- }}}
```

---

## Profession Management API

High-level operations:

```lua
-- {{{ Profession management
local professions = {}

-- {{{ learn
function professions.learn(entity, profession_id)
    local prof_comp = ecs.get_component(entity, "professions")
    if not prof_comp then
        error("Entity has no professions component")
    end

    -- Check if already learned
    if prof_comp.learned[profession_id] then
        return false, "already_learned"
    end

    -- Get profession definition
    local def = profession_registry.get(profession_id)
    if not def then
        return false, "unknown_profession"
    end

    -- Check primary limit
    if def.category == "primary" and prof_comp.config.primary_limit then
        local primary_count = 0
        for id, _ in pairs(prof_comp.learned) do
            local other_def = profession_registry.get(id)
            if other_def and other_def.category == "primary" then
                primary_count = primary_count + 1
            end
        end

        if primary_count >= prof_comp.config.primary_limit then
            return false, "primary_limit"
        end
    end

    -- Check prerequisites
    if def.learn_requirements and def.learn_requirements.prerequisites then
        for _, prereq in ipairs(def.learn_requirements.prerequisites) do
            if not prof_comp.learned[prereq] then
                return false, "missing_prereq", prereq
            end
        end
    end

    -- Check exclusivity
    if def.exclusive_with then
        for _, excl in ipairs(def.exclusive_with) do
            if prof_comp.learned[excl] then
                return false, "exclusive", excl
            end
        end
    end

    -- Learn the profession
    prof_comp.learned[profession_id] = {
        skill_current = def.skill_start or 1,
        skill_max = def.skill_max_default or 300,
        skill_tier = "apprentice",
        learned_at = os.time(),
        last_skillup_at = nil,
        total_skillups = 0,
        actions_performed = 0,
        specialization = nil,
        cooldowns = {},
        is_active = true,
    }

    -- Fire event
    events.fire("EVENT_PROFESSION_LEARNED", {
        entity = entity,
        profession = profession_id,
    })

    return true, "success"
end
-- }}}

-- {{{ unlearn
function professions.unlearn(entity, profession_id)
    local prof_comp = ecs.get_component(entity, "professions")
    if not prof_comp then return false end

    if not prof_comp.learned[profession_id] then
        return false, "not_learned"
    end

    local def = profession_registry.get(profession_id)
    if def and def.flags and not def.flags.can_unlearn then
        return false, "cannot_unlearn"
    end

    -- Store old data for event
    local old_data = prof_comp.learned[profession_id]

    -- Remove profession
    prof_comp.learned[profession_id] = nil

    -- Fire event
    events.fire("EVENT_PROFESSION_UNLEARNED", {
        entity = entity,
        profession = profession_id,
        old_skill = old_data.skill_current,
    })

    return true, "success"
end
-- }}}

-- {{{ has
function professions.has(entity, profession_id)
    local prof_comp = ecs.get_component(entity, "professions")
    if not prof_comp then return false end

    return prof_comp.learned[profession_id] ~= nil
end
-- }}}

-- {{{ get_all
function professions.get_all(entity)
    local prof_comp = ecs.get_component(entity, "professions")
    if not prof_comp then return {} end

    local result = {}
    for id, data in pairs(prof_comp.learned) do
        result[id] = {
            skill = data.skill_current,
            skill_max = data.skill_max,
            tier = data.skill_tier,
            specialization = data.specialization,
        }
    end
    return result
end
-- }}}

-- {{{ get_primary_count
function professions.get_primary_count(entity)
    local prof_comp = ecs.get_component(entity, "professions")
    if not prof_comp then return 0 end

    local count = 0
    for id, _ in pairs(prof_comp.learned) do
        local def = profession_registry.get(id)
        if def and def.category == "primary" then
            count = count + 1
        end
    end
    return count
end
-- }}}

-- {{{ can_learn
function professions.can_learn(entity, profession_id)
    local success, reason = professions.learn(entity, profession_id)
    -- Undo if it succeeded (just checking)
    if success then
        professions.unlearn(entity, profession_id)
    end
    return success, reason
end
-- }}}
-- }}}
```

---

## Cooldown System

Profession-level cooldowns (e.g., transmutes):

```lua
-- {{{ Cooldown management
local cooldowns = {}

function cooldowns.set(entity, profession_id, cooldown_name, duration)
    local prof_comp = ecs.get_component(entity, "professions")
    if not prof_comp then return false end

    local learned = prof_comp.learned[profession_id]
    if not learned then return false end

    learned.cooldowns[cooldown_name] = os.time() + duration
    return true
end

function cooldowns.get_remaining(entity, profession_id, cooldown_name)
    local prof_comp = ecs.get_component(entity, "professions")
    if not prof_comp then return 0 end

    local learned = prof_comp.learned[profession_id]
    if not learned then return 0 end

    local expires = learned.cooldowns[cooldown_name]
    if not expires then return 0 end

    local remaining = expires - os.time()
    return remaining > 0 and remaining or 0
end

function cooldowns.is_ready(entity, profession_id, cooldown_name)
    return cooldowns.get_remaining(entity, profession_id, cooldown_name) <= 0
end

function cooldowns.clear(entity, profession_id, cooldown_name)
    local prof_comp = ecs.get_component(entity, "professions")
    if not prof_comp then return false end

    local learned = prof_comp.learned[profession_id]
    if not learned then return false end

    learned.cooldowns[cooldown_name] = nil
    return true
end
-- }}}
```

---

## Events

```lua
events.register("EVENT_PROFESSION_LEARNED")    -- Profession added
events.register("EVENT_PROFESSION_UNLEARNED")  -- Profession removed
events.register("EVENT_SKILL_UP")              -- Skill increased
events.register("EVENT_SKILL_CAP_INCREASED")   -- Max skill raised (tier up)
events.register("EVENT_PROFESSION_COOLDOWN")   -- Cooldown started
```

---

## Standard Profession Definitions

```lua
-- {{{ Built-in profession types
local PROFESSION_TYPES = {
    -- Gathering
    {id = "mining", name = "Mining", type = "gathering", category = "primary"},
    {id = "herbalism", name = "Herbalism", type = "gathering", category = "primary"},
    {id = "skinning", name = "Skinning", type = "gathering", category = "primary"},
    {id = "lumber", name = "Lumberjacking", type = "gathering", category = "secondary"},
    {id = "fishing", name = "Fishing", type = "gathering", category = "secondary"},

    -- Crafting
    {id = "blacksmithing", name = "Blacksmithing", type = "crafting", category = "primary"},
    {id = "leatherworking", name = "Leatherworking", type = "crafting", category = "primary"},
    {id = "tailoring", name = "Tailoring", type = "crafting", category = "primary"},
    {id = "alchemy", name = "Alchemy", type = "crafting", category = "primary"},
    {id = "engineering", name = "Engineering", type = "crafting", category = "primary"},
    {id = "enchanting", name = "Enchanting", type = "crafting", category = "primary"},
    {id = "jewelcrafting", name = "Jewelcrafting", type = "crafting", category = "primary"},
    {id = "inscription", name = "Inscription", type = "crafting", category = "primary"},
    {id = "cooking", name = "Cooking", type = "crafting", category = "secondary"},
    {id = "first_aid", name = "First Aid", type = "crafting", category = "secondary"},

    -- Service (mostly WC3)
    {id = "repair", name = "Repair", type = "service", category = "secondary"},
    {id = "construction", name = "Construction", type = "service", category = "secondary"},
}

-- Register all on init
function professions.init()
    for _, def in ipairs(PROFESSION_TYPES) do
        profession_registry.register(def)
    end
end
-- }}}
```

---

## Module API Summary

```lua
local professions = require("runtime.systems.professions")

-- Registry
professions.registry.register(definition)
professions.registry.get(profession_id)
professions.registry.get_all()
professions.registry.get_by_type(type)
professions.registry.get_by_category(category)

-- Entity operations
professions.learn(entity, profession_id)
professions.unlearn(entity, profession_id)
professions.has(entity, profession_id)
professions.get_all(entity)
professions.can_learn(entity, profession_id)
professions.get_primary_count(entity)

-- Skill operations
professions.skill.get(entity, profession_id)
professions.skill.set(entity, profession_id, value)
professions.skill.get_max(entity, profession_id)
professions.skill.set_max(entity, profession_id, value)
professions.skill.modify(entity, profession_id, delta)

-- Skill-up
professions.skillup.try(entity, profession_id, action_skill)
professions.skillup.get_difficulty(current, action_skill)
professions.skillup.set_formula(formula_name_or_fn)

-- Cooldowns
professions.cooldown.set(entity, profession_id, name, duration)
professions.cooldown.get_remaining(entity, profession_id, name)
professions.cooldown.is_ready(entity, profession_id, name)
professions.cooldown.clear(entity, profession_id, name)
```

---

## Acceptance Criteria

- [ ] Profession registry can define profession types
- [ ] Profession component attaches to entities
- [ ] Entities can learn professions
- [ ] Entities can unlearn professions
- [ ] Primary profession limit enforced
- [ ] Skill levels track correctly
- [ ] Skill-up mechanics work (difficulty colors)
- [ ] Multiple skill formulas supported (WoW, WC3, linear)
- [ ] Cooldowns track per-profession
- [ ] Events fire for learn/unlearn/skillup
- [ ] Unit tests for all core operations

---

## Notes

This is the foundation for the entire profession system. Key design decisions:

1. **Component-based**: Professions attach to entities via ECS, not a separate system
2. **Registry pattern**: Profession types defined separately from instances
3. **Mode-agnostic**: Core doesn't know about WoW vs WC3 details
4. **Configurable**: Skill formulas, limits, and rules are configuration
5. **Event-driven**: All actions emit events for UI/triggers to react

The core purposefully avoids:
- Recipe systems (702d)
- Gathering/crafting actions (702b, 702c)
- Mode-specific rules (702e, 702f)
- UI concerns (702g)

Those are layered on top of this foundation.
