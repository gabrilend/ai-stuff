# Issue 702a: Profession Core Component and Skill System

**Phase:** 7 - Gameplay: Core Mechanics
**Type:** Feature
**Priority:** High
**Dependencies:** 402 (ECS)

---

## Current Behavior

No profession or skill tracking exists for entities.

---

## Intended Behavior

A core `profession` component that tracks:
- Which professions an entity knows
- Current skill level in each profession
- Skill experience and progression
- Active profession slots (WoW: 2 primary + unlimited secondary)

---

## Component Design

```lua
ecs.register_component("professions", {
    -- Primary professions (limited slots, WoW-style)
    primary = {},  -- {[profession_id] = skill_data}

    -- Secondary professions (unlimited, always available)
    secondary = {},  -- {[profession_id] = skill_data}

    -- Profession slots available (WoW: 2 primary)
    primary_slots = 2,

    -- Currently active profession (for gathering actions)
    active_profession = nil,
})

-- Skill data structure
--[[
skill_data = {
    skill_level = 1,        -- Current skill (1-300, 1-450, etc.)
    skill_max = 75,         -- Current cap (needs training to raise)
    experience = 0,         -- XP toward next level (optional)
    specialization = nil,   -- Sub-spec (Armorsmith, Weaponsmith, etc.)
    recipes_known = {},     -- Set of recipe IDs learned
    last_skillup = 0,       -- Game time of last skill increase
}
]]
```

---

## Skill Calculation System

```lua
-- Skill-up chance based on recipe difficulty
-- Orange: 100% skillup
-- Yellow: 75% skillup
-- Green: 25% skillup
-- Gray: 0% skillup

function get_skillup_chance(skill_level, recipe_skill_req)
    local diff = skill_level - recipe_skill_req

    if diff < 0 then return 0 end      -- Can't craft
    if diff < 10 then return 1.0 end   -- Orange
    if diff < 25 then return 0.75 end  -- Yellow
    if diff < 50 then return 0.25 end  -- Green
    return 0                            -- Gray
end

-- WC3 simplified mode: always skill up on success
function get_skillup_chance_wc3(skill_level, action_type)
    return 1.0  -- Always gain experience
end
```

---

## API Design

```lua
local professions = require("runtime.systems.professions")

-- Query
professions.get_skill(entity, profession_id)
professions.get_max_skill(entity, profession_id)
professions.has_profession(entity, profession_id)
professions.can_learn_profession(entity, profession_id)
professions.get_known_recipes(entity, profession_id)

-- Modification
professions.learn_profession(entity, profession_id, initial_skill)
professions.forget_profession(entity, profession_id)
professions.add_skill(entity, profession_id, amount)
professions.set_skill_cap(entity, profession_id, new_max)
professions.learn_recipe(entity, profession_id, recipe_id)

-- Progression
professions.try_skillup(entity, profession_id, difficulty)
professions.get_skillup_chance(entity, profession_id, recipe_skill)
```

---

## Events

```lua
events.register("EVENT_PROFESSION_LEARNED")   -- Entity learned new profession
events.register("EVENT_PROFESSION_FORGOTTEN") -- Entity unlearned profession
events.register("EVENT_SKILL_UP")             -- Skill level increased
events.register("EVENT_SKILL_CAP_RAISED")     -- Training raised cap
events.register("EVENT_RECIPE_LEARNED")       -- New recipe acquired
events.register("EVENT_SPECIALIZATION_CHOSEN") -- Spec selected
```

---

## Configuration Modes

```lua
-- WoW Mode (default)
PROFESSION_CONFIG_WOW = {
    max_primary_slots = 2,
    skill_range = {1, 300},  -- Classic
    skill_caps = {75, 150, 225, 300},  -- Apprentice, Journeyman, Expert, Artisan
    use_experience = false,  -- Direct skill levels
    skillup_formula = "wow_classic",
}

-- WC3 Mode
PROFESSION_CONFIG_WC3 = {
    max_primary_slots = 0,  -- No limit, ability-based
    skill_range = {1, 5},   -- Simple 5-level system
    skill_caps = {1, 2, 3, 4, 5},  -- Each level unlocked by research
    use_experience = true,  -- XP accumulates
    skillup_formula = "always",
}

-- Custom Mode
PROFESSION_CONFIG_CUSTOM = {
    -- User-defined
}
```

---

## Acceptance Criteria

- [ ] Profession component stores skill data correctly
- [ ] Skill levels can increase via try_skillup()
- [ ] Skill caps limit progression until raised
- [ ] Primary profession slots enforced (WoW mode)
- [ ] Recipe tracking per profession
- [ ] Events fire on skill changes
- [ ] Configuration switches between WoW/WC3 modes
- [ ] Unit tests for skill calculations

---

## Notes

The skill system is intentionally generic. "Skill" could mean:
- WoW profession skill (Mining 1-300)
- WC3 unit experience with a task
- Custom game mastery levels

The same engine, different numbers.
