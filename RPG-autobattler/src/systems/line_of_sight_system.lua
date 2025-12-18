-- Line-of-Sight System
-- Handles line-of-sight calculations, obstacle detection, partial cover,
-- and target visibility for ranged combat

local LineOfSightSystem = {}

-- Module requires
local Vector2 = require("src.utils.vector2")
local Colors = require("src.config.colors")
local Debug = require("src.utils.debug")

-- System state
local los_cache = {}
local cache_duration = 0.1  -- Cache results for 100ms

-- {{{ local function check_line_of_sight
local function check_line_of_sight(from_unit_id, to_unit_id)
    local from_pos = EntityManager:get_component(from_unit_id, "position")
    local to_pos = EntityManager:get_component(to_unit_id, "position")
    
    if not from_pos or not to_pos then
        return false
    end
    
    local start_position = Vector2:new(from_pos.x, from_pos.y)
    local end_position = Vector2:new(to_pos.x, to_pos.y)
    
    -- Perform line-of-sight raycast
    local los_result = perform_los_raycast(from_unit_id, to_unit_id, start_position, end_position)
    
    return los_result.clear_line_of_sight
end
-- }}}

-- {{{ local function perform_los_raycast
local function perform_los_raycast(from_unit_id, to_unit_id, start_pos, end_pos)
    -- Check cache first
    local cache_key = from_unit_id .. "_" .. to_unit_id
    local current_time = love.timer.getTime()
    
    if los_cache[cache_key] and current_time - los_cache[cache_key].timestamp < cache_duration then
        return los_cache[cache_key].result
    end
    
    local los_result = {
        clear_line_of_sight = true,
        blocked_by = nil,
        blocking_position = nil,
        partial_cover = false,
        cover_percentage = 0
    }
    
    local direction = end_pos:subtract(start_pos)
    local total_distance = direction:length()
    
    if total_distance == 0 then
        return los_result
    end
    
    direction = direction:normalize()
    
    -- Raycast parameters
    local step_size = 2  -- Check every 2 units along the ray
    local num_steps = math.ceil(total_distance / step_size)
    
    for i = 1, num_steps do
        local step_distance = math.min(i * step_size, total_distance)
        local check_position = start_pos:add(direction:multiply(step_distance))
        
        -- Check for blocking objects at this position
        local blocking_object = check_position_for_obstacles(check_position, from_unit_id, to_unit_id)
        
        if blocking_object then
            los_result.clear_line_of_sight = false
            los_result.blocked_by = blocking_object
            los_result.blocking_position = check_position
            
            -- Calculate partial cover
            local cover_info = calculate_cover_amount(start_pos, end_pos, check_position, blocking_object)
            los_result.partial_cover = cover_info.partial
            los_result.cover_percentage = cover_info.percentage
            
            break
        end
    end
    
    -- Cache the result
    los_cache[cache_key] = {
        result = los_result,
        timestamp = current_time
    }
    
    return los_result
end
-- }}}

-- {{{ local function check_position_for_obstacles
local function check_position_for_obstacles(position, from_unit_id, to_unit_id)
    -- Check for units that might block line of sight
    local blocking_unit = check_units_blocking_position(position, from_unit_id, to_unit_id)
    if blocking_unit then
        return {type = "unit", id = blocking_unit}
    end
    
    -- Check for terrain obstacles
    local terrain_obstacle = check_terrain_blocking_position(position)
    if terrain_obstacle then
        return {type = "terrain", id = terrain_obstacle}
    end
    
    -- Check for lane boundaries (walls/barriers)
    local boundary_obstacle = check_boundary_blocking_position(position, from_unit_id)
    if boundary_obstacle then
        return {type = "boundary", id = boundary_obstacle}
    end
    
    return nil
end
-- }}}

-- {{{ local function check_units_blocking_position
local function check_units_blocking_position(position, from_unit_id, to_unit_id)
    local blocking_radius = 8  -- How close to a unit blocks LOS
    local nearby_units = get_units_near_position(position, blocking_radius)
    
    for _, unit_id in ipairs(nearby_units) do
        if unit_id ~= from_unit_id and unit_id ~= to_unit_id then
            local unit_pos = EntityManager:get_component(unit_id, "position")
            local unit_data = EntityManager:get_component(unit_id, "unit")
            local unit_health = EntityManager:get_component(unit_id, "health")
            
            if unit_pos and unit_data and unit_health and unit_health.is_alive then
                local unit_position = Vector2:new(unit_pos.x, unit_pos.y)
                local distance = position:distance_to(unit_position)
                
                -- Check if unit is large enough to block LOS
                local unit_size = unit_data.size or 8
                if distance <= unit_size / 2 then
                    return unit_id
                end
            end
        end
    end
    
    return nil
end
-- }}}

-- {{{ local function check_terrain_blocking_position
local function check_terrain_blocking_position(position)
    -- Check for terrain features that block line of sight
    -- This would integrate with terrain/obstacle system when implemented
    
    -- For now, check basic collision areas
    local terrain_obstacles = get_terrain_obstacles_at_position(position)
    
    for _, obstacle in ipairs(terrain_obstacles) do
        if obstacle.blocks_line_of_sight then
            return obstacle.id
        end
    end
    
    return nil
end
-- }}}

-- {{{ local function get_terrain_obstacles_at_position
local function get_terrain_obstacles_at_position(position)
    -- Placeholder for terrain system integration
    -- Returns empty for now since terrain obstacles aren't implemented yet
    return {}
end
-- }}}

-- {{{ local function check_boundary_blocking_position
local function check_boundary_blocking_position(position, from_unit_id)
    local from_pos = EntityManager:get_component(from_unit_id, "position")
    
    if not from_pos then
        return nil
    end
    
    -- Check if position is outside the unit's sub-path (indicating wall/boundary)
    local sub_path = LaneSystem:get_sub_path(from_pos.sub_path_id)
    
    if sub_path then
        local in_bounds = CollisionSystem:check_unit_in_bounds({position = position}, sub_path)
        if not in_bounds then
            return "lane_boundary"
        end
    end
    
    return nil
end
-- }}}

-- {{{ local function get_units_near_position
local function get_units_near_position(position, search_radius)
    local nearby_units = {}
    local all_units = EntityManager:get_entities_with_component("position")
    
    for _, unit_id in ipairs(all_units) do
        local unit_pos = EntityManager:get_component(unit_id, "position")
        if unit_pos then
            local unit_position = Vector2:new(unit_pos.x, unit_pos.y)
            local distance = position:distance_to(unit_position)
            
            if distance <= search_radius then
                table.insert(nearby_units, unit_id)
            end
        end
    end
    
    return nearby_units
end
-- }}}

-- {{{ local function calculate_cover_amount
local function calculate_cover_amount(start_pos, end_pos, blocking_pos, blocking_object)
    local cover_info = {
        partial = false,
        percentage = 0
    }
    
    if blocking_object.type == "unit" then
        -- Calculate how much of the target is obscured by the blocking unit
        local blocking_unit_data = EntityManager:get_component(blocking_object.id, "unit")
        
        if blocking_unit_data then
            local blocking_size = blocking_unit_data.size or 8
            local distance_to_blocker = start_pos:distance_to(blocking_pos)
            local total_distance = start_pos:distance_to(end_pos)
            
            -- Calculate angular coverage
            local angular_size = math.atan(blocking_size / distance_to_blocker)
            local max_angular_size = math.pi / 4  -- 45 degrees max coverage
            
            cover_info.percentage = math.min(1.0, angular_size / max_angular_size)
            cover_info.partial = cover_info.percentage < 0.8  -- Less than 80% = partial cover
        end
    elseif blocking_object.type == "terrain" then
        -- Terrain usually provides full cover
        cover_info.percentage = 1.0
        cover_info.partial = false
    elseif blocking_object.type == "boundary" then
        -- Boundaries provide full cover
        cover_info.percentage = 1.0
        cover_info.partial = false
    end
    
    return cover_info
end
-- }}}

-- {{{ local function find_targets_with_line_of_sight
local function find_targets_with_line_of_sight(unit_id, max_range)
    local position = EntityManager:get_component(unit_id, "position")
    local team = EntityManager:get_component(unit_id, "team")
    
    if not position or not team then
        return {}
    end
    
    -- Get all potential targets in range
    local potential_targets = find_enemy_units_in_range(unit_id, max_range)
    local valid_targets = {}
    
    for _, target in ipairs(potential_targets) do
        local los_result = perform_los_raycast(
            unit_id, target.unit_id,
            Vector2:new(position.x, position.y),
            target.position
        )
        
        if los_result.clear_line_of_sight then
            -- Clear line of sight
            target.los_quality = "clear"
            target.cover_percentage = 0
            table.insert(valid_targets, target)
            
        elseif los_result.partial_cover then
            -- Partial cover - still can target but with penalty
            target.los_quality = "partial"
            target.cover_percentage = los_result.cover_percentage
            table.insert(valid_targets, target)
        end
        
        -- Units with full cover are not added to valid targets
    end
    
    return valid_targets
end
-- }}}

-- {{{ local function apply_los_targeting_penalties
local function apply_los_targeting_penalties(attacker_id, target_id, base_accuracy)
    local los_result = perform_los_raycast(
        attacker_id, target_id,
        get_unit_position(attacker_id),
        get_unit_position(target_id)
    )
    
    local final_accuracy = base_accuracy
    
    if los_result.partial_cover then
        -- Apply cover penalty
        local cover_penalty = los_result.cover_percentage * 0.4  -- Up to 40% penalty
        final_accuracy = final_accuracy * (1 - cover_penalty)
    end
    
    return final_accuracy
end
-- }}}

-- {{{ local function update_target_visibility
local function update_target_visibility(unit_id)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not unit_data or unit_data.unit_type ~= "ranged" then
        return
    end
    
    -- Check current target visibility
    if unit_data.combat_target then
        local target_visible = check_line_of_sight(unit_id, unit_data.combat_target)
        
        if not target_visible then
            -- Current target is no longer visible, look for new target
            search_for_visible_target(unit_id)
        end
    else
        -- No current target, search for visible targets
        search_for_visible_target(unit_id)
    end
end
-- }}}

-- {{{ local function search_for_visible_target
local function search_for_visible_target(unit_id)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not unit_data then
        return
    end
    
    local detection_range = get_unit_detection_range(unit_data)
    local visible_targets = find_targets_with_line_of_sight(unit_id, detection_range)
    
    if #visible_targets > 0 then
        -- Select best visible target
        local best_target = select_best_visible_target(unit_id, visible_targets)
        
        if best_target then
            unit_data.combat_target = best_target.unit_id
            
            -- Initiate combat if not already in combat
            if unit_data.state ~= "combat" then
                initiate_combat_engagement(unit_id, best_target.unit_id)
            end
        end
    else
        -- No visible targets, clear current target
        unit_data.combat_target = nil
        
        if unit_data.state == "combat" then
            unit_data.state = "moving"
        end
    end
end
-- }}}

-- {{{ local function get_unit_detection_range
local function get_unit_detection_range(unit_data)
    if unit_data.unit_type == "ranged" then
        return 45  -- Ranged units have longer detection range
    else
        return 25  -- Melee units have shorter detection range
    end
end
-- }}}

-- {{{ local function select_best_visible_target
local function select_best_visible_target(unit_id, visible_targets)
    local best_target = nil
    local best_score = -1
    
    for _, target in ipairs(visible_targets) do
        local score = calculate_target_visibility_score(unit_id, target)
        
        if score > best_score then
            best_score = score
            best_target = target
        end
    end
    
    return best_target
end
-- }}}

-- {{{ local function calculate_target_visibility_score
local function calculate_target_visibility_score(unit_id, target)
    local score = 0
    
    -- Distance factor (closer is better)
    local distance_factor = math.max(0, 1 - (target.distance / 50))
    score = score + distance_factor * 30
    
    -- Line of sight quality factor
    if target.los_quality == "clear" then
        score = score + 40
    elseif target.los_quality == "partial" then
        score = score + 20 * (1 - target.cover_percentage)
    end
    
    -- Target type preference
    local target_unit_data = EntityManager:get_component(target.unit_id, "unit")
    if target_unit_data then
        if target_unit_data.unit_type == "ranged" then
            score = score + 15  -- Prefer ranged targets
        end
    end
    
    -- Health factor (prefer weakened enemies)
    local target_health = EntityManager:get_component(target.unit_id, "health")
    if target_health then
        local health_ratio = target_health.current / target_health.maximum
        score = score + (1 - health_ratio) * 10
    end
    
    return score
end
-- }}}

-- {{{ local function create_los_debug_visualization
local function create_los_debug_visualization(from_unit_id, to_unit_id, los_result)
    local from_pos = EntityManager:get_component(from_unit_id, "position")
    local to_pos = EntityManager:get_component(to_unit_id, "position")
    
    if not from_pos or not to_pos then
        return
    end
    
    local start_position = Vector2:new(from_pos.x, from_pos.y)
    local end_position = Vector2:new(to_pos.x, to_pos.y)
    
    local line_color = los_result.clear_line_of_sight and Colors.GREEN or Colors.RED
    
    local debug_effect = {
        type = "los_debug_line",
        start_position = start_position,
        end_position = end_position,
        color = line_color,
        duration = 1.0,
        start_time = love.timer.getTime(),
        blocked_position = los_result.blocking_position
    }
    
    EffectSystem:add_effect(debug_effect)
end
-- }}}

-- {{{ local function get_unit_position
local function get_unit_position(unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    
    if position then
        return Vector2:new(position.x, position.y)
    end
    
    return Vector2:new(0, 0)
end
-- }}}

-- {{{ local function clear_los_cache
local function clear_los_cache()
    los_cache = {}
end
-- }}}

-- {{{ local function update_los_system
local function update_los_system(dt)
    -- Update visibility for all ranged units
    local all_units = EntityManager:get_entities_with_component("unit")
    
    for _, unit_id in ipairs(all_units) do
        local unit_data = EntityManager:get_component(unit_id, "unit")
        if unit_data and unit_data.unit_type == "ranged" then
            update_target_visibility(unit_id)
        end
    end
    
    -- Clean old cache entries periodically
    local current_time = love.timer.getTime()
    if math.random() < 0.01 then  -- 1% chance per frame
        clean_old_cache_entries(current_time)
    end
end
-- }}}

-- {{{ local function clean_old_cache_entries
local function clean_old_cache_entries(current_time)
    local entries_to_remove = {}
    
    for key, entry in pairs(los_cache) do
        if current_time - entry.timestamp > cache_duration * 2 then
            table.insert(entries_to_remove, key)
        end
    end
    
    for _, key in ipairs(entries_to_remove) do
        los_cache[key] = nil
    end
end
-- }}}

-- Public API
function LineOfSightSystem:update(dt)
    update_los_system(dt)
end

function LineOfSightSystem:check_line_of_sight(from_unit_id, to_unit_id)
    return check_line_of_sight(from_unit_id, to_unit_id)
end

function LineOfSightSystem:get_los_result(from_unit_id, to_unit_id)
    local from_pos = get_unit_position(from_unit_id)
    local to_pos = get_unit_position(to_unit_id)
    return perform_los_raycast(from_unit_id, to_unit_id, from_pos, to_pos)
end

function LineOfSightSystem:find_visible_targets(unit_id, max_range)
    return find_targets_with_line_of_sight(unit_id, max_range)
end

function LineOfSightSystem:apply_cover_penalty(attacker_id, target_id, base_accuracy)
    return apply_los_targeting_penalties(attacker_id, target_id, base_accuracy)
end

function LineOfSightSystem:debug_visualize_los(from_unit_id, to_unit_id)
    local los_result = self:get_los_result(from_unit_id, to_unit_id)
    create_los_debug_visualization(from_unit_id, to_unit_id, los_result)
end

function LineOfSightSystem:clear_cache()
    clear_los_cache()
end

return LineOfSightSystem