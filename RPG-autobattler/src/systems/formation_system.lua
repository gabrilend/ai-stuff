-- {{{ FormationSystem
local FormationSystem = {}

local Vector2 = require("src.utils.vector2")
local MathUtils = require("src.utils.math_utils")
local debug = require("src.utils.debug")

-- {{{ FormationSystem:new
function FormationSystem:new(entity_manager, unit_movement_system, lane_system)
    local system = {
        entity_manager = entity_manager,
        unit_movement_system = unit_movement_system,
        lane_system = lane_system,
        name = "formation",
        
        -- Formation tracking
        formations = {},              -- Active formations by ID
        formation_assignments = {},   -- Maps unit ID to formation ID
        next_formation_id = 1,
        
        -- Formation parameters
        formation_strength = 0.5,     -- How strongly units try to maintain formation
        max_formation_deviation = 30, -- Max distance before reformation
        reformation_threshold = 0.7,  -- Percentage of units needed for reformation
        leader_follow_distance = 20,  -- Distance to maintain from formation leader
        
        -- Formation preservation parameters
        cohesion_strength = 2.0,      -- Force strength for maintaining cohesion
        max_cohesion_distance = 50,   -- Max distance before applying cohesion force
        terrain_adaptation_factor = 0.8, -- How much formations adapt to terrain constraints
        preservation_priority = 0.6,  -- Balance between formation and individual movement
        
        -- Formation types and their behaviors
        formation_templates = {
            line = {
                spacing = {x = 20, y = 0},
                leader_position = "center",
                flexibility = 0.8
            },
            column = {
                spacing = {x = 0, y = 15},
                leader_position = "front",
                flexibility = 0.6
            },
            wedge = {
                spacing = {x = 15, y = 12},
                leader_position = "front",
                flexibility = 0.7
            },
            box = {
                spacing = {x = 18, y = 18},
                leader_position = "center",
                flexibility = 0.5
            },
            spread = {
                spacing = {x = 25, y = 20},
                leader_position = "center",
                flexibility = 0.9
            }
        },
        
        -- Update frequency
        update_frequency = 1/15,      -- Update formations 15 times per second
        last_update = 0
    }
    setmetatable(system, {__index = FormationSystem})
    
    debug.log("FormationSystem created", "FORMATION")
    return system
end
-- }}}

-- {{{ FormationSystem:update
function FormationSystem:update(dt)
    self.last_update = self.last_update + dt
    
    if self.last_update < self.update_frequency then
        return
    end
    
    -- Update all active formations
    for formation_id, formation in pairs(self.formations) do
        self:update_formation(formation, self.last_update)
    end
    
    -- Clean up empty formations
    self:cleanup_empty_formations()
    
    self.last_update = 0
end
-- }}}

-- {{{ FormationSystem:create_formation
function FormationSystem:create_formation(units, formation_type, leader_unit)
    formation_type = formation_type or "line"
    
    if not units or #units == 0 then
        debug.warn("Cannot create formation with no units", "FORMATION")
        return nil
    end
    
    local formation_id = self.next_formation_id
    self.next_formation_id = self.next_formation_id + 1
    
    -- Choose leader (first unit if not specified)
    leader_unit = leader_unit or units[1]
    
    local formation = {
        id = formation_id,
        type = formation_type,
        leader = leader_unit,
        units = {},
        created_time = love.timer.getTime(),
        
        -- Formation state
        center_position = Vector2:new(0, 0),
        facing_direction = Vector2:new(1, 0),
        formation_positions = {},     -- Ideal positions for each unit
        formation_health = 1.0,       -- How well formation is maintained
        
        -- Formation parameters
        template = self.formation_templates[formation_type] or self.formation_templates.line,
        spacing_scale = 1.0,
        formation_speed = 0,
        
        -- Movement tracking
        last_position = Vector2:new(0, 0),
        movement_velocity = Vector2:new(0, 0)
    }
    
    -- Add units to formation
    for i, unit in ipairs(units) do
        self:add_unit_to_formation(formation, unit, i)
    end
    
    -- Calculate initial formation layout
    self:calculate_formation_positions(formation)
    
    self.formations[formation_id] = formation
    
    debug.log("Created formation " .. formation_id .. " with " .. #units .. " units", "FORMATION")
    return formation
end
-- }}}

-- {{{ FormationSystem:add_unit_to_formation
function FormationSystem:add_unit_to_formation(formation, unit, position_index)
    position_index = position_index or (#formation.units + 1)
    
    -- Remove unit from any existing formation
    local old_formation_id = self.formation_assignments[unit.id]
    if old_formation_id then
        self:remove_unit_from_formation(self.formations[old_formation_id], unit)
    end
    
    -- Add to new formation
    table.insert(formation.units, unit)
    self.formation_assignments[unit.id] = formation.id
    
    -- Set unit's formation data
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    if unit_data then
        unit_data.formation_id = formation.id
        unit_data.formation_position = position_index
        unit_data.in_formation = true
    end
    
    debug.log("Added unit " .. unit.name .. " to formation " .. formation.id, "FORMATION")
end
-- }}}

-- {{{ FormationSystem:remove_unit_from_formation
function FormationSystem:remove_unit_from_formation(formation, unit)
    if not formation then
        return
    end
    
    -- Remove from units list
    for i, formation_unit in ipairs(formation.units) do
        if formation_unit.id == unit.id then
            table.remove(formation.units, i)
            break
        end
    end
    
    -- Remove assignment
    self.formation_assignments[unit.id] = nil
    
    -- Clear unit's formation data
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    if unit_data then
        unit_data.formation_id = nil
        unit_data.formation_position = nil
        unit_data.in_formation = false
    end
    
    -- If leader was removed, choose new leader
    if formation.leader and formation.leader.id == unit.id and #formation.units > 0 then
        formation.leader = formation.units[1]
        debug.log("New formation leader: " .. formation.leader.name, "FORMATION")
    end
    
    debug.log("Removed unit " .. unit.name .. " from formation " .. formation.id, "FORMATION")
end
-- }}}

-- {{{ FormationSystem:update_formation
function FormationSystem:update_formation(formation, dt)
    if #formation.units == 0 then
        return
    end
    
    -- Update formation center and facing direction
    self:update_formation_state(formation)
    
    -- Calculate ideal positions for all units
    self:calculate_formation_positions(formation)
    
    -- Apply formation forces to units
    self:apply_formation_forces(formation, dt)
    
    -- Apply formation preservation logic
    self:maintain_formation_cohesion(formation, dt)
    
    -- Adapt formation to terrain constraints
    self:adapt_formation_to_terrain(formation)
    
    -- Check formation health
    formation.formation_health = self:calculate_formation_health(formation)
    
    -- Trigger reformation if needed
    if formation.formation_health < self.reformation_threshold then
        self:trigger_formation_reformation(formation)
    end
end
-- }}}

-- {{{ FormationSystem:update_formation_state
function FormationSystem:update_formation_state(formation)
    if not formation.leader then
        return
    end
    
    -- Get leader position
    local leader_position = self.entity_manager:get_component(formation.leader, "position")
    local leader_moveable = self.entity_manager:get_component(formation.leader, "moveable")
    
    if leader_position then
        local new_center = Vector2:new(leader_position.x, leader_position.y)
        
        -- Calculate movement velocity
        formation.movement_velocity = new_center:subtract(formation.last_position)
        formation.last_position = formation.center_position:copy()
        formation.center_position = new_center
        
        -- Update facing direction based on leader's velocity
        if leader_moveable and (leader_moveable.velocity_x ~= 0 or leader_moveable.velocity_y ~= 0) then
            local velocity = Vector2:new(leader_moveable.velocity_x, leader_moveable.velocity_y)
            if velocity:length() > 0.1 then
                formation.facing_direction = velocity:normalize()
            end
        end
        
        -- Calculate formation speed
        formation.formation_speed = formation.movement_velocity:length()
    end
end
-- }}}

-- {{{ FormationSystem:calculate_formation_positions
function FormationSystem:calculate_formation_positions(formation)
    local template = formation.template
    local unit_count = #formation.units
    formation.formation_positions = {}
    
    if formation.type == "line" then
        self:calculate_line_formation(formation, template, unit_count)
    elseif formation.type == "column" then
        self:calculate_column_formation(formation, template, unit_count)
    elseif formation.type == "wedge" then
        self:calculate_wedge_formation(formation, template, unit_count)
    elseif formation.type == "box" then
        self:calculate_box_formation(formation, template, unit_count)
    elseif formation.type == "spread" then
        self:calculate_spread_formation(formation, template, unit_count)
    else
        self:calculate_line_formation(formation, template, unit_count)
    end
end
-- }}}

-- {{{ FormationSystem:calculate_line_formation
function FormationSystem:calculate_line_formation(formation, template, unit_count)
    local spacing = template.spacing.x * formation.spacing_scale
    local center_index = math.ceil(unit_count / 2)
    
    for i, unit in ipairs(formation.units) do
        local offset_index = i - center_index
        local side_offset = offset_index * spacing
        
        -- Create perpendicular offset
        local perpendicular = Vector2:new(-formation.facing_direction.y, formation.facing_direction.x)
        local position_offset = perpendicular:multiply(side_offset)
        
        local ideal_position = formation.center_position:add(position_offset)
        formation.formation_positions[unit.id] = ideal_position
    end
end
-- }}}

-- {{{ FormationSystem:calculate_column_formation
function FormationSystem:calculate_column_formation(formation, template, unit_count)
    local spacing = template.spacing.y * formation.spacing_scale
    
    for i, unit in ipairs(formation.units) do
        local depth_offset = (i - 1) * spacing
        
        -- Create backward offset
        local backward_offset = formation.facing_direction:multiply(-depth_offset)
        local ideal_position = formation.center_position:add(backward_offset)
        
        formation.formation_positions[unit.id] = ideal_position
    end
end
-- }}}

-- {{{ FormationSystem:calculate_wedge_formation
function FormationSystem:calculate_wedge_formation(formation, template, unit_count)
    local x_spacing = template.spacing.x * formation.spacing_scale
    local y_spacing = template.spacing.y * formation.spacing_scale
    
    for i, unit in ipairs(formation.units) do
        local row = math.floor((i - 1) / 2)  -- Which row (0, 0, 1, 1, 2, 2, ...)
        local side = (i - 1) % 2  -- Which side (0 = left, 1 = right)
        
        -- Calculate position
        local x_offset = (side == 0 and -1 or 1) * (row + 1) * x_spacing / 2
        local y_offset = -row * y_spacing  -- Negative to go backward
        
        -- Apply formation orientation
        local perpendicular = Vector2:new(-formation.facing_direction.y, formation.facing_direction.x)
        local forward = formation.facing_direction
        
        local position_offset = perpendicular:multiply(x_offset):add(forward:multiply(y_offset))
        local ideal_position = formation.center_position:add(position_offset)
        
        formation.formation_positions[unit.id] = ideal_position
    end
end
-- }}}

-- {{{ FormationSystem:calculate_box_formation
function FormationSystem:calculate_box_formation(formation, template, unit_count)
    local spacing = template.spacing.x * formation.spacing_scale
    local units_per_side = math.ceil(math.sqrt(unit_count))
    
    for i, unit in ipairs(formation.units) do
        local row = math.floor((i - 1) / units_per_side)
        local col = (i - 1) % units_per_side
        
        -- Center the formation
        local x_offset = (col - (units_per_side - 1) / 2) * spacing
        local y_offset = (row - (units_per_side - 1) / 2) * spacing
        
        -- Apply formation orientation
        local perpendicular = Vector2:new(-formation.facing_direction.y, formation.facing_direction.x)
        local forward = formation.facing_direction
        
        local position_offset = perpendicular:multiply(x_offset):add(forward:multiply(y_offset))
        local ideal_position = formation.center_position:add(position_offset)
        
        formation.formation_positions[unit.id] = ideal_position
    end
end
-- }}}

-- {{{ FormationSystem:calculate_spread_formation
function FormationSystem:calculate_spread_formation(formation, template, unit_count)
    local base_spacing = template.spacing.x * formation.spacing_scale
    
    for i, unit in ipairs(formation.units) do
        -- Create a more random spread pattern
        local angle = (i - 1) * (2 * math.pi / unit_count)
        local distance = base_spacing * (0.5 + math.random() * 0.5)  -- Random distance
        
        local x_offset = math.cos(angle) * distance
        local y_offset = math.sin(angle) * distance
        
        local position_offset = Vector2:new(x_offset, y_offset)
        local ideal_position = formation.center_position:add(position_offset)
        
        formation.formation_positions[unit.id] = ideal_position
    end
end
-- }}}

-- {{{ FormationSystem:apply_formation_forces
function FormationSystem:apply_formation_forces(formation, dt)
    for _, unit in ipairs(formation.units) do
        local ideal_position = formation.formation_positions[unit.id]
        if ideal_position then
            self:apply_formation_force_to_unit(unit, ideal_position, formation, dt)
        end
    end
end
-- }}}

-- {{{ FormationSystem:apply_formation_force_to_unit
function FormationSystem:apply_formation_force_to_unit(unit, ideal_position, formation, dt)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    
    if not position or not moveable then
        return
    end
    
    local current_pos = Vector2:new(position.x, position.y)
    local to_ideal = ideal_position:subtract(current_pos)
    local distance_to_ideal = to_ideal:length()
    
    -- Only apply formation force if not too close
    if distance_to_ideal > 2.0 then
        local force_strength = self.formation_strength
        
        -- Reduce force strength based on template flexibility
        force_strength = force_strength * formation.template.flexibility
        
        -- Stronger force if unit is way out of position
        if distance_to_ideal > self.max_formation_deviation then
            force_strength = force_strength * 2.0
        end
        
        -- Calculate formation force
        local formation_force = to_ideal:normalize():multiply(force_strength)
        
        -- Apply to velocity with blending
        local current_velocity = Vector2:new(moveable.velocity_x, moveable.velocity_y)
        local blend_factor = 0.2  -- 20% formation force, 80% current movement
        
        local new_velocity = current_velocity:multiply(1 - blend_factor):add(
            formation_force:multiply(moveable.speed * blend_factor)
        )
        
        -- Limit to max speed
        if new_velocity:length() > moveable.max_speed then
            new_velocity = new_velocity:normalize():multiply(moveable.max_speed)
        end
        
        moveable.velocity_x = new_velocity.x
        moveable.velocity_y = new_velocity.y
    end
    
    -- Update unit data
    if unit_data then
        unit_data.formation_deviation = distance_to_ideal
    end
end
-- }}}

-- {{{ FormationSystem:calculate_formation_health
function FormationSystem:calculate_formation_health(formation)
    local total_deviation = 0
    local unit_count = 0
    
    for _, unit in ipairs(formation.units) do
        local unit_data = self.entity_manager:get_component(unit, "unit_data")
        if unit_data and unit_data.formation_deviation then
            total_deviation = total_deviation + unit_data.formation_deviation
            unit_count = unit_count + 1
        end
    end
    
    if unit_count == 0 then
        return 1.0
    end
    
    local average_deviation = total_deviation / unit_count
    local max_acceptable_deviation = self.max_formation_deviation
    
    -- Health decreases as average deviation increases
    local health = 1.0 - math.min(1.0, average_deviation / max_acceptable_deviation)
    return health
end
-- }}}

-- {{{ FormationSystem:trigger_formation_reformation
function FormationSystem:trigger_formation_reformation(formation)
    debug.log("Triggering reformation for formation " .. formation.id, "FORMATION")
    
    -- Reset spacing scale to help units catch up
    formation.spacing_scale = 0.8
    
    -- Increase formation strength temporarily
    local old_strength = self.formation_strength
    self.formation_strength = self.formation_strength * 1.5
    
    -- Schedule restoration of normal parameters
    formation.reformation_timer = 3.0  -- Reform for 3 seconds
    formation.old_formation_strength = old_strength
end
-- }}}

-- {{{ FormationSystem:cleanup_empty_formations
function FormationSystem:cleanup_empty_formations()
    local formations_to_remove = {}
    
    for formation_id, formation in pairs(self.formations) do
        if #formation.units == 0 then
            table.insert(formations_to_remove, formation_id)
        end
    end
    
    for _, formation_id in ipairs(formations_to_remove) do
        self.formations[formation_id] = nil
        debug.log("Removed empty formation " .. formation_id, "FORMATION")
    end
end
-- }}}

-- {{{ FormationSystem:get_formation_by_unit
function FormationSystem:get_formation_by_unit(unit)
    local formation_id = self.formation_assignments[unit.id]
    return formation_id and self.formations[formation_id] or nil
end
-- }}}

-- {{{ FormationSystem:break_formation
function FormationSystem:break_formation(formation_id)
    local formation = self.formations[formation_id]
    if not formation then
        return false
    end
    
    -- Remove all units from formation
    for _, unit in ipairs(formation.units) do
        self:remove_unit_from_formation(formation, unit)
    end
    
    self.formations[formation_id] = nil
    debug.log("Broke formation " .. formation_id, "FORMATION")
    return true
end
-- }}}

-- {{{ FormationSystem:maintain_formation_cohesion
function FormationSystem:maintain_formation_cohesion(formation, dt)
    local formation_center = self:calculate_formation_center(formation)
    
    for _, unit in ipairs(formation.units) do
        local position = self.entity_manager:get_component(unit, "position")
        local moveable = self.entity_manager:get_component(unit, "moveable")
        
        if position and moveable then
            local unit_pos = Vector2:new(position.x, position.y)
            local distance_from_center = unit_pos:distance_to(formation_center)
            
            if distance_from_center > self.max_cohesion_distance then
                -- Apply cohesion force to pull unit back toward formation
                local cohesion_direction = formation_center:subtract(unit_pos):normalize()
                local cohesion_force = cohesion_direction:multiply(self.cohesion_strength)
                
                -- Blend with current movement
                local current_velocity = Vector2:new(moveable.velocity_x, moveable.velocity_y)
                local preservation_factor = self.preservation_priority
                local blended_velocity = current_velocity:multiply(1 - preservation_factor):add(
                    cohesion_force:multiply(preservation_factor)
                )
                
                moveable.velocity_x = blended_velocity.x
                moveable.velocity_y = blended_velocity.y
            end
        end
    end
end
-- }}}

-- {{{ FormationSystem:calculate_formation_center
function FormationSystem:calculate_formation_center(formation)
    local total_x, total_y = 0, 0
    local valid_units = 0
    
    for _, unit in ipairs(formation.units) do
        local position = self.entity_manager:get_component(unit, "position")
        if position then
            total_x = total_x + position.x
            total_y = total_y + position.y
            valid_units = valid_units + 1
        end
    end
    
    if valid_units == 0 then
        return Vector2:new(0, 0)
    end
    
    return Vector2:new(total_x / valid_units, total_y / valid_units)
end
-- }}}

-- {{{ FormationSystem:adapt_formation_to_terrain
function FormationSystem:adapt_formation_to_terrain(formation)
    if not self.lane_system then
        return
    end
    
    -- Get the sub-path for the formation leader
    local leader_position = self.entity_manager:get_component(formation.leader, "position")
    if not leader_position then
        return
    end
    
    local sub_path = self.lane_system:get_sub_path_at_position(leader_position.x, leader_position.y)
    if not sub_path then
        return
    end
    
    -- Check if formation fits within sub-path width
    local formation_width = self:calculate_formation_width(formation)
    local path_width = sub_path.width or 50
    
    if formation_width > path_width * self.terrain_adaptation_factor then
        -- Compress formation laterally
        local compression_ratio = (path_width * self.terrain_adaptation_factor) / formation_width
        formation.spacing_scale = formation.spacing_scale * compression_ratio
        
        debug.log("Adapted formation " .. formation.id .. " to terrain (compression: " .. compression_ratio .. ")", "FORMATION")
    end
    
    -- Handle path curvature
    local path_curvature = self:calculate_path_curvature(sub_path)
    if path_curvature > 0.1 then  -- Significant curve
        self:adjust_formation_for_curve(formation, path_curvature)
    end
end
-- }}}

-- {{{ FormationSystem:calculate_formation_width
function FormationSystem:calculate_formation_width(formation)
    if #formation.units == 0 then
        return 0
    end
    
    local min_x, max_x = math.huge, -math.huge
    
    for unit_id, ideal_position in pairs(formation.formation_positions) do
        min_x = math.min(min_x, ideal_position.x)
        max_x = math.max(max_x, ideal_position.x)
    end
    
    return max_x - min_x
end
-- }}}

-- {{{ FormationSystem:calculate_path_curvature
function FormationSystem:calculate_path_curvature(sub_path)
    -- Simple curvature calculation based on path direction changes
    if not sub_path.center_line or #sub_path.center_line < 3 then
        return 0
    end
    
    local center_line = sub_path.center_line
    local total_angle_change = 0
    
    for i = 2, #center_line - 1 do
        local v1 = center_line[i]:subtract(center_line[i-1])
        local v2 = center_line[i+1]:subtract(center_line[i])
        
        if v1:length() > 0 and v2:length() > 0 then
            local angle_change = math.abs(math.atan2(v2.y, v2.x) - math.atan2(v1.y, v1.x))
            total_angle_change = total_angle_change + angle_change
        end
    end
    
    return total_angle_change / (#center_line - 2)
end
-- }}}

-- {{{ FormationSystem:adjust_formation_for_curve
function FormationSystem:adjust_formation_for_curve(formation, curvature)
    -- Adjust formation spacing and positioning for curved paths
    local curve_factor = math.min(curvature / 0.5, 1.0)  -- Normalize curvature
    
    -- Reduce lateral spacing for tighter curves
    formation.spacing_scale = formation.spacing_scale * (1.0 - curve_factor * 0.3)
    
    -- Increase formation flexibility for curves
    if formation.template.flexibility then
        formation.template.flexibility = math.min(1.0, formation.template.flexibility + curve_factor * 0.2)
    end
    
    debug.log("Adjusted formation " .. formation.id .. " for curve (curvature: " .. curvature .. ")", "FORMATION")
end
-- }}}

-- {{{ FormationSystem:preserve_formation_structure
function FormationSystem:preserve_formation_structure(formation, obstacle_positions)
    -- Temporarily adjust formation to navigate around obstacles while maintaining structure
    if not obstacle_positions or #obstacle_positions == 0 then
        return
    end
    
    local formation_center = self:calculate_formation_center(formation)
    local avoidance_adjustments = {}
    
    for _, obstacle_pos in ipairs(obstacle_positions) do
        local distance_to_obstacle = formation_center:distance_to(obstacle_pos)
        
        if distance_to_obstacle < 40 then  -- Within obstacle avoidance range
            -- Calculate avoidance direction
            local avoidance_direction = formation_center:subtract(obstacle_pos):normalize()
            
            -- Apply temporary position adjustments to formation
            for _, unit in ipairs(formation.units) do
                local unit_ideal = formation.formation_positions[unit.id]
                if unit_ideal then
                    local unit_distance = unit_ideal:distance_to(obstacle_pos)
                    if unit_distance < 25 then  -- Unit is close to obstacle
                        local adjustment = avoidance_direction:multiply(25 - unit_distance)
                        avoidance_adjustments[unit.id] = adjustment
                    end
                end
            end
        end
    end
    
    -- Apply temporary adjustments
    for unit_id, adjustment in pairs(avoidance_adjustments) do
        if formation.formation_positions[unit_id] then
            formation.formation_positions[unit_id] = formation.formation_positions[unit_id]:add(adjustment)
        end
    end
end
-- }}}

-- {{{ FormationSystem:get_debug_info
function FormationSystem:get_debug_info()
    local total_formations = 0
    local total_units_in_formation = 0
    local formation_health_sum = 0
    
    for _, formation in pairs(self.formations) do
        total_formations = total_formations + 1
        total_units_in_formation = total_units_in_formation + #formation.units
        formation_health_sum = formation_health_sum + formation.formation_health
    end
    
    return {
        total_formations = total_formations,
        total_units_in_formation = total_units_in_formation,
        average_formation_health = total_formations > 0 and (formation_health_sum / total_formations) or 0,
        formation_strength = self.formation_strength,
        cohesion_strength = self.cohesion_strength,
        preservation_priority = self.preservation_priority,
        available_formation_types = {"line", "column", "wedge", "box", "spread"}
    }
end
-- }}}

return FormationSystem
-- }}}