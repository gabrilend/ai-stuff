# Issue 702e: WoW-Mode Profession Configuration

**Phase:** 7 - Gameplay: Core Mechanics
**Type:** Feature
**Priority:** Medium
**Dependencies:** 702a (Core), 702b (Gathering), 702c (Crafting), 702d (Recipes)

---

## Current Behavior

The profession engine is generic. No WoW-specific configuration exists for
full MMO-style profession progression with trainers, skill caps, and
specializations.

---

## Intended Behavior

A complete WoW-style profession configuration that enables:
- 1-300+ skill progression (Classic through expansions)
- Profession trainers with tiered recipes
- Skill cap increases requiring trainers
- Two primary profession limit
- Specialization choices at high skill
- Profession-specific perks and bonuses

---

## Skill Tier System

```lua
-- {{{ WoW skill tiers (Classic baseline)
WOW_SKILL_TIERS = {
    {
        name = "Apprentice",
        skill_range = {1, 75},
        trainer_type = "apprentice",
        level_required = 5,
        cost = { gold = 10 },
    },
    {
        name = "Journeyman",
        skill_range = {76, 150},
        trainer_type = "journeyman",
        level_required = 10,
        cost = { gold = 500 },
    },
    {
        name = "Expert",
        skill_range = {151, 225},
        trainer_type = "expert",
        level_required = 20,
        cost = { gold = 5000 },
    },
    {
        name = "Artisan",
        skill_range = {226, 300},
        trainer_type = "artisan",
        level_required = 35,
        cost = { gold = 50000 },
    },
    -- Expansion tiers (optional)
    {
        name = "Master",
        skill_range = {301, 375},
        trainer_type = "master",
        level_required = 50,
        cost = { gold = 100000 },
        expansion = "tbc",
    },
    {
        name = "Grand Master",
        skill_range = {376, 450},
        trainer_type = "grand_master",
        level_required = 65,
        cost = { gold = 350000 },
        expansion = "wotlk",
    },
}
-- }}}
```

---

## Profession Categories

```lua
-- {{{ WoW profession categories
WOW_PROFESSION_CATEGORIES = {
    -- Primary professions (pick 2)
    PRIMARY = {
        max_count = 2,
        professions = {
            "alchemy",
            "blacksmithing",
            "enchanting",
            "engineering",
            "herbalism",
            "inscription",
            "jewelcrafting",
            "leatherworking",
            "mining",
            "skinning",
            "tailoring",
        },
    },

    -- Secondary professions (unlimited)
    SECONDARY = {
        max_count = nil,  -- No limit
        professions = {
            "cooking",
            "first_aid",
            "fishing",
            "archaeology",  -- Cata+
        },
    },
}
-- }}}
```

---

## Trainer System

```lua
-- {{{ Trainer NPC component
ecs.register_component("profession_trainer", {
    -- What this trainer teaches
    profession = "blacksmithing",
    trainer_tier = "expert",      -- apprentice/journeyman/expert/artisan/etc.

    -- What they can do
    can_train_tier = true,        -- Can increase skill cap
    can_teach_recipes = true,     -- Can teach recipes

    -- Recipe availability
    recipes_taught = {            -- Recipe IDs available here
        "iron_sword",
        "steel_breastplate",
        -- ...
    },

    -- Reputation requirements (optional)
    faction = nil,
    reputation_required = nil,

    -- Specialization trainer (optional)
    specialization = nil,         -- "armorsmith", "weaponsmith", etc.

    -- Dialogue
    greeting = "Greetings, smith. Ready to learn?",
    train_prompt = "Train me in %s.",
    no_skill_response = "You must practice more before I can teach you.",
})
-- }}}

-- {{{ Trainer interaction API
function trainers.open_window(entity, trainer)
    -- Show trainer UI with available recipes
end

function trainers.train_tier(entity, trainer)
    -- Increase skill cap to next tier
    -- Deduct cost
    -- Fire EVENT_TIER_TRAINED
end

function trainers.learn_recipe(entity, trainer, recipe_id)
    -- Teach recipe if requirements met
    -- Deduct cost
    -- Fire EVENT_RECIPE_LEARNED
end
-- }}}
```

---

## Specialization System

```lua
-- {{{ Specializations (Classic examples)
WOW_SPECIALIZATIONS = {
    blacksmithing = {
        skill_required = 200,
        quest_required = true,
        choices = {
            {
                id = "armorsmith",
                name = "Armorsmith",
                description = "Specialize in crafting armor.",
                exclusive_recipes = {"ornate_mithril_breastplate", ...},
                bonus = {armor_stats = "+5%"},
            },
            {
                id = "weaponsmith",
                name = "Weaponsmith",
                description = "Specialize in forging weapons.",
                exclusive_recipes = {"phantom_blade", ...},
                bonus = {weapon_stats = "+5%"},
                -- Further specialization
                sub_specs = {"swordsmith", "axesmith", "hammersmith"},
            },
        },
    },

    engineering = {
        skill_required = 200,
        quest_required = true,
        choices = {
            {
                id = "gnomish",
                name = "Gnomish Engineering",
                theme = "utility",
                exclusive_recipes = {"gnomish_shrink_ray", ...},
            },
            {
                id = "goblin",
                name = "Goblin Engineering",
                theme = "explosives",
                exclusive_recipes = {"goblin_rocket_boots", ...},
            },
        },
    },

    alchemy = {
        skill_required = 300,
        quest_required = true,
        choices = {
            {id = "elixir_master", bonus = "elixirs_proc_extra"},
            {id = "potion_master", bonus = "potions_proc_extra"},
            {id = "transmutation_master", bonus = "transmutes_proc_extra"},
        },
    },

    leatherworking = {
        skill_required = 225,
        choices = {
            {id = "dragonscale", armor_type = "mail"},
            {id = "elemental", armor_type = "leather"},
            {id = "tribal", armor_type = "leather"},
        },
    },
}
-- }}}
```

---

## Profession Perks

```lua
-- {{{ WoW profession bonuses
WOW_PROFESSION_PERKS = {
    mining = {
        passive = {
            id = "toughness",
            description = "Mining increases your Stamina.",
            ranks = {
                {skill = 75, bonus = {stamina = 3}},
                {skill = 150, bonus = {stamina = 5}},
                {skill = 225, bonus = {stamina = 7}},
                {skill = 300, bonus = {stamina = 10}},
            },
        },
    },

    skinning = {
        passive = {
            id = "master_of_anatomy",
            description = "Skinning increases your Critical Strike.",
            ranks = {
                {skill = 75, bonus = {crit_rating = 3}},
                {skill = 150, bonus = {crit_rating = 6}},
                -- ...
            },
        },
    },

    herbalism = {
        ability = {
            id = "lifeblood",
            description = "Heals you over 5 seconds.",
            cooldown = 180,
            heal_percent = 0.05,  -- 5% max health
        },
    },

    enchanting = {
        ability = {
            id = "disenchant",
            description = "Extract magical materials from items.",
        },
        perk = {
            id = "ring_enchants",
            description = "Enchant your own rings.",
        },
    },

    engineering = {
        perk = {
            id = "engineering_only_items",
            description = "Use engineering gadgets and goggles.",
        },
    },

    jewelcrafting = {
        perk = {
            id = "jeweler_gems",
            description = "Use unique Jeweler's gems in your gear.",
        },
    },
}
-- }}}
```

---

## WoW Mode Configuration

```lua
-- {{{ Main WoW mode config
WOW_PROFESSION_CONFIG = {
    -- Mode identifier
    mode = "wow",

    -- Skill system
    skill_max_base = 300,         -- Classic cap
    skill_max_expansion = 450,    -- WotLK cap (if enabled)

    -- Profession limits
    primary_profession_limit = 2,
    secondary_profession_limit = nil,  -- Unlimited

    -- Skill-up behavior
    skillup = {
        orange_chance = 1.0,
        yellow_chance = 0.75,
        green_chance = 0.25,
        gray_chance = 0,
    },

    -- Tier requirements
    tier_training_required = true,
    tier_cost_scaling = true,

    -- Specializations
    specialization_enabled = true,
    specialization_quest_required = true,

    -- Profession perks
    perks_enabled = true,

    -- Trainer system
    trainers_required = true,      -- Must visit trainers for tiers/recipes
    trainer_discovery = false,     -- Recipes also discoverable (alt mode)

    -- UI presentation
    ui_style = "wow",
    show_skill_bar = true,
    show_recipe_difficulty = true,
}
-- }}}
```

---

## Profession Leveling Data

```lua
-- {{{ Skill-up point requirements
-- Points needed to advance from skill X to X+1
function wow_profession.get_skillup_requirement(current_skill)
    -- WoW-like: each point takes more attempts at higher skill
    if current_skill < 100 then
        return 1  -- Easy gains
    elseif current_skill < 200 then
        return 2  -- Moderate
    elseif current_skill < 300 then
        return 3  -- Slow
    else
        return 5  -- Very slow
    end
end

-- Alternative: flat progression (simpler)
function wow_profession.get_skillup_requirement_flat(current_skill)
    return 1  -- Always 1 skillup per success
end
-- }}}
```

---

## API Extensions

```lua
-- WoW-specific profession functions
local wow_prof = require("runtime.configs.wow_profession")

-- Tier management
wow_prof.can_train_tier(entity, profession)
wow_prof.get_current_tier(entity, profession)
wow_prof.get_next_tier(entity, profession)
wow_prof.train_tier(entity, profession, trainer)

-- Primary profession management
wow_prof.get_primary_count(entity)
wow_prof.can_learn_primary(entity)
wow_prof.unlearn_profession(entity, profession)  -- Free up slot

-- Specialization
wow_prof.get_available_specs(entity, profession)
wow_prof.choose_specialization(entity, profession, spec_id)
wow_prof.get_specialization(entity, profession)

-- Perks
wow_prof.get_active_perks(entity)
wow_prof.apply_perk_bonuses(entity, stats)
```

---

## Events

```lua
events.register("EVENT_WOW_TIER_TRAINED")       -- Skill cap increased
events.register("EVENT_WOW_SPEC_CHOSEN")        -- Specialization selected
events.register("EVENT_WOW_PERK_UNLOCKED")      -- Passive bonus unlocked
events.register("EVENT_WOW_PRIMARY_LIMIT")      -- Tried to learn 3rd primary
```

---

## Acceptance Criteria

- [ ] Skill progression 1-300 (or expansion max) works
- [ ] Tier system gates skill cap advancement
- [ ] Trainers teach tiers and recipes
- [ ] Primary profession limit enforced (2 max)
- [ ] Specializations can be chosen at thresholds
- [ ] Profession perks apply bonuses
- [ ] Skill-up chances follow color system
- [ ] WoW-style recipe difficulty display
- [ ] Unlearning profession frees slot
- [ ] Events fire for WoW-specific actions
- [ ] Unit tests for tier/spec logic

---

## Notes

This configuration brings the full WoW profession experience:
- Long progression curve (1-300+)
- Meaningful trainer visits
- Strategic specialization choices
- Profession perks affecting combat

The WoW-chat playerbots will use this mode to grind professions authentically,
visiting trainers, choosing specs, and benefiting from profession bonuses.

When combined with 702f (WC3 mode), the same engine powers both extremes:
- WoW: Deep MMO progression
- WC3: Simple ability-based workers
