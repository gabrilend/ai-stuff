--[[
Event Context Stack

Provides context management for trigger execution. When a trigger fires,
event-specific data (triggering unit, player, etc.) is pushed onto a stack.
Context accessor functions (GetTriggerUnit, GetTriggerPlayer, etc.) read
from the current context.

The stack design supports nested trigger execution - when one trigger's
action fires another trigger, each maintains its own context.

Usage by event system:
    context.push({unit = someUnit, player = somePlayer}, trigger)
    -- trigger actions run, can call GetTriggerUnit() etc.
    context.pop()
]]

local context = {}

-- {{{ State
-- Context stack for nested trigger execution
-- Each entry: {trigger = <Trigger>, unit = <unit>, player = <player>, ...}
local context_stack = {}

-- Current context (top of stack, nil when empty)
local current_context = nil
-- }}}

-- {{{ context.push
-- Push a new context for trigger execution.
-- @param event_data Table with event-specific fields (unit, player, event_id, etc.)
-- @param trigger The trigger being executed
function context.push(event_data, trigger)
    -- Save current context to stack
    if current_context then
        context_stack[#context_stack + 1] = current_context
    end

    -- Create new context
    current_context = {
        trigger = trigger,
        event_id = event_data and event_data.event_id,
        unit = event_data and event_data.unit,
        player = event_data and event_data.player,
    }

    -- Copy any additional event-specific fields
    if event_data then
        for k, v in pairs(event_data) do
            if current_context[k] == nil then
                current_context[k] = v
            end
        end
    end
end
-- }}}

-- {{{ context.pop
-- Pop the current context and restore the previous one.
function context.pop()
    if #context_stack > 0 then
        current_context = context_stack[#context_stack]
        context_stack[#context_stack] = nil
    else
        current_context = nil
    end
end
-- }}}

-- {{{ context.get
-- Get a field from the current context.
-- @param field The field name to retrieve
-- @return The field value or nil if not set/no context
function context.get(field)
    if current_context then
        return current_context[field]
    end
    return nil
end
-- }}}

-- {{{ context.get_current
-- Get the entire current context table.
-- @return Current context or nil
function context.get_current()
    return current_context
end
-- }}}

-- {{{ context.is_active
-- Check if there is an active context.
-- @return true if in trigger execution, false otherwise
function context.is_active()
    return current_context ~= nil
end
-- }}}

-- {{{ context.get_depth
-- Get the current context stack depth.
-- @return Number of nested contexts (0 = no context, 1 = one trigger, etc.)
function context.get_depth()
    return #context_stack + (current_context and 1 or 0)
end
-- }}}

-- {{{ context.reset
-- Reset the context system.
-- Used when loading a new map or testing.
function context.reset()
    context_stack = {}
    current_context = nil
end
-- }}}

-- {{{ context.dump
-- Debug helper: print context stack info.
function context.dump()
    print("Context stack depth:", context.get_depth())
    if current_context then
        print("  Current trigger:", current_context.trigger)
        print("  Event ID:", current_context.event_id)
        print("  Unit:", current_context.unit)
        print("  Player:", current_context.player)
    else
        print("  (no active context)")
    end
end
-- }}}

return context
