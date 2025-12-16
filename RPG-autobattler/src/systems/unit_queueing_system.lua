-- {{{ UnitQueueingSystem
local UnitQueueingSystem = {}

local Vector2 = require("src.utils.vector2")
local MathUtils = require("src.utils.math_utils")
local debug = require("src.utils.debug")

-- {{{ UnitQueueingSystem:new
function UnitQueueingSystem:new(entity_manager, unit_movement_system, lane_system)
    local system = {
        entity_manager = entity_manager,
        unit_movement_system = unit_movement_system,
        lane_system = lane_system,
        name = "unit_queueing",
        
        -- Queue management
        lane_queues = {},             -- Queues for each lane/sub-path combination
        queue_assignments = {},       -- Maps unit ID to queue position
        next_queue_id = 1,
        
        -- Queueing parameters
        queue_spacing = 18,           -- Distance between units in queue
        max_queue_length = 20,        -- Maximum units in a single queue
        detection_radius = 25,        -- Distance to detect blocking units
        merge_threshold = 40,         -- Distance to consider merging queues
        
        -- Congestion detection parameters
        congestion_check_distance = 40,  -- Distance ahead to check for congestion
        congestion_threshold = 0.7,      -- 70% capacity before forming queues
        space_limit_threshold = 0.8,     -- 80% capacity considered space-limited
        
        -- Behavior settings
        dynamic_queue_spacing = true, -- Adjust spacing based on unit types
        queue_compression = true,     -- Compress queue when units are closer
        queue_branching = true,       -- Allow queues to branch to other sub-paths
        patience_system = true,       -- Units get impatient in long queues
        
        -- Movement control
        queue_movement_speed = 0.7,   -- Speed multiplier for queued units
        leader_follow_distance = 20,  -- Distance to maintain from queue leader
        catch_up_speed_bonus = 1.3,   -- Speed bonus when catching up to queue
        
        -- Update frequency
        update_frequency = 1/10,      -- Update queues 10 times per second
        last_update = 0
    }
    setmetatable(system, {__index = UnitQueueingSystem})
    
    debug.log("UnitQueueingSystem created", "QUEUEING")
    return system
end
-- }}}

-- {{{ UnitQueueingSystem:update
function UnitQueueingSystem:update(dt)
    self.last_update = self.last_update + dt
    
    if self.last_update < self.update_frequency then
        return
    end
    
    -- Detect and form new queues
    self:detect_queue_situations()
    
    -- Update existing queues
    for queue_id, queue in pairs(self.lane_queues) do
        self:update_queue(queue, self.last_update)
    end
    
    -- Clean up empty queues
    self:cleanup_empty_queues()
    
    -- Handle queue merging and branching
    self:handle_queue_optimization()
    
    self.last_update = 0
end
-- }}}

-- {{{ UnitQueueingSystem:detect_queue_situations
function UnitQueueingSystem:detect_queue_situations()
    local units = self.entity_manager:get_entities_with_components({
        "position", "moveable", "unit_data", "team"
    })
    
    for _, unit in ipairs(units) do
        -- Skip units already in queues
        if self.queue_assignments[unit.id] then
            goto continue
        end
        
        local moveable = self.entity_manager:get_component(unit, "moveable")
        local assignment = self.unit_movement_system:get_unit_assignment(unit)
        
        -- Only check moving units with lane assignments
        if moveable and moveable.moving and assignment and assignment.sub_path then
            if self:should_form_queue(unit, assignment) then
                self:create_or_join_queue(unit, assignment)
            end
        end
        
        ::continue::
    end
end
-- }}}

-- {{{ UnitQueueingSystem:should_form_queue
function UnitQueueingSystem:should_form_queue(unit, assignment)
    local position = self.entity_manager:get_component(unit, "position")
    local team = self.entity_manager:get_component(unit, "team")
    
    if not position or not team then
        return false
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    
    -- Check for congestion ahead
    local congestion_level = self:calculate_congestion_ahead(unit, assignment, unit_pos)
    if congestion_level > self.congestion_threshold then
        return true
    end
    
    -- Check for space limitations in sub-path
    if self:is_space_limited(unit, assignment) then
        return true
    end
    
    -- Find blocking units ahead in the same sub-path
    local blocking_units = self:find_blocking_units(unit, assignment, unit_pos)
    
    -- Form queue if there are blocking allies
    return #blocking_units > 0
end
-- }}}

-- {{{ UnitQueueingSystem:find_blocking_units
function UnitQueueingSystem:find_blocking_units(unit, assignment, unit_pos)
    local blocking_units = {}
    local team = self.entity_manager:get_component(unit, "team")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    
    if not team or not moveable then
        return blocking_units
    end
    
    local movement_direction = Vector2:new(moveable.velocity_x, moveable.velocity_y):normalize()
    
    -- Get units in the same sub-path
    local same_subpath_units = self.unit_movement_system:get_units_on_sub_path(
        assignment.lane, assignment.sub_path_id
    )
    
    for _, other_unit in ipairs(same_subpath_units) do
        if other_unit.id ~= unit.id then
            local other_position = self.entity_manager:get_component(other_unit, "position")
            local other_team = self.entity_manager:get_component(other_unit, "team")
            local other_assignment = self.unit_movement_system:get_unit_assignment(other_unit)
            
            if other_position and other_team and other_assignment and
               team.player_id == other_team.player_id then  -- Same team
                
                local other_pos = Vector2:new(other_position.x, other_position.y)
                local to_other = other_pos:subtract(unit_pos)
                local distance = to_other:length()
                
                -- Check if other unit is ahead and close enough to block
                if distance <= self.detection_radius then
                    local dot_product = to_other:normalize():dot(movement_direction)
                    
                    -- Other unit is ahead (dot product > 0.5 means roughly in front)
                    if dot_product > 0.5 then
                        -- Check if other unit is moving slower or stopped
                        local other_moveable = self.entity_manager:get_component(other_unit, "moveable")
                        if other_moveable then
                            local other_speed = Vector2:new(other_moveable.velocity_x, other_moveable.velocity_y):length()
                            local my_speed = Vector2:new(moveable.velocity_x, moveable.velocity_y):length()
                            
                            if other_speed < my_speed * 0.8 then  -- Significantly slower
                                table.insert(blocking_units, {
                                    unit = other_unit,
                                    distance = distance,
                                    progress = other_assignment.progress or 0
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(blocking_units, function(a, b) return a.distance < b.distance end)
    
    return blocking_units
end
-- }}}

-- {{{ UnitQueueingSystem:create_or_join_queue
function UnitQueueingSystem:create_or_join_queue(unit, assignment)
    -- Check if there's an existing queue we can join
    local existing_queue = self:find_nearby_queue(unit, assignment)
    
    if existing_queue then
        self:add_unit_to_queue(existing_queue, unit)
    else
        self:create_new_queue(unit, assignment)
    end
end
-- }}}

-- {{{ UnitQueueingSystem:find_nearby_queue
function UnitQueueingSystem:find_nearby_queue(unit, assignment)
    local position = self.entity_manager:get_component(unit, "position")
    if not position then
        return nil
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    
    for _, queue in pairs(self.lane_queues) do
        if queue.lane == assignment.lane and queue.sub_path_id == assignment.sub_path_id then
            -- Check if unit is close enough to the queue
            local queue_tail_pos = self:get_queue_tail_position(queue)
            if queue_tail_pos and unit_pos:distance_to(queue_tail_pos) <= self.merge_threshold then
                return queue
            end
        end
    end
    
    return nil
end
-- }}}

-- {{{ UnitQueueingSystem:create_new_queue
function UnitQueueingSystem:create_new_queue(unit, assignment)
    local queue_id = self.next_queue_id
    self.next_queue_id = self.next_queue_id + 1
    
    local queue = {
        id = queue_id,
        lane = assignment.lane,
        sub_path_id = assignment.sub_path_id,
        units = {},
        created_time = love.timer.getTime(),
        
        -- Queue state
        queue_leader = unit,
        movement_speed = self.queue_movement_speed,
        queue_direction = Vector2:new(1, 0),
        
        -- Queue parameters
        spacing = self.queue_spacing,
        compression_factor = 1.0,
        patience_level = 1.0
    }
    
    self:add_unit_to_queue(queue, unit)
    self.lane_queues[queue_id] = queue
    
    debug.log("Created new queue " .. queue_id .. " on sub-path " .. assignment.sub_path_id, "QUEUEING")
    return queue
end
-- }}}

-- {{{ UnitQueueingSystem:add_unit_to_queue
function UnitQueueingSystem:add_unit_to_queue(queue, unit)
    if #queue.units >= self.max_queue_length then
        debug.warn("Queue " .. queue.id .. " is full, cannot add unit", "QUEUEING")
        return false
    end
    
    -- Remove from existing queue if any
    local old_queue_id = self.queue_assignments[unit.id]
    if old_queue_id then
        self:remove_unit_from_queue(self.lane_queues[old_queue_id], unit)
    end
    
    -- Add to new queue
    table.insert(queue.units, unit)
    self.queue_assignments[unit.id] = queue.id
    
    -- Update unit data
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    if unit_data then
        unit_data.in_queue = true
        unit_data.queue_id = queue.id
        unit_data.queue_position = #queue.units
        unit_data.patience = 1.0
    end
    
    debug.log("Added unit " .. unit.name .. " to queue " .. queue.id .. " at position " .. #queue.units, "QUEUEING")
    return true
end
-- }}}

-- {{{ UnitQueueingSystem:remove_unit_from_queue
function UnitQueueingSystem:remove_unit_from_queue(queue, unit)
    if not queue then
        return
    end
    
    -- Remove from units list
    for i, queue_unit in ipairs(queue.units) do
        if queue_unit.id == unit.id then
            table.remove(queue.units, i)
            break
        end
    end
    
    -- Remove assignment
    self.queue_assignments[unit.id] = nil
    
    -- Update remaining units' positions
    for i, remaining_unit in ipairs(queue.units) do
        local unit_data = self.entity_manager:get_component(remaining_unit, "unit_data")
        if unit_data then
            unit_data.queue_position = i
        end
    end
    
    -- Clear unit's queue data
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    if unit_data then
        unit_data.in_queue = false
        unit_data.queue_id = nil
        unit_data.queue_position = nil
    end
    
    -- Update queue leader if necessary
    if queue.queue_leader and queue.queue_leader.id == unit.id and #queue.units > 0 then
        queue.queue_leader = queue.units[1]
    end
    
    debug.log("Removed unit " .. unit.name .. " from queue " .. queue.id, "QUEUEING")
end
-- }}}

-- {{{ UnitQueueingSystem:update_queue
function UnitQueueingSystem:update_queue(queue, dt)
    if #queue.units == 0 then
        return
    end
    
    -- Update queue state
    self:update_queue_state(queue)
    
    -- Calculate ideal positions for all units in queue
    local queue_positions = self:calculate_queue_positions(queue)
    
    -- Apply queue movement to units
    for i, unit in ipairs(queue.units) do
        local target_position = queue_positions[i]
        if target_position then
            self:apply_queue_movement(unit, target_position, queue, i, dt)
        end
    end
    
    -- Handle queue overflow
    if #queue.units > self.max_queue_length then
        self:handle_queue_overflow(queue)
    end
    
    -- Check if queue should be dissolved
    if self:should_dissolve_queue(queue) then
        self:dissolve_queue(queue)
    end
end
-- }}}

-- {{{ UnitQueueingSystem:update_queue_state
function UnitQueueingSystem:update_queue_state(queue)
    if not queue.queue_leader then
        return
    end
    
    -- Get leader's movement information
    local leader_position = self.entity_manager:get_component(queue.queue_leader, "position")
    local leader_moveable = self.entity_manager:get_component(queue.queue_leader, "moveable")
    
    if leader_position and leader_moveable then
        -- Update queue direction based on leader's movement
        local velocity = Vector2:new(leader_moveable.velocity_x, leader_moveable.velocity_y)
        if velocity:length() > 0.1 then
            queue.queue_direction = velocity:normalize()
        end
        
        -- Adjust queue spacing based on conditions
        if self.dynamic_queue_spacing then
            self:adjust_queue_spacing(queue)
        end
        
        -- Update patience levels
        if self.patience_system then
            self:update_queue_patience(queue)
        end
    end
end
-- }}}

-- {{{ UnitQueueingSystem:calculate_queue_positions
function UnitQueueingSystem:calculate_queue_positions(queue)
    local positions = {}
    
    if not queue.queue_leader then
        return positions
    end
    
    local leader_position = self.entity_manager:get_component(queue.queue_leader, "position")
    if not leader_position then
        return positions
    end
    
    local leader_pos = Vector2:new(leader_position.x, leader_position.y)
    
    -- Calculate positions behind the leader
    for i, unit in ipairs(queue.units) do
        if i == 1 then
            -- Leader stays at current position
            positions[i] = leader_pos
        else
            -- Calculate position behind previous unit
            local distance_back = (i - 1) * queue.spacing * queue.compression_factor
            local position_offset = queue.queue_direction:multiply(-distance_back)
            local target_position = leader_pos:add(position_offset)
            
            positions[i] = target_position
        end
    end
    
    return positions
end
-- }}}

-- {{{ UnitQueueingSystem:apply_queue_movement
function UnitQueueingSystem:apply_queue_movement(unit, target_position, queue, queue_position, dt)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    
    if not position or not moveable then
        return
    end
    
    local current_pos = Vector2:new(position.x, position.y)
    local to_target = target_position:subtract(current_pos)
    local distance_to_target = to_target:length()
    
    -- Don't move if very close to target
    if distance_to_target < 2.0 then
        moveable.velocity_x = 0
        moveable.velocity_y = 0
        moveable.moving = false
        return
    end
    
    -- Calculate movement speed
    local base_speed = moveable.speed * queue.movement_speed
    local movement_speed = base_speed
    
    -- Speed up if falling behind
    if distance_to_target > queue.spacing * 1.5 then
        movement_speed = base_speed * self.catch_up_speed_bonus
    end
    
    -- Reduce speed if too close to target
    if distance_to_target < queue.spacing * 0.5 then
        movement_speed = base_speed * 0.5
    end
    
    -- Apply movement
    local movement_direction = to_target:normalize()
    moveable.velocity_x = movement_direction.x * movement_speed
    moveable.velocity_y = movement_direction.y * movement_speed
    moveable.moving = true
    
    -- Update unit state
    if unit_data then
        unit_data.queue_following = true
        unit_data.distance_to_queue_position = distance_to_target
    end
end
-- }}}

-- {{{ UnitQueueingSystem:adjust_queue_spacing
function UnitQueueingSystem:adjust_queue_spacing(queue)
    -- Compress queue if units are moving slowly
    local leader_moveable = self.entity_manager:get_component(queue.queue_leader, "moveable")
    if leader_moveable then
        local leader_speed = Vector2:new(leader_moveable.velocity_x, leader_moveable.velocity_y):length()
        local speed_ratio = leader_speed / leader_moveable.speed
        
        -- Compress more when moving slower
        queue.compression_factor = 0.7 + speed_ratio * 0.3
    end
end
-- }}}

-- {{{ UnitQueueingSystem:update_queue_patience
function UnitQueueingSystem:update_queue_patience(queue)
    for i, unit in ipairs(queue.units) do
        local unit_data = self.entity_manager:get_component(unit, "unit_data")
        if unit_data then
            -- Reduce patience over time, especially for units further back
            local patience_decay = 0.001 * i  -- Back units lose patience faster
            unit_data.patience = math.max(0, unit_data.patience - patience_decay)
            
            -- Impatient units might try to leave the queue
            if unit_data.patience < 0.3 and i > 3 then  -- Don't let first 3 units leave easily
                self:handle_impatient_unit(unit, queue)
            end
        end
    end
end
-- }}}

-- {{{ UnitQueueingSystem:handle_impatient_unit
function UnitQueueingSystem:handle_impatient_unit(unit, queue)
    -- Try to move unit to a different sub-path if available
    if self.queue_branching then
        local alternative_subpath = self:find_alternative_subpath(unit, queue)
        if alternative_subpath then
            self:remove_unit_from_queue(queue, unit)
            -- Assign to new sub-path (this would be handled by the movement system)
            debug.log("Impatient unit " .. unit.name .. " switching sub-paths", "QUEUEING")
        end
    end
end
-- }}}

-- {{{ UnitQueueingSystem:find_alternative_subpath
function UnitQueueingSystem:find_alternative_subpath(unit, queue)
    -- Check adjacent sub-paths for lower congestion
    local adjacent_subpaths = {queue.sub_path_id - 1, queue.sub_path_id + 1}
    
    for _, subpath_id in ipairs(adjacent_subpaths) do
        if subpath_id >= 1 and subpath_id <= 5 then  -- Valid sub-path range
            local units_on_path = self.unit_movement_system:get_units_on_sub_path(queue.lane, subpath_id)
            if #units_on_path < 3 then  -- Less crowded
                return subpath_id
            end
        end
    end
    
    return nil
end
-- }}}

-- {{{ UnitQueueingSystem:should_dissolve_queue
function UnitQueueingSystem:should_dissolve_queue(queue)
    -- Dissolve if queue has become too small
    if #queue.units <= 1 then
        return true
    end
    
    -- Dissolve if leader is no longer blocked
    if queue.queue_leader then
        local assignment = self.unit_movement_system:get_unit_assignment(queue.queue_leader)
        if assignment and not self:should_form_queue(queue.queue_leader, assignment) then
            return true
        end
    end
    
    return false
end
-- }}}

-- {{{ UnitQueueingSystem:dissolve_queue
function UnitQueueingSystem:dissolve_queue(queue)
    debug.log("Dissolving queue " .. queue.id, "QUEUEING")
    
    -- Remove all units from queue
    for _, unit in ipairs(queue.units) do
        self:remove_unit_from_queue(queue, unit)
    end
    
    -- Remove queue
    self.lane_queues[queue.id] = nil
end
-- }}}

-- {{{ UnitQueueingSystem:cleanup_empty_queues
function UnitQueueingSystem:cleanup_empty_queues()
    local queues_to_remove = {}
    
    for queue_id, queue in pairs(self.lane_queues) do
        if #queue.units == 0 then
            table.insert(queues_to_remove, queue_id)
        end
    end
    
    for _, queue_id in ipairs(queues_to_remove) do
        self.lane_queues[queue_id] = nil
    end
end
-- }}}

-- {{{ UnitQueueingSystem:handle_queue_optimization
function UnitQueueingSystem:handle_queue_optimization()
    -- Merge nearby queues if beneficial
    -- Branch queues to less congested paths
    -- This is a placeholder for more advanced queue management
end
-- }}}

-- {{{ UnitQueueingSystem:get_queue_tail_position
function UnitQueueingSystem:get_queue_tail_position(queue)
    if #queue.units == 0 then
        return nil
    end
    
    local last_unit = queue.units[#queue.units]
    local position = self.entity_manager:get_component(last_unit, "position")
    
    if position then
        return Vector2:new(position.x, position.y)
    end
    
    return nil
end
-- }}}

-- {{{ UnitQueueingSystem:calculate_congestion_ahead
function UnitQueueingSystem:calculate_congestion_ahead(unit, assignment, unit_pos)
    if not assignment.sub_path then
        return 0
    end
    
    -- Define area ahead of unit for congestion checking
    local check_area = self:define_congestion_check_area(unit_pos, assignment.sub_path, self.congestion_check_distance)
    
    -- Count units in the area
    local units_in_area = 0
    local area_capacity = self:calculate_area_capacity(check_area, assignment.sub_path)
    
    local units_in_path = self.unit_movement_system:get_units_on_sub_path(assignment.lane, assignment.sub_path_id)
    
    for _, other_unit in ipairs(units_in_path) do
        if other_unit.id ~= unit.id then
            local other_position = self.entity_manager:get_component(other_unit, "position")
            if other_position then
                local other_pos = Vector2:new(other_position.x, other_position.y)
                
                if self:is_position_in_area(other_pos, check_area) and self:is_unit_ahead(unit, other_unit, assignment.sub_path) then
                    units_in_area = units_in_area + 1
                end
            end
        end
    end
    
    return area_capacity > 0 and units_in_area / area_capacity or 0
end
-- }}}

-- {{{ UnitQueueingSystem:is_space_limited
function UnitQueueingSystem:is_space_limited(unit, assignment)
    if not assignment.sub_path then
        return false
    end
    
    -- Calculate total units on sub-path vs capacity
    local units_in_path = self.unit_movement_system:get_units_on_sub_path(assignment.lane, assignment.sub_path_id)
    local sub_path_capacity = self:calculate_sub_path_capacity(assignment.sub_path)
    
    local utilization = #units_in_path / sub_path_capacity
    return utilization > self.space_limit_threshold
end
-- }}}

-- {{{ UnitQueueingSystem:define_congestion_check_area
function UnitQueueingSystem:define_congestion_check_area(unit_pos, sub_path, check_distance)
    -- Create rectangular area ahead of unit
    local moveable = self.entity_manager:get_component(unit, "moveable")
    local direction = Vector2:new(1, 0)  -- Default forward direction
    
    if moveable and (moveable.velocity_x ~= 0 or moveable.velocity_y ~= 0) then
        direction = Vector2:new(moveable.velocity_x, moveable.velocity_y):normalize()
    end
    
    local ahead_point = unit_pos:add(direction:multiply(check_distance))
    local path_width = sub_path.width or 25
    
    return {
        center = unit_pos:add(direction:multiply(check_distance / 2)),
        width = path_width,
        length = check_distance,
        direction = direction
    }
end
-- }}}

-- {{{ UnitQueueingSystem:calculate_area_capacity
function UnitQueueingSystem:calculate_area_capacity(check_area, sub_path)
    -- Estimate how many units can fit in the area
    local area_size = check_area.width * check_area.length
    local unit_footprint = 15  -- Approximate space per unit
    return math.floor(area_size / unit_footprint)
end
-- }}}

-- {{{ UnitQueueingSystem:calculate_sub_path_capacity
function UnitQueueingSystem:calculate_sub_path_capacity(sub_path)
    -- Calculate how many units can fit on the entire sub-path
    local path_length = sub_path.length or 200
    local path_width = sub_path.width or 25
    local unit_footprint = 20  -- Space per unit including movement
    
    return math.floor((path_length * path_width) / unit_footprint)
end
-- }}}

-- {{{ UnitQueueingSystem:is_position_in_area
function UnitQueueingSystem:is_position_in_area(position, check_area)
    -- Simple rectangular bounds check
    local to_center = position:subtract(check_area.center)
    local forward_distance = math.abs(to_center:dot(check_area.direction))
    local lateral_distance = math.abs(to_center:dot(Vector2:new(-check_area.direction.y, check_area.direction.x)))
    
    return forward_distance <= check_area.length / 2 and lateral_distance <= check_area.width / 2
end
-- }}}

-- {{{ UnitQueueingSystem:is_unit_ahead
function UnitQueueingSystem:is_unit_ahead(unit, other_unit, sub_path)
    -- Determine if other_unit is ahead of unit on the sub-path
    local unit_assignment = self.unit_movement_system:get_unit_assignment(unit)
    local other_assignment = self.unit_movement_system:get_unit_assignment(other_unit)
    
    if not unit_assignment or not other_assignment then
        return false
    end
    
    -- Compare progress along sub-path
    local unit_progress = unit_assignment.progress or 0
    local other_progress = other_assignment.progress or 0
    
    return other_progress > unit_progress
end
-- }}}

-- {{{ UnitQueueingSystem:handle_queue_overflow
function UnitQueueingSystem:handle_queue_overflow(queue)
    if #queue.units <= self.max_queue_length then
        return
    end
    
    -- Try to create alternative routes for overflow units
    local overflow_units = {}
    for i = self.max_queue_length + 1, #queue.units do
        table.insert(overflow_units, queue.units[i])
    end
    
    for _, unit in ipairs(overflow_units) do
        -- Try to find alternative sub-path
        local alternative_path = self:find_alternative_subpath(unit, queue)
        if alternative_path then
            self:remove_unit_from_queue(queue, unit)
            -- Signal movement system to redirect unit
            local unit_data = self.entity_manager:get_component(unit, "unit_data")
            if unit_data then
                unit_data.needs_rerouting = true
                unit_data.preferred_subpath = alternative_path
            end
            debug.log("Redirected overflow unit " .. unit.name .. " to sub-path " .. alternative_path, "QUEUEING")
        else
            -- Keep in queue but mark as overflow
            local unit_data = self.entity_manager:get_component(unit, "unit_data")
            if unit_data then
                unit_data.queue_overflow = true
                unit_data.patience = unit_data.patience * 0.8  -- Reduce patience faster
            end
        end
    end
end
-- }}}

-- {{{ UnitQueueingSystem:get_debug_info
function UnitQueueingSystem:get_debug_info()
    local total_queues = 0
    local total_queued_units = 0
    local longest_queue = 0
    local queue_info = {}
    local overflow_units = 0
    
    for queue_id, queue in pairs(self.lane_queues) do
        total_queues = total_queues + 1
        total_queued_units = total_queued_units + #queue.units
        longest_queue = math.max(longest_queue, #queue.units)
        
        local queue_overflow = math.max(0, #queue.units - self.max_queue_length)
        overflow_units = overflow_units + queue_overflow
        
        table.insert(queue_info, {
            id = queue_id,
            sub_path_id = queue.sub_path_id,
            unit_count = #queue.units,
            compression_factor = queue.compression_factor,
            overflow_count = queue_overflow
        })
    end
    
    return {
        total_queues = total_queues,
        total_queued_units = total_queued_units,
        longest_queue = longest_queue,
        overflow_units = overflow_units,
        queue_details = queue_info,
        dynamic_spacing = self.dynamic_queue_spacing,
        patience_system = self.patience_system,
        congestion_threshold = self.congestion_threshold,
        space_limit_threshold = self.space_limit_threshold
    }
end
-- }}}

return UnitQueueingSystem
-- }}}