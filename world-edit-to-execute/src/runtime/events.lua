--[[
Event Registry Core (308a)

The foundational event system that stores trigger-to-event bindings and
fires events to registered triggers. This is the central dispatch mechanism
for the runtime - all game events (timers, combat, regions, players) flow
through this registry.

Usage:
    local events = require("runtime.events")

    -- Register a trigger for an event type
    local listener = events.register(events.EVENT.UNIT_DEATH, trigger, filterFunc)

    -- Fire an event (called by game systems)
    events.fire(events.EVENT.UNIT_DEATH, {unit = dyingUnit, killer = killerUnit})

    -- Unregister when done
    events.unregister(listener)

The event system is intentionally event-type agnostic at this layer.
Specific event behaviors (timer ticks, region checks, etc.) are added
in 308b-308e and Phase 4 issues.
]]

-- {{{ Configuration
local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

-- {{{ Module setup
local events = {}
-- }}}

-- ============================================================================
-- EVENT Type Constants
-- ============================================================================

-- {{{ EVENT
-- All event type constants used by the runtime.
-- Events are grouped by category for organization.
events.EVENT = {
    -- Game events
    MAP_INIT = 1,
    GAME_START = 2,

    -- Timer events (308b)
    TIMER_EXPIRE = 10,
    TIMER_PERIODIC = 11,

    -- Unit events (308d)
    UNIT_DEATH = 20,
    UNIT_SPAWN = 21,
    UNIT_DAMAGED = 22,
    UNIT_ATTACKED = 23,
    UNIT_ACQUIRED_TARGET = 24,
    UNIT_ISSUED_ORDER = 25,
    UNIT_ISSUED_POINT_ORDER = 26,
    UNIT_ISSUED_TARGET_ORDER = 27,
    UNIT_SELECTED = 28,
    UNIT_DESELECTED = 29,

    -- Spell events (308d)
    UNIT_SPELL_CHANNEL = 30,
    UNIT_SPELL_CAST = 31,
    UNIT_SPELL_EFFECT = 32,
    UNIT_SPELL_FINISH = 33,
    UNIT_SPELL_ENDCAST = 34,

    -- Region events (308c)
    UNIT_ENTER_REGION = 40,
    UNIT_LEAVE_REGION = 41,

    -- Player events (308e)
    PLAYER_CHAT = 50,
    PLAYER_LEAVE = 51,
    PLAYER_ALLIANCE_CHANGE = 52,
    PLAYER_DEFEAT = 53,
    PLAYER_VICTORY = 54,

    -- Dialog events
    DIALOG_BUTTON_CLICK = 60,
    DIALOG_CLOSE = 61,

    -- Trackable events (for custom UI elements)
    TRACKABLE_HIT = 70,
    TRACKABLE_TRACK = 71,
}
-- }}}

-- ============================================================================
-- Listener Storage
-- ============================================================================

-- {{{ Internal registry state
-- Listeners are stored by event type for efficient lookup.
-- Each entry in listeners[event_type] is a table:
--   { id, trigger, filter, event_type }
local listeners = {}  -- event_type -> list of listener objects
local next_listener_id = 1
-- }}}

-- ============================================================================
-- Registry Operations
-- ============================================================================

-- {{{ register
-- Register a trigger to receive events of a specific type.
-- @param event_type The EVENT constant to listen for
-- @param trigger The trigger object to fire when event occurs
-- @param filter Optional function(ctx) -> bool to narrow which events fire
-- @return listener handle for unregistration
function events.register(event_type, trigger, filter)
    if event_type == nil then
        return nil
    end
    if trigger == nil then
        return nil
    end

    -- Initialize listener list for this event type if needed
    if not listeners[event_type] then
        listeners[event_type] = {}
    end

    -- Create listener object
    local id = next_listener_id
    next_listener_id = next_listener_id + 1

    local listener = {
        id = id,
        event_type = event_type,
        trigger = trigger,
        filter = filter,  -- Optional: may be nil
    }

    -- Add to event's listener list
    local list = listeners[event_type]
    list[#list + 1] = listener

    -- Track in trigger.events for cleanup when trigger is destroyed
    -- Each entry has unregister method for DestroyTrigger to call
    if trigger.events then
        trigger.events[#trigger.events + 1] = {
            type = event_type,
            listener = listener,
            unregister = function(self, trig)
                events.unregister(self.listener)
            end,
        }
    end

    return listener
end
-- }}}

-- {{{ unregister
-- Remove a listener from the registry.
-- @param listener The listener handle returned by register()
-- Note: Does NOT remove from trigger.events - that's handled by DestroyTrigger
-- which clears trigger.events after iterating. This avoids modification-during-iteration.
function events.unregister(listener)
    if listener == nil then
        return
    end

    local event_type = listener.event_type
    if not event_type then
        return
    end

    local list = listeners[event_type]
    if not list then
        return
    end

    -- Find and remove listener from list
    for i, l in ipairs(list) do
        if l.id == listener.id then
            table.remove(list, i)
            break
        end
    end
end
-- }}}

-- {{{ fire
-- Fire an event to all registered triggers.
-- @param event_type The EVENT constant being fired
-- @param context Table containing event-specific data
-- Called by game systems (timer tick, combat, region check, etc.)
function events.fire(event_type, context)
    if event_type == nil then
        return
    end

    local list = listeners[event_type]
    if not list then
        return
    end

    -- Ensure context has event_id
    context = context or {}
    context.event_id = event_type

    -- Iterate through listeners (copy list to handle modifications during iteration)
    -- A listener may unregister itself during fire, so we snapshot the list
    local list_copy = {}
    for i, l in ipairs(list) do
        list_copy[i] = l
    end

    for _, listener in ipairs(list_copy) do
        local should_fire = true

        -- Apply filter if present
        if listener.filter then
            local success, result = pcall(listener.filter, context)
            if not success then
                -- Filter threw error - skip this listener
                should_fire = false
            elseif not result then
                -- Filter returned false - skip
                should_fire = false
            end
        end

        -- Fire the trigger if filter passed (or no filter)
        if should_fire then
            local trigger = listener.trigger
            if trigger and trigger.fire then
                -- trigger:fire handles context push/pop and condition/action execution
                trigger:fire(context)
            end
        end
    end
end
-- }}}

-- {{{ get_listener_count
-- Get the number of listeners for a specific event type.
-- @param event_type The EVENT constant to check
-- @return Number of registered listeners
function events.get_listener_count(event_type)
    local list = listeners[event_type]
    if not list then
        return 0
    end
    return #list
end
-- }}}

-- {{{ get_total_listener_count
-- Get the total number of listeners across all event types.
-- @return Total number of registered listeners
function events.get_total_listener_count()
    local count = 0
    for _, list in pairs(listeners) do
        count = count + #list
    end
    return count
end
-- }}}

-- {{{ reset
-- Clear all event registrations.
-- Called when loading a new map or resetting runtime.
function events.reset()
    listeners = {}
    next_listener_id = 1
end
-- }}}

-- ============================================================================
-- Timer Update (308b)
-- ============================================================================

-- {{{ update_timers
-- Update all timers by delta time.
-- Called by the game loop each tick.
-- @param dt Delta time in seconds since last tick
-- @param runtime Reference to runtime module (for accessing _timers)
-- Note: This function is called by the game loop (401), passing the runtime module.
function events.update_timers(dt, runtime)
    if not runtime or not runtime._timers then
        return
    end

    for id, timer in pairs(runtime._timers) do
        if timer.enabled and timer.timeout > 0 then
            timer.elapsed = timer.elapsed + dt

            if timer.elapsed >= timer.timeout then
                -- Timer fired!
                local event_type = timer.periodic and
                    events.EVENT.TIMER_PERIODIC or
                    events.EVENT.TIMER_EXPIRE

                -- Build event context
                local ctx = {
                    event_id = event_type,
                    timer_id = id,
                    timer = timer,
                    expired_timer = timer,  -- For GetExpiredTimer()
                    elapsed = timer.elapsed,
                }

                -- If timer has a direct callback (from TimerStart), call it
                if timer.callback then
                    local success, err = pcall(timer.callback)
                    if not success then
                        -- Could log: print("Timer callback error:", err)
                    end
                end

                -- Fire the event for trigger-based timers
                if timer.trigger then
                    events.fire(event_type, ctx)
                end

                if timer.periodic then
                    -- Periodic: reset elapsed, preserving overflow for accuracy
                    timer.elapsed = timer.elapsed - timer.timeout
                else
                    -- One-shot: disable after firing
                    timer.enabled = false
                end
            end
        end
    end
end
-- }}}

-- ============================================================================
-- Region Events (308c)
-- ============================================================================

-- {{{ unit_entered_region
-- Called by region/collision system when unit crosses into a region.
-- @param unit The unit that entered
-- @param region The region entered
function events.unit_entered_region(unit, region)
    events.fire(events.EVENT.UNIT_ENTER_REGION, {
        event_id = events.EVENT.UNIT_ENTER_REGION,
        unit = unit,
        entering_unit = unit,
        region = region,
    })
end
-- }}}

-- {{{ unit_left_region
-- Called by region/collision system when unit crosses out of a region.
-- @param unit The unit that left
-- @param region The region left
function events.unit_left_region(unit, region)
    events.fire(events.EVENT.UNIT_LEAVE_REGION, {
        event_id = events.EVENT.UNIT_LEAVE_REGION,
        unit = unit,
        leaving_unit = unit,
        region = region,
    })
end
-- }}}

-- {{{ get_stats
-- Get event registry statistics for debugging.
-- @return Table with listener counts by event type
function events.get_stats()
    local stats = {
        total_listeners = 0,
        by_type = {},
    }

    for event_type, list in pairs(listeners) do
        local count = #list
        stats.by_type[event_type] = count
        stats.total_listeners = stats.total_listeners + count
    end

    return stats
end
-- }}}

return events
