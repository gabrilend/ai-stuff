# Issue #024: Add Unit Queueing When Space is Limited

## Current Behavior
Units may attempt to occupy the same space or push through areas that are too crowded, leading to unrealistic stacking or movement issues.

## Intended Behavior
When space is limited, units should form orderly queues behind obstacles or crowded areas, waiting their turn to advance while maintaining formation discipline.

## Implementation Details

### Unit Queueing System (src/systems/unit_queueing_system.lua)
```lua
-- {{{ local function update_unit_queueing
local function update_unit_queueing(unit_id, dt)
    local position = EntityManager:get_component(unit_id, "position")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not position or not unit_data then
        return
    end
    
    -- Check if unit should enter queuing state
    local should_queue = should_unit_queue(unit_id)
    
    if should_queue and unit_data.state ~= "queued" then
        enter_queue_state(unit_id)
    elseif not should_queue and unit_data.state == "queued" then
        exit_queue_state(unit_id)
    end
    
    -- Update queueing behavior
    if unit_data.state == "queued" then
        update_queue_positioning(unit_id, dt)
    end
end
-- }}}

-- {{{ local function should_unit_queue
local function should_unit_queue(unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    
    if not position or not moveable then
        return false
    end
    
    local sub_path = LaneSystem:get_sub_path(position.sub_path_id)
    if not sub_path then
        return false
    end
    
    -- Check for congestion ahead
    local congestion_check_distance = 40
    local congestion_level = calculate_congestion_ahead(unit_id, congestion_check_distance)
    
    -- Queue if congestion is high
    local congestion_threshold = 0.7  -- 70% capacity
    if congestion_level > congestion_threshold then
        return true
    end
    
    -- Check for immovable obstacles
    local blocking_obstacle = find_blocking_obstacle(unit_id)
    if blocking_obstacle then
        return true
    end
    
    -- Check if front unit is stationary
    local front_unit = find_unit_directly_ahead(unit_id, 25)
    if front_unit then
        local front_moveable = EntityManager:get_component(front_unit, "moveable")
        if front_moveable and not front_moveable.is_moving then
            return true
        end
    end
    
    return false
end
-- }}}

-- {{{ local function calculate_congestion_ahead
local function calculate_congestion_ahead(unit_id, check_distance)
    local position = EntityManager:get_component(unit_id, "position")
    local current_pos = Vector2:new(position.x, position.y)
    
    local sub_path = LaneSystem:get_sub_path(position.sub_path_id)
    if not sub_path then
        return 0
    end
    
    -- Define area ahead of unit
    local check_area = define_congestion_check_area(current_pos, sub_path, check_distance)
    
    -- Count units in the area
    local units_in_area = 0
    local area_capacity = calculate_area_capacity(check_area, sub_path)
    
    local units_in_path = get_units_in_sub_path(position.sub_path_id)
    
    for _, other_unit_id in ipairs(units_in_path) do
        if other_unit_id ~= unit_id then
            local other_position = EntityManager:get_component(other_unit_id, "position")
            if other_position then
                local other_pos = Vector2:new(other_position.x, other_position.y)
                
                if is_position_in_area(other_pos, check_area) and is_unit_ahead(unit_id, other_unit_id, sub_path) then
                    units_in_area = units_in_area + 1
                end
            end
        end
    end
    
    return area_capacity > 0 and units_in_area / area_capacity or 0
end
-- }}}

-- {{{ local function enter_queue_state
local function enter_queue_state(unit_id)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    
    if unit_data then
        unit_data.state = "queued"
        unit_data.queue_entry_time = love.timer.getTime()
    end
    
    if moveable then
        -- Stop movement when entering queue
        moveable.velocity_x = 0
        moveable.velocity_y = 0
        moveable.is_moving = false
    end
    
    -- Find queue position
    local queue_position = find_queue_position(unit_id)
    assign_to_queue(unit_id, queue_position)
    
    Debug:log("Unit " .. unit_id .. " entered queue")
end
-- }}}

-- {{{ local function find_queue_position
local function find_queue_position(unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    local sub_path = LaneSystem:get_sub_path(position.sub_path_id)
    
    if not position or not sub_path then
        return nil
    end
    
    -- Find existing queue in this sub-path
    local existing_queue = find_existing_queue(position.sub_path_id)
    
    if existing_queue then
        -- Join existing queue at the back
        return {
            queue_id = existing_queue.id,
            position_in_queue = #existing_queue.units + 1,
            target_position = calculate_queue_back_position(existing_queue)
        }
    else
        -- Create new queue
        local queue_id = create_new_queue(unit_id, sub_path)
        return {
            queue_id = queue_id,
            position_in_queue = 1,
            target_position = Vector2:new(position.x, position.y)
        }
    end
end
-- }}}

-- {{{ local function update_queue_positioning
local function update_queue_positioning(unit_id, dt)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not position or not moveable or not unit_data.queue_data then
        return
    end
    
    local queue = get_queue(unit_data.queue_data.queue_id)
    if not queue then
        exit_queue_state(unit_id)
        return
    end
    
    -- Calculate ideal position in queue
    local ideal_position = calculate_ideal_queue_position(unit_id, queue)
    
    -- Move toward ideal position if not already there
    local current_pos = Vector2:new(position.x, position.y)
    local distance_to_ideal = current_pos:distance_to(ideal_position)
    
    if distance_to_ideal > 2.0 then  -- 2 unit tolerance
        local direction = ideal_position:subtract(current_pos):normalize()
        local queue_movement_speed = 15  -- Slower than normal movement
        
        moveable.velocity_x = direction.x * queue_movement_speed
        moveable.velocity_y = direction.y * queue_movement_speed
        moveable.is_moving = true
        
        position.x = position.x + moveable.velocity_x * dt
        position.y = position.y + moveable.velocity_y * dt
    else
        -- Hold position
        moveable.velocity_x = 0
        moveable.velocity_y = 0
        moveable.is_moving = false
    end
    
    -- Check if unit can advance in queue
    check_queue_advancement(unit_id, queue)
end
-- }}}

-- {{{ local function calculate_ideal_queue_position
local function calculate_ideal_queue_position(unit_id, queue)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local position_in_queue = unit_data.queue_data.position_in_queue
    
    -- Get queue formation parameters
    local queue_spacing = 18  -- Distance between units in queue
    local queue_direction = queue.direction or Vector2:new(-1, 0)  -- Default backward
    
    -- Calculate position based on place in line
    local offset_distance = (position_in_queue - 1) * queue_spacing
    local offset_vector = queue_direction:multiply(offset_distance)
    
    return queue.anchor_position:add(offset_vector)
end
-- }}}

-- {{{ local function check_queue_advancement
local function check_queue_advancement(unit_id, queue)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local position_in_queue = unit_data.queue_data.position_in_queue
    
    -- Check if unit can move up in queue
    if position_in_queue > 1 then
        local ahead_unit_id = get_unit_at_queue_position(queue, position_in_queue - 1)
        
        if not ahead_unit_id then
            -- Position ahead is empty, move up
            advance_in_queue(unit_id, queue, position_in_queue - 1)
        end
    else
        -- Front of queue, check if path ahead is clear
        if is_path_ahead_clear(unit_id) then
            -- Can exit queue and resume movement
            exit_queue_state(unit_id)
        end
    end
end
-- }}}

-- {{{ local function advance_in_queue
local function advance_in_queue(unit_id, queue, new_position)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if unit_data and unit_data.queue_data then
        unit_data.queue_data.position_in_queue = new_position
        
        -- Update queue registry
        update_queue_positions(queue.id)
        
        Debug:log("Unit " .. unit_id .. " advanced to position " .. new_position .. " in queue")
    end
end
-- }}}

-- {{{ local function exit_queue_state
local function exit_queue_state(unit_id)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if unit_data then
        -- Remove from queue
        if unit_data.queue_data then
            remove_from_queue(unit_id, unit_data.queue_data.queue_id)
            unit_data.queue_data = nil
        end
        
        -- Resume normal movement state
        unit_data.state = "moving"
        
        Debug:log("Unit " .. unit_id .. " exited queue")
    end
end
-- }}}

-- {{{ local function create_new_queue
local function create_new_queue(anchor_unit_id, sub_path)
    local position = EntityManager:get_component(anchor_unit_id, "position")
    local anchor_position = Vector2:new(position.x, position.y)
    
    -- Determine queue direction (opposite to path direction)
    local path_direction = get_path_direction_at_position(position, sub_path)
    local queue_direction = path_direction:multiply(-1)
    
    local queue = {
        id = generate_queue_id(),
        sub_path_id = sub_path.id,
        anchor_position = anchor_position,
        direction = queue_direction,
        units = {},
        creation_time = love.timer.getTime(),
        max_length = 10  -- Maximum units in queue
    }
    
    register_queue(queue)
    return queue.id
end
-- }}}

-- {{{ local function handle_queue_overflow
local function handle_queue_overflow(queue_id)
    local queue = get_queue(queue_id)
    if not queue or #queue.units <= queue.max_length then
        return
    end
    
    -- Try to create alternative routes for overflow units
    local overflow_units = {}
    for i = queue.max_length + 1, #queue.units do
        table.insert(overflow_units, queue.units[i])
    end
    
    for _, unit_id in ipairs(overflow_units) do
        -- Try to find alternative sub-path
        local alternative_path = find_alternative_sub_path(unit_id)
        if alternative_path then
            redirect_unit_to_sub_path(unit_id, alternative_path.id)
        else
            -- Keep in queue but mark as overflow
            mark_unit_as_overflow(unit_id)
        end
    end
end
-- }}}
```

### Queueing Features
1. **Congestion Detection**: Identify when areas become too crowded
2. **Automatic Queue Formation**: Create orderly lines when needed
3. **Queue Advancement**: Move units forward as space becomes available
4. **Position Maintenance**: Keep proper spacing and alignment
5. **Overflow Handling**: Manage queues that become too long

### Queue Management
- Dynamic queue creation and dissolution
- Position tracking within queues
- Smart advancement algorithms
- Alternative routing for overflow

### Integration Points
- Works with lane following system
- Respects formation preferences
- Coordinates with obstacle avoidance
- Supports combat state transitions

### Tool Suggestions
- Use Edit tool to enhance queueing system
- Test with high unit density scenarios
- Verify queue formation and advancement
- Check overflow handling with many units

### Acceptance Criteria
- [ ] Units form orderly queues when space is limited
- [ ] Queue advancement works smoothly as space opens
- [ ] Position maintenance keeps proper spacing
- [ ] Overflow scenarios are handled gracefully
- [ ] System integrates well with existing movement mechanics