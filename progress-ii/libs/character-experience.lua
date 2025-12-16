#!/usr/bin/env lua

-- Character Experience Calculation Engine for Progress-II
-- Handles complex stat calculations, bonuses, and progression math

local CharacterExperience = {}

-- Stat progression curves and magical essence affinities
local STAT_PROGRESSIONS = {
    -- Primary stats have linear progression
    wit = { base_cost = 1, scaling = 1.0, max_level = 20 },
    strength = { base_cost = 1, scaling = 1.0, max_level = 20 },
    intuition = { base_cost = 1, scaling = 1.0, max_level = 20 },
    resilience = { base_cost = 1, scaling = 1.0, max_level = 20 },
    
    -- Magical stats have exponential progression (harder to master)
    druid_lore = { base_cost = 1, scaling = 1.2, max_level = 15 },
    astral_sight = { base_cost = 1, scaling = 1.3, max_level = 12 },
    shadow_walk = { base_cost = 1, scaling = 1.4, max_level = 10 },
    elemental_bond = { base_cost = 1, scaling = 1.3, max_level = 12 },
    
    -- Social stats have moderate progression
    charm = { base_cost = 1, scaling = 1.1, max_level = 18 },
    empathy = { base_cost = 1, scaling = 1.1, max_level = 18 },
    leadership = { base_cost = 1, scaling = 1.2, max_level = 15 },
    
    -- Survival stats are easy to improve early but plateau
    survival = { base_cost = 1, scaling = 1.15, max_level = 16 },
    crafting = { base_cost = 1, scaling = 1.15, max_level = 16 },
    luck = { base_cost = 1, scaling = 1.25, max_level = 12 }
}

-- Essence to stat affinity mappings
local ESSENCE_STAT_AFFINITIES = {
    natural_magic = { druid_lore = 2, wit = 1, empathy = 1, survival = 1 },
    forest_essence = { druid_lore = 3, survival = 2, crafting = 1 },
    growth_energy = { druid_lore = 2, resilience = 2, crafting = 1 },
    shadow_essence = { shadow_walk = 3, intuition = 2, luck = 1 },
    drain_energy = { shadow_walk = 2, intuition = 1, resilience = 1 },
    void_touch = { shadow_walk = 2, astral_sight = 1, luck = 2 },
    astral_resonance = { astral_sight = 3, intuition = 2, wit = 1 },
    star_essence = { astral_sight = 2, luck = 2, leadership = 1 },
    cosmic_flow = { astral_sight = 2, leadership = 2, intuition = 1 },
    earth_pulse = { strength = 2, resilience = 2, crafting = 1 },
    flame_spirit = { elemental_bond = 3, strength = 1, charm = 1, leadership = 1 },
    water_essence = { elemental_bond = 2, empathy = 2, resilience = 1 }
}

-- Environmental variable impacts on experience gains
local ENVIRONMENTAL_EXPERIENCE_MODIFIERS = {
    magic_drain = {
        high = { druid_lore = 1.5, astral_sight = 1.3, elemental_bond = 1.2 },
        low = { strength = 1.2, crafting = 1.3, survival = 1.2 }
    },
    struggle_peace = {
        high = { strength = 1.4, resilience = 1.3, leadership = 1.2 },
        low = { empathy = 1.3, charm = 1.2, crafting = 1.2 }
    },
    growth_death = {
        high = { druid_lore = 1.4, survival = 1.3, resilience = 1.2 },
        low = { shadow_walk = 1.3, intuition = 1.2, luck = 1.4 }
    },
    nature_astral = {
        high = { astral_sight = 1.5, druid_lore = 1.3, intuition = 1.2 },
        low = { crafting = 1.2, strength = 1.1, charm = 1.1 }
    }
}

-- {{{ calculate_experience_from_resonance
function CharacterExperience.calculate_experience_from_resonance(essence_type, resonance_strength, environmental_vars)
    local base_experience = math.floor(resonance_strength * 15) + 1  -- 1-16 XP range
    
    -- Apply environmental modifiers
    local modifier = 1.0
    
    for env_var, env_value in pairs(environmental_vars) do
        local env_modifiers = ENVIRONMENTAL_EXPERIENCE_MODIFIERS[env_var]
        if env_modifiers then
            if env_value > 0.7 and env_modifiers.high then
                -- High environmental value effects
                for stat, mult in pairs(env_modifiers.high) do
                    if ESSENCE_STAT_AFFINITIES[essence_type] and ESSENCE_STAT_AFFINITIES[essence_type][stat] then
                        modifier = modifier + (mult - 1.0) * 0.5  -- Moderate the bonus
                    end
                end
            elseif env_value < 0.3 and env_modifiers.low then
                -- Low environmental value effects
                for stat, mult in pairs(env_modifiers.low) do
                    if ESSENCE_STAT_AFFINITIES[essence_type] and ESSENCE_STAT_AFFINITIES[essence_type][stat] then
                        modifier = modifier + (mult - 1.0) * 0.5
                    end
                end
            end
        end
    end
    
    local final_experience = math.floor(base_experience * modifier)
    return math.max(1, math.min(25, final_experience))  -- Cap at 1-25 XP
end
-- }}}

-- {{{ calculate_stat_allocation_bonus
function CharacterExperience.calculate_stat_allocation_bonus(stat_name, recent_essences, environmental_vars)
    local total_bonus = 0
    
    -- Check recent essence discoveries for affinity bonuses
    for _, essence in ipairs(recent_essences) do
        local affinities = ESSENCE_STAT_AFFINITIES[essence]
        if affinities and affinities[stat_name] then
            total_bonus = total_bonus + affinities[stat_name]
        end
    end
    
    -- Apply environmental bonuses
    local env_bonus = 0
    for env_var, env_value in pairs(environmental_vars) do
        local env_modifiers = ENVIRONMENTAL_EXPERIENCE_MODIFIERS[env_var]
        if env_modifiers then
            local modifier_set = nil
            if env_value > 0.7 then
                modifier_set = env_modifiers.high
            elseif env_value < 0.3 then
                modifier_set = env_modifiers.low
            end
            
            if modifier_set and modifier_set[stat_name] then
                env_bonus = env_bonus + math.floor((modifier_set[stat_name] - 1.0) * 2)
            end
        end
    end
    
    total_bonus = total_bonus + env_bonus
    
    -- Cap the bonus to prevent exploitation
    return math.min(total_bonus, 5)
end
-- }}}

-- {{{ calculate_stat_cost
function CharacterExperience.calculate_stat_cost(stat_name, current_level, points_to_buy)
    local progression = STAT_PROGRESSIONS[stat_name]
    if not progression then
        return points_to_buy  -- Default 1:1 cost for unknown stats
    end
    
    local total_cost = 0
    
    for i = 1, points_to_buy do
        local target_level = current_level + i
        if target_level > progression.max_level then
            return -1  -- Cannot exceed max level
        end
        
        local level_cost = math.floor(progression.base_cost * math.pow(progression.scaling, target_level - 1))
        total_cost = total_cost + level_cost
    end
    
    return total_cost
end
-- }}}

-- {{{ generate_level_up_narrative
function CharacterExperience.generate_level_up_narrative(character_name, stat_name, points_gained, essence_bonus, environmental_context)
    local narratives = {
        wit = {
            "sharp intellect cutting through confusion like a blade through silk",
            "mind expanding to embrace new possibilities and creative solutions",
            "understanding dawning like sunrise over previously murky problems"
        },
        strength = {
            "muscles hardening like iron, power flowing through sinew and bone",
            "physical prowess growing, capable of moving mountains if needed",
            "body becoming a temple of controlled force and measured might"
        },
        intuition = {
            "inner sight opening like a third eye, perceiving hidden truths",
            "instincts sharpening to perceive what others cannot see",
            "developing an uncanny ability to sense the currents of fate"
        },
        resilience = {
            "spirit fortifying against all hardships, unbreakable as ancient oak",
            "endurance deepening like roots in rich earth, drawing strength from trials",
            "will becoming as constant as the north star, unwavering in adversity"
        },
        druid_lore = {
            "ancient forest wisdom flowing into consciousness like morning mist",
            "understanding the secret language that trees whisper to wind",
            "gaining knowledge of the old ways, where nature and magic intertwine"
        },
        astral_sight = {
            "cosmic awareness expanding, touching the infinite web of starlight",
            "vision piercing the veil between worlds, seeing beyond the material",
            "consciousness ascending to perceive the celestial harmonies"
        },
        shadow_walk = {
            "learning to dance with darkness, moving unseen through hidden paths",
            "embracing the lessons that shadows teach to those who listen",
            "gaining mastery over the spaces between light and void"
        },
        elemental_bond = {
            "forging connections with fire, water, earth, and air",
            "becoming a bridge between human understanding and elemental wisdom",
            "attuning to the primal forces that shape the world"
        },
        charm = {
            "presence becoming magnetic, drawing others with natural charisma",
            "words taking on weight and grace, opening hearts and minds",
            "developing the rare gift of making others feel truly seen"
        },
        empathy = {
            "heart expanding to hold the joys and sorrows of others",
            "emotional intelligence deepening like a well-tuned instrument",
            "gaining the ability to heal wounds that cannot be seen"
        },
        leadership = {
            "authority growing not from dominance but from earned trust",
            "learning to inspire others to reach heights they never thought possible",
            "becoming a beacon that guides others through uncertainty"
        },
        survival = {
            "wilderness skills sharpening, learning to thrive in any environment",
            "developing an intimate understanding of nature's rhythms and resources",
            "gaining the confidence to venture far from civilization's comforts"
        },
        crafting = {
            "hands learning to shape raw materials into objects of beauty and function",
            "understanding the patience required to create something lasting",
            "developing the artisan's eye for quality and attention to detail"
        },
        luck = {
            "fortune beginning to smile more frequently, small miracles becoming common",
            "developing an uncanny ability to be in the right place at the right time",
            "learning to ride the currents of chance with grace and wisdom"
        }
    }
    
    local base_narrative = narratives[stat_name] and narratives[stat_name][math.random(#narratives[stat_name])] or
                          "growing stronger in ways both subtle and profound"
    
    local environmental_flavor = ""
    if environmental_context.magic_drain and environmental_context.magic_drain > 0.7 then
        environmental_flavor = " The magical currents run strong, amplifying this growth."
    elseif environmental_context.struggle_peace and environmental_context.struggle_peace > 0.7 then
        environmental_flavor = " Times of struggle forge the strongest spirits."
    elseif environmental_context.nature_astral and environmental_context.nature_astral > 0.8 then
        environmental_flavor = " The cosmic forces align to bless this development."
    end
    
    local essence_flavor = ""
    if essence_bonus > 0 then
        essence_flavor = " Recent magical discoveries resonate deeply with this growth, creating unexpected synergies."
    end
    
    return string.format("%s feels %s%s%s", 
        character_name, base_narrative, environmental_flavor, essence_flavor)
end
-- }}}

-- {{{ calculate_companion_experience_sharing
function CharacterExperience.calculate_companion_experience_sharing(player_experience, companion_count, relationship_bonuses)
    local base_companion_experience = math.floor(player_experience / 5)
    local shared_experiences = {}
    
    for i = 1, companion_count do
        local companion_experience = base_companion_experience
        
        -- Apply relationship bonuses if provided
        if relationship_bonuses and relationship_bonuses[i] then
            companion_experience = math.floor(companion_experience * relationship_bonuses[i])
        end
        
        table.insert(shared_experiences, companion_experience)
    end
    
    return shared_experiences
end
-- }}}

-- {{{ generate_progression_report
function CharacterExperience.generate_progression_report(character_data, environmental_vars)
    local report = {}
    
    table.insert(report, "╔═══════════════════════════════════════════════════════════════════════════════╗")
    table.insert(report, "║                        CHARACTER PROGRESSION ANALYSIS                        ║")
    table.insert(report, "╠═══════════════════════════════════════════════════════════════════════════════╣")
    
    -- Overall progress assessment
    local total_stats = 0
    local stat_count = 0
    for stat_name, progression in pairs(STAT_PROGRESSIONS) do
        local current_value = character_data[stat_name] or 0
        total_stats = total_stats + current_value
        stat_count = stat_count + 1
    end
    
    local average_stat = stat_count > 0 and (total_stats / stat_count) or 0
    local progression_stage = ""
    
    if average_stat < 3 then
        progression_stage = "Novice - Just beginning the journey"
    elseif average_stat < 6 then
        progression_stage = "Apprentice - Learning the fundamentals"
    elseif average_stat < 10 then
        progression_stage = "Journeyman - Developing expertise"
    elseif average_stat < 15 then
        progression_stage = "Expert - Mastering advanced techniques"
    else
        progression_stage = "Master - Approaching legendary status"
    end
    
    table.insert(report, string.format("║ Overall Development: %-59s ║", progression_stage))
    table.insert(report, string.format("║ Average Stat Level: %.1f                                                  ║", average_stat))
    
    -- Environmental impact analysis
    table.insert(report, "╠═══════════════════════════════════════════════════════════════════════════════╣")
    table.insert(report, "║ ENVIRONMENTAL INFLUENCE ON GROWTH                                            ║")
    table.insert(report, "╠═══════════════════════════════════════════════════════════════════════════════╣")
    
    for env_var, env_value in pairs(environmental_vars) do
        local influence = ""
        if env_value > 0.7 then
            influence = "Strong Positive"
        elseif env_value > 0.5 then
            influence = "Moderate Positive"
        elseif env_value > 0.3 then
            influence = "Moderate Negative"
        else
            influence = "Strong Negative"
        end
        
        table.insert(report, string.format("║ %-20s: %-54s ║", env_var, influence))
    end
    
    -- Growth recommendations
    table.insert(report, "╠═══════════════════════════════════════════════════════════════════════════════╣")
    table.insert(report, "║ GROWTH RECOMMENDATIONS                                                        ║")
    table.insert(report, "╠═══════════════════════════════════════════════════════════════════════════════╣")
    
    -- Find lowest stats for improvement suggestions
    local stat_recommendations = {}
    for stat_name, progression in pairs(STAT_PROGRESSIONS) do
        local current_value = character_data[stat_name] or 0
        table.insert(stat_recommendations, {stat = stat_name, value = current_value, max = progression.max_level})
    end
    
    table.sort(stat_recommendations, function(a, b) return a.value < b.value end)
    
    for i = 1, math.min(3, #stat_recommendations) do
        local rec = stat_recommendations[i]
        table.insert(report, string.format("║ Consider improving %-15s (currently %2d, max %2d)                    ║", 
            rec.stat, rec.value, rec.max))
    end
    
    table.insert(report, "╚═══════════════════════════════════════════════════════════════════════════════╝")
    
    return table.concat(report, "\n")
end
-- }}}

-- {{{ parse_character_file
function CharacterExperience.parse_character_file(file_path)
    local character_data = {}
    local file = io.open(file_path, "r")
    
    if not file then
        return character_data
    end
    
    for line in file:lines() do
        local key, value = line:match("^([%w_]+)=([%w%d%.%s%,%-_]+)$")
        if key and value then
            -- Try to convert to number if possible
            local num_value = tonumber(value)
            character_data[key] = num_value or value
        end
    end
    
    file:close()
    return character_data
end
-- }}}

-- {{{ parse_environmental_file
function CharacterExperience.parse_environmental_file(file_path)
    local environmental_vars = {}
    local file = io.open(file_path, "r")
    
    if not file then
        return environmental_vars
    end
    
    for line in file:lines() do
        local var_name, var_value = line:match("^([%w_]+)=([%d%.]+)$")
        if var_name and var_value then
            environmental_vars[var_name] = tonumber(var_value)
        end
    end
    
    file:close()
    return environmental_vars
end
-- }}}

-- Main execution when called as script
if arg and arg[0] and arg[0]:match("character%-experience%.lua$") then
    local command = arg[1]
    
    if command == "calculate_experience" then
        local essence_type = arg[2]
        local resonance = tonumber(arg[3])
        local env_file = arg[4]
        
        if not essence_type or not resonance or not env_file then
            print("Usage: character-experience.lua calculate_experience <essence_type> <resonance> <env_file>")
            os.exit(1)
        end
        
        local environmental_vars = CharacterExperience.parse_environmental_file(env_file)
        local experience = CharacterExperience.calculate_experience_from_resonance(essence_type, resonance, environmental_vars)
        print(experience)
        
    elseif command == "calculate_stat_bonus" then
        local stat_name = arg[2]
        local essences_string = arg[3]
        local env_file = arg[4]
        
        if not stat_name or not essences_string or not env_file then
            print("Usage: character-experience.lua calculate_stat_bonus <stat_name> <essences> <env_file>")
            os.exit(1)
        end
        
        local recent_essences = {}
        for essence in essences_string:gmatch("[^,]+") do
            table.insert(recent_essences, essence)
        end
        
        local environmental_vars = CharacterExperience.parse_environmental_file(env_file)
        local bonus = CharacterExperience.calculate_stat_allocation_bonus(stat_name, recent_essences, environmental_vars)
        print(bonus)
        
    elseif command == "generate_narrative" then
        local character_name = arg[2]
        local stat_name = arg[3]
        local points_gained = tonumber(arg[4])
        local essence_bonus = tonumber(arg[5])
        local env_file = arg[6]
        
        if not character_name or not stat_name or not points_gained or not essence_bonus or not env_file then
            print("Usage: character-experience.lua generate_narrative <character> <stat> <points> <bonus> <env_file>")
            os.exit(1)
        end
        
        local environmental_vars = CharacterExperience.parse_environmental_file(env_file)
        local narrative = CharacterExperience.generate_level_up_narrative(character_name, stat_name, points_gained, essence_bonus, environmental_vars)
        print(narrative)
        
    elseif command == "progression_report" then
        local character_file = arg[2]
        local env_file = arg[3]
        
        if not character_file or not env_file then
            print("Usage: character-experience.lua progression_report <character_file> <env_file>")
            os.exit(1)
        end
        
        local character_data = CharacterExperience.parse_character_file(character_file)
        local environmental_vars = CharacterExperience.parse_environmental_file(env_file)
        local report = CharacterExperience.generate_progression_report(character_data, environmental_vars)
        print(report)
        
    else
        print("Unknown command: " .. (command or "none"))
        print("Available commands: calculate_experience, calculate_stat_bonus, generate_narrative, progression_report")
        os.exit(1)
    end
end

return CharacterExperience