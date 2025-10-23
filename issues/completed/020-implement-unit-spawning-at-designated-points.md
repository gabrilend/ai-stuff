# Issue #020: Implement Unit Spawning at Designated Points

## Current Behavior
Basic spawning system exists but needs enhancement for proper spawn point management and unit deployment.

## Intended Behavior
Units should spawn at designated spawn points with proper team assignment, lane allocation, and formation positioning.

## Implementation Details

### Enhanced Spawning System (src/systems/unit_spawning_system.lua)
```lua
-- {{{ local function spawn_unit_at_point
local function spawn_unit_at_point(template, team_id, spawn_point_id, sub_path_preference)
    local spawn_point = get_spawn_point(spawn_point_id)
    if not spawn_point or spawn_point.team_id ~= team_id then
        Debug:log("Invalid spawn point for team: " .. tostring(team_id))
        return nil
    end
    
    -- Find appropriate sub-path for spawning
    local target_sub_path = find_spawn_sub_path(spawn_point, sub_path_preference)
    if not target_sub_path then
        Debug:log("No available sub-path for spawning")
        return nil
    end
    
    -- Calculate spawn position with formation offset
    local spawn_position = calculate_spawn_position(spawn_point, target_sub_path, template)
    if not spawn_position then
        Debug:log("Cannot calculate valid spawn position")
        return nil
    end
    
    -- Create unit entity
    local unit_id = UnitEntity:create(template, team_id, spawn_position, target_sub_path.id)
    
    -- Register unit in spawning system
    register_spawned_unit(unit_id, spawn_point_id, target_sub_path.id)
    
    -- Trigger spawn effects
    create_spawn_effects(spawn_position, team_id)
    
    Debug:log("Unit spawned: " .. unit_id .. " at " .. spawn_position.x .. "," .. spawn_position.y)
    return unit_id
end
-- }}}

-- {{{ local function find_spawn_sub_path
local function find_spawn_sub_path(spawn_point, preference)
    local available_lanes = LaneSystem:get_lanes_at_spawn_point(spawn_point.id)
    
    if #available_lanes == 0 then
        return nil
    end
    
    -- If preference specified, try to use it
    if preference and preference.lane_id then
        for _, lane in ipairs(available_lanes) do
            if lane.id == preference.lane_id then
                local sub_path = select_sub_path_in_lane(lane, preference.sub_path_index)
                if sub_path then
                    return sub_path
                end
            end
        end
    end
    
    -- Default selection: find least crowded sub-path
    local best_sub_path = nil
    local min_unit_count = math.huge
    
    for _, lane in ipairs(available_lanes) do
        for _, sub_path in ipairs(lane.sub_paths) do
            local unit_count = count_units_in_sub_path(sub_path.id)
            if unit_count < min_unit_count then
                min_unit_count = unit_count
                best_sub_path = sub_path
            end
        end
    end
    
    return best_sub_path
end
-- }}}

-- {{{ local function calculate_spawn_position
local function calculate_spawn_position(spawn_point, sub_path, template)
    local base_position = spawn_point.position
    
    -- Find closest point on sub-path center line to spawn point
    local center_line = sub_path.center_line
    if #center_line == 0 then
        return nil
    end
    
    local closest_point = center_line[1]
    local min_distance = base_position:distance_to(closest_point)
    
    for i = 2, #center_line do
        local distance = base_position:distance_to(center_line[i])
        if distance < min_distance then
            min_distance = distance
            closest_point = center_line[i]
        end
    end
    
    -- Apply formation offset based on unit count in sub-path
    local formation_offset = calculate_formation_offset(sub_path, template)
    local spawn_position = closest_point:add(formation_offset)
    
    -- Ensure position is within sub-path boundaries
    if not CollisionSystem:check_unit_in_bounds({position = spawn_position}, sub_path) then
        spawn_position = CollisionSystem:correct_unit_position({position = spawn_position}, sub_path)
    end
    
    return spawn_position
end
-- }}}

-- {{{ local function calculate_formation_offset
local function calculate_formation_offset(sub_path, template)
    local existing_units = get_units_in_sub_path(sub_path.id)
    local unit_count = #existing_units
    
    -- Calculate lateral offset to prevent spawning on top of each other
    local lateral_spacing = 12  -- Distance between units side-by-side
    local depth_spacing = 16   -- Distance between units front-to-back
    
    -- Determine formation position based on unit count
    local units_per_row = 3  -- Maximum units side-by-side
    local row = math.floor(unit_count / units_per_row)
    local col = unit_count % units_per_row
    
    -- Calculate offset perpendicular to path direction
    local path_direction = get_sub_path_direction(sub_path)
    local perpendicular = Vector2:new(-path_direction.y, path_direction.x)
    
    -- Center the formation
    local lateral_offset = (col - (units_per_row - 1) / 2) * lateral_spacing
    local depth_offset = -row * depth_spacing  -- Behind the front line
    
    local formation_offset = perpendicular:multiply(lateral_offset):add(
        path_direction:multiply(depth_offset)
    )
    
    return formation_offset
end
-- }}}

-- {{{ local function get_sub_path_direction
local function get_sub_path_direction(sub_path)
    local center_line = sub_path.center_line
    
    if #center_line < 2 then
        return Vector2:new(1, 0)  -- Default direction
    end
    
    -- Use direction from first segment
    local direction = center_line[2]:subtract(center_line[1]):normalize()
    return direction
end
-- }}}

-- {{{ local function create_spawn_effects
local function create_spawn_effects(position, team_id)
    -- Visual spawn effect (simple circle expansion)
    local effect_duration = 0.5
    local max_radius = 20
    
    local effect = {
        position = position,
        team_id = team_id,
        start_time = love.timer.getTime(),
        duration = effect_duration,
        max_radius = max_radius,
        type = "spawn"
    }
    
    EffectSystem:add_effect(effect)
end
-- }}}

-- {{{ local function get_spawn_points_for_team
local function get_spawn_points_for_team(team_id)
    local team_spawn_points = {}
    
    for _, spawn_point in ipairs(spawn_points) do
        if spawn_point.team_id == team_id then
            table.insert(team_spawn_points, spawn_point)
        end
    end
    
    return team_spawn_points
end
-- }}}

-- {{{ local function can_spawn_unit
local function can_spawn_unit(template, team_id, spawn_point_id)
    local spawn_point = get_spawn_point(spawn_point_id)
    
    if not spawn_point then
        return false, "Invalid spawn point"
    end
    
    if spawn_point.team_id ~= team_id then
        return false, "Spawn point belongs to different team"
    end
    
    -- Check if spawn point area is clear
    local nearby_units = get_units_near_position(spawn_point.position, 20)
    if #nearby_units > 5 then  -- Limit concurrent spawning
        return false, "Spawn area too crowded"
    end
    
    -- Check if valid sub-paths are available
    local available_lanes = LaneSystem:get_lanes_at_spawn_point(spawn_point.id)
    if #available_lanes == 0 then
        return false, "No available lanes"
    end
    
    return true, "Ready to spawn"
end
-- }}}

-- {{{ local function batch_spawn_units
local function batch_spawn_units(spawn_requests)
    local spawned_units = {}
    local spawn_delay = 0.1  -- Delay between spawns in batch
    
    for i, request in ipairs(spawn_requests) do
        -- Schedule spawn with slight delay to prevent overlap
        local spawn_time = love.timer.getTime() + (i - 1) * spawn_delay
        
        schedule_delayed_spawn(request, spawn_time)
    end
    
    return spawned_units
end
-- }}}
```

### Spawning Features
1. **Smart Positioning**: Automatic formation and spacing
2. **Sub-Path Selection**: Intelligent lane and path assignment
3. **Collision Avoidance**: Prevent spawning on existing units
4. **Batch Spawning**: Support for multiple unit deployment
5. **Visual Effects**: Spawn animations and feedback

### Formation System
- Automatic arrangement in rows and columns
- Respect sub-path width constraints
- Maintain unit spacing for movement
- Consider unit size in positioning

### Validation and Safety
- Check spawn point validity and ownership
- Ensure adequate space for spawning
- Validate template and team parameters
- Handle edge cases gracefully

### Tool Suggestions
- Use Edit tool to enhance spawning system
- Test with different unit templates and team configurations
- Verify formation positioning and spacing
- Check spawn point validation logic

### Acceptance Criteria
- [ ] Units spawn at correct team spawn points
- [ ] Formation positioning prevents unit overlap
- [ ] Sub-path assignment works efficiently
- [ ] Spawn validation prevents invalid operations
- [ ] Visual spawn effects provide feedback