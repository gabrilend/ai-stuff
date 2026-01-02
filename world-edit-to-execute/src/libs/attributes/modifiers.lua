-- Modifier Stack System Module
-- Manages attribute modifiers from equipment, buffs, auras, etc.
--
-- This module provides:
-- - Modifier types (flat, percent, multiplier, override)
-- - Source tracking for easy removal (unequip item, dispel buff)
-- - Category grouping for bulk operations (remove all debuffs)
-- - Stacking support with max stack limits
-- - Duration-based auto-expiry
-- - Conditional modifiers (active only when condition met)
--
-- The getters module applies modifiers during attribute computation.
-- Modifier application order: (base + flat) * (1 + percent/100) * multiplier
-- Override type replaces the entire value (last override wins).
--
-- Usage:
--   local modifiers = require("libs.attributes.modifiers")
--
--   -- Add a buff
--   modifiers.add(container, "strength", {
--       source = "buff:blessing_of_might",
--       type = "flat",
--       value = 185,
--       duration = 1800,
--   })
--
--   -- Remove when buff expires or is dispelled
--   modifiers.remove(container, "strength", "buff:blessing_of_might")
--
--   -- Unequip item removes all its modifiers
--   modifiers.remove_by_source(container, "equipment:sword_of_might")

local registry = require("libs.attributes.registry")

-- {{{ Constants

-- {{{ MOD_TYPE
-- Types of modifiers and how they're applied
local MOD_TYPE = {
    FLAT = "flat",            -- Added to base: base + flat
    PERCENT = "percent",      -- Percentage: value * (1 + pct/100)
    MULTIPLIER = "multiplier", -- Multiplicative: value * mult
    OVERRIDE = "override",    -- Replaces value entirely (last wins)
}
-- }}}

-- {{{ MOD_PRIORITY
-- Application order determines final value
-- Lower priority applies first
local MOD_PRIORITY = {
    [MOD_TYPE.FLAT] = 1,
    [MOD_TYPE.PERCENT] = 2,
    [MOD_TYPE.MULTIPLIER] = 3,
    [MOD_TYPE.OVERRIDE] = 4,
}
-- }}}

-- {{{ SOURCE_CATEGORY
-- Source categories for grouping and bulk operations
local SOURCE_CATEGORY = {
    BASE = "base",           -- Base stats (rarely modified)
    EQUIPMENT = "equipment", -- Gear bonuses
    ENCHANT = "enchant",     -- Enchantments on gear
    GEM = "gem",             -- Socketed gems
    BUFF = "buff",           -- Positive temporary effects
    DEBUFF = "debuff",       -- Negative temporary effects
    AURA = "aura",           -- Area effects from nearby entities
    TALENT = "talent",       -- Talent/skill tree bonuses
    RACIAL = "racial",       -- Race-specific bonuses
    SET_BONUS = "set_bonus", -- Armor set bonuses
    CONSUMABLE = "consumable", -- Food, potions, etc.
    ABILITY = "ability",     -- Active ability effects
}
-- }}}

-- }}}

-- {{{ Modifier class

local Modifier = {}
Modifier.__index = Modifier

-- {{{ Modifier.new
-- Create a new modifier from a specification table.
-- @param spec Table with modifier definition:
--   - source: string - Unique source ID (e.g., "buff:blessing_of_might") (required)
--   - type: string - MOD_TYPE value (default: FLAT)
--   - value: number - Modifier value (default: 0)
--   - category: string - SOURCE_CATEGORY value (default: BUFF)
--   - priority: number - Application order (default: from MOD_PRIORITY)
--   - duration: number - Duration in seconds (nil = permanent)
--   - expires_at: number - Unix timestamp for expiry (auto-set from duration)
--   - stacks: number - Current stack count (default: 1)
--   - max_stacks: number - Maximum stacks (default: 1)
--   - condition: function(container) -> bool - Only active when true
--   - name: string - Display name for UI
--   - icon: string - Icon identifier for UI
--   - description: string - Tooltip text
-- @return Modifier instance
function Modifier.new(spec)
    if not spec.source then
        error("Modifier requires 'source' field")
    end

    local self = setmetatable({}, Modifier)

    -- Required
    self.source = spec.source

    -- Type and value
    self.type = spec.type or MOD_TYPE.FLAT
    self.value = spec.value or 0

    -- Category and priority
    self.category = spec.category or SOURCE_CATEGORY.BUFF
    self.priority = spec.priority or MOD_PRIORITY[self.type] or 1

    -- Stacking
    self.stacks = spec.stacks or 1
    self.max_stacks = spec.max_stacks or 1

    -- Duration/expiry
    self.duration = spec.duration
    if spec.expires_at then
        self.expires_at = spec.expires_at
    elseif spec.duration then
        self.expires_at = os.time() + spec.duration
    end

    -- Conditional
    self.condition = spec.condition

    -- Metadata for UI
    self.name = spec.name
    self.icon = spec.icon
    self.description = spec.description

    -- Timestamp for ordering modifiers added at same time
    self.created_at = os.time()

    return self
end
-- }}}

-- {{{ Modifier:is_expired
-- Check if this modifier has expired based on duration.
-- @return boolean
function Modifier:is_expired()
    if not self.expires_at then
        return false
    end
    return os.time() >= self.expires_at
end
-- }}}

-- {{{ Modifier:is_active
-- Check if this modifier is currently active.
-- Considers expiry and conditional function.
-- @param container The attribute container (for condition check)
-- @return boolean
function Modifier:is_active(container)
    if self:is_expired() then
        return false
    end
    if self.condition then
        local ok, result = pcall(self.condition, container)
        if not ok or not result then
            return false
        end
    end
    return true
end
-- }}}

-- {{{ Modifier:get_value
-- Get the effective value (base * stacks).
-- @return number
function Modifier:get_value()
    return self.value * self.stacks
end
-- }}}

-- {{{ Modifier:get_remaining_duration
-- Get remaining duration in seconds.
-- @return number or nil if permanent
function Modifier:get_remaining_duration()
    if not self.expires_at then
        return nil
    end
    local remaining = self.expires_at - os.time()
    return remaining > 0 and remaining or 0
end
-- }}}

-- {{{ Modifier:refresh_duration
-- Refresh the expiry time based on the original duration.
-- @param new_duration Optional new duration (uses original if nil)
function Modifier:refresh_duration(new_duration)
    local duration = new_duration or self.duration
    if duration then
        self.expires_at = os.time() + duration
    end
end
-- }}}

-- {{{ Modifier:add_stack
-- Add a stack (up to max_stacks).
-- @return true if stack added, false if at max
function Modifier:add_stack()
    if self.stacks >= self.max_stacks then
        return false
    end
    self.stacks = self.stacks + 1
    return true
end
-- }}}

-- {{{ Modifier:remove_stack
-- Remove a stack.
-- @return new stack count (0 means should be removed)
function Modifier:remove_stack()
    self.stacks = self.stacks - 1
    return self.stacks
end
-- }}}

-- {{{ Modifier:clone
-- Create a copy of this modifier.
-- @return New Modifier instance
function Modifier:clone()
    return Modifier.new({
        source = self.source,
        type = self.type,
        value = self.value,
        category = self.category,
        priority = self.priority,
        duration = self.duration,
        expires_at = self.expires_at,
        stacks = self.stacks,
        max_stacks = self.max_stacks,
        condition = self.condition,
        name = self.name,
        icon = self.icon,
        description = self.description,
    })
end
-- }}}

-- {{{ Modifier:__tostring
function Modifier:__tostring()
    local stack_str = self.max_stacks > 1 and
        string.format(" [%d/%d]", self.stacks, self.max_stacks) or ""
    local duration_str = self.duration and
        string.format(" (%ds)", self:get_remaining_duration() or 0) or ""
    return string.format("Modifier<%s %s %+g%s%s>",
        self.source, self.type, self.value, stack_str, duration_str)
end
-- }}}

-- }}}

-- {{{ ModifierManager

local modifiers = {}

-- {{{ Forward declarations
local invalidate_attribute
-- }}}

-- {{{ invalidate_attribute
-- Mark an attribute and its dependents as needing recalculation.
-- @param container The attribute container
-- @param attr_id The attribute that changed
invalidate_attribute = function(container, attr_id)
    -- Mark derived attributes that depend on this one as dirty
    local dependents = registry.get_dependents(attr_id)
    for i = 1, #dependents do
        local dep_id = dependents[i]
        local schema = registry.get(dep_id)
        if schema then
            container.dirty[schema.index] = true
            -- Recursively invalidate
            invalidate_attribute(container, dep_id)
        end
    end
end
-- }}}

-- {{{ modifiers.add
-- Add a modifier to an attribute.
-- If a modifier with the same source exists, it will stack or replace.
-- @param container The attribute container
-- @param attr_id Attribute ID or index
-- @param spec Modifier specification (see Modifier.new)
-- @return modifier, action ("added", "stacked", or "replaced")
function modifiers.add(container, attr_id, spec)
    -- Resolve attr_id to string if numeric
    local schema = registry.get(attr_id)
    if schema then
        attr_id = schema.id
    end

    -- Create the modifier
    local mod = Modifier.new(spec)

    -- Initialize modifier list if needed
    container.modifiers[attr_id] = container.modifiers[attr_id] or {}
    local mods = container.modifiers[attr_id]

    -- Check for existing modifier from same source
    for i = 1, #mods do
        local existing = mods[i]
        if existing.source == mod.source then
            -- Same source - stack or replace
            if mod.max_stacks > 1 and existing.stacks < existing.max_stacks then
                -- Add stack
                existing:add_stack()
                -- Refresh duration if specified
                if mod.duration then
                    existing:refresh_duration(mod.duration)
                end
                invalidate_attribute(container, attr_id)
                return existing, "stacked"
            else
                -- Replace existing modifier
                mods[i] = mod
                invalidate_attribute(container, attr_id)
                return mod, "replaced"
            end
        end
    end

    -- Add new modifier
    mods[#mods + 1] = mod

    -- Sort by priority (lower priority applies first)
    table.sort(mods, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        -- Same priority: earlier created first
        return a.created_at < b.created_at
    end)

    invalidate_attribute(container, attr_id)
    return mod, "added"
end
-- }}}

-- {{{ modifiers.remove
-- Remove a modifier by source.
-- @param container The attribute container
-- @param attr_id Attribute ID or index
-- @param source The source ID to remove
-- @return true if removed, false if not found
function modifiers.remove(container, attr_id, source)
    -- Resolve attr_id to string if numeric
    local schema = registry.get(attr_id)
    if schema then
        attr_id = schema.id
    end

    local mods = container.modifiers[attr_id]
    if not mods then
        return false
    end

    for i = 1, #mods do
        if mods[i].source == source then
            table.remove(mods, i)
            invalidate_attribute(container, attr_id)
            return true
        end
    end

    return false
end
-- }}}

-- {{{ modifiers.remove_stack
-- Remove one stack from a modifier.
-- If stacks reach 0, the modifier is removed entirely.
-- @param container The attribute container
-- @param attr_id Attribute ID or index
-- @param source The source ID
-- @return remaining stacks, or nil if not found
function modifiers.remove_stack(container, attr_id, source)
    local schema = registry.get(attr_id)
    if schema then
        attr_id = schema.id
    end

    local mods = container.modifiers[attr_id]
    if not mods then
        return nil
    end

    for i = 1, #mods do
        local mod = mods[i]
        if mod.source == source then
            local remaining = mod:remove_stack()
            if remaining <= 0 then
                table.remove(mods, i)
            end
            invalidate_attribute(container, attr_id)
            return remaining
        end
    end

    return nil
end
-- }}}

-- {{{ modifiers.remove_by_source
-- Remove all modifiers from a specific source across all attributes.
-- Useful for unequipping items or dispelling multi-attribute buffs.
-- @param container The attribute container
-- @param source The source ID to remove
-- @return Array of attr_ids that were affected
function modifiers.remove_by_source(container, source)
    local affected = {}

    for attr_id, mods in pairs(container.modifiers) do
        for i = #mods, 1, -1 do
            if mods[i].source == source then
                table.remove(mods, i)
                affected[#affected + 1] = attr_id
            end
        end
    end

    -- Invalidate all affected attributes
    for i = 1, #affected do
        invalidate_attribute(container, affected[i])
    end

    return affected
end
-- }}}

-- {{{ modifiers.remove_by_category
-- Remove all modifiers of a specific category.
-- Useful for "remove all debuffs" type effects.
-- @param container The attribute container
-- @param category The SOURCE_CATEGORY to remove
-- @return Array of {attr_id, source} for removed modifiers
function modifiers.remove_by_category(container, category)
    local removed = {}

    for attr_id, mods in pairs(container.modifiers) do
        for i = #mods, 1, -1 do
            local mod = mods[i]
            if mod.category == category then
                removed[#removed + 1] = {
                    attr_id = attr_id,
                    source = mod.source,
                    name = mod.name,
                }
                table.remove(mods, i)
                invalidate_attribute(container, attr_id)
            end
        end
    end

    return removed
end
-- }}}

-- {{{ modifiers.clean_expired
-- Remove all expired modifiers from the container.
-- Should be called periodically (e.g., on game tick).
-- @param container The attribute container
-- @return Array of {attr_id, source} for removed modifiers
function modifiers.clean_expired(container)
    local removed = {}

    for attr_id, mods in pairs(container.modifiers) do
        for i = #mods, 1, -1 do
            local mod = mods[i]
            if mod:is_expired() then
                removed[#removed + 1] = {
                    attr_id = attr_id,
                    source = mod.source,
                    name = mod.name,
                }
                table.remove(mods, i)
                invalidate_attribute(container, attr_id)
            end
        end
    end

    return removed
end
-- }}}

-- {{{ modifiers.get
-- Get a specific modifier by source.
-- @param container The attribute container
-- @param attr_id Attribute ID or index
-- @param source The source ID to find
-- @return Modifier or nil
function modifiers.get(container, attr_id, source)
    local schema = registry.get(attr_id)
    if schema then
        attr_id = schema.id
    end

    local mods = container.modifiers[attr_id]
    if not mods then
        return nil
    end

    for i = 1, #mods do
        if mods[i].source == source then
            return mods[i]
        end
    end

    return nil
end
-- }}}

-- {{{ modifiers.get_all
-- Get all modifiers for an attribute.
-- @param container The attribute container
-- @param attr_id Attribute ID or index
-- @param filter Optional filter table:
--   - category: only this category
--   - type: only this mod type
--   - active_only: only currently active modifiers
-- @return Array of Modifier objects
function modifiers.get_all(container, attr_id, filter)
    local schema = registry.get(attr_id)
    if schema then
        attr_id = schema.id
    end

    local mods = container.modifiers[attr_id] or {}
    if not filter then
        return mods
    end

    local results = {}
    for i = 1, #mods do
        local mod = mods[i]
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
        if filter.source_pattern then
            if not mod.source:find(filter.source_pattern) then
                include = false
            end
        end

        if include then
            results[#results + 1] = mod
        end
    end

    return results
end
-- }}}

-- {{{ modifiers.count
-- Count modifiers for an attribute.
-- @param container The attribute container
-- @param attr_id Attribute ID or index
-- @param filter Optional filter (same as get_all)
-- @return number
function modifiers.count(container, attr_id, filter)
    return #modifiers.get_all(container, attr_id, filter)
end
-- }}}

-- {{{ modifiers.has
-- Check if a modifier exists.
-- @param container The attribute container
-- @param attr_id Attribute ID or index
-- @param source The source ID to check
-- @return boolean
function modifiers.has(container, attr_id, source)
    return modifiers.get(container, attr_id, source) ~= nil
end
-- }}}

-- {{{ modifiers.list_sources
-- List all unique sources across all attributes.
-- @param container The attribute container
-- @param filter Optional filter:
--   - category: only this category
-- @return Array of {source, category, name, attr_ids}
function modifiers.list_sources(container, filter)
    local sources = {}
    local seen = {}

    for attr_id, mods in pairs(container.modifiers) do
        for i = 1, #mods do
            local mod = mods[i]
            local include = true

            if filter and filter.category and mod.category ~= filter.category then
                include = false
            end

            if include then
                if not seen[mod.source] then
                    seen[mod.source] = {
                        source = mod.source,
                        category = mod.category,
                        name = mod.name,
                        icon = mod.icon,
                        attr_ids = {},
                    }
                    sources[#sources + 1] = seen[mod.source]
                end
                -- Track which attributes this source affects
                local attr_ids = seen[mod.source].attr_ids
                attr_ids[#attr_ids + 1] = attr_id
            end
        end
    end

    return sources
end
-- }}}

-- {{{ modifiers.clear
-- Remove all modifiers from an attribute.
-- @param container The attribute container
-- @param attr_id Attribute ID or index
-- @return number of modifiers removed
function modifiers.clear(container, attr_id)
    local schema = registry.get(attr_id)
    if schema then
        attr_id = schema.id
    end

    local mods = container.modifiers[attr_id]
    if not mods then
        return 0
    end

    local count = #mods
    container.modifiers[attr_id] = {}
    invalidate_attribute(container, attr_id)

    return count
end
-- }}}

-- {{{ modifiers.clear_all
-- Remove all modifiers from all attributes.
-- @param container The attribute container
-- @return number of modifiers removed
function modifiers.clear_all(container)
    local count = 0

    for attr_id, mods in pairs(container.modifiers) do
        count = count + #mods
        invalidate_attribute(container, attr_id)
    end

    container.modifiers = {}
    return count
end
-- }}}

-- {{{ modifiers.refresh
-- Refresh the duration of a modifier.
-- @param container The attribute container
-- @param attr_id Attribute ID or index
-- @param source The source ID
-- @param new_duration Optional new duration (uses original if nil)
-- @return true if found and refreshed, false otherwise
function modifiers.refresh(container, attr_id, source, new_duration)
    local mod = modifiers.get(container, attr_id, source)
    if not mod then
        return false
    end

    mod:refresh_duration(new_duration)
    return true
end
-- }}}

-- {{{ modifiers.set_stacks
-- Set the stack count directly.
-- @param container The attribute container
-- @param attr_id Attribute ID or index
-- @param source The source ID
-- @param stacks New stack count (clamped to 1..max_stacks)
-- @return new stack count, or nil if not found
function modifiers.set_stacks(container, attr_id, source, stacks)
    local mod = modifiers.get(container, attr_id, source)
    if not mod then
        return nil
    end

    stacks = math.max(1, math.min(mod.max_stacks, stacks))
    mod.stacks = stacks
    invalidate_attribute(container, attr_id)

    return stacks
end
-- }}}

-- {{{ modifiers.apply
-- Calculate the final value with all active modifiers.
-- This is called by getters.get() internally - you usually don't need this directly.
-- @param container The attribute container
-- @param attr_id Attribute ID
-- @param base_value The raw attribute value
-- @return Modified value
function modifiers.apply(container, attr_id, base_value)
    local mods = container.modifiers[attr_id] or {}

    local flat_sum = 0
    local percent_sum = 0
    local multiplier = 1
    local override = nil

    for i = 1, #mods do
        local mod = mods[i]
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

    if override ~= nil then
        return override
    end

    -- Order: (base + flat) * (1 + percent/100) * multiplier
    return (base_value + flat_sum) * (1 + percent_sum / 100) * multiplier
end
-- }}}

-- {{{ modifiers.get_breakdown
-- Get a detailed breakdown of how modifiers affect a value.
-- Useful for tooltips and debugging.
-- @param container The attribute container
-- @param attr_id Attribute ID
-- @param base_value The raw attribute value
-- @return Breakdown table
function modifiers.get_breakdown(container, attr_id, base_value)
    local schema = registry.get(attr_id)
    if schema then
        attr_id = schema.id
    end

    local mods = container.modifiers[attr_id] or {}

    local breakdown = {
        base = base_value,
        flat_total = 0,
        percent_total = 0,
        multiplier_total = 1,
        override = nil,
        sources = {},
        active_count = 0,
        inactive_count = 0,
    }

    for i = 1, #mods do
        local mod = mods[i]
        local is_active = mod:is_active(container)

        breakdown.sources[#breakdown.sources + 1] = {
            source = mod.source,
            name = mod.name,
            type = mod.type,
            value = mod.value,
            stacks = mod.stacks,
            effective_value = mod:get_value(),
            category = mod.category,
            is_active = is_active,
            expires_in = mod:get_remaining_duration(),
        }

        if is_active then
            breakdown.active_count = breakdown.active_count + 1
            local value = mod:get_value()

            if mod.type == MOD_TYPE.FLAT then
                breakdown.flat_total = breakdown.flat_total + value
            elseif mod.type == MOD_TYPE.PERCENT then
                breakdown.percent_total = breakdown.percent_total + value
            elseif mod.type == MOD_TYPE.MULTIPLIER then
                breakdown.multiplier_total = breakdown.multiplier_total * value
            elseif mod.type == MOD_TYPE.OVERRIDE then
                breakdown.override = value
            end
        else
            breakdown.inactive_count = breakdown.inactive_count + 1
        end
    end

    -- Calculate final
    if breakdown.override ~= nil then
        breakdown.final = breakdown.override
    else
        breakdown.final = (base_value + breakdown.flat_total) *
            (1 + breakdown.percent_total / 100) *
            breakdown.multiplier_total
    end

    return breakdown
end
-- }}}

-- }}}

-- {{{ Module exports
modifiers.MOD_TYPE = MOD_TYPE
modifiers.MOD_PRIORITY = MOD_PRIORITY
modifiers.SOURCE_CATEGORY = SOURCE_CATEGORY
modifiers.Modifier = Modifier

return modifiers
-- }}}
