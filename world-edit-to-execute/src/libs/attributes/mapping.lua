-- Cross-System Attribute Mapping Module
-- Provides bidirectional attribute conversion between WC3 and WoW systems.
--
-- This module enables:
-- - Direct parallel attribute mapping (strength -> strength)
-- - Renamed attribute translation (intelligence -> intellect)
-- - Scaling factor application (WC3 armor * 10 = WoW armor)
-- - Semantic mappings for complex conversions
-- - Mapping profiles for different conversion strategies
--
-- Usage:
--   local mapping = require("libs.attributes.mapping")
--   local result = mapping.convert_value("wc3", "wow", "armor", 10)
--   -- result = { source = "armor", target = "armor", value = 100, factor = 10 }

-- {{{ Module
local mapping = {}
-- }}}

-- {{{ Attribute Parallels
-- Maps equivalent attributes between systems.
-- Format: { wc3_id, wow_id, wc3_to_wow_factor, notes }
-- A factor of 1.0 means direct 1:1 mapping.
-- A factor of 10.0 means WoW value = WC3 value * 10.
-- nil for either ID means no direct equivalent exists.

local PARALLELS = {
    -- Primary stats (direct parallels)
    { "strength",     "strength",     1.0, "Direct parallel" },
    { "agility",      "agility",      1.0, "Direct parallel" },
    { "intelligence", "intellect",    1.0, "WC3 INT -> WoW INT (renamed)" },

    -- WoW-only primaries (no WC3 equivalent)
    -- stamina: WC3 derives health from STR, WoW from STA
    -- spirit: WC3 has simpler regen mechanics

    -- Core character
    { "level",        "level",        1.0, "Direct parallel" },
    { "experience",   "experience",   1.0, "Direct parallel (different XP tables)" },

    -- Resources (direct parallels)
    { "health",       "health",       1.0, "Current health" },
    { "max_health",   "max_health",   1.0, "Max health (different formulas)" },
    { "mana",         "mana",         1.0, "Current mana" },
    { "max_mana",     "max_mana",     1.0, "Max mana (different formulas)" },
    { "base_health",  "base_health",  1.0, "Base health before stats" },
    { "base_mana",    "base_mana",    1.0, "Base mana before stats" },

    -- Combat stats
    -- WC3 armor values are ~10x smaller than WoW armor values.
    -- WC3: 10 armor = ~37.5% reduction vs equal level.
    -- WoW: 100 armor at level 1 = similar reduction.
    { "base_armor",   "base_armor",   10.0, "WC3 armor is ~10x smaller" },
    { "armor",        "armor",        10.0, "Derived armor (same scaling)" },

    -- Attack stats
    -- WC3 damage bonus from primary stat is 1:1.
    -- WoW attack power gives ~1 DPS per 14 AP.
    -- Assuming 1.5s attack speed: 1 WC3 bonus ~= 14 WoW AP.
    { "attack_damage_bonus", "base_attack_power", 14.0, "WC3 dmg bonus -> WoW base AP" },

    -- Movement (different systems - no direct conversion)
    { "movement_speed", nil, nil, "WoW uses percentage-based movement" },

    -- Attack speed
    -- WC3: attack_cooldown is seconds between attacks
    -- WoW: haste is percentage increase
    -- No direct conversion - handled by semantic mapping
    { "base_attack_cooldown", nil, nil, "See semantic: attack_speed_to_haste" },
}
-- }}}

-- {{{ Mapping Tables
-- Build lookup tables for fast conversion
local WC3_TO_WOW = {}
local WOW_TO_WC3 = {}

-- {{{ build_mapping_tables
local function build_mapping_tables()
    WC3_TO_WOW = {}
    WOW_TO_WC3 = {}

    for _, parallel in ipairs(PARALLELS) do
        local wc3_id, wow_id, factor, notes = parallel[1], parallel[2], parallel[3], parallel[4]

        if wc3_id and wow_id and factor then
            WC3_TO_WOW[wc3_id] = {
                target = wow_id,
                factor = factor,
                notes = notes,
            }
            WOW_TO_WC3[wow_id] = {
                target = wc3_id,
                factor = 1 / factor,
                notes = notes,
            }
        end
    end
end
-- }}}

-- Initialize tables on module load
build_mapping_tables()
-- }}}

-- {{{ Semantic Mappings
-- Complex conversions that involve multiple attributes or formulas.
-- These handle cases where a simple factor doesn't apply.

local SEMANTIC_MAPPINGS = {
    -- {{{ wc3_to_wow_stamina
    -- WC3 doesn't have stamina, but we can derive it from health formula.
    -- WC3: max_health = base_health + (strength * 25)
    -- WoW: max_health = base_health + 20 + (stamina - 20) * 10
    -- Solve for stamina given WC3 max_health.
    wc3_to_wow_stamina = {
        description = "Derive WoW stamina from WC3 max_health",
        source_system = "wc3",
        target_system = "wow",
        source_attrs = { "base_health", "strength" },
        target_attr = "stamina",
        formula = function(get)
            local base_hp = get("base_health") or 100
            local str = get("strength") or 10
            -- WC3 max health
            local max_hp = base_hp + (str * 25)
            -- Reverse WoW formula: sta = ((max_hp - base - 20) / 10) + 20
            -- Simplified: sta = (max_hp - 100) / 10 + 20
            local sta = ((max_hp - 100) / 10) + 20
            return math.max(1, math.floor(sta))
        end,
    },
    -- }}}

    -- {{{ wow_to_wc3_strength_bonus
    -- WoW strength contributes to health via stamina.
    -- When converting WoW -> WC3, we need to account for this.
    wow_to_wc3_strength_bonus = {
        description = "Adjust WC3 strength for WoW stamina health contribution",
        source_system = "wow",
        target_system = "wc3",
        source_attrs = { "stamina", "strength" },
        target_attr = "strength",
        formula = function(get)
            local sta = get("stamina") or 10
            local str = get("strength") or 10
            -- WoW stamina gives health, WC3 strength gives health
            -- Add a portion of stamina to strength
            local sta_health = (sta - 20) * 10
            local sta_as_str = math.floor(sta_health / 25)
            return str + math.max(0, sta_as_str)
        end,
    },
    -- }}}

    -- {{{ wc3_to_wow_attack_power
    -- WC3 primary stat gives +1 damage.
    -- WoW: 14 AP = 1 DPS, so with 1.5s attack ~= 1 damage per hit.
    -- This uses the primary stat value directly.
    wc3_to_wow_attack_power = {
        description = "Convert WC3 primary stat to WoW attack power",
        source_system = "wc3",
        target_system = "wow",
        source_attrs = { "strength", "agility", "primary_stat" },
        target_attr = "attack_power",
        formula = function(get)
            local primary = get("primary_stat") or "strength"
            local stat_value = get(primary) or 10
            -- Primary stat gives +stat_value damage in WC3
            -- Convert to AP: damage * 14
            return stat_value * 14
        end,
    },
    -- }}}

    -- {{{ wow_to_wc3_damage_bonus
    -- Convert WoW attack power to WC3 damage bonus.
    wow_to_wc3_damage_bonus = {
        description = "Convert WoW attack power to WC3 damage bonus",
        source_system = "wow",
        target_system = "wc3",
        source_attrs = { "attack_power" },
        target_attr = "attack_damage_bonus",
        formula = function(get)
            local ap = get("attack_power") or 0
            -- WoW: 14 AP = 1 DPS
            -- Assume 1.5s attack speed = 1.5 damage per hit
            local dps = ap / 14
            return math.floor(dps * 1.5)
        end,
    },
    -- }}}

    -- {{{ wc3_to_wow_haste
    -- WC3 attack speed bonus (percent) to WoW haste rating.
    -- WoW: ~15.77 haste rating = 1% haste at level 70.
    wc3_to_wow_haste = {
        description = "Convert WC3 attack speed bonus to WoW haste rating",
        source_system = "wc3",
        target_system = "wow",
        source_attrs = { "attack_speed_bonus" },
        target_attr = "haste_rating",
        formula = function(get)
            local speed_bonus = get("attack_speed_bonus") or 0
            -- 15.77 rating per 1% haste at level 70
            return math.floor(speed_bonus * 15.77)
        end,
    },
    -- }}}

    -- {{{ wow_to_wc3_mana_regen
    -- Convert WoW spirit-based regen to WC3 mana regen percent.
    -- WoW: mp5 = 5 * sqrt(int) * spirit * 0.0093
    -- WC3: base_mana_regen is percent of max per second.
    wow_to_wc3_mana_regen = {
        description = "Convert WoW spirit-based regen to WC3 mana regen",
        source_system = "wow",
        target_system = "wc3",
        source_attrs = { "spirit", "intellect", "max_mana" },
        target_attr = "base_mana_regen",
        formula = function(get)
            local int = get("intellect") or 10
            local spirit = get("spirit") or 10
            local max_mana = get("max_mana") or 1000
            if max_mana <= 0 then return 0 end
            -- WoW mp5 formula
            local mp5 = 5 * math.sqrt(int) * spirit * 0.0093
            -- Convert to per-second, then to percent of max
            local per_sec = mp5 / 5
            return per_sec / max_mana
        end,
    },
    -- }}}

    -- {{{ wc3_to_wow_spell_power
    -- WC3 intelligence contributes to spell damage.
    -- WoW spell power is separate from intellect.
    wc3_to_wow_spell_power = {
        description = "Derive WoW spell power from WC3 intelligence",
        source_system = "wc3",
        target_system = "wow",
        source_attrs = { "intelligence" },
        target_attr = "base_spell_power",
        formula = function(get)
            local int = get("intelligence") or 10
            -- WC3 INT gives mana and spell effectiveness
            -- Rough conversion: 1 INT ~= 1 spell power
            return int
        end,
    },
    -- }}}
}
-- }}}

-- {{{ Mapping Profiles
-- Predefined conversion strategies for different use cases.

local PROFILES = {
    -- {{{ balanced
    -- Tries to maintain relative power level between systems.
    balanced = {
        name = "Balanced",
        description = "Maintains relative power level between systems",
        semantic_mappings = {
            "wc3_to_wow_stamina",
            "wc3_to_wow_attack_power",
            "wc3_to_wow_haste",
            "wc3_to_wow_spell_power",
        },
        scale_factor = 1.0,
    },
    -- }}}

    -- {{{ pve_optimized
    -- Optimized for WoW PvE content (slightly buffed, adds hit).
    pve_optimized = {
        name = "PvE Optimized",
        description = "Converts for WoW PvE content",
        semantic_mappings = {
            "wc3_to_wow_stamina",
            "wc3_to_wow_attack_power",
            "wc3_to_wow_haste",
            "wc3_to_wow_spell_power",
        },
        scale_factor = 1.2,
        bonuses = {
            hit_rating = 50,  -- Add base hit for PvE
        },
    },
    -- }}}

    -- {{{ faithful_wc3
    -- Preserves WC3 gameplay feel with minimal conversion.
    faithful_wc3 = {
        name = "Faithful WC3",
        description = "Preserves WC3 gameplay feel",
        semantic_mappings = {},  -- Skip complex mappings
        scale_factor = 0.8,      -- WC3 heroes are relatively stronger
        skip_ratings = true,     -- Don't convert secondary stats
    },
    -- }}}

    -- {{{ pvp_balanced
    -- For PvP scenarios with resilience.
    pvp_balanced = {
        name = "PvP Balanced",
        description = "Balanced for PvP content",
        semantic_mappings = {
            "wc3_to_wow_stamina",
            "wc3_to_wow_attack_power",
        },
        scale_factor = 1.0,
        bonuses = {
            resilience_rating = 100,  -- Base PvP survivability
        },
    },
    -- }}}
}
-- }}}

-- {{{ Public API

-- {{{ convert_value
-- Convert a single attribute value between systems.
-- @param source_system string "wc3" or "wow"
-- @param target_system string "wc3" or "wow"
-- @param attr_id string The attribute to convert
-- @param value number The value to convert
-- @return table|nil Result with source, target, value, factor; or nil on error
-- @return string|nil Error message if conversion failed
function mapping.convert_value(source_system, target_system, attr_id, value)
    if source_system == target_system then
        return { source = attr_id, target = attr_id, value = value, factor = 1.0 }
    end

    local lookup
    if source_system == "wc3" and target_system == "wow" then
        lookup = WC3_TO_WOW[attr_id]
    elseif source_system == "wow" and target_system == "wc3" then
        lookup = WOW_TO_WC3[attr_id]
    else
        return nil, "Unknown system pair: " .. tostring(source_system) .. " -> " .. tostring(target_system)
    end

    if not lookup then
        return nil, "No mapping for attribute: " .. tostring(attr_id)
    end

    return {
        source = attr_id,
        target = lookup.target,
        value = value * lookup.factor,
        factor = lookup.factor,
        notes = lookup.notes,
    }
end
-- }}}

-- {{{ convert_container
-- Convert all mappable attributes from a container to another system.
-- @param container table The attribute container to read from
-- @param source_system string "wc3" or "wow"
-- @param target_system string "wc3" or "wow"
-- @return table Result with values (converted), unmapped (list of skipped attrs)
function mapping.convert_container(container, source_system, target_system)
    local getters = require("libs.attributes.getters")
    local results = {}
    local unmapped = {}

    local lookup_table
    if source_system == "wc3" and target_system == "wow" then
        lookup_table = WC3_TO_WOW
    elseif source_system == "wow" and target_system == "wc3" then
        lookup_table = WOW_TO_WC3
    else
        return nil, "Unknown system pair: " .. tostring(source_system) .. " -> " .. tostring(target_system)
    end

    -- Get all attribute values from source container
    local source_values = getters.get_all(container)

    for attr_id, value in pairs(source_values) do
        local lookup = lookup_table[attr_id]
        if lookup then
            results[lookup.target] = value * lookup.factor
        else
            table.insert(unmapped, attr_id)
        end
    end

    return {
        values = results,
        unmapped = unmapped,
        source_system = source_system,
        target_system = target_system,
    }
end
-- }}}

-- {{{ apply_semantic_mapping
-- Apply a semantic (complex) mapping.
-- @param container table The source container
-- @param mapping_id string The semantic mapping ID
-- @return table|nil Result with target, value, mapping; or nil on error
-- @return string|nil Error message
function mapping.apply_semantic_mapping(container, mapping_id)
    local semantic = SEMANTIC_MAPPINGS[mapping_id]
    if not semantic then
        return nil, "Unknown semantic mapping: " .. tostring(mapping_id)
    end

    local getters = require("libs.attributes.getters")

    -- Create getter function for the source container
    local get = function(attr_id)
        return getters.get(container, attr_id) or 0
    end

    local result_value = semantic.formula(get)

    return {
        target = semantic.target_attr,
        value = result_value,
        mapping = mapping_id,
        description = semantic.description,
    }
end
-- }}}

-- {{{ apply_profile
-- Apply a full conversion profile to convert one container to another.
-- @param source_container table The source attribute container
-- @param target_container table The target container to populate
-- @param profile_name string The profile to use
-- @param source_system string Source system (defaults to "wc3")
-- @return table Results of the conversion
function mapping.apply_profile(source_container, target_container, profile_name, source_system)
    local profile = PROFILES[profile_name]
    if not profile then
        return nil, "Unknown profile: " .. tostring(profile_name)
    end

    source_system = source_system or "wc3"
    local target_system = source_system == "wc3" and "wow" or "wc3"

    local setters = require("libs.attributes.setters")
    local results = { converted = {}, semantic = {}, bonuses = {} }

    -- Apply direct parallel conversions with scale factor
    local conversion = mapping.convert_container(source_container, source_system, target_system)
    if conversion and conversion.values then
        for attr_id, value in pairs(conversion.values) do
            local scaled = value * profile.scale_factor
            local ok = setters.set(target_container, attr_id, scaled, { clamp = true })
            if ok then
                results.converted[attr_id] = scaled
            end
        end
    end

    -- Apply semantic mappings
    for _, mapping_id in ipairs(profile.semantic_mappings or {}) do
        local result = mapping.apply_semantic_mapping(source_container, mapping_id)
        if result then
            local scaled = result.value * profile.scale_factor
            local ok = setters.set(target_container, result.target, scaled, { clamp = true })
            if ok then
                results.semantic[result.target] = scaled
            end
        end
    end

    -- Apply profile bonuses
    if profile.bonuses then
        for attr_id, bonus in pairs(profile.bonuses) do
            setters.adjust(target_container, attr_id, bonus, { clamp = true })
            results.bonuses[attr_id] = bonus
        end
    end

    return results
end
-- }}}

-- {{{ get_parallel
-- Get the parallel attribute info for a given attribute.
-- @param source_system string "wc3" or "wow"
-- @param attr_id string The attribute ID
-- @return table|nil Mapping info or nil if not found
function mapping.get_parallel(source_system, attr_id)
    if source_system == "wc3" then
        return WC3_TO_WOW[attr_id]
    elseif source_system == "wow" then
        return WOW_TO_WC3[attr_id]
    end
    return nil
end
-- }}}

-- {{{ has_parallel
-- Check if an attribute has a parallel in the other system.
-- @param source_system string "wc3" or "wow"
-- @param attr_id string The attribute ID
-- @return boolean
function mapping.has_parallel(source_system, attr_id)
    return mapping.get_parallel(source_system, attr_id) ~= nil
end
-- }}}

-- {{{ list_parallels
-- Get all parallel attribute definitions.
-- @return table Array of parallel definitions
function mapping.list_parallels()
    local result = {}
    for _, p in ipairs(PARALLELS) do
        table.insert(result, {
            wc3 = p[1],
            wow = p[2],
            factor = p[3],
            notes = p[4],
        })
    end
    return result
end
-- }}}

-- {{{ list_semantic_mappings
-- Get all semantic mapping definitions.
-- @return table Map of mapping_id -> info
function mapping.list_semantic_mappings()
    local result = {}
    for id, m in pairs(SEMANTIC_MAPPINGS) do
        result[id] = {
            description = m.description,
            source_system = m.source_system,
            target_system = m.target_system,
            source_attrs = m.source_attrs,
            target_attr = m.target_attr,
        }
    end
    return result
end
-- }}}

-- {{{ list_profiles
-- Get all available conversion profiles.
-- @return table Map of profile_name -> info
function mapping.list_profiles()
    local result = {}
    for name, p in pairs(PROFILES) do
        result[name] = {
            name = p.name,
            description = p.description,
            scale_factor = p.scale_factor,
            has_bonuses = p.bonuses ~= nil,
        }
    end
    return result
end
-- }}}

-- {{{ print_mapping_table
-- Print a human-readable mapping table.
function mapping.print_mapping_table()
    print("=== Attribute Parallels (WC3 <-> WoW) ===")
    print(string.format("%-25s %-25s %-10s %s", "WC3", "WoW", "Factor", "Notes"))
    print(string.rep("-", 80))

    for _, p in ipairs(PARALLELS) do
        print(string.format("%-25s %-25s %-10s %s",
            p[1] or "(none)",
            p[2] or "(none)",
            p[3] or "N/A",
            p[4] or ""))
    end

    print("\n=== Semantic Mappings ===")
    for id, m in pairs(SEMANTIC_MAPPINGS) do
        print(string.format("  %s: %s", id, m.description))
        print(string.format("    %s -> %s", table.concat(m.source_attrs, ", "), m.target_attr))
    end

    print("\n=== Conversion Profiles ===")
    for name, p in pairs(PROFILES) do
        print(string.format("  %s: %s (scale: %.1f)", name, p.description, p.scale_factor))
    end
end
-- }}}

-- }}}

return mapping
