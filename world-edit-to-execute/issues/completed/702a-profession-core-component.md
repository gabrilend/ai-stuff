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

- [x] Profession component stores skill data correctly
- [x] Skill levels can increase via try_skillup()
- [x] Skill caps limit progression until raised
- [x] Primary profession slots enforced (WoW mode)
- [x] Recipe tracking per profession
- [x] Events fire on skill changes
- [x] Configuration switches between WoW/WC3 modes
- [x] Unit tests for skill calculations

---

## Notes

The skill system is intentionally generic. "Skill" could mean:
- WoW profession skill (Mining 1-300)
- WC3 unit experience with a task
- Custom game mastery levels

The same engine, different numbers.

---

**Status:** Completed
**Dependencies:** 402 (ECS)

---

## Implementation Notes

**Completed 2026-01-01**

### Files Created

1. **src/runtime/systems/professions.lua** (~830 lines)
   - Configuration modes: WoW (2 primary slots, 1-300 skill), WC3 (unlimited, 1-5 levels, XP-based), Custom
   - `PROFESSIONS_DEFAULTS` component with primary/secondary profession tables
   - `create_skill_data()` - creates skill structure with mode-aware initial cap
   - `ensure_fresh_tables()` - fixes ECS metatable inheritance issue for per-entity state
   - Query functions: `get_skill()`, `get_max_skill()`, `has_profession()`, `can_learn_profession()`,
     `get_known_recipes()`, `knows_recipe()`, `get_specialization()`, `get_experience()`, `get_all_professions()`
   - Modification functions: `learn_profession()`, `forget_profession()`, `add_skill()`, `set_skill_cap()`,
     `learn_recipe()`, `set_specialization()`, `add_experience()`
   - Progression functions: `try_skillup()`, `get_skillup_chance()`, `get_difficulty()`
   - Active profession: `set_active()`, `get_active()`
   - Event constants for PROFESSION_LEARNED, SKILL_UP, etc.

2. **src/tests/test_professions.lua** (~620 lines)
   - 42 comprehensive unit tests covering all acceptance criteria
   - Tests configuration modes (WoW/WC3/Custom)
   - Tests learn/forget professions with slot limits
   - Tests skill levels, caps, clamping
   - Tests skillup chance calculations (orange/yellow/green/gray)
   - Tests try_skillup with random roll
   - Tests recipes and specializations
   - Tests XP-based leveling (WC3 mode)
   - Tests active profession tracking

### Key Design Decisions

1. **ECS Metatable Inheritance Fix**: The ECS uses `setmetatable(instance, {__index = defaults})`
   for component instances. This means table fields like `primary` and `secondary` are shared
   by reference across all entities. Fixed with `ensure_fresh_tables()` which uses `rawset()`
   to create per-entity copies on first access.

2. **Mode-Aware Initial Caps**: WoW mode starts at skill_caps[1] (75) requiring training to progress.
   WC3 mode starts at skill_max (5) since progression is XP-based not training-based.

3. **Skill Difficulty Colors**: Based on skill - recipe_skill difference:
   - Orange (diff < 0-9): 100% skillup chance
   - Yellow (diff 10-24): 75% skillup chance
   - Green (diff 25-49): 25% skillup chance
   - Gray (diff 50+): 0% skillup chance

4. **Modifier Order**: Formula is `(base + flat) * (1 + percent/100) * multiplier`
   matching WoW's standard modifier stacking.

### Test Results

```
=== Test Summary ===
Passed: 42
Failed: 0
Total: 42
All tests PASSED!
```
