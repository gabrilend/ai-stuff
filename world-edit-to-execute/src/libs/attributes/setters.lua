-- Attribute Setters Module
-- Dispatch table-based setters for O(1) attribute modification.
--
-- This module provides validated setters that:
-- - Validate values against schema constraints
-- - Fire change events for reactive systems
-- - Invalidate dependent (derived) attributes
-- - Clamp or reject out-of-range values
-- - Support transactions for batch updates
--
-- Usage:
--   local setters = require("libs.attributes.setters")
--   setters.set(container, "strength", 25)
--   setters.set(container, "agility", 999, { clamp = true })
--   setters.adjust(container, "health", -50)
--   setters.set_many(container, { strength = 20, agility = 15 })

local registry = require("libs.attributes.registry")

-- {{{ Module state
local setters = {}

-- Dispatch table: populated from registry
-- SETTERS[id] and SETTERS[index] both work
local SETTERS = {}

-- Event listeners
-- Key: event_name, Value: array of listener functions
local event_listeners = {}
-- }}}

-- {{{ Forward declarations
local invalidate_dependents
local fire_event
-- }}}

-- {{{ invalidate_dependents
-- Mark all derived attributes that depend on this attribute as dirty.
-- Uses the dependency graph from the registry.
-- @param container The attribute container
-- @param attr_id The attribute that changed
invalidate_dependents = function(container, attr_id)
    local dependents = registry.get_dependents(attr_id)
    for i = 1, #dependents do
        local dep_id = dependents[i]
        local dep_schema = registry.get(dep_id)
        if dep_schema then
            container.dirty[dep_schema.index] = true
            -- Recursively invalidate dependents of dependents
            invalidate_dependents(container, dep_id)
        end
    end
end
-- }}}

-- {{{ fire_event
-- Fire an event to all registered listeners.
-- @param event_name The event name
-- @param data Event data table
fire_event = function(event_name, data)
    local listeners = event_listeners[event_name]
    if not listeners then return end

    for i = 1, #listeners do
        local ok, err = pcall(listeners[i], data)
        if not ok then
            -- Log error but don't stop other listeners
            -- In production, this would use a proper logging system
            io.stderr:write("Event listener error: " .. tostring(err) .. "\n")
        end
    end
end
-- }}}

-- {{{ build_setters
-- Build dispatch table from the registry.
-- Called automatically on module load and can be called after
-- registry changes via rebuild().
local function build_setters()
    SETTERS = {}

    for id, schema in pairs(registry.schemas) do
        local index = schema.index

        if schema:is_derived() then
            -- Derived attributes cannot be set directly
            -- They are computed from other attributes via formula
            SETTERS[id] = function(container, value, options)
                return false, "Cannot set derived attribute: " .. id
            end

        elseif schema:is_readonly() then
            -- Readonly attributes cannot be modified
            SETTERS[id] = function(container, value, options)
                return false, "Attribute is readonly: " .. id
            end

        else
            -- Standard setter with validation and events
            SETTERS[id] = function(container, value, options)
                options = options or {}

                -- Validate the value
                local ok, err = schema:validate(value)
                if not ok then
                    -- If clamp option is set and schema has range, clamp instead of reject
                    if options.clamp and (schema.min ~= nil or schema.max ~= nil) then
                        value = schema:clamp(value)
                    -- If schema has CLAMPED flag, auto-clamp
                    elseif schema:is_clamped() and (schema.min ~= nil or schema.max ~= nil) then
                        value = schema:clamp(value)
                    else
                        return false, err
                    end
                end

                -- Get old value for change detection
                local old_value = container.values[index]
                if old_value == value then
                    -- No change, early return
                    return true
                end

                -- Set new value
                container.values[index] = value

                -- Invalidate dependent derived attributes
                invalidate_dependents(container, id)

                -- Fire change event (unless suppressed)
                if not options.silent then
                    fire_event("attribute_changed", {
                        container = container,
                        attribute = id,
                        index = index,
                        old_value = old_value,
                        new_value = value,
                        source = options.source,
                    })
                end

                return true
            end
        end

        -- Also index by numeric key for O(1) access
        SETTERS[index] = SETTERS[id]
    end
end
-- }}}

-- {{{ Public API

-- {{{ setters.set
-- Set an attribute value with validation and events.
-- @param container The attribute container
-- @param attr_id Attribute ID (string) or index (number)
-- @param value The value to set
-- @param options Optional table:
--   - clamp: boolean - Clamp to min/max instead of rejecting
--   - silent: boolean - Don't fire change events
--   - source: string - Track what caused the change (for debugging)
-- @return true on success, or false and error message on failure
function setters.set(container, attr_id, value, options)
    local setter = SETTERS[attr_id]
    if not setter then
        return false, "Unknown attribute: " .. tostring(attr_id)
    end
    return setter(container, value, options)
end
-- }}}

-- {{{ setters.set_raw
-- Set an attribute value bypassing validation (dangerous).
-- Use only for internal operations like loading saved data.
-- @param container The attribute container
-- @param attr_id Attribute ID or index
-- @param value The value to set
-- @return true on success, or false and error message
function setters.set_raw(container, attr_id, value)
    local schema = registry.get(attr_id)
    if not schema then
        return false, "Unknown attribute: " .. tostring(attr_id)
    end

    container.values[schema.index] = value
    invalidate_dependents(container, schema.id)
    return true
end
-- }}}

-- {{{ setters.set_many
-- Batch update multiple attributes with a single event.
-- @param container The attribute container
-- @param updates Table mapping attr_id -> value
-- @param options Optional table (same as set())
-- @return Table mapping attr_id -> { ok = bool, error = string or nil }
function setters.set_many(container, updates, options)
    options = options or {}
    local results = {}
    local changes = {}

    -- Suppress individual events, collect changes
    local batch_options = {
        silent = true,
        clamp = options.clamp,
        source = options.source,
    }

    for attr_id, value in pairs(updates) do
        local schema = registry.get(attr_id)
        if schema then
            local old_value = container.values[schema.index]
            local ok, err = setters.set(container, attr_id, value, batch_options)
            results[attr_id] = { ok = ok, error = err }

            if ok and old_value ~= value then
                changes[#changes + 1] = {
                    attribute = attr_id,
                    index = schema.index,
                    old_value = old_value,
                    new_value = value,
                }
            end
        else
            results[attr_id] = { ok = false, error = "Unknown attribute" }
        end
    end

    -- Fire single batch event if changes occurred
    if not options.silent and #changes > 0 then
        fire_event("attributes_changed", {
            container = container,
            changes = changes,
            source = options.source,
        })
    end

    return results
end
-- }}}

-- {{{ setters.adjust
-- Add or subtract from current value.
-- @param container The attribute container
-- @param attr_id Attribute ID or index
-- @param delta Amount to add (negative to subtract)
-- @param options Optional table (same as set())
-- @return true on success, or false and error message
function setters.adjust(container, attr_id, delta, options)
    local schema = registry.get(attr_id)
    if not schema then
        return false, "Unknown attribute: " .. tostring(attr_id)
    end

    local current = container.values[schema.index]
    if type(current) ~= "number" then
        return false, "Cannot adjust non-numeric attribute"
    end

    return setters.set(container, attr_id, current + delta, options)
end
-- }}}

-- {{{ setters.reset
-- Reset an attribute to its default value.
-- @param container The attribute container
-- @param attr_id Attribute ID or index
-- @param options Optional table (same as set())
-- @return true on success, or false and error message
function setters.reset(container, attr_id, options)
    local schema = registry.get(attr_id)
    if not schema then
        return false, "Unknown attribute: " .. tostring(attr_id)
    end

    return setters.set(container, attr_id, schema.default, options)
end
-- }}}

-- {{{ setters.reset_all
-- Reset all attributes to their default values.
-- Also clears all modifiers.
-- @param container The attribute container
-- @param options Optional table (same as set())
-- @return true
function setters.reset_all(container, options)
    options = options or {}
    local batch_options = { silent = true, source = options.source }

    -- Reset all non-derived attributes
    for id, schema in pairs(registry.schemas) do
        if not schema:is_derived() and not schema:is_readonly() then
            setters.set(container, id, schema.default, batch_options)
        end
    end

    -- Clear all modifiers
    container.modifiers = {}

    -- Mark all derived attributes as dirty
    for _, schema in pairs(registry.schemas) do
        if schema:is_derived() then
            container.dirty[schema.index] = true
        end
    end

    -- Fire reset event
    if not options.silent then
        fire_event("attributes_reset", {
            container = container,
            source = options.source,
        })
    end

    return true
end
-- }}}

-- {{{ setters.has
-- Check if a setter exists for an attribute.
-- @param attr_id Attribute ID or index
-- @return boolean
function setters.has(attr_id)
    return SETTERS[attr_id] ~= nil
end
-- }}}

-- {{{ setters.get_setter
-- Get the setter function directly for hot-path optimization.
-- @param attr_id Attribute ID or index
-- @return Setter function or nil
function setters.get_setter(attr_id)
    return SETTERS[attr_id]
end
-- }}}

-- {{{ setters.rebuild
-- Rebuild dispatch table after registry changes.
function setters.rebuild()
    build_setters()
end
-- }}}

-- }}}

-- {{{ Event system

-- {{{ setters.on
-- Register an event listener.
-- Event names:
--   - "attribute_changed": Single attribute changed
--   - "attributes_changed": Batch update completed
--   - "attributes_reset": All attributes reset
-- @param event_name The event to listen for
-- @param listener Function to call with event data
-- @return listener (for unregistration)
function setters.on(event_name, listener)
    if not event_listeners[event_name] then
        event_listeners[event_name] = {}
    end
    event_listeners[event_name][#event_listeners[event_name] + 1] = listener
    return listener
end
-- }}}

-- {{{ setters.off
-- Unregister an event listener.
-- @param event_name The event name
-- @param listener The listener to remove
-- @return true if removed, false if not found
function setters.off(event_name, listener)
    local listeners = event_listeners[event_name]
    if not listeners then return false end

    for i = #listeners, 1, -1 do
        if listeners[i] == listener then
            table.remove(listeners, i)
            return true
        end
    end
    return false
end
-- }}}

-- {{{ setters.clear_listeners
-- Clear all event listeners (useful for testing).
-- @param event_name Optional - if provided, only clear that event
function setters.clear_listeners(event_name)
    if event_name then
        event_listeners[event_name] = nil
    else
        event_listeners = {}
    end
end
-- }}}

-- }}}

-- {{{ Transaction support

-- {{{ Transaction class
local Transaction = {}
Transaction.__index = Transaction

-- {{{ Transaction.new
-- Create a new transaction for batch updates.
-- @param container The attribute container
-- @return Transaction instance
function Transaction.new(container)
    local self = setmetatable({}, Transaction)
    self.container = container
    self.snapshot = {}
    self.pending = {}
    self.committed = false

    -- Snapshot current values for rollback
    for index, value in pairs(container.values) do
        self.snapshot[index] = value
    end

    return self
end
-- }}}

-- {{{ Transaction:set
-- Queue a value change in this transaction.
-- @param attr_id Attribute ID or index
-- @param value The value to set
function Transaction:set(attr_id, value)
    if self.committed then
        error("Transaction already committed")
    end
    self.pending[attr_id] = value
end
-- }}}

-- {{{ Transaction:get_pending
-- Get a pending value from this transaction.
-- @param attr_id Attribute ID or index
-- @return Pending value or nil if not set in this transaction
function Transaction:get_pending(attr_id)
    return self.pending[attr_id]
end
-- }}}

-- {{{ Transaction:commit
-- Apply all pending changes as a batch.
-- @param options Optional table (same as set())
-- @return Results table from set_many()
function Transaction:commit(options)
    if self.committed then
        error("Transaction already committed")
    end
    self.committed = true
    return setters.set_many(self.container, self.pending, options)
end
-- }}}

-- {{{ Transaction:rollback
-- Restore container to pre-transaction state.
function Transaction:rollback()
    if self.committed then
        error("Cannot rollback committed transaction")
    end

    -- Restore snapshot values
    for index, value in pairs(self.snapshot) do
        self.container.values[index] = value
    end

    -- Mark all derived as dirty (safe approach)
    for _, schema in pairs(registry.schemas) do
        if schema:is_derived() then
            self.container.dirty[schema.index] = true
        end
    end

    self.committed = true
end
-- }}}
-- }}}

-- {{{ setters.begin_transaction
-- Start a new transaction for batch updates with rollback support.
-- @param container The attribute container
-- @return Transaction instance
function setters.begin_transaction(container)
    return Transaction.new(container)
end
-- }}}

-- }}}

-- Initialize on load
build_setters()

return setters
