--[[
Game Loop - Core Fixed Timestep Implementation

Provides the foundational game loop with fixed timestep accumulator pattern.
Runs at 62.5 Hz to match WC3's tick rate for deterministic replay compatibility.

The accumulator pattern separates simulation rate from render rate:
- Simulation advances in fixed 16ms ticks regardless of frame rate
- Interpolation alpha provided for smooth rendering between ticks
- Deterministic for replay and multiplayer synchronization
]]

local gameloop = {}

-- {{{ Constants
-- WC3 runs at approximately 62.5 ticks per second.
-- This rate is critical for:
--   - Deterministic replay playback
--   - Multiplayer synchronization
--   - Consistent trigger timing
local TICK_RATE = 62.5
local TICK_DURATION = 1.0 / TICK_RATE  -- ~0.016 seconds (16ms)

-- Speed bounds (WC3 supports Slow/Normal/Fast)
local MIN_SPEED = 0.5
local MAX_SPEED = 2.0

-- Maximum delta time to prevent spiral of death after lag spikes
local MAX_DELTA_TIME = 0.25
-- }}}

-- {{{ State variables
local game_time = 0.0      -- Total elapsed game time in seconds
local tick_count = 0       -- Total ticks processed
local game_speed = 1.0     -- Speed multiplier (1.0 = normal)
local paused = false       -- Pause state
local accumulator = 0.0    -- Time accumulator for fixed timestep

-- Tick callbacks (filled by other systems like timers, triggers)
-- Each entry is a function(tick_count, game_time) or nil
local tick_callbacks = {}
-- }}}

-- {{{ gameloop.reset
-- Reset all state to initial values.
-- Called when loading a new map or restarting the game.
function gameloop.reset()
    game_time = 0.0
    tick_count = 0
    game_speed = 1.0
    paused = false
    accumulator = 0.0
    tick_callbacks = {}
end
-- }}}

-- {{{ gameloop.tick
-- Advance game state by one tick.
-- This is the core simulation step, called at fixed intervals.
--
-- Processing order (deterministic):
--   1. Increment tick count and game time
--   2. Execute registered tick callbacks (timers, periodic triggers)
--   3. (Future: entity updates, combat, death/cleanup, events)
function gameloop.tick()
    tick_count = tick_count + 1
    game_time = tick_count * TICK_DURATION

    -- Execute registered tick callbacks
    -- Each callback receives current tick and game time
    for i = 1, #tick_callbacks do
        local cb = tick_callbacks[i]
        if cb then
            cb(tick_count, game_time)
        end
    end
end
-- }}}

-- {{{ gameloop.update
-- Main update function, called each frame with delta time.
-- Uses accumulator pattern for fixed timestep simulation.
--
-- @param dt Real elapsed time in seconds since last frame
-- @return Number of ticks processed this frame
function gameloop.update(dt)
    if paused then
        return 0  -- No ticks processed when paused
    end

    -- Validate delta time to prevent spiral of death
    -- Cap at MAX_DELTA_TIME to prevent huge catch-up after lag
    if dt > MAX_DELTA_TIME then
        dt = MAX_DELTA_TIME
    end

    -- Negative delta time is invalid
    if dt < 0 then
        dt = 0
    end

    -- Accumulate time, scaled by game speed
    accumulator = accumulator + (dt * game_speed)

    local ticks_processed = 0

    -- Process as many fixed timesteps as accumulated
    while accumulator >= TICK_DURATION do
        gameloop.tick()
        accumulator = accumulator - TICK_DURATION
        ticks_processed = ticks_processed + 1
    end

    return ticks_processed
end
-- }}}

-- {{{ Pause/Resume Controls

-- {{{ gameloop.pause
-- Pause game simulation.
-- Ticks stop advancing, but time can still be queried.
function gameloop.pause()
    paused = true
end
-- }}}

-- {{{ gameloop.resume
-- Resume game simulation from paused state.
function gameloop.resume()
    paused = false
end
-- }}}

-- {{{ gameloop.is_paused
-- Check if game is currently paused.
-- @return true if paused, false otherwise
function gameloop.is_paused()
    return paused
end
-- }}}

-- {{{ gameloop.toggle_pause
-- Toggle pause state.
-- @return New pause state (true if now paused)
function gameloop.toggle_pause()
    paused = not paused
    return paused
end
-- }}}

-- }}}

-- {{{ Speed Control

-- {{{ gameloop.set_speed
-- Set game speed multiplier.
-- WC3 speeds: Slow=0.5, Normal=1.0, Fast=1.5-2.0
--
-- Speed affects accumulator rate, not tick duration.
-- This means ticks are still 16ms of game time each,
-- but real time passes faster or slower.
--
-- @param multiplier Speed multiplier (clamped to 0.5-2.0)
function gameloop.set_speed(multiplier)
    if type(multiplier) ~= "number" then
        error("set_speed: multiplier must be a number")
    end

    -- Clamp to valid range
    if multiplier < MIN_SPEED then
        multiplier = MIN_SPEED
    elseif multiplier > MAX_SPEED then
        multiplier = MAX_SPEED
    end

    game_speed = multiplier
end
-- }}}

-- {{{ gameloop.get_speed
-- Get current game speed multiplier.
-- @return Current speed (1.0 = normal)
function gameloop.get_speed()
    return game_speed
end
-- }}}

-- }}}

-- {{{ Time/Tick Accessors

-- {{{ gameloop.get_time
-- Get elapsed game time in seconds.
-- This is the canonical game time for all systems.
-- @return Game time in seconds
function gameloop.get_time()
    return game_time
end
-- }}}

-- {{{ gameloop.get_tick
-- Get total tick count since game start.
-- @return Number of ticks processed
function gameloop.get_tick()
    return tick_count
end
-- }}}

-- {{{ gameloop.get_tick_duration
-- Get duration of one tick in seconds.
-- Useful for systems that need to know tick rate.
-- @return Tick duration (~0.016 seconds)
function gameloop.get_tick_duration()
    return TICK_DURATION
end
-- }}}

-- {{{ gameloop.get_tick_rate
-- Get ticks per second.
-- @return Tick rate (62.5)
function gameloop.get_tick_rate()
    return TICK_RATE
end
-- }}}

-- {{{ gameloop.get_accumulator
-- Get current accumulator value.
-- Useful for interpolation in rendering.
-- @return Value between 0 and TICK_DURATION
function gameloop.get_accumulator()
    return accumulator
end
-- }}}

-- {{{ gameloop.get_interpolation_alpha
-- Get interpolation factor for rendering.
-- Use this to interpolate entity positions between ticks.
-- @return 0.0 = at previous tick state, 1.0 = at current tick state
function gameloop.get_interpolation_alpha()
    return accumulator / TICK_DURATION
end
-- }}}

-- }}}

-- {{{ Tick Callback Registration

-- {{{ gameloop.add_tick_callback
-- Register a function to be called each tick.
-- Callbacks receive (tick_count, game_time) parameters.
--
-- Used by timer system, periodic triggers, entity updates, etc.
--
-- @param callback Function to call each tick
-- @return Callback ID for later removal
function gameloop.add_tick_callback(callback)
    if type(callback) ~= "function" then
        error("add_tick_callback: callback must be a function")
    end

    tick_callbacks[#tick_callbacks + 1] = callback
    return #tick_callbacks
end
-- }}}

-- {{{ gameloop.remove_tick_callback
-- Remove a tick callback by ID.
-- Sets to nil to preserve indices (avoids shifting and ID invalidation).
--
-- @param id Callback ID returned by add_tick_callback
function gameloop.remove_tick_callback(id)
    if id >= 1 and id <= #tick_callbacks then
        tick_callbacks[id] = nil
    end
end
-- }}}

-- {{{ gameloop.get_callback_count
-- Get count of registered callbacks (including nil slots).
-- Useful for debugging and testing.
-- @return Number of callback slots
function gameloop.get_callback_count()
    return #tick_callbacks
end
-- }}}

-- }}}

-- {{{ Module Constants Export
gameloop.TICK_RATE = TICK_RATE
gameloop.TICK_DURATION = TICK_DURATION
gameloop.MIN_SPEED = MIN_SPEED
gameloop.MAX_SPEED = MAX_SPEED
-- }}}

return gameloop
