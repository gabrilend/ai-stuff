# Issue 016d: Modifier Stack System

## Current Behavior

Equipment and buff bonuses are applied inconsistently. No source tracking means removing bonuses requires knowing what was added.

## Intended Behavior

A modifier stack system that:
- Tracks modifiers by source (equipment, buffs, auras, etc.)
- Supports flat, percent, and multiplier modifier types
- Allows easy addition/removal by source ID
- Maintains application order for deterministic results
- Supports duration-based auto-expiry

## Suggested Implementation Steps

### 1. Modifier Types and Priorities

```lua
-- src/libs/attributes/modifiers.lua

local MOD_TYPE = {
    FLAT = "flat",            -- Added to base: base + flat
    PERCENT = "percent",      -- Percentage: value * (1 + pct/100)
    MULTIPLIER = "multiplier", -- Multiplicative: value * mult
    OVERRIDE = "override",    -- Replaces value entirely
}

-- Application order determines final value
local MOD_PRIORITY = {
    [MOD_TYPE.FLAT] = 1,
    [MOD_TYPE.PERCENT] = 2,
    [MOD_TYPE.MULTIPLIER] = 3,
    [MOD_TYPE.OVERRIDE] = 4,
}

-- Source categories for grouping
local SOURCE_CATEGORY = {
    BASE = "base",
    EQUIPMENT = "equipment",
    ENCHANT = "enchant",
    GEM = "gem",
    BUFF = "buff",
    DEBUFF = "debuff",
    AURA = "aura",
    TALENT = "talent",
    RACIAL = "racial",
    SET_BONUS = "set_bonus",
}
```

### 2. Modifier Structure

```lua
-- {{{ Modifier
local Modifier = {}
Modifier.__index = Modifier

function Modifier.new(spec)
    local self = setmetatable({}, Modifier)

    self.source = spec.source           -- Unique source ID (e.g., "buff:blessing_of_might")
    self.category = spec.category or SOURCE_CATEGORY.BUFF
    self.type = spec.type or MOD_TYPE.FLAT
    self.value = spec.value or 0
    self.priority = spec.priority or MOD_PRIORITY[self.type]

    -- Optional fields
    self.expires_at = spec.expires_at   -- Unix timestamp for auto-expiry
    self.duration = spec.duration       -- Duration in seconds
    self.stacks = spec.stacks or 1      -- Stack count
    self.max_stacks = spec.max_stacks or 1

    -- Conditional modifiers
    self.condition = spec.condition     -- function(container) -> bool

    -- Metadata
    self.name = spec.name               -- Display name
    self.icon = spec.icon               -- For UI
    self.description = spec.description

    return self
end

function Modifier:is_expired()
    if not self.expires_at then return false end
    return os.time() >= self.expires_at
end

function Modifier:is_active(container)
    if self:is_expired() then return false end
    if self.condition and not self.condition(container) then
        return false
    end
    return true
end

function Modifier:get_value()
    return self.value * self.stacks
end
-- }}}
```

### 3. Modifier Manager

```lua
-- {{{ ModifierManager
local ModifierManager = {}

-- {{{ add_modifier
function ModifierManager.add_modifier(container, attr_id, modifier_spec)
    local mod = Modifier.new(modifier_spec)

    container.modifiers[attr_id] = container.modifiers[attr_id] or {}
    local mods = container.modifiers[attr_id]

    -- Check for existing modifier from same source
    for i, existing in ipairs(mods) do
        if existing.source == mod.source then
            -- Stack or replace
            if mod.max_stacks > 1 and existing.stacks < mod.max_stacks then
                existing.stacks = existing.stacks + 1
                -- Refresh duration
                if mod.duration then
                    existing.expires_at = os.time() + mod.duration
                end
                return existing, "stacked"
            else
                -- Replace
                mods[i] = mod
                return mod, "replaced"
            end
        end
    end

    -- Add new modifier
    table.insert(mods, mod)

    -- Sort by priority
    table.sort(mods, function(a, b)
        return a.priority < b.priority
    end)

    -- Mark derived attributes dirty
    local setters = require("src.libs.attributes.setters")
    setters.invalidate_dependents(container, attr_id)

    return mod, "added"
end
-- }}}

-- {{{ remove_modifier
function ModifierManager.remove_modifier(container, attr_id, source)
    local mods = container.modifiers[attr_id]
    if not mods then return false end

    for i, mod in ipairs(mods) do
        if mod.source == source then
            table.remove(mods, i)

            local setters = require("src.libs.attributes.setters")
            setters.invalidate_dependents(container, attr_id)

            return true
        end
    end

    return false
end
-- }}}

-- {{{ remove_by_source
-- Remove all modifiers from a source (e.g., unequipping an item)
function ModifierManager.remove_by_source(container, source)
    local removed = {}

    for attr_id, mods in pairs(container.modifiers) do
        for i = #mods, 1, -1 do
            if mods[i].source == source then
                table.remove(mods, i)
                table.insert(removed, attr_id)
            end
        end
    end

    -- Invalidate affected attributes
    local setters = require("src.libs.attributes.setters")
    for _, attr_id in ipairs(removed) do
        setters.invalidate_dependents(container, attr_id)
    end

    return removed
end
-- }}}

-- {{{ remove_by_category
function ModifierManager.remove_by_category(container, category)
    local removed = {}

    for attr_id, mods in pairs(container.modifiers) do
        for i = #mods, 1, -1 do
            if mods[i].category == category then
                table.remove(mods, i)
                table.insert(removed, { attr_id = attr_id, source = mods[i].source })
            end
        end
    end

    return removed
end
-- }}}

-- {{{ clean_expired
function ModifierManager.clean_expired(container)
    local removed = {}

    for attr_id, mods in pairs(container.modifiers) do
        for i = #mods, 1, -1 do
            if mods[i]:is_expired() then
                table.insert(removed, { attr_id = attr_id, source = mods[i].source })
                table.remove(mods, i)
            end
        end
    end

    return removed
end
-- }}}

-- {{{ get_modifiers
function ModifierManager.get_modifiers(container, attr_id, filter)
    local mods = container.modifiers[attr_id] or {}
    if not filter then return mods end

    local results = {}
    for _, mod in ipairs(mods) do
        local include = true
        if filter.category and mod.category ~= filter.category then
            include = false
        end
        if filter.type and mod.type ~= filter.type then
            include = false
        end
        if filter.active_only and not mod:is_active(container) then
            include = false
        end
        if include then
            table.insert(results, mod)
        end
    end
    return results
end
-- }}}

-- {{{ list_sources
function ModifierManager.list_sources(container)
    local sources = {}
    local seen = {}

    for attr_id, mods in pairs(container.modifiers) do
        for _, mod in ipairs(mods) do
            if not seen[mod.source] then
                seen[mod.source] = true
                table.insert(sources, {
                    source = mod.source,
                    category = mod.category,
                    name = mod.name,
                })
            end
        end
    end

    return sources
end
-- }}}

-- {{{ apply
-- Calculate final value with modifiers
function ModifierManager.apply(container, attr_id, base_value)
    local mods = container.modifiers[attr_id] or {}

    local flat_sum = 0
    local percent_sum = 0
    local multiplier = 1
    local override = nil

    for _, mod in ipairs(mods) do
        if mod:is_active(container) then
            local value = mod:get_value()

            if mod.type == MOD_TYPE.FLAT then
                flat_sum = flat_sum + value
            elseif mod.type == MOD_TYPE.PERCENT then
                percent_sum = percent_sum + value
            elseif mod.type == MOD_TYPE.MULTIPLIER then
                multiplier = multiplier * value
            elseif mod.type == MOD_TYPE.OVERRIDE then
                override = value  -- Last override wins
            end
        end
    end

    if override then
        return override
    end

    return (base_value + flat_sum) * (1 + percent_sum / 100) * multiplier
end
-- }}}

return ModifierManager
-- }}}
```

### 4. Usage Examples

```lua
-- Equipment adds modifiers
local function equip_item(entity, item)
    for attr_id, bonus in pairs(item.stat_bonuses) do
        ModifierManager.add_modifier(entity.attrs, attr_id, {
            source = "equipment:" .. item.id,
            category = SOURCE_CATEGORY.EQUIPMENT,
            type = MOD_TYPE.FLAT,
            value = bonus,
        })
    end
end

-- Buff with duration
ModifierManager.add_modifier(entity.attrs, "strength", {
    source = "buff:blessing_of_might",
    category = SOURCE_CATEGORY.BUFF,
    type = MOD_TYPE.FLAT,
    value = 185,
    duration = 1800,  -- 30 minutes
    name = "Blessing of Might",
    icon = "spell_blessing_of_might",
})

-- Percentage buff that stacks
ModifierManager.add_modifier(entity.attrs, "attack_power", {
    source = "buff:battle_shout",
    category = SOURCE_CATEGORY.BUFF,
    type = MOD_TYPE.PERCENT,
    value = 10,
    max_stacks = 5,
    duration = 120,
})

-- Unequip removes all modifiers from that source
ModifierManager.remove_by_source(entity.attrs, "equipment:" .. item.id)
```

## Related Documents

- Issue 016b - Getters use this to apply modifiers
- Issue 016c - Setters invalidate when modifiers change
- Issue 016e - Derived attributes recalculate on modifier change

## Acceptance Criteria

- [ ] Modifier types: flat, percent, multiplier, override
- [ ] Source tracking for easy removal
- [ ] Category grouping for bulk operations
- [ ] Stacking support with max stacks
- [ ] Duration-based auto-expiry
- [ ] Conditional modifiers
- [ ] Correct application order
- [ ] Unit tests for all operations

---

**Status:** Pending
**Dependencies:** 016a, 016b, 016c
