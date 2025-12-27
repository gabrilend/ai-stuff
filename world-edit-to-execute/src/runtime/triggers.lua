--[[
Trigger Framework

Provides the Trigger class and related utilities for the JASS trigger system.
Triggers are the core scripting mechanism in WC3 maps - they respond to
events, evaluate conditions, and execute actions.

This module defines the Trigger data structure. The runtime API functions
(CreateTrigger, TriggerAddAction, etc.) are implemented in init.lua and
use this class internally.
]]

-- {{{ Module setup
-- Get directory for proper requires
local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local handles = require("runtime.handles")

local triggers = {}
-- }}}

-- {{{ Trigger class
local Trigger = {}
Trigger.__index = Trigger

-- Export class for internal use
triggers.Trigger = Trigger
-- }}}

-- {{{ Active trigger tracking
-- Weak table to track all active triggers
-- Weak values allow garbage collection when triggers aren't referenced
local active_triggers = setmetatable({}, {__mode = "v"})
-- }}}

-- {{{ Trigger.new
-- Create a new trigger with initialized state.
-- Automatically registers with handle system and active tracker.
-- @return New Trigger instance
function Trigger.new()
    local self = setmetatable({}, Trigger)

    -- State
    self.enabled = true

    -- Condition functions: evaluated with AND logic
    -- Each entry: {func = <function>, trigger = self}
    self.conditions = {}

    -- Action functions: executed in order
    -- Each entry: {func = <function>, trigger = self}
    self.actions = {}

    -- Registered events: for cleanup on destroy
    -- Each entry: {type = "event_type", unregister = function}
    self.events = {}

    -- Execution statistics
    self._exec_count = 0

    -- Register with handle system
    handles.register(self, "trigger")

    -- Track in active triggers
    active_triggers[self._handle_id] = self

    return self
end
-- }}}

-- {{{ Trigger:is_valid
-- Check if this trigger is still valid (not destroyed).
-- @return true if valid, false if destroyed
function Trigger:is_valid()
    return handles.is_valid(self)
end
-- }}}

-- {{{ Trigger.__tostring
-- String representation for debugging.
-- Format: Trigger<id>[N cond, M act, status]
function Trigger:__tostring()
    local id = self._handle_id or "?"
    local status = self.enabled and "enabled" or "disabled"
    if not self:is_valid() then
        status = "destroyed"
    end
    return string.format("Trigger<%s>[%d cond, %d act, %s]",
        id, #self.conditions, #self.actions, status)
end
-- }}}

-- {{{ triggers.is_trigger
-- Check if an object is a Trigger instance.
-- @param obj The object to check
-- @return true if obj is a Trigger
function triggers.is_trigger(obj)
    return type(obj) == "table" and getmetatable(obj) == Trigger
end
-- }}}

-- {{{ triggers.get_all
-- Get all active (non-destroyed) triggers.
-- @return Array of active Trigger instances
function triggers.get_all()
    local result = {}
    for _, t in pairs(active_triggers) do
        if t:is_valid() then
            result[#result + 1] = t
        end
    end
    return result
end
-- }}}

-- {{{ triggers.get_count
-- Get count of active triggers.
-- @return Number of active triggers
function triggers.get_count()
    local count = 0
    for _, t in pairs(active_triggers) do
        if t:is_valid() then
            count = count + 1
        end
    end
    return count
end
-- }}}

-- {{{ triggers.increment_exec_count
-- Increment the execution counter for a trigger.
-- Called internally when trigger fires successfully.
-- @param trigger The trigger to update
function triggers.increment_exec_count(trigger)
    if trigger and trigger._exec_count then
        trigger._exec_count = trigger._exec_count + 1
    end
end
-- }}}

-- {{{ Trigger:fire
-- Internal: Called by event system when trigger should fire.
-- Evaluates conditions, then executes actions if passed.
-- @param event_data Table with event context (unit, player, event_id, etc.)
-- @return true if actions executed, false if conditions failed or trigger disabled
function Trigger:fire(event_data)
    if not self:is_valid() then
        return false
    end
    if not self.enabled then
        return false
    end

    -- Push context for this trigger execution
    -- Context module handles nested triggers via stack
    local context = require("runtime.context")
    context.push(event_data, self)

    -- Evaluate all conditions (AND logic)
    local should_run = true
    for _, cond in ipairs(self.conditions) do
        local success, result = pcall(cond.func)
        if not success or not result then
            should_run = false
            break
        end
    end

    -- Execute actions if conditions passed
    if should_run then
        triggers.increment_exec_count(self)

        for _, action in ipairs(self.actions) do
            -- Check trigger still valid (may be destroyed by previous action)
            if not self:is_valid() then
                break
            end

            local success, err = pcall(action.func)
            if not success then
                -- Could log: print("Trigger action error:", err)
            end
        end
    end

    -- Pop context (restore previous if nested)
    context.pop()

    return should_run
end
-- }}}

-- {{{ triggers.reset
-- Reset the trigger subsystem.
-- Destroys all active triggers and clears tracking.
function triggers.reset()
    -- Destroy all active triggers through handle system
    for _, t in pairs(active_triggers) do
        if t:is_valid() then
            handles.destroy(t)
        end
    end
    active_triggers = setmetatable({}, {__mode = "v"})
end
-- }}}

return triggers
