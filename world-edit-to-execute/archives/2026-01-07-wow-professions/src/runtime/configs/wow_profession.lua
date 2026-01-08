--[[
WoW-Mode Profession Configuration (Issue 702e)

Complete WoW-style profession progression configuration including:
- 1-300+ skill progression with tiers
- Profession trainers and skill cap advancement
- Two primary profession limit
- Specialization choices at high skill
- Profession-specific perks and bonuses

Usage:
    local wow_prof = require("runtime.configs.wow_profession")
    local professions = require("runtime.systems.professions")

    -- Apply WoW mode
    professions.set_mode(professions.MODE.WOW)

    -- Use WoW-specific features
    wow_prof.train_tier(entity, "mining", trainer)
    wow_prof.choose_specialization(entity, "blacksmithing", "armorsmith")
]]

-- {{{ Configuration
local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

local ecs = require("runtime.ecs")
local events = require("runtime.events")

local wow_prof = {}

-- ============================================================================
-- Constants
-- ============================================================================

-- {{{ SKILL_TIERS
-- WoW skill tier progression (Classic baseline + expansions)
wow_prof.SKILL_TIERS = {
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

-- {{{ PROFESSION_CATEGORIES
-- Primary (pick 2) vs Secondary (unlimited)
wow_prof.PROFESSION_CATEGORIES = {
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
    SECONDARY = {
        max_count = nil,  -- Unlimited
        professions = {
            "cooking",
            "first_aid",
            "fishing",
            "archaeology",
        },
    },
}
-- }}}

-- ============================================================================
-- Event Constants
-- ============================================================================

-- {{{ WoW-specific events
wow_prof.EVENT = {
    TIER_TRAINED = 500,
    SPEC_CHOSEN = 501,
    PERK_UNLOCKED = 502,
    PRIMARY_LIMIT = 503,
}
-- }}}

-- ============================================================================
-- Specializations
-- ============================================================================

-- {{{ SPECIALIZATIONS
wow_prof.SPECIALIZATIONS = {
    blacksmithing = {
        skill_required = 200,
        quest_required = true,
        choices = {
            {
                id = "armorsmith",
                name = "Armorsmith",
                description = "Specialize in crafting armor.",
                exclusive_recipes = {"ornate_mithril_breastplate", "thorium_armor"},
                bonus = {armor_stats = "+5%"},
            },
            {
                id = "weaponsmith",
                name = "Weaponsmith",
                description = "Specialize in forging weapons.",
                exclusive_recipes = {"phantom_blade", "arcanite_reaper"},
                bonus = {weapon_stats = "+5%"},
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
                exclusive_recipes = {"gnomish_shrink_ray", "gnomish_battle_chicken"},
            },
            {
                id = "goblin",
                name = "Goblin Engineering",
                theme = "explosives",
                exclusive_recipes = {"goblin_rocket_boots", "goblin_bomb_dispenser"},
            },
        },
    },

    alchemy = {
        skill_required = 300,
        quest_required = true,
        choices = {
            {id = "elixir_master", name = "Elixir Master", bonus = "elixirs_proc_extra"},
            {id = "potion_master", name = "Potion Master", bonus = "potions_proc_extra"},
            {id = "transmutation_master", name = "Transmutation Master", bonus = "transmutes_proc_extra"},
        },
    },

    leatherworking = {
        skill_required = 225,
        quest_required = false,
        choices = {
            {id = "dragonscale", name = "Dragonscale Leatherworking", armor_type = "mail"},
            {id = "elemental", name = "Elemental Leatherworking", armor_type = "leather"},
            {id = "tribal", name = "Tribal Leatherworking", armor_type = "leather"},
        },
    },

    tailoring = {
        skill_required = 300,
        quest_required = false,
        choices = {
            {id = "mooncloth", name = "Mooncloth Tailoring", focus = "healing"},
            {id = "shadoweave", name = "Shadoweave Tailoring", focus = "shadow"},
            {id = "spellfire", name = "Spellfire Tailoring", focus = "fire"},
        },
    },
}
-- }}}

-- ============================================================================
-- Profession Perks
-- ============================================================================

-- {{{ PROFESSION_PERKS
wow_prof.PROFESSION_PERKS = {
    mining = {
        passive = {
            id = "toughness",
            name = "Toughness",
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
            name = "Master of Anatomy",
            description = "Skinning increases your Critical Strike.",
            ranks = {
                {skill = 75, bonus = {crit_rating = 3}},
                {skill = 150, bonus = {crit_rating = 6}},
                {skill = 225, bonus = {crit_rating = 9}},
                {skill = 300, bonus = {crit_rating = 12}},
            },
        },
    },

    herbalism = {
        ability = {
            id = "lifeblood",
            name = "Lifeblood",
            description = "Heals you over 5 seconds.",
            cooldown = 180,
            heal_percent = 0.05,
        },
    },

    enchanting = {
        ability = {
            id = "disenchant",
            name = "Disenchant",
            description = "Extract magical materials from items.",
        },
        perk = {
            id = "ring_enchants",
            name = "Ring Enchants",
            description = "Enchant your own rings.",
        },
    },

    engineering = {
        perk = {
            id = "engineering_only_items",
            name = "Engineering Items",
            description = "Use engineering gadgets and goggles.",
        },
    },

    jewelcrafting = {
        perk = {
            id = "jeweler_gems",
            name = "Jeweler's Gems",
            description = "Use unique Jeweler's gems in your gear.",
        },
    },

    alchemy = {
        perk = {
            id = "mixology",
            name = "Mixology",
            description = "Your own elixirs and flasks last longer.",
            bonus = {self_potion_duration = "+50%"},
        },
    },

    inscription = {
        perk = {
            id = "shoulder_enchants",
            name = "Master's Inscription",
            description = "Inscribe powerful enchants on your shoulders.",
        },
    },

    blacksmithing = {
        perk = {
            id = "socket_bracer",
            name = "Socket Bracers",
            description = "Add sockets to your own bracers.",
        },
        perk2 = {
            id = "socket_gloves",
            name = "Socket Gloves",
            description = "Add sockets to your own gloves.",
        },
    },

    tailoring = {
        perk = {
            id = "cloak_enchant",
            name = "Lightweave Embroidery",
            description = "Embroider your cloak with powerful magic.",
        },
    },

    leatherworking = {
        perk = {
            id = "wrist_enchant",
            name = "Fur Lining",
            description = "Reinforce your bracers with fur lining.",
        },
    },
}
-- }}}

-- ============================================================================
-- Main Configuration
-- ============================================================================

-- {{{ WOW_PROFESSION_CONFIG
wow_prof.CONFIG = {
    mode = "wow",

    -- Skill system
    skill_max_base = 300,
    skill_max_expansion = 450,

    -- Profession limits
    primary_profession_limit = 2,
    secondary_profession_limit = nil,

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
    trainers_required = true,
    trainer_discovery = false,

    -- UI presentation
    ui_style = "wow",
    show_skill_bar = true,
    show_recipe_difficulty = true,
}
-- }}}

-- ============================================================================
-- Component Definition
-- ============================================================================

-- {{{ PROFESSION_TRAINER_DEFAULTS
local PROFESSION_TRAINER_DEFAULTS = {
    profession = nil,
    trainer_tier = "apprentice",

    can_train_tier = true,
    can_teach_recipes = true,

    recipes_taught = {},

    faction = nil,
    reputation_required = nil,

    specialization = nil,

    greeting = "Greetings. Ready to learn?",
    train_prompt = "Train me in %s.",
    no_skill_response = "You must practice more before I can teach you.",
}
-- }}}

-- {{{ Register component
local function register_component()
    if not (ecs.component_exists and ecs.component_exists("profession_trainer")) then
        ecs.register_component("profession_trainer", PROFESSION_TRAINER_DEFAULTS)
    end
end
-- }}}

-- ============================================================================
-- Lazy Loading
-- ============================================================================

-- {{{ get_professions
local _professions = nil
local function get_professions()
    if not _professions then
        _professions = require("runtime.systems.professions")
    end
    return _professions
end
-- }}}

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- {{{ is_primary_profession
-- Check if a profession is primary or secondary.
local function is_primary_profession(profession_id)
    for _, prof in ipairs(wow_prof.PROFESSION_CATEGORIES.PRIMARY.professions) do
        if prof == profession_id then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ get_tier_for_skill
-- Get the skill tier for a given skill level.
local function get_tier_for_skill(skill_level)
    for _, tier in ipairs(wow_prof.SKILL_TIERS) do
        if skill_level >= tier.skill_range[1] and skill_level <= tier.skill_range[2] then
            return tier
        end
    end
    return nil
end
-- }}}

-- ============================================================================
-- Tier Management
-- ============================================================================

-- {{{ wow_prof.get_current_tier
-- Get the current tier for an entity's profession.
function wow_prof.get_current_tier(entity_id, profession_id)
    local professions = get_professions()
    local skill = professions.get_skill(entity_id, profession_id)
    if not skill then
        return nil
    end

    return get_tier_for_skill(skill)
end
-- }}}

-- {{{ wow_prof.get_next_tier
-- Get the next tier after the current one.
function wow_prof.get_next_tier(entity_id, profession_id)
    local current_tier = wow_prof.get_current_tier(entity_id, profession_id)
    if not current_tier then
        return wow_prof.SKILL_TIERS[1]  -- Start at Apprentice
    end

    -- Find current tier index
    for i, tier in ipairs(wow_prof.SKILL_TIERS) do
        if tier.name == current_tier.name then
            return wow_prof.SKILL_TIERS[i + 1]  -- May be nil if at max
        end
    end

    return nil
end
-- }}}

-- {{{ wow_prof.can_train_tier
-- Check if entity can train to the next tier.
function wow_prof.can_train_tier(entity_id, profession_id)
    local professions = get_professions()

    -- Must have the profession
    if not professions.has_profession(entity_id, profession_id) then
        return false, "Profession not learned"
    end

    -- Get current skill and cap
    local skill = professions.get_skill(entity_id, profession_id)
    local skill_cap = professions.get_max_skill(entity_id, profession_id)

    -- Must be at or near cap
    if skill < skill_cap then
        return false, "Must reach skill cap first"
    end

    -- Check if there is a next tier
    local next_tier = wow_prof.get_next_tier(entity_id, profession_id)
    if not next_tier then
        return false, "Already at maximum tier"
    end

    -- Check level requirement
    -- TODO: Integrate with level system when available
    -- For now, assume level requirement is met

    return true
end
-- }}}

-- {{{ wow_prof.train_tier
-- Train to the next profession tier, increasing skill cap.
function wow_prof.train_tier(entity_id, profession_id, trainer_id)
    local professions = get_professions()

    local can, err = wow_prof.can_train_tier(entity_id, profession_id)
    if not can then
        return false, err
    end

    local next_tier = wow_prof.get_next_tier(entity_id, profession_id)
    local new_cap = next_tier.skill_range[2]

    -- Set new skill cap
    professions.set_skill_cap(entity_id, profession_id, new_cap)

    -- Deduct cost
    -- TODO: Integrate with currency system when available

    events.fire(wow_prof.EVENT.TIER_TRAINED, {
        entity = entity_id,
        profession = profession_id,
        tier = next_tier.name,
        new_cap = new_cap,
    })

    return true, next_tier
end
-- }}}

-- ============================================================================
-- Primary Profession Management
-- ============================================================================

-- {{{ wow_prof.get_primary_count
-- Get how many primary professions an entity has.
function wow_prof.get_primary_count(entity_id)
    local professions = get_professions()
    local all_profs = professions.get_all_professions(entity_id)
    if not all_profs then
        return 0
    end

    local count = 0
    for _, prof_id in ipairs(all_profs.primary or {}) do
        if is_primary_profession(prof_id) then
            count = count + 1
        end
    end

    return count
end
-- }}}

-- {{{ wow_prof.can_learn_primary
-- Check if entity can learn another primary profession.
function wow_prof.can_learn_primary(entity_id)
    local count = wow_prof.get_primary_count(entity_id)
    local limit = wow_prof.CONFIG.primary_profession_limit

    if count >= limit then
        return false, "Primary profession limit reached"
    end

    return true
end
-- }}}

-- {{{ wow_prof.unlearn_profession
-- Unlearn a profession, freeing up a slot.
function wow_prof.unlearn_profession(entity_id, profession_id)
    local professions = get_professions()
    return professions.forget_profession(entity_id, profession_id)
end
-- }}}

-- ============================================================================
-- Specialization System
-- ============================================================================

-- {{{ wow_prof.get_available_specs
-- Get available specializations for a profession.
function wow_prof.get_available_specs(entity_id, profession_id)
    local professions = get_professions()

    local spec_def = wow_prof.SPECIALIZATIONS[profession_id]
    if not spec_def then
        return {}
    end

    -- Check skill requirement
    local skill = professions.get_skill(entity_id, profession_id)
    if not skill or skill < spec_def.skill_required then
        return {}
    end

    -- Already have a specialization?
    local current_spec = professions.get_specialization(entity_id, profession_id)
    if current_spec then
        return {}  -- Already specialized
    end

    return spec_def.choices
end
-- }}}

-- {{{ wow_prof.choose_specialization
-- Choose a specialization for a profession.
function wow_prof.choose_specialization(entity_id, profession_id, spec_id)
    local professions = get_professions()

    local available = wow_prof.get_available_specs(entity_id, profession_id)
    if #available == 0 then
        return false, "No specializations available"
    end

    -- Find the chosen spec
    local chosen_spec = nil
    for _, spec in ipairs(available) do
        if spec.id == spec_id then
            chosen_spec = spec
            break
        end
    end

    if not chosen_spec then
        return false, "Invalid specialization"
    end

    -- Set specialization
    professions.set_specialization(entity_id, profession_id, spec_id)

    events.fire(wow_prof.EVENT.SPEC_CHOSEN, {
        entity = entity_id,
        profession = profession_id,
        specialization = spec_id,
    })

    return true, chosen_spec
end
-- }}}

-- {{{ wow_prof.get_specialization
-- Get the current specialization for a profession.
function wow_prof.get_specialization(entity_id, profession_id)
    local professions = get_professions()
    return professions.get_specialization(entity_id, profession_id)
end
-- }}}

-- ============================================================================
-- Profession Perks
-- ============================================================================

-- {{{ wow_prof.get_active_perks
-- Get all active perks for an entity's professions.
function wow_prof.get_active_perks(entity_id)
    local professions = get_professions()
    local all_profs = professions.get_all_professions(entity_id)
    if not all_profs then
        return {}
    end

    local active_perks = {}

    -- Check all professions
    for _, prof_id in pairs(all_profs.primary or {}) do
        local perk_def = wow_prof.PROFESSION_PERKS[prof_id]
        if perk_def then
            local skill = professions.get_skill(entity_id, prof_id)

            -- Passive perks with ranks
            if perk_def.passive and perk_def.passive.ranks then
                for _, rank in ipairs(perk_def.passive.ranks) do
                    if skill >= rank.skill then
                        active_perks[#active_perks + 1] = {
                            profession = prof_id,
                            type = "passive",
                            perk = perk_def.passive,
                            rank = rank,
                        }
                    end
                end
            end

            -- Abilities
            if perk_def.ability then
                active_perks[#active_perks + 1] = {
                    profession = prof_id,
                    type = "ability",
                    perk = perk_def.ability,
                }
            end

            -- General perks
            if perk_def.perk then
                active_perks[#active_perks + 1] = {
                    profession = prof_id,
                    type = "perk",
                    perk = perk_def.perk,
                }
            end
        end
    end

    -- Check secondary professions too
    for _, prof_id in pairs(all_profs.secondary or {}) do
        local perk_def = wow_prof.PROFESSION_PERKS[prof_id]
        if perk_def then
            if perk_def.ability then
                active_perks[#active_perks + 1] = {
                    profession = prof_id,
                    type = "ability",
                    perk = perk_def.ability,
                }
            end
        end
    end

    return active_perks
end
-- }}}

-- {{{ wow_prof.apply_perk_bonuses
-- Apply profession perk bonuses to stats.
function wow_prof.apply_perk_bonuses(entity_id, stats)
    local perks = wow_prof.get_active_perks(entity_id)

    for _, perk_entry in ipairs(perks) do
        if perk_entry.rank and perk_entry.rank.bonus then
            -- Apply stat bonuses from ranked perks
            for stat_name, bonus_value in pairs(perk_entry.rank.bonus) do
                stats[stat_name] = (stats[stat_name] or 0) + bonus_value
            end
        end
    end

    return stats
end
-- }}}

-- ============================================================================
-- Initialization
-- ============================================================================

-- {{{ wow_prof.init
-- Initialize WoW profession system.
function wow_prof.init()
    register_component()
end
-- }}}

-- {{{ wow_prof.reset
-- Reset state (for testing).
function wow_prof.reset()
    -- Nothing to reset currently
end
-- }}}

return wow_prof
