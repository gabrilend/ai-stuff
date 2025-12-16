#!/usr/bin/env lua

-- Magical Discovery Text Processing and Calculation Engine for Progress-II
-- Handles complex text manipulation and mathematical resonance calculations

local MagicalDiscovery = {}

-- Environmental variable oscillation patterns
local OSCILLATION_PATTERNS = {
    struggle_peace = { frequency = 0.1, amplitude = 0.8, phase = 0 },
    magic_drain = { frequency = 0.15, amplitude = 0.6, phase = math.pi/4 },
    growth_death = { frequency = 0.08, amplitude = 0.9, phase = math.pi/2 },
    fire_ice = { frequency = 0.12, amplitude = 0.7, phase = 0 },
    nature_astral = { frequency = 0.05, amplitude = 1.0, phase = math.pi/3 },
    wind_stone = { frequency = 0.18, amplitude = 0.5, phase = math.pi },
    blood_temple = { frequency = 0.07, amplitude = 0.8, phase = math.pi/6 },
    metal_wood = { frequency = 0.11, amplitude = 0.6, phase = 3*math.pi/4 },
    few_all = { frequency = 0.09, amplitude = 0.9, phase = math.pi/2 },
    struggle_silence = { frequency = 0.13, amplitude = 0.4, phase = 2*math.pi/3 }
}

-- Essence type definitions and their affinities
local ESSENCE_AFFINITIES = {
    natural_magic = { nature_astral = 1.0, growth_death = 0.8, magic_drain = 0.7 },
    forest_essence = { nature_astral = 0.9, growth_death = 1.0, metal_wood = 0.6 },
    growth_energy = { growth_death = 1.0, nature_astral = 0.7, struggle_peace = 0.5 },
    shadow_essence = { magic_drain = -0.8, growth_death = -0.6, struggle_silence = 0.9 },
    drain_energy = { magic_drain = -1.0, nature_astral = -0.7, blood_temple = 0.5 },
    void_touch = { magic_drain = -0.9, struggle_silence = 1.0, few_all = -0.6 },
    astral_resonance = { nature_astral = 1.0, struggle_silence = 0.6, wind_stone = 0.4 },
    star_essence = { nature_astral = 0.8, wind_stone = 0.7, fire_ice = 0.3 },
    cosmic_flow = { nature_astral = 0.9, wind_stone = 0.5, few_all = 0.8 },
    earth_pulse = { wind_stone = -1.0, metal_wood = 0.8, growth_death = 0.6 },
    flame_spirit = { fire_ice = 1.0, metal_wood = -0.4, struggle_peace = 0.7 },
    water_essence = { fire_ice = -0.8, growth_death = 0.5, nature_astral = 0.6 }
}

-- {{{ calculate_oscillation_value
function MagicalDiscovery.calculate_oscillation_value(variable_name, time_factor)
    local pattern = OSCILLATION_PATTERNS[variable_name]
    if not pattern then
        return 0.5  -- Default middle value
    end
    
    -- Calculate sine wave oscillation
    local base_value = 0.5 + (pattern.amplitude * 0.5 * math.sin(pattern.frequency * time_factor + pattern.phase))
    
    -- Ensure value stays within [0, 1] bounds
    return math.max(0, math.min(1, base_value))
end
-- }}}

-- {{{ calculate_resonance_strength
function MagicalDiscovery.calculate_resonance_strength(essence_type, environmental_vars)
    local affinities = ESSENCE_AFFINITIES[essence_type]
    if not affinities then
        -- Unknown essence type gets neutral resonance
        return 0.5
    end
    
    local total_resonance = 0
    local affinity_count = 0
    
    for var_name, affinity_strength in pairs(affinities) do
        local env_value = environmental_vars[var_name] or 0.5
        
        -- Calculate resonance based on affinity and current environmental value
        local resonance_contribution
        if affinity_strength > 0 then
            -- Positive affinity: higher env value = stronger resonance
            resonance_contribution = env_value * affinity_strength
        else
            -- Negative affinity: lower env value = stronger resonance
            resonance_contribution = (1 - env_value) * math.abs(affinity_strength)
        end
        
        total_resonance = total_resonance + resonance_contribution
        affinity_count = affinity_count + 1
    end
    
    if affinity_count == 0 then
        return 0.5
    end
    
    -- Average the resonance and ensure it stays within bounds
    local final_resonance = total_resonance / affinity_count
    return math.max(0, math.min(1, final_resonance))
end
-- }}}

-- {{{ generate_discovery_narrative
function MagicalDiscovery.generate_discovery_narrative(location, essence_type, resonance, environmental_vars)
    local narratives = {}
    
    -- Location-based narrative elements
    local location_descriptors = {
        forest = {"ancient grove", "moonlit clearing", "whispering trees", "sacred glade"},
        cave = {"echoing chamber", "crystal formations", "hidden depths", "stone sanctuary"},
        lake = {"mirror-still waters", "rippling surface", "misty shore", "depths unknown"},
        mountain = {"windswept peak", "rocky outcrop", "cloud-touched summit", "stone faces"},
        meadow = {"flower-filled expanse", "rolling grassland", "butterfly haven", "sun-dappled field"},
        river = {"flowing currents", "babbling brook", "rushing waters", "meandering stream"}
    }
    
    -- Essence-based narrative elements
    local essence_descriptors = {
        natural_magic = {"pulses of green energy", "living light", "nature's breath", "growth incarnate"},
        shadow_essence = {"whispers of darkness", "void tendrils", "forgotten echoes", "silence made manifest"},
        astral_resonance = {"starlight patterns", "cosmic harmonies", "celestial threads", "infinite connections"},
        flame_spirit = {"dancing embers", "warm radiance", "passionate heat", "creative spark"},
        water_essence = {"flowing serenity", "cleansing currents", "emotional tides", "fluid wisdom"}
    }
    
    -- Resonance-based intensity descriptors
    local intensity_descriptors = {
        [1] = {"overwhelming", "earth-shaking", "reality-bending", "transcendent"},
        [0.8] = {"powerful", "commanding", "radiant", "magnificent"},
        [0.6] = {"noticeable", "clear", "evident", "apparent"},
        [0.4] = {"subtle", "gentle", "faint", "whispered"},
        [0.2] = {"barely perceptible", "hidden", "dormant", "potential"}
    }
    
    -- Select appropriate descriptors
    local loc_key = string.lower(location):match("(%w+)")
    local location_desc = location_descriptors[loc_key] or {"mysterious place"}
    
    local essence_desc = essence_descriptors[essence_type] or {"unknown energies"}
    
    local intensity_level = math.floor(resonance * 5) / 5
    if intensity_level < 0.2 then intensity_level = 0.2 end
    local intensity_desc = intensity_descriptors[intensity_level] or {"moderate"}
    
    -- Generate environmental context
    local env_context = {}
    if environmental_vars.magic_drain and environmental_vars.magic_drain > 0.7 then
        table.insert(env_context, "the magical currents run strong")
    elseif environmental_vars.magic_drain and environmental_vars.magic_drain < 0.3 then
        table.insert(env_context, "magical energies feel drained and distant")
    end
    
    if environmental_vars.struggle_peace and environmental_vars.struggle_peace > 0.7 then
        table.insert(env_context, "tension crackles in the air")
    elseif environmental_vars.struggle_peace and environmental_vars.struggle_peace < 0.3 then
        table.insert(env_context, "peaceful serenity blankets the area")
    end
    
    -- Construct narrative
    local narrative = string.format("In this %s, %s manifests as %s. ",
        location_desc[math.random(#location_desc)],
        essence_desc[math.random(#essence_desc)],
        intensity_desc[math.random(#intensity_desc)])
    
    if #env_context > 0 then
        narrative = narrative .. "The discovery occurs as " .. table.concat(env_context, " and ") .. "."
    end
    
    return narrative
end
-- }}}

-- {{{ update_environmental_oscillations
function MagicalDiscovery.update_environmental_oscillations(time_factor)
    local updated_vars = {}
    
    for var_name, _ in pairs(OSCILLATION_PATTERNS) do
        updated_vars[var_name] = MagicalDiscovery.calculate_oscillation_value(var_name, time_factor)
    end
    
    return updated_vars
end
-- }}}

-- {{{ parse_environmental_file
function MagicalDiscovery.parse_environmental_file(file_path)
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

-- {{{ write_environmental_file
function MagicalDiscovery.write_environmental_file(file_path, environmental_vars)
    local file = io.open(file_path, "w")
    
    if not file then
        return false
    end
    
    file:write("# Environmental Variable Oscillations - Progress-II\n")
    file:write("# Variables oscillate like sine curves, affecting magical discovery\n")
    file:write("\n")
    
    for var_name, var_value in pairs(environmental_vars) do
        file:write(string.format("%s=%.3f\n", var_name, var_value))
    end
    
    file:write("\n")
    file:write("# Last updated: " .. os.date() .. "\n")
    file:close()
    
    return true
end
-- }}}

-- {{{ format_discovery_report
function MagicalDiscovery.format_discovery_report(discovery_data)
    local report = {}
    
    table.insert(report, "╔═══════════════════════════════════════════════════════════════════════════════╗")
    table.insert(report, "║                        MAGICAL DISCOVERY REPORT                              ║")
    table.insert(report, "╠═══════════════════════════════════════════════════════════════════════════════╣")
    
    table.insert(report, string.format("║ Timestamp: %-66s ║", discovery_data.timestamp or "Unknown"))
    table.insert(report, string.format("║ Location:  %-66s ║", discovery_data.location or "Unknown"))
    table.insert(report, string.format("║ Essence:   %-66s ║", discovery_data.essence_type or "Unknown"))
    
    local resonance_bar = string.rep("█", math.floor((discovery_data.resonance or 0.5) * 20))
    local resonance_empty = string.rep("░", 20 - #resonance_bar)
    table.insert(report, string.format("║ Resonance: [%s%s] %.1f%%                                 ║", 
        resonance_bar, resonance_empty, (discovery_data.resonance or 0.5) * 100))
    
    table.insert(report, "╠═══════════════════════════════════════════════════════════════════════════════╣")
    
    -- Wrap description text to fit within the box
    local description = discovery_data.description or "No description available"
    local max_width = 75
    local words = {}
    for word in description:gmatch("%S+") do
        table.insert(words, word)
    end
    
    local current_line = ""
    for _, word in ipairs(words) do
        if #current_line + #word + 1 <= max_width then
            current_line = current_line .. (current_line == "" and "" or " ") .. word
        else
            table.insert(report, string.format("║ %-77s ║", current_line))
            current_line = word
        end
    end
    if current_line ~= "" then
        table.insert(report, string.format("║ %-77s ║", current_line))
    end
    
    table.insert(report, "╚═══════════════════════════════════════════════════════════════════════════════╝")
    
    return table.concat(report, "\n")
end
-- }}}

-- Main execution when called as script
if arg and arg[0] and arg[0]:match("magical%-discovery%.lua$") then
    local command = arg[1]
    
    if command == "calculate_resonance" then
        local essence_type = arg[2]
        local env_file = arg[3]
        
        if not essence_type or not env_file then
            print("Usage: magical-discovery.lua calculate_resonance <essence_type> <env_file>")
            os.exit(1)
        end
        
        local environmental_vars = MagicalDiscovery.parse_environmental_file(env_file)
        local resonance = MagicalDiscovery.calculate_resonance_strength(essence_type, environmental_vars)
        print(string.format("%.3f", resonance))
        
    elseif command == "generate_narrative" then
        local location = arg[2]
        local essence_type = arg[3]
        local resonance = tonumber(arg[4])
        local env_file = arg[5]
        
        if not location or not essence_type or not resonance or not env_file then
            print("Usage: magical-discovery.lua generate_narrative <location> <essence_type> <resonance> <env_file>")
            os.exit(1)
        end
        
        local environmental_vars = MagicalDiscovery.parse_environmental_file(env_file)
        local narrative = MagicalDiscovery.generate_discovery_narrative(location, essence_type, resonance, environmental_vars)
        print(narrative)
        
    elseif command == "update_oscillations" then
        local env_file = arg[2]
        local time_factor = tonumber(arg[3]) or os.time()
        
        if not env_file then
            print("Usage: magical-discovery.lua update_oscillations <env_file> [time_factor]")
            os.exit(1)
        end
        
        local updated_vars = MagicalDiscovery.update_environmental_oscillations(time_factor)
        if MagicalDiscovery.write_environmental_file(env_file, updated_vars) then
            print("Environmental oscillations updated successfully")
        else
            print("Error: Could not write to environmental file")
            os.exit(1)
        end
        
    else
        print("Unknown command: " .. (command or "none"))
        print("Available commands: calculate_resonance, generate_narrative, update_oscillations")
        os.exit(1)
    end
end

return MagicalDiscovery