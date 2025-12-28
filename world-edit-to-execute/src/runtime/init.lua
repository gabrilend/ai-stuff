--[[
Runtime API for Transpiled JASS Code

This module exports all runtime functions that transpiled JASS natives call.
When JASS code is transpiled to Lua, native function calls become runtime.X().

Example transpiled code:
    local t = runtime.CreateTrigger()
    runtime.TriggerAddAction(t, myAction)

The runtime module aggregates functionality from:
- handles.lua: Handle management (307a)
- triggers.lua: Trigger framework (307a-307d)
- context.lua: Event context stack (307d)
- timers.lua: Timer natives (401b)
- gameloop.lua: Game tick system (401a)
- ecs/: Entity component system (402)

Native functions are added incrementally as issues are implemented.
]]

-- {{{ Module setup
local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local runtime = {}
-- }}}

-- {{{ Load submodules
local handles = require("runtime.handles")
local triggers = require("runtime.triggers")
local context = require("runtime.context")
local events = require("runtime.events")
-- }}}

-- {{{ Export internal modules (for testing/debugging)
runtime._handles = handles
runtime._triggers = triggers
runtime._context = context
runtime._events = events
runtime._Trigger = triggers.Trigger

-- Export EVENT constants at top level for convenience
runtime.EVENT = events.EVENT
-- }}}

-- {{{ Utility: is_trigger
-- Check if an object is a valid trigger.
-- Used internally by trigger functions for validation.
runtime._is_trigger = triggers.is_trigger
-- }}}

--[[
=== Trigger Natives ===

Trigger lifecycle and management functions.
Implemented across issues 307a-307d:
- 307a: Data structures (this file setup)
- 307b: CreateTrigger, DestroyTrigger, Enable/Disable
- 307c: Conditions and Actions
- 307d: Context accessors (GetTriggerUnit, etc.)
]]

-- ============================================================================
-- 307b: Trigger Lifecycle API
-- ============================================================================

-- {{{ CreateTrigger
-- native CreateTrigger takes nothing returns trigger
-- Creates a new trigger and returns it.
function runtime.CreateTrigger()
    return triggers.Trigger.new()
end
-- }}}

-- {{{ DestroyTrigger
-- native DestroyTrigger takes trigger t returns nothing
-- Destroys a trigger, unregistering from all events and clearing state.
function runtime.DestroyTrigger(trigger)
    -- Silent fail for nil/invalid triggers (matches JASS behavior)
    if not triggers.is_trigger(trigger) then
        return
    end
    if not trigger:is_valid() then
        return
    end

    -- Unregister from all events (cleanup for event system)
    -- Each event entry should have an unregister method
    for _, event in ipairs(trigger.events) do
        if event.unregister then
            event:unregister(trigger)
        end
    end
    trigger.events = {}

    -- Clear conditions and actions
    -- Destroy their handles too
    for _, cond in ipairs(trigger.conditions) do
        handles.destroy(cond)
    end
    trigger.conditions = {}

    for _, action in ipairs(trigger.actions) do
        handles.destroy(action)
    end
    trigger.actions = {}

    -- Mark as disabled
    trigger.enabled = false

    -- Remove from handle system
    handles.destroy(trigger)
end
-- }}}

-- {{{ EnableTrigger
-- native EnableTrigger takes trigger t returns nothing
-- Enables a trigger so it can fire.
function runtime.EnableTrigger(trigger)
    if not triggers.is_trigger(trigger) then
        return
    end
    if not trigger:is_valid() then
        return
    end
    trigger.enabled = true
end
-- }}}

-- {{{ DisableTrigger
-- native DisableTrigger takes trigger t returns nothing
-- Disables a trigger so it won't fire.
function runtime.DisableTrigger(trigger)
    if not triggers.is_trigger(trigger) then
        return
    end
    if not trigger:is_valid() then
        return
    end
    trigger.enabled = false
end
-- }}}

-- {{{ IsTriggerEnabled
-- native IsTriggerEnabled takes trigger t returns boolean
-- Returns true if the trigger is enabled.
function runtime.IsTriggerEnabled(trigger)
    if not triggers.is_trigger(trigger) then
        return false
    end
    if not trigger:is_valid() then
        return false
    end
    return trigger.enabled
end
-- }}}

-- {{{ ResetTrigger
-- native ResetTrigger takes trigger t returns nothing
-- Resets the trigger's wait state (for TriggerSleepAction).
-- Currently a stub - full implementation requires coroutine support.
function runtime.ResetTrigger(trigger)
    if not triggers.is_trigger(trigger) then
        return
    end
    if not trigger:is_valid() then
        return
    end
    -- Reset any internal wait/sleep state
    trigger._wait_state = nil
end
-- }}}

-- {{{ TriggerGetExecCount
-- Returns how many times a trigger has executed.
-- Used for debugging and performance monitoring.
function runtime.TriggerGetExecCount(trigger)
    if not triggers.is_trigger(trigger) then
        return 0
    end
    return trigger._exec_count or 0
end
-- }}}

-- ============================================================================
-- 307c: Condition/Action System
-- ============================================================================

-- {{{ Condition
-- native Condition takes code func returns conditionfunc
-- Wraps a function for use as a trigger condition.
function runtime.Condition(func)
    if type(func) ~= "function" then
        -- Handle invalid input gracefully - return always-true condition
        return { type = "condition", func = function() return true end }
    end
    return {
        type = "condition",
        func = func,
    }
end
-- }}}

-- {{{ Filter
-- native Filter takes code func returns filterfunc
-- Same as Condition, used for enumeration filtering.
function runtime.Filter(func)
    return runtime.Condition(func)
end
-- }}}

-- {{{ TriggerAddCondition
-- native TriggerAddCondition takes trigger t, conditionfunc c returns triggercondition
-- Adds a condition to a trigger. Returns the condition handle.
function runtime.TriggerAddCondition(trigger, condition)
    if not triggers.is_trigger(trigger) or not trigger:is_valid() then
        return nil
    end
    if type(condition) ~= "table" or condition.type ~= "condition" then
        return nil
    end

    local triggercondition = {
        func = condition.func,
        trigger = trigger,
        _handle_type = "triggercondition",
    }

    -- Register with handle system
    handles.register(triggercondition, "triggercondition")

    -- Add to trigger's condition list
    trigger.conditions[#trigger.conditions + 1] = triggercondition

    return triggercondition
end
-- }}}

-- {{{ TriggerRemoveCondition
-- native TriggerRemoveCondition takes trigger t, triggercondition c returns nothing
-- Removes a specific condition from a trigger.
function runtime.TriggerRemoveCondition(trigger, condition)
    if not triggers.is_trigger(trigger) or not trigger:is_valid() then
        return
    end
    if condition == nil then
        return
    end

    for i, c in ipairs(trigger.conditions) do
        if c == condition then
            table.remove(trigger.conditions, i)
            handles.destroy(condition)
            return
        end
    end
end
-- }}}

-- {{{ TriggerClearConditions
-- native TriggerClearConditions takes trigger t returns nothing
-- Removes all conditions from a trigger.
function runtime.TriggerClearConditions(trigger)
    if not triggers.is_trigger(trigger) or not trigger:is_valid() then
        return
    end

    -- Destroy all condition handles
    for _, cond in ipairs(trigger.conditions) do
        handles.destroy(cond)
    end

    trigger.conditions = {}
end
-- }}}

-- {{{ TriggerEvaluate
-- native TriggerEvaluate takes trigger t returns boolean
-- Evaluates all conditions with AND logic.
-- Returns true only if all conditions return true.
function runtime.TriggerEvaluate(trigger)
    if not triggers.is_trigger(trigger) or not trigger:is_valid() then
        return false
    end
    if not trigger.enabled then
        return false
    end

    -- All conditions must return true (AND logic)
    for _, cond in ipairs(trigger.conditions) do
        local success, result = pcall(cond.func)
        if not success then
            -- Condition threw error - treat as false
            return false
        end
        if not result then
            return false
        end
    end

    return true
end
-- }}}

-- {{{ TriggerAddAction
-- native TriggerAddAction takes trigger t, code func returns triggeraction
-- Adds an action to a trigger. Returns the action handle.
function runtime.TriggerAddAction(trigger, func)
    if not triggers.is_trigger(trigger) or not trigger:is_valid() then
        return nil
    end
    if type(func) ~= "function" then
        return nil
    end

    local triggeraction = {
        func = func,
        trigger = trigger,
        _handle_type = "triggeraction",
    }

    -- Register with handle system
    handles.register(triggeraction, "triggeraction")

    -- Add to trigger's action list
    trigger.actions[#trigger.actions + 1] = triggeraction

    return triggeraction
end
-- }}}

-- {{{ TriggerRemoveAction
-- native TriggerRemoveAction takes trigger t, triggeraction a returns nothing
-- Removes a specific action from a trigger.
function runtime.TriggerRemoveAction(trigger, action)
    if not triggers.is_trigger(trigger) or not trigger:is_valid() then
        return
    end
    if action == nil then
        return
    end

    for i, a in ipairs(trigger.actions) do
        if a == action then
            table.remove(trigger.actions, i)
            handles.destroy(action)
            return
        end
    end
end
-- }}}

-- {{{ TriggerClearActions
-- native TriggerClearActions takes trigger t returns nothing
-- Removes all actions from a trigger.
function runtime.TriggerClearActions(trigger)
    if not triggers.is_trigger(trigger) or not trigger:is_valid() then
        return
    end

    -- Destroy all action handles
    for _, action in ipairs(trigger.actions) do
        handles.destroy(action)
    end

    trigger.actions = {}
end
-- }}}

-- {{{ TriggerExecute
-- native TriggerExecute takes trigger t returns nothing
-- Executes all actions (does NOT check conditions).
function runtime.TriggerExecute(trigger)
    if not triggers.is_trigger(trigger) or not trigger:is_valid() then
        return
    end
    if not trigger.enabled then
        return
    end

    -- Track execution count
    triggers.increment_exec_count(trigger)

    -- Execute each action in order
    for _, action in ipairs(trigger.actions) do
        -- Check trigger still valid (may be destroyed by previous action)
        if not trigger:is_valid() then
            break
        end
        local success, err = pcall(action.func)
        if not success then
            -- Action threw error - continue with next action
            -- Could log: print("Trigger action error:", err)
        end
    end
end
-- }}}

-- ============================================================================
-- 307d: Context Accessors
-- ============================================================================

-- {{{ GetTriggeringTrigger
-- native GetTriggeringTrigger takes nothing returns trigger
-- Returns the trigger that is currently executing.
function runtime.GetTriggeringTrigger()
    return context.get("trigger")
end
-- }}}

-- {{{ GetTriggerEventId
-- native GetTriggerEventId takes nothing returns eventid
-- Returns the event ID that caused the trigger to fire.
function runtime.GetTriggerEventId()
    return context.get("event_id")
end
-- }}}

-- {{{ GetTriggerUnit
-- native GetTriggerUnit takes nothing returns unit
-- Returns the unit that caused the event to fire.
function runtime.GetTriggerUnit()
    return context.get("unit")
end
-- }}}

-- {{{ GetTriggerPlayer
-- native GetTriggerPlayer takes nothing returns player
-- Returns the player that caused the event to fire.
function runtime.GetTriggerPlayer()
    return context.get("player")
end
-- }}}

-- {{{ Spell event accessors
-- native GetSpellAbilityId takes nothing returns integer
function runtime.GetSpellAbilityId()
    return context.get("spell_ability_id")
end

-- native GetSpellAbilityUnit takes nothing returns unit
function runtime.GetSpellAbilityUnit()
    return context.get("unit")  -- Same as GetTriggerUnit for spell events
end

-- native GetSpellTargetUnit takes nothing returns unit
function runtime.GetSpellTargetUnit()
    return context.get("spell_target_unit")
end

-- native GetSpellTargetX takes nothing returns real
function runtime.GetSpellTargetX()
    return context.get("spell_target_x") or 0.0
end

-- native GetSpellTargetY takes nothing returns real
function runtime.GetSpellTargetY()
    return context.get("spell_target_y") or 0.0
end
-- }}}

-- {{{ Order event accessors
-- native GetOrderedUnit takes nothing returns unit
function runtime.GetOrderedUnit()
    return context.get("ordered_unit") or context.get("unit")
end

-- native GetIssuedOrderId takes nothing returns integer
function runtime.GetIssuedOrderId()
    return context.get("order_id")
end

-- native GetOrderTargetUnit takes nothing returns unit
function runtime.GetOrderTargetUnit()
    return context.get("order_target_unit")
end

-- native GetOrderPointX takes nothing returns real
function runtime.GetOrderPointX()
    return context.get("order_point_x") or 0.0
end

-- native GetOrderPointY takes nothing returns real
function runtime.GetOrderPointY()
    return context.get("order_point_y") or 0.0
end
-- }}}

-- {{{ Death event accessors
-- native GetDyingUnit takes nothing returns unit
function runtime.GetDyingUnit()
    return context.get("dying_unit") or context.get("unit")
end

-- native GetKillingUnit takes nothing returns unit
function runtime.GetKillingUnit()
    return context.get("killing_unit")
end
-- }}}

-- {{{ Construction event accessors
-- native GetConstructingStructure takes nothing returns unit
function runtime.GetConstructingStructure()
    return context.get("constructed_structure")
end

-- native GetConstructedStructure takes nothing returns unit
function runtime.GetConstructedStructure()
    return context.get("constructed_structure")
end
-- }}}

-- {{{ Attack event accessors
-- native GetAttacker takes nothing returns unit
function runtime.GetAttacker()
    return context.get("attacker")
end

-- native GetAttackedUnitBJ takes nothing returns unit
function runtime.GetAttackedUnitBJ()
    return context.get("attacked_unit") or context.get("unit")
end
-- }}}

-- {{{ Damage event accessors
-- native GetEventDamage takes nothing returns real
function runtime.GetEventDamage()
    return context.get("event_damage") or 0.0
end

-- native GetEventDamageSource takes nothing returns unit
function runtime.GetEventDamageSource()
    return context.get("damage_source")
end
-- }}}

-- {{{ Timer event accessor
-- native GetExpiredTimer takes nothing returns timer
function runtime.GetExpiredTimer()
    return context.get("expired_timer")
end
-- }}}

-- ============================================================================
-- 308b: Timer Events
-- ============================================================================

-- {{{ Timer storage
-- Timers are stored in runtime._timers by their unique ID.
-- Each timer tracks timeout, elapsed time, periodic flag, and associated trigger.
runtime._timers = {}
runtime._next_timer_id = 1
-- }}}

-- {{{ TriggerRegisterTimerEvent
-- Register a trigger to fire on a timer.
-- @param trigger The trigger to fire
-- @param timeout Time in seconds until fire
-- @param periodic If true, fires repeatedly; if false, fires once
-- @return Timer object for control (pause/resume/destroy)
function runtime.TriggerRegisterTimerEvent(trigger, timeout, periodic)
    if not triggers.is_trigger(trigger) then
        return nil
    end
    if type(timeout) ~= "number" or timeout <= 0 then
        return nil
    end

    local timer_id = runtime._next_timer_id
    runtime._next_timer_id = runtime._next_timer_id + 1

    local timer = {
        id = timer_id,
        trigger = trigger,
        timeout = timeout,
        periodic = periodic or false,
        elapsed = 0,
        enabled = true,
        _handle_type = "timer",
    }

    -- Register with handle system
    handles.register(timer, "timer")

    -- Determine event type based on periodic flag
    local event_type = periodic and
        events.EVENT.TIMER_PERIODIC or
        events.EVENT.TIMER_EXPIRE

    -- Register with event system, filter for this specific timer
    local listener = events.register(
        event_type,
        trigger,
        function(ctx) return ctx.timer_id == timer_id end
    )

    timer.listener = listener
    timer.event_type = event_type
    runtime._timers[timer_id] = timer

    return timer
end
-- }}}

-- {{{ CreateTimer
-- native CreateTimer takes nothing returns timer
-- Creates a standalone timer (not attached to a trigger).
-- Use TimerStart to begin it.
function runtime.CreateTimer()
    local timer_id = runtime._next_timer_id
    runtime._next_timer_id = runtime._next_timer_id + 1

    local timer = {
        id = timer_id,
        trigger = nil,
        timeout = 0,
        periodic = false,
        elapsed = 0,
        enabled = false,  -- Not started yet
        callback = nil,
        _handle_type = "timer",
    }

    -- Register with handle system
    handles.register(timer, "timer")
    runtime._timers[timer_id] = timer

    return timer
end
-- }}}

-- {{{ TimerStart
-- native TimerStart takes timer t, real timeout, boolean periodic, code handlerFunc returns nothing
-- Starts a timer with specified timeout and callback.
function runtime.TimerStart(timer, timeout, periodic, handlerFunc)
    if not timer or not runtime._timers[timer.id] then
        return
    end
    if type(timeout) ~= "number" or timeout <= 0 then
        return
    end

    timer.timeout = timeout
    timer.periodic = periodic or false
    timer.elapsed = 0
    timer.enabled = true
    timer.callback = handlerFunc

    -- Determine event type based on periodic flag
    local event_type = periodic and
        events.EVENT.TIMER_PERIODIC or
        events.EVENT.TIMER_EXPIRE

    timer.event_type = event_type
end
-- }}}

-- {{{ PauseTimer
-- native PauseTimer takes timer t returns nothing
-- Pauses a timer, stopping time accumulation.
function runtime.PauseTimer(timer)
    if timer and runtime._timers[timer.id] then
        timer.enabled = false
    end
end
-- }}}

-- {{{ ResumeTimer
-- native ResumeTimer takes timer t returns nothing
-- Resumes a paused timer.
function runtime.ResumeTimer(timer)
    if timer and runtime._timers[timer.id] then
        timer.enabled = true
    end
end
-- }}}

-- {{{ DestroyTimer
-- native DestroyTimer takes timer t returns nothing
-- Destroys a timer, removing it completely.
function runtime.DestroyTimer(timer)
    if not timer then return end

    local stored = runtime._timers[timer.id]
    if not stored then return end

    -- Unregister from event system if listener exists
    if stored.listener then
        events.unregister(stored.listener)
    end

    -- Remove from timer registry
    runtime._timers[timer.id] = nil

    -- Remove from handle system
    handles.destroy(timer)
end
-- }}}

-- {{{ TimerGetElapsed
-- native TimerGetElapsed takes timer t returns real
-- Returns accumulated time since last fire (or start).
function runtime.TimerGetElapsed(timer)
    if timer and runtime._timers[timer.id] then
        return timer.elapsed
    end
    return 0
end
-- }}}

-- {{{ TimerGetRemaining
-- native TimerGetRemaining takes timer t returns real
-- Returns time remaining until next fire.
function runtime.TimerGetRemaining(timer)
    if timer and runtime._timers[timer.id] then
        return math.max(0, timer.timeout - timer.elapsed)
    end
    return 0
end
-- }}}

-- {{{ TimerGetTimeout
-- native TimerGetTimeout takes timer t returns real
-- Returns the timer's timeout period.
function runtime.TimerGetTimeout(timer)
    if timer and runtime._timers[timer.id] then
        return timer.timeout
    end
    return 0
end
-- }}}

-- {{{ IsTimerPeriodic
-- Returns true if the timer is periodic (repeating).
function runtime.IsTimerPeriodic(timer)
    if timer and runtime._timers[timer.id] then
        return timer.periodic
    end
    return false
end
-- }}}

-- ============================================================================
-- 308c: Region Events
-- ============================================================================

-- {{{ TriggerRegisterEnterRegion
-- Register a trigger to fire when a unit enters a region.
-- @param trigger The trigger to fire
-- @param region The region to watch
-- @param filter Optional function(unit) to filter which units trigger event
-- @return Listener handle for unregistration
function runtime.TriggerRegisterEnterRegion(trigger, region, filter)
    if not triggers.is_trigger(trigger) then
        return nil
    end
    if region == nil then
        return nil
    end

    return events.register(
        events.EVENT.UNIT_ENTER_REGION,
        trigger,
        function(ctx)
            -- Must match the registered region
            if ctx.region ~= region then return false end
            -- Apply optional unit filter
            if filter and not filter(ctx.unit) then return false end
            return true
        end
    )
end
-- }}}

-- {{{ TriggerRegisterLeaveRegion
-- Register a trigger to fire when a unit leaves a region.
-- @param trigger The trigger to fire
-- @param region The region to watch
-- @param filter Optional function(unit) to filter which units trigger event
-- @return Listener handle for unregistration
function runtime.TriggerRegisterLeaveRegion(trigger, region, filter)
    if not triggers.is_trigger(trigger) then
        return nil
    end
    if region == nil then
        return nil
    end

    return events.register(
        events.EVENT.UNIT_LEAVE_REGION,
        trigger,
        function(ctx)
            -- Must match the registered region
            if ctx.region ~= region then return false end
            -- Apply optional unit filter
            if filter and not filter(ctx.unit) then return false end
            return true
        end
    )
end
-- }}}

-- {{{ GetEnteringUnit
-- native GetEnteringUnit takes nothing returns unit
-- Returns the unit that entered a region.
function runtime.GetEnteringUnit()
    return context.get("entering_unit") or context.get("unit")
end
-- }}}

-- {{{ GetLeavingUnit
-- native GetLeavingUnit takes nothing returns unit
-- Returns the unit that left a region.
function runtime.GetLeavingUnit()
    return context.get("leaving_unit") or context.get("unit")
end
-- }}}

-- {{{ GetTriggerRegion
-- Returns the region that triggered the enter/leave event.
function runtime.GetTriggerRegion()
    return context.get("region")
end
-- }}}

-- {{{ runtime.reset
-- Reset all runtime state.
-- Called when loading a new map or restarting.
function runtime.reset()
    handles.reset()
    triggers.reset()
    context.reset()
    events.reset()
    -- Reset timer state
    runtime._timers = {}
    runtime._next_timer_id = 1
end
-- }}}

-- {{{ runtime.get_stats
-- Get runtime statistics for debugging.
-- @return Table with handle_count, trigger_count, event_listeners, timer_count, etc.
function runtime.get_stats()
    local handle_stats = handles.get_stats()
    local event_stats = events.get_stats()
    -- Count active timers
    local timer_count = 0
    for _ in pairs(runtime._timers) do
        timer_count = timer_count + 1
    end
    return {
        handle_count = handle_stats.count,
        next_handle_id = handle_stats.next_id,
        trigger_count = triggers.get_count(),
        event_listeners = event_stats.total_listeners,
        timer_count = timer_count,
    }
end
-- }}}

return runtime
