# Issue 016h: Cross-System Mapping

## Current Behavior

No mechanism exists to map attributes between WC3 and WoW systems. Converting a WC3 hero to WoW stats or vice versa would require manual translation.

## Intended Behavior

A cross-system mapping layer that:
- Defines parallel attributes between WC3 and WoW
- Provides conversion formulas for stat translation
- Supports bidirectional mapping
- Handles attributes unique to each system
- Enables hybrid entities with stats from both systems

## Suggested Implementation Steps

### 1. Attribute Parallels Definition

```lua
-- src/libs/attributes/mapping.lua

-- {{{ Attribute Parallels
-- Maps equivalent attributes between systems
-- Format: { wc3_id, wow_id, conversion_factor, notes }

local PARALLELS = {
    -- Primary stats
    { "strength",     "strength",     1.0, "Direct parallel" },
    { "agility",      "agility",      1.0, "Direct parallel" },
    { "intelligence", "intellect",    1.0, "WC3 INT -> WoW INT" },

    -- WoW has additional primaries not in WC3
    -- stamina: WC3 doesn't have a direct equivalent (health is derived from STR)
    -- spirit: WC3 doesn't have (regen is simpler)

    -- Resources
    { "health",       "health",       1.0,  "Direct parallel" },
    { "max_health",   "max_health",   1.0,  "Direct parallel" },
    { "mana",         "mana",         1.0,  "Direct parallel" },
    { "max_mana",     "max_mana",     1.0,  "Direct parallel" },

    -- Combat
    { "armor",        "armor",        10.0, "WC3 armor ~= WoW armor / 10" },
    { "movement_speed", nil,          nil,  "WoW uses different movement system" },

    -- Derived combat
    { "attack_damage_bonus", "attack_power", 0.5, "WC3 dmg bonus ~= WoW AP * 0.5" },
}
-- }}}

-- {{{ Mapping Tables
local WC3_TO_WOW = {}
local WOW_TO_WC3 = {}

for _, parallel in ipairs(PARALLELS) do
    local wc3_id, wow_id, factor = parallel[1], parallel[2], parallel[3]

    if wc3_id and wow_id then
        WC3_TO_WOW[wc3_id] = { target = wow_id, factor = factor }
        WOW_TO_WC3[wow_id] = { target = wc3_id, factor = 1 / factor }
    end
end
-- }}}
```

### 2. Conversion Functions

```lua
-- {{{ AttributeMapper
local AttributeMapper = {}

-- {{{ convert_value
-- Convert a single attribute value between systems
function AttributeMapper.convert_value(source_system, target_system, attr_id, value)
    local mapping

    if source_system == "wc3" and target_system == "wow" then
        mapping = WC3_TO_WOW[attr_id]
    elseif source_system == "wow" and target_system == "wc3" then
        mapping = WOW_TO_WC3[attr_id]
    else
        return nil, "Unknown system: " .. tostring(source_system)
    end

    if not mapping then
        return nil, "No mapping for attribute: " .. tostring(attr_id)
    end

    return {
        source = attr_id,
        target = mapping.target,
        value = value * mapping.factor,
        factor = mapping.factor,
    }
end
-- }}}

-- {{{ convert_container
-- Convert all mappable attributes from one system to another
function AttributeMapper.convert_container(source_container, source_system, target_system)
    local getters = require("src.libs.attributes.getters")
    local results = {}
    local unmapped = {}

    local mapping_table
    if source_system == "wc3" and target_system == "wow" then
        mapping_table = WC3_TO_WOW
    elseif source_system == "wow" and target_system == "wc3" then
        mapping_table = WOW_TO_WC3
    else
        return nil, "Unknown system pair"
    end

    -- Get all attribute values from source
    local source_values = getters.get_all(source_container)

    for attr_id, value in pairs(source_values) do
        local mapping = mapping_table[attr_id]
        if mapping then
            results[mapping.target] = value * mapping.factor
        else
            table.insert(unmapped, attr_id)
        end
    end

    return {
        values = results,
        unmapped = unmapped,
    }
end
-- }}}

-- {{{ create_hybrid_container
-- Create a container that tracks both WC3 and WoW stats
function AttributeMapper.create_hybrid_container()
    local wc3_registry = require("src.libs.attributes.configs.wc3")
    local wow_registry = require("src.libs.attributes.configs.wow")

    -- Register both systems (with namespaced IDs to avoid conflicts)
    -- This is a design decision - could also use separate containers

    local container = {
        wc3 = {},  -- WC3 attribute container
        wow = {},  -- WoW attribute container
        sync_enabled = true,
    }

    -- Initialize both
    local registry = require("src.libs.attributes.registry")
    container.wc3 = registry.create_container()
    container.wow = registry.create_container()

    return container
end
-- }}}

-- {{{ sync_parallel
-- Keep parallel attributes in sync when one changes
function AttributeMapper.sync_parallel(container, source_system, attr_id, new_value)
    if not container.sync_enabled then return end

    local mapping
    local target_container

    if source_system == "wc3" then
        mapping = WC3_TO_WOW[attr_id]
        target_container = container.wow
    else
        mapping = WOW_TO_WC3[attr_id]
        target_container = container.wc3
    end

    if mapping and target_container then
        local setters = require("src.libs.attributes.setters")
        setters.set(target_container, mapping.target, new_value * mapping.factor, {
            silent = true,  -- Don't trigger events (prevent loops)
            source = "sync:" .. source_system,
        })
    end
end
-- }}}
-- }}}
```

### 3. Semantic Mapping (Beyond Direct Parallels)

```lua
-- {{{ Semantic Mappings
-- Complex mappings that involve multiple attributes or formulas

local SEMANTIC_MAPPINGS = {
    -- WC3 doesn't have stamina, but we can derive it from health
    wc3_to_wow_stamina = {
        description = "Derive WoW stamina from WC3 max_health",
        source_attrs = { "base_health", "strength" },
        target_attr = "stamina",
        formula = function(get)
            -- WC3: max_health = base_health + (strength * 25)
            -- WoW: max_health = base + (stamina - 20) * 10
            -- Solve for stamina given WC3 max_health
            local max_hp = get("base_health") + (get("strength") * 25)
            return math.floor((max_hp - 100) / 10) + 20
        end,
    },

    -- WoW attack power to WC3 damage bonus
    wow_to_wc3_damage = {
        description = "Convert WoW attack power to WC3 damage bonus",
        source_attrs = { "attack_power" },
        target_attr = "attack_damage_bonus",
        formula = function(get)
            -- WoW: 14 AP = 1 DPS
            -- WC3: damage is per-hit, assume 1.5s attack speed
            local ap = get("attack_power")
            local dps = ap / 14
            return math.floor(dps * 1.5)
        end,
    },

    -- WC3 agility-based attack speed to WoW haste
    wc3_to_wow_haste = {
        description = "Convert WC3 attack speed bonus to WoW haste",
        source_attrs = { "agility", "attack_speed_bonus" },
        target_attr = "haste_rating",
        formula = function(get)
            -- WC3: 1% attack speed per agility
            -- WoW: ~15.77 rating per 1% haste at 70
            local speed_bonus = get("attack_speed_bonus")
            return math.floor(speed_bonus * 15.77)
        end,
    },

    -- WoW spirit to WC3 mana regen
    wow_to_wc3_mana_regen = {
        description = "Convert WoW spirit-based regen to WC3 mana regen",
        source_attrs = { "spirit", "intellect" },
        target_attr = "base_mana_regen",
        formula = function(get)
            -- WoW: mp5 = 5 * sqrt(int) * spirit * 0.0093
            -- WC3: regen is percent of max per second
            local int = get("intellect")
            local spirit = get("spirit")
            local mp5 = 5 * math.sqrt(int) * spirit * 0.0093
            local max_mana = get("max_mana") or 1000
            return (mp5 / 5) / max_mana
        end,
    },
}
-- }}}

-- {{{ apply_semantic_mapping
function AttributeMapper.apply_semantic_mapping(source_container, mapping_id)
    local mapping = SEMANTIC_MAPPINGS[mapping_id]
    if not mapping then
        return nil, "Unknown semantic mapping: " .. tostring(mapping_id)
    end

    local getters = require("src.libs.attributes.getters")

    -- Create getter for source container
    local get = function(attr_id)
        return getters.get(source_container, attr_id) or 0
    end

    local result_value = mapping.formula(get)

    return {
        target = mapping.target_attr,
        value = result_value,
        mapping = mapping_id,
    }
end
-- }}}
```

### 4. Mapping Profiles

```lua
-- {{{ Mapping Profiles
-- Predefined conversion strategies for different use cases

local PROFILES = {
    -- Balanced conversion - tries to maintain relative power
    balanced = {
        name = "Balanced",
        description = "Maintains relative power level between systems",
        mappings = {
            "wc3_to_wow_stamina",
            "wc3_to_wow_haste",
        },
        scale_factor = 1.0,
    },

    -- PvE focused - optimizes for WoW raid content
    pve_optimized = {
        name = "PvE Optimized",
        description = "Converts for WoW PvE content",
        mappings = {
            "wc3_to_wow_stamina",
            "wc3_to_wow_haste",
        },
        scale_factor = 1.2,  -- Slightly buffed for raiding
        hit_rating_bonus = 50,  -- Add base hit for PvE
    },

    -- Faithful WC3 - keeps WC3 feel in WoW context
    faithful_wc3 = {
        name = "Faithful WC3",
        description = "Preserves WC3 gameplay feel",
        mappings = {},  -- Minimal conversion
        scale_factor = 0.8,  -- WC3 heroes are relatively stronger
        ignore_ratings = true,  -- Skip secondary stats
    },
}

function AttributeMapper.apply_profile(source_container, target_container, profile_name)
    local profile = PROFILES[profile_name]
    if not profile then
        return nil, "Unknown profile: " .. tostring(profile_name)
    end

    local setters = require("src.libs.attributes.setters")
    local results = {}

    -- Apply direct parallels with scale factor
    local conversion = AttributeMapper.convert_container(
        source_container, "wc3", "wow")

    for attr_id, value in pairs(conversion.values) do
        local scaled = value * profile.scale_factor
        setters.set(target_container, attr_id, scaled)
        results[attr_id] = scaled
    end

    -- Apply semantic mappings
    for _, mapping_id in ipairs(profile.mappings) do
        local result = AttributeMapper.apply_semantic_mapping(
            source_container, mapping_id)
        if result then
            local scaled = result.value * profile.scale_factor
            setters.set(target_container, result.target, scaled)
            results[result.target] = scaled
        end
    end

    -- Apply profile bonuses
    if profile.hit_rating_bonus then
        setters.adjust(target_container, "hit_rating", profile.hit_rating_bonus)
    end

    return results
end
-- }}}
```

### 5. Introspection and Documentation

```lua
-- {{{ Documentation
function AttributeMapper.get_parallel_docs()
    local docs = {}

    for _, parallel in ipairs(PARALLELS) do
        table.insert(docs, {
            wc3 = parallel[1],
            wow = parallel[2],
            factor = parallel[3],
            notes = parallel[4],
        })
    end

    return docs
end

function AttributeMapper.get_semantic_mapping_docs()
    local docs = {}

    for id, mapping in pairs(SEMANTIC_MAPPINGS) do
        table.insert(docs, {
            id = id,
            description = mapping.description,
            source_attrs = mapping.source_attrs,
            target_attr = mapping.target_attr,
        })
    end

    return docs
end

function AttributeMapper.print_mapping_table()
    print("=== Attribute Parallels (WC3 <-> WoW) ===")
    print(string.format("%-20s %-20s %-10s %s", "WC3", "WoW", "Factor", "Notes"))
    print(string.rep("-", 70))

    for _, parallel in ipairs(PARALLELS) do
        print(string.format("%-20s %-20s %-10s %s",
            parallel[1] or "(none)",
            parallel[2] or "(none)",
            parallel[3] or "N/A",
            parallel[4] or ""))
    end
end
-- }}}

return AttributeMapper
```

## Related Documents

- Issue 016f - WC3 attribute config
- Issue 016g - WoW attribute config
- Issue 016a - Core attribute registry (shared infrastructure)

## Acceptance Criteria

- [ ] Parallel attributes defined for both systems
- [ ] Bidirectional conversion functions
- [ ] Semantic mappings for complex conversions
- [ ] Mapping profiles for different use cases
- [ ] Hybrid container support
- [ ] Sync mechanism for parallel attrs
- [ ] Documentation/introspection functions
- [ ] Unit tests for conversions

---

**Status:** Pending
**Dependencies:** 016f, 016g

