--[[
Timer Subsystem - WC3-Compatible Timer Implementation

Provides a timer system matching WC3's JASS timer API:
- CreateTimer, DestroyTimer
- TimerStart, PauseTimer, ResumeTimer
- TimerGetElapsed, TimerGetRemaining, TimerGetTimeout

Uses a min-heap priority queue for efficient expiration checking.
Integrates with gameloop for tick-based processing.
]]

local timers = {}

local gameloop = require("runtime.gameloop")

-- {{{ State
-- Priority queue for active timers (min-heap sorted by expiration_time)
local timer_queue = {}

-- Counter for generating timer IDs when no handle system is available
local timer_id_counter = 0

-- Tick callback ID for cleanup
local tick_callback_id = nil

-- B02 fix: Timer registry for orphan detection.
-- Maps timer_id -> timer for all active timers.
-- Allows cleanup_orphans to find all timers even if script lost reference.
local timer_registry = {}
-- }}}

-- {{{ Priority Queue - Binary Heap Implementation
-- Min-heap where smallest expiration_time is at index 1.
-- This ensures O(1) peek and O(log n) insert/remove.

-- {{{ heap_parent
local function heap_parent(i)
    return math.floor(i / 2)
end
-- }}}

-- {{{ heap_left
local function heap_left(i)
    return 2 * i
end
-- }}}

-- {{{ heap_right
local function heap_right(i)
    return 2 * i + 1
end
-- }}}

-- {{{ heap_swap
local function heap_swap(i, j)
    timer_queue[i], timer_queue[j] = timer_queue[j], timer_queue[i]
    -- Update queue indices stored in timer objects
    timer_queue[i].queue_index = i
    timer_queue[j].queue_index = j
end
-- }}}

-- {{{ heap_bubble_up
local function heap_bubble_up(i)
    while i > 1 do
        local parent = heap_parent(i)
        if timer_queue[parent].expiration_time <= timer_queue[i].expiration_time then
            break
        end
        heap_swap(i, parent)
        i = parent
    end
end
-- }}}

-- {{{ heap_bubble_down
local function heap_bubble_down(i)
    local n = #timer_queue
    while true do
        local smallest = i
        local left = heap_left(i)
        local right = heap_right(i)

        if left <= n and timer_queue[left].expiration_time < timer_queue[smallest].expiration_time then
            smallest = left
        end
        if right <= n and timer_queue[right].expiration_time < timer_queue[smallest].expiration_time then
            smallest = right
        end

        if smallest == i then
            break
        end

        heap_swap(i, smallest)
        i = smallest
    end
end
-- }}}

-- {{{ heap_insert
local function heap_insert(timer)
    timer_queue[#timer_queue + 1] = timer
    timer.queue_index = #timer_queue
    heap_bubble_up(#timer_queue)
end
-- }}}

-- {{{ heap_remove
local function heap_remove(timer)
    local i = timer.queue_index
    if not i or i > #timer_queue then
        return
    end

    local n = #timer_queue
    if i == n then
        -- Removing last element, just pop
        timer_queue[n] = nil
    else
        -- Move last element to this position and reheapify
        timer_queue[i] = timer_queue[n]
        timer_queue[i].queue_index = i
        timer_queue[n] = nil

        -- May need to bubble up or down depending on new value
        if i > 1 and timer_queue[i].expiration_time < timer_queue[heap_parent(i)].expiration_time then
            heap_bubble_up(i)
        else
            heap_bubble_down(i)
        end
    end

    timer.queue_index = nil
end
-- }}}

-- {{{ heap_peek
local function heap_peek()
    return timer_queue[1]
end
-- }}}

-- {{{ heap_pop
local function heap_pop()
    local timer = timer_queue[1]
    if timer then
        heap_remove(timer)
    end
    return timer
end
-- }}}

-- }}}

-- {{{ timers.create
-- Create a new timer handle.
-- Returns timer object with handle integration.
-- B02 fix: Timers are now tracked in registry for orphan detection.
function timers.create()
    timer_id_counter = timer_id_counter + 1

    local timer = {
        _handle_type = "timer",
        _handle_id = timer_id_counter,

        -- Timer state
        duration = 0,
        expiration_time = 0,
        elapsed = 0,
        periodic = false,
        callback = nil,
        running = false,
        paused = false,

        -- Queue tracking
        queue_index = nil,

        -- B02 fix: Owner tracking for orphan detection.
        -- If owner handle becomes invalid, timer can be cleaned up.
        owner = nil,
    }

    -- B02 fix: Register timer for orphan detection
    timer_registry[timer._handle_id] = timer

    return timer
end
-- }}}

-- {{{ timers.start
-- Start a timer with specified parameters.
--
-- @param timer Timer handle from create()
-- @param duration Time until expiration in seconds
-- @param periodic If true, timer repeats; if false, one-shot
-- @param callback Function to call on expiration
function timers.start(timer, duration, periodic, callback)
    if not timer or timer._handle_type ~= "timer" then
        error("TimerStart: invalid timer handle")
    end

    if type(duration) ~= "number" or duration < 0 then
        error("TimerStart: duration must be non-negative number")
    end

    if type(callback) ~= "function" then
        error("TimerStart: callback must be a function")
    end

    -- Remove from queue if already running
    if timer.running and timer.queue_index then
        heap_remove(timer)
    end

    -- Set timer properties
    timer.duration = duration
    timer.periodic = periodic or false
    timer.callback = callback
    timer.elapsed = 0
    timer.running = true
    timer.paused = false

    -- Calculate expiration time
    local current_time = gameloop.get_time()
    timer.expiration_time = current_time + duration

    -- Insert into priority queue
    heap_insert(timer)
end
-- }}}

-- {{{ timers.pause
-- Pause a running timer.
-- Elapsed time is preserved for later resume.
function timers.pause(timer)
    if not timer or timer._handle_type ~= "timer" then
        return
    end

    if not timer.running or timer.paused then
        return
    end

    -- Calculate how much time has elapsed
    local current_time = gameloop.get_time()
    timer.elapsed = timer.duration - (timer.expiration_time - current_time)

    -- Clamp elapsed to valid range
    if timer.elapsed < 0 then
        timer.elapsed = 0
    elseif timer.elapsed > timer.duration then
        timer.elapsed = timer.duration
    end

    -- Remove from queue
    if timer.queue_index then
        heap_remove(timer)
    end

    timer.paused = true
end
-- }}}

-- {{{ timers.resume
-- Resume a paused timer.
-- Continues from where it was paused.
function timers.resume(timer)
    if not timer or timer._handle_type ~= "timer" then
        return
    end

    if not timer.running or not timer.paused then
        return
    end

    -- Calculate remaining time
    local remaining = timer.duration - timer.elapsed
    local current_time = gameloop.get_time()
    timer.expiration_time = current_time + remaining

    -- Re-insert into queue
    heap_insert(timer)

    timer.paused = false
end
-- }}}

-- {{{ timers.destroy
-- Destroy a timer and clean up resources.
-- B02 fix: Also removes from timer registry.
function timers.destroy(timer)
    if not timer or timer._handle_type ~= "timer" then
        return
    end

    -- B02 fix: Remove from registry before clearing handle_id
    if timer._handle_id then
        timer_registry[timer._handle_id] = nil
    end

    -- Remove from queue if present
    if timer.queue_index then
        heap_remove(timer)
    end

    -- Clear state
    timer.running = false
    timer.paused = false
    timer.callback = nil
    timer.owner = nil
    timer._handle_id = nil
    timer._handle_type = nil
end
-- }}}

-- {{{ timers.get_elapsed
-- Return time elapsed since timer started.
function timers.get_elapsed(timer)
    if not timer or timer._handle_type ~= "timer" then
        return 0
    end

    if timer.paused then
        return timer.elapsed
    end

    if not timer.running then
        return 0
    end

    local current_time = gameloop.get_time()
    local elapsed = timer.duration - (timer.expiration_time - current_time)

    -- Clamp to valid range
    if elapsed < 0 then
        return 0
    elseif elapsed > timer.duration then
        return timer.duration
    end

    return elapsed
end
-- }}}

-- {{{ timers.get_remaining
-- Return time remaining until expiration.
function timers.get_remaining(timer)
    if not timer or timer._handle_type ~= "timer" then
        return 0
    end

    if timer.paused then
        return timer.duration - timer.elapsed
    end

    if not timer.running then
        return 0
    end

    local current_time = gameloop.get_time()
    local remaining = timer.expiration_time - current_time

    return remaining > 0 and remaining or 0
end
-- }}}

-- {{{ timers.get_timeout
-- Return the timer's duration (timeout value).
function timers.get_timeout(timer)
    if not timer or timer._handle_type ~= "timer" then
        return 0
    end

    return timer.duration
end
-- }}}

-- {{{ timers.set_owner
-- B02 fix: Associate a timer with an owner handle.
-- When cleanup_orphans is called with a validation function,
-- timers with invalid owners will be destroyed.
--
-- @param timer Timer handle from create()
-- @param owner Any value representing the owner (entity ID, handle, etc.)
function timers.set_owner(timer, owner)
    if not timer or timer._handle_type ~= "timer" then
        return
    end

    timer.owner = owner
end
-- }}}

-- {{{ timers.get_owner
-- B02 fix: Get the owner associated with a timer.
-- Returns nil if no owner set or timer invalid.
function timers.get_owner(timer)
    if not timer or timer._handle_type ~= "timer" then
        return nil
    end

    return timer.owner
end
-- }}}

-- {{{ timers.cleanup_orphans
-- B02 fix: Destroy all timers whose owners are no longer valid.
-- This prevents periodic timers from running forever when their
-- owner (unit, trigger, etc.) is destroyed but DestroyTimer wasn't called.
--
-- @param is_valid_fn Function that takes an owner and returns true if valid.
--                    If nil, destroys all timers that have an owner set.
-- @return Number of timers destroyed
function timers.cleanup_orphans(is_valid_fn)
    local destroyed = 0
    local to_destroy = {}

    -- Collect orphaned timers
    for timer_id, timer in pairs(timer_registry) do
        if timer.owner ~= nil then
            -- Timer has an owner - check if still valid
            if is_valid_fn then
                if not is_valid_fn(timer.owner) then
                    to_destroy[#to_destroy + 1] = timer
                end
            else
                -- No validation function - destroy all with owners
                to_destroy[#to_destroy + 1] = timer
            end
        end
    end

    -- Destroy collected timers
    for _, timer in ipairs(to_destroy) do
        timers.destroy(timer)
        destroyed = destroyed + 1
    end

    return destroyed
end
-- }}}

-- {{{ timers.get_registry_count
-- B02 fix: Get the number of timers in the registry.
-- This includes both running and non-running timers that haven't been destroyed.
function timers.get_registry_count()
    local count = 0
    for _ in pairs(timer_registry) do
        count = count + 1
    end
    return count
end
-- }}}

-- {{{ timers.process_tick
-- Process timer expirations for this tick.
-- Called by gameloop each tick via tick callback.
-- Fires all timers whose expiration_time <= game_time.
function timers.process_tick(tick_count, game_time)
    while true do
        local timer = heap_peek()
        if not timer then
            break
        end

        if timer.expiration_time > game_time then
            break
        end

        -- Timer has expired - remove from queue first
        heap_pop()

        -- Execute callback with error protection
        if timer.callback then
            local ok, err = pcall(timer.callback)
            if not ok then
                -- Log error but continue processing other timers
                print("[TIMER ERROR] " .. tostring(err))
            end
        end

        -- Handle periodic timers
        if timer.periodic and timer.running then
            -- Reset for next period
            timer.elapsed = 0
            timer.expiration_time = game_time + timer.duration
            heap_insert(timer)
        else
            -- One-shot timer is done
            timer.running = false
        end
    end
end
-- }}}

-- {{{ timers.init
-- Initialize timer system.
-- Registers tick callback with gameloop.
function timers.init()
    timers.reset()

    -- Register with gameloop for per-tick processing
    tick_callback_id = gameloop.add_tick_callback(timers.process_tick)
end
-- }}}

-- {{{ timers.reset
-- Reset timer system to initial state.
-- Destroys all active timers.
-- B02 fix: Also clears timer registry.
function timers.reset()
    -- Clear queue
    for i = #timer_queue, 1, -1 do
        local timer = timer_queue[i]
        if timer then
            timer.queue_index = nil
            timer.running = false
        end
        timer_queue[i] = nil
    end

    -- B02 fix: Clear registry
    timer_registry = {}
end
-- }}}

-- {{{ timers.get_active_count
-- Return number of active timers in queue.
function timers.get_active_count()
    return #timer_queue
end
-- }}}

-- {{{ timers.register_runtime_api
-- Register WC3-style runtime API functions.
-- These match JASS native function signatures.
-- B02 fix: Added owner and cleanup functions.
function timers.register_runtime_api(runtime)
    -- CreateTimer() -> timer
    runtime.CreateTimer = timers.create

    -- DestroyTimer(timer)
    runtime.DestroyTimer = timers.destroy

    -- TimerStart(timer, timeout, periodic, callback)
    runtime.TimerStart = timers.start

    -- PauseTimer(timer)
    runtime.PauseTimer = timers.pause

    -- ResumeTimer(timer)
    runtime.ResumeTimer = timers.resume

    -- TimerGetElapsed(timer) -> real
    runtime.TimerGetElapsed = timers.get_elapsed

    -- TimerGetRemaining(timer) -> real
    runtime.TimerGetRemaining = timers.get_remaining

    -- TimerGetTimeout(timer) -> real
    runtime.TimerGetTimeout = timers.get_timeout

    -- B02 fix: Owner tracking for orphan cleanup
    -- TimerSetOwner(timer, owner)
    runtime.TimerSetOwner = timers.set_owner

    -- TimerGetOwner(timer) -> owner
    runtime.TimerGetOwner = timers.get_owner

    -- CleanupOrphanTimers(is_valid_fn) -> count
    runtime.CleanupOrphanTimers = timers.cleanup_orphans
end
-- }}}

return timers
