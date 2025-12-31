--[[
Movement Orders System (Issue 404c)

Provides high-level order interface for issuing movement commands to entities.
Integrates with pathfinding to automatically generate paths for move orders.
Supports order queuing for shift-click behavior.

Usage:
    local orders = require("runtime.orders")

    -- Issue a move order (with automatic pathfinding)
    orders.move(entity, { x = 1000, y = 2000 })

    -- Queue orders (shift-click behavior)
    orders.move(entity, { x = 1000, y = 2000 }, { queue = true })

    -- Stop current movement
    orders.stop(entity)

    -- Hold position (clears movement, stays put)
    orders.hold(entity)

    -- Query current order
    local order = orders.get_current(entity)

    -- Register completion callback
    orders.on_complete(entity, function(entity, order, success)
        print("Order completed:", success)
    end)
]]

local ecs = require("runtime.ecs")
local movement = require("runtime.systems.movement")

local orders = {}

-- {{{ Order type constants
-- Types of orders that can be issued to units.
-- MOVE: Move to a point
-- ATTACK_MOVE: Move but attack enemies encountered
-- PATROL: Cycle between waypoints
-- HOLD: Stay at current position
-- STOP: Cancel current action
orders.TYPE = {
    MOVE = "move",
    ATTACK_MOVE = "attack_move",
    PATROL = "patrol",
    HOLD = "hold",
    STOP = "stop",
}
-- }}}

-- {{{ Order status constants
-- Status of an order during its lifecycle.
-- PENDING: Order issued but not yet started
-- EXECUTING: Order is being carried out
-- COMPLETED: Order finished successfully
-- FAILED: Order could not be completed
-- CANCELLED: Order was interrupted
orders.STATUS = {
    PENDING = "pending",
    EXECUTING = "executing",
    COMPLETED = "completed",
    FAILED = "failed",
    CANCELLED = "cancelled",
}
-- }}}

-- {{{ Order component defaults
-- Default values for the orders component.
-- current: The order currently being executed (or nil)
-- Note: queue and callbacks are NOT in defaults because they're mutable tables.
-- Each entity needs its own tables, which are created in _ensure_tables().
local ORDER_DEFAULTS = {
    current = nil,
}
orders.DEFAULTS = ORDER_DEFAULTS

-- Register orders component if not already registered
local existing = ecs.get_component_defaults("orders")
if not existing then
    ecs.register_component("orders", ORDER_DEFAULTS)
end
-- }}}

-- {{{ _ensure_tables
-- Ensures an orders component has its own queue and callbacks tables.
-- Called before any operation that needs these tables.
-- This is necessary because metatable inheritance shares table references.
--
-- @param ord orders component
local function ensure_tables(ord)
    if not rawget(ord, "queue") then
        ord.queue = {}
    end
    if not rawget(ord, "callbacks") then
        ord.callbacks = {}
    end
end
-- }}}

-- {{{ orders.reset
-- Resets module state. Called when ECS is reset.
-- Currently a no-op since all state is in components,
-- but provided for future use and consistency.
function orders.reset()
    -- Module has no global state to reset
    -- All state is stored in entity components
end
-- }}}

-- {{{ orders._get_time
-- Returns current timestamp for order tracking.
-- Separated for testability.
local function get_time()
    return os.clock()
end
-- }}}

-- {{{ orders._fire_callbacks
-- Fires completion callbacks for an entity's order.
-- Uses pcall to prevent one broken callback from affecting others.
--
-- @param entity entity ID
-- @param order the completed order
-- @param success boolean indicating if order completed successfully
local function fire_callbacks(entity, order, success)
    local ord = ecs.get_component(entity, "orders")
    if not ord then
        return
    end

    ensure_tables(ord)

    for _, callback in ipairs(ord.callbacks) do
        local ok, err = pcall(callback, entity, order, success)
        if not ok then
            -- Log error but continue with other callbacks
            -- In production, this would use proper logging
        end
    end
end
-- }}}

-- {{{ orders._cancel_current
-- Cancels the current order and fires callbacks.
-- Does not advance the queue (caller is responsible).
--
-- @param entity entity ID
-- @param ord orders component
local function cancel_current(entity, ord)
    if ord.current and ord.current.status == orders.STATUS.EXECUTING then
        ord.current.status = orders.STATUS.CANCELLED
        fire_callbacks(entity, ord.current, false)
    end
    ord.current = nil
end
-- }}}

-- {{{ orders._execute_move
-- Internal: Starts executing a move order.
-- Sets up the path on the movement component.
--
-- @param entity entity ID
-- @param order the move order to execute
-- @return boolean success
local function execute_move(entity, order)
    local pos = ecs.get_component(entity, "position")
    local mov = ecs.get_component(entity, "movement")

    if not pos or not mov then
        order.status = orders.STATUS.FAILED
        order.error = "Missing position or movement component"
        fire_callbacks(entity, order, false)
        return false
    end

    -- For simple movement, we create a direct path to target
    -- In a full implementation, this would use pathfinding:
    -- local path = pathfinding.find_path({x=pos.x, y=pos.y}, order.target, mov.pathing_type)
    --
    -- For now, create a simple direct path (single waypoint)
    -- Pathfinding integration can be added in a sub-issue if needed
    local path = {
        {x = order.target.x, y = order.target.y}
    }

    -- Set path on movement component
    local success = movement.set_path(entity, path)
    if not success then
        order.status = orders.STATUS.FAILED
        order.error = "Failed to set movement path"
        fire_callbacks(entity, order, false)
        return false
    end

    order.status = orders.STATUS.EXECUTING
    return true
end
-- }}}

-- {{{ orders.move
-- Issues a move order to an entity.
-- The entity will pathfind and move to the target position.
--
-- @param entity entity ID
-- @param target table with x, y coordinates
-- @param options optional table with:
--   queue: boolean - if true, add to queue instead of replacing current
-- @return boolean success, string error message
function orders.move(entity, target, options)
    options = options or {}

    local ord = ecs.get_component(entity, "orders")
    if not ord then
        return false, "Entity has no orders component"
    end

    local pos = ecs.get_component(entity, "position")
    if not pos then
        return false, "Entity has no position component"
    end

    local mov = ecs.get_component(entity, "movement")
    if not mov then
        return false, "Entity has no movement component"
    end

    -- Ensure entity has its own queue table
    ensure_tables(ord)

    -- Create the order
    local order = {
        type = orders.TYPE.MOVE,
        target = {x = target.x, y = target.y},
        status = orders.STATUS.PENDING,
        issued_at = get_time(),
    }

    if options.queue and ord.current then
        -- Add to queue instead of replacing
        ord.queue[#ord.queue + 1] = order
    else
        -- Replace current order
        if ord.current then
            cancel_current(entity, ord)
        end
        ord.current = order
        execute_move(entity, order)
    end

    return true
end
-- }}}

-- {{{ orders.stop
-- Stops current movement and clears order queue.
--
-- @param entity entity ID
-- @return boolean success, string error message
function orders.stop(entity)
    local ord = ecs.get_component(entity, "orders")
    if not ord then
        return false, "Entity has no orders component"
    end

    -- Ensure entity has its own tables
    ensure_tables(ord)

    -- Cancel current order
    if ord.current then
        cancel_current(entity, ord)
    end

    -- Clear queue
    ord.queue = {}

    -- Stop movement
    movement.clear_path(entity)

    return true
end
-- }}}

-- {{{ orders.hold
-- Issues a hold position order.
-- The entity stops moving and stays at current position.
--
-- @param entity entity ID
-- @return boolean success, string error message
function orders.hold(entity)
    local ord = ecs.get_component(entity, "orders")
    if not ord then
        return false, "Entity has no orders component"
    end

    -- Ensure entity has its own tables
    ensure_tables(ord)

    -- Cancel current order
    if ord.current then
        cancel_current(entity, ord)
    end

    -- Clear queue
    ord.queue = {}

    -- Stop movement
    movement.clear_path(entity)

    -- Set hold order as current
    ord.current = {
        type = orders.TYPE.HOLD,
        status = orders.STATUS.EXECUTING,
        issued_at = get_time(),
    }

    return true
end
-- }}}

-- {{{ orders.clear_queue
-- Clears the order queue but keeps current order.
--
-- @param entity entity ID
-- @return boolean success
function orders.clear_queue(entity)
    local ord = ecs.get_component(entity, "orders")
    if not ord then
        return false
    end

    ensure_tables(ord)
    ord.queue = {}
    return true
end
-- }}}

-- {{{ orders.get_current
-- Returns the current order being executed.
--
-- @param entity entity ID
-- @return table order or nil
function orders.get_current(entity)
    local ord = ecs.get_component(entity, "orders")
    if not ord then
        return nil
    end
    return ord.current
end
-- }}}

-- {{{ orders.get_queue
-- Returns the order queue (array of pending orders).
--
-- @param entity entity ID
-- @return table array of orders (empty if no queue)
function orders.get_queue(entity)
    local ord = ecs.get_component(entity, "orders")
    if not ord then
        return {}
    end
    ensure_tables(ord)
    return ord.queue
end
-- }}}

-- {{{ orders.has_orders
-- Returns true if entity has any orders (current or queued).
--
-- @param entity entity ID
-- @return boolean
function orders.has_orders(entity)
    local ord = ecs.get_component(entity, "orders")
    if not ord then
        return false
    end
    ensure_tables(ord)
    return ord.current ~= nil or #ord.queue > 0
end
-- }}}

-- {{{ orders.on_complete
-- Registers a callback for when orders complete.
-- Callback signature: function(entity, order, success)
--
-- @param entity entity ID
-- @param callback function to call
-- @return boolean success
function orders.on_complete(entity, callback)
    local ord = ecs.get_component(entity, "orders")
    if not ord then
        return false
    end

    ensure_tables(ord)
    ord.callbacks[#ord.callbacks + 1] = callback
    return true
end
-- }}}

-- {{{ Order system update
-- Monitors movement completion and advances order queue.
-- Runs after the movement system to detect when movement stops.
local function order_system_update(iter, dt)
    for entity, pos, mov, ord in iter do
        -- Ensure entity has its own tables before processing
        ensure_tables(ord)

        if ord.current then
            -- Check if current move order completed
            if ord.current.type == orders.TYPE.MOVE then
                if not movement.is_moving(entity) then
                    -- Movement stopped - check if we reached target
                    local target = ord.current.target
                    local dx = target.x - pos.x
                    local dy = target.y - pos.y
                    local dist = math.sqrt(dx * dx + dy * dy)

                    if dist <= movement.ARRIVAL_THRESHOLD then
                        ord.current.status = orders.STATUS.COMPLETED
                        fire_callbacks(entity, ord.current, true)
                    else
                        -- Didn't reach target - path was blocked or interrupted
                        ord.current.status = orders.STATUS.FAILED
                        ord.current.error = "Path blocked or incomplete"
                        fire_callbacks(entity, ord.current, false)
                    end

                    -- Clear current and advance queue
                    ord.current = nil
                    if #ord.queue > 0 then
                        ord.current = table.remove(ord.queue, 1)
                        execute_move(entity, ord.current)
                    end
                end
            end
            -- HOLD orders don't complete on their own
            -- They must be cancelled by another order
        end
    end
end
-- }}}

-- {{{ Register order system
-- Priority 15 runs after movement system (priority 10) so we can
-- detect when movement completes.
ecs.register_system(
    "orders",
    {"position", "movement", "orders"},
    order_system_update,
    {priority = 15}
)
-- }}}

-- {{{ Frame-based movement orders
-- Movement stored as choreography - the shape of the path, not just destinations.

local frames_module = nil
local function get_frames()
    if not frames_module then
        frames_module = require("runtime.pathfinding.frames")
    end
    return frames_module
end

-- Forward declaration for execute_move_frames
local execute_move_frames

-- {{{ orders.move_frames
-- Issue a move order using a frame path (choreography).
-- The entity follows the shape of movement, not just the destination.
--
-- @param entity entity ID
-- @param frame_path { start = {x,y}, frames = {...}, goal = {x,y} }
-- @param options optional table with:
--   queue: boolean - if true, add to queue instead of replacing current
-- @return boolean success, string error message
function orders.move_frames(entity, frame_path, options)
    options = options or {}

    local ord = ecs.get_component(entity, "orders")
    if not ord then
        return false, "Entity has no orders component"
    end

    local pos = ecs.get_component(entity, "position")
    if not pos then
        return false, "Entity has no position component"
    end

    local mov = ecs.get_component(entity, "movement")
    if not mov then
        return false, "Entity has no movement component"
    end

    ensure_tables(ord)

    -- Create frame-based order
    local order = {
        type = orders.TYPE.MOVE,
        frame_path = frame_path,  -- The choreography
        target = frame_path.goal or { x = 0, y = 0 },
        status = orders.STATUS.PENDING,
        issued_at = get_time(),
        frame_index = 1,  -- Current step in choreography
    }

    if options.queue and ord.current then
        ord.queue[#ord.queue + 1] = order
    else
        if ord.current then
            cancel_current(entity, ord)
        end
        ord.current = order
        execute_move_frames(entity, order)
    end

    return true
end
-- }}}

-- {{{ execute_move_frames
-- Internal: Starts executing a frame-based move order.
-- Converts frame path to coordinate path for movement system.
--
-- @param entity entity ID
-- @param order the move order with frame_path
-- @return boolean success
local function execute_move_frames(entity, order)
    local pos = ecs.get_component(entity, "position")
    local mov = ecs.get_component(entity, "movement")

    if not pos or not mov then
        order.status = orders.STATUS.FAILED
        order.error = "Missing position or movement component"
        fire_callbacks(entity, order, false)
        return false
    end

    local frames = get_frames()

    -- Adjust frame_path start to current position (apply choreography from here)
    local adjusted_path = {
        start = { x = pos.x, y = pos.y },
        frames = order.frame_path.frames,
    }

    -- Convert frames to coordinate path
    local path = frames.frames_to_path(adjusted_path)

    -- Set path on movement component
    local success = movement.set_path(entity, path)
    if not success then
        order.status = orders.STATUS.FAILED
        order.error = "Failed to set movement path"
        fire_callbacks(entity, order, false)
        return false
    end

    order.status = orders.STATUS.EXECUTING
    return true
end
-- }}}

-- {{{ orders.get_path_shape
-- Get the current movement path as a frame sequence (ASCII art).
--
-- @param entity entity ID
-- @return string ASCII representation of path shape (e.g., "→→↗↗↑↑")
function orders.get_path_shape(entity)
    local mov = ecs.get_component(entity, "movement")
    if not mov or not mov.path or #mov.path < 2 then
        return "○"  -- Stationary
    end

    local frames = get_frames()
    local frame_path = frames.path_to_frames(mov.path)
    return frames.path_to_ascii(frame_path)
end
-- }}}

-- {{{ orders.get_momentum
-- Get entity's current movement as momentum (direction + magnitude).
--
-- @param entity entity ID
-- @return Momentum object or nil
function orders.get_momentum(entity)
    local pos = ecs.get_component(entity, "position")
    local mov = ecs.get_component(entity, "movement")

    if not pos or not mov then
        return nil
    end

    local frames = get_frames()

    if not movement.is_moving(entity) then
        return frames.Momentum.new(frames.ORIGIN, 0)
    end

    -- Get direction from current movement
    local target = movement.get_target(entity)
    if not target then
        return frames.Momentum.new(frames.ORIGIN, 0)
    end

    local direction = frames.points_to_frame(pos.x, pos.y, target.x, target.y)
    local speed = movement.get_effective_speed(entity) or 0

    -- Magnitude is based on speed (normalized to reasonable range)
    local magnitude = math.floor(speed / 50)  -- ~1 per 50 speed

    return frames.Momentum.new(direction, magnitude)
end
-- }}}

-- {{{ orders.apply_force
-- Apply a directional force to entity's momentum.
-- Combines with current movement direction and adds to magnitude.
--
-- @param entity entity ID
-- @param force_frame Direction frame of applied force
-- @param strength Magnitude of force (default 1)
-- @return boolean success
function orders.apply_force(entity, force_frame, strength)
    strength = strength or 1

    local momentum = orders.get_momentum(entity)
    if not momentum then
        return false
    end

    local frames = get_frames()

    -- Apply force to momentum
    for i = 1, strength do
        momentum:apply_force(force_frame)
    end

    -- Convert momentum to movement order
    if not momentum:is_stationary() then
        local pos = ecs.get_component(entity, "position")
        if pos then
            local dx, dy = momentum:get_vector()
            local target = {
                x = pos.x + dx * 32,  -- Scale to world units
                y = pos.y + dy * 32,
            }
            orders.move(entity, target)
        end
    end

    return true
end
-- }}}

-- {{{ orders.shapes
-- Predefined movement shapes (choreography templates)
orders.shapes = {
    -- Straight lines
    EAST_LINE = function(steps)
        local f = get_frames()
        local frames_list = {}
        for i = 1, steps do frames_list[i] = f.EAST end
        return { start = {x=0, y=0}, frames = frames_list }
    end,

    -- Circle (approximation)
    CIRCLE = function(radius)
        local f = get_frames()
        -- 8-step circle: E, NE, N, NW, W, SW, S, SE
        local pattern = {f.EAST, f.NORTHEAST, f.NORTH, f.NORTHWEST,
                        f.WEST, f.SOUTHWEST, f.SOUTH, f.SOUTHEAST}
        local frames_list = {}
        for r = 1, radius do
            for _, dir in ipairs(pattern) do
                frames_list[#frames_list + 1] = dir
            end
        end
        return { start = {x=0, y=0}, frames = frames_list }
    end,

    -- Zigzag patrol
    ZIGZAG = function(width, count)
        local f = get_frames()
        local frames_list = {}
        for i = 1, count do
            -- Right
            for j = 1, width do frames_list[#frames_list + 1] = f.EAST end
            -- Up-right
            frames_list[#frames_list + 1] = f.NORTHEAST
            -- Left
            for j = 1, width do frames_list[#frames_list + 1] = f.WEST end
            -- Up-left
            frames_list[#frames_list + 1] = f.NORTHWEST
        end
        return { start = {x=0, y=0}, frames = frames_list }
    end,

    -- Retreat (away from point)
    RETREAT = function(from_x, from_y, to_x, to_y, steps)
        local f = get_frames()
        -- Direction away from threat
        local dir = f.vector_to_frame(to_x - from_x, to_y - from_y)
        -- Invert (combine with itself until it wraps)
        local retreat_dir = f.combine_frames(f.ORIGIN, dir)
        -- Actually, just use opposite
        retreat_dir = f.vector_to_frame(from_x - to_x, from_y - to_y)

        local frames_list = {}
        for i = 1, steps do frames_list[i] = retreat_dir end
        return { start = {x=from_x, y=from_y}, frames = frames_list }
    end,
}
-- }}}
-- }}}

return orders
