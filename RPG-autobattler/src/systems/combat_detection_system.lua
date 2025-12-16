-- {{{ CombatDetectionSystem
local CombatDetectionSystem = {}

local Vector2 = require("src.utils.vector2")
local MathUtils = require("src.utils.math_utils")
local Unit = require("src.entities.unit")
local debug = require("src.utils.debug")

-- {{{ CombatDetectionSystem:new
function CombatDetectionSystem:new(entity_manager)
    local system = {
        entity_manager = entity_manager,
        name = "combat_detection",
        
        -- Detection parameters
        detection_ranges = {
            melee = 20,      -- Melee units detect enemies at close range
            ranged = 35,     -- Ranged units detect enemies at longer range
            tank = 25,       -- Tanks have medium detection range
            support = 30,    -- Support units detect at medium-long range
            special = 28     -- Special units have medium range
        },
        
        -- Engagement parameters
        engagement_ranges = {
            melee = 12,      -- Must be very close to engage
            ranged = 30,     -- Can engage at distance
            tank = 15,       -- Slightly longer than melee
            support = 25,    -- Support range
            special = 20     -- Medium engagement range
        },
        
        -- Combat state tracking
        combat_engagements = {},      -- Active combat pairs
        target_assignments = {},      -- Maps unit ID to target unit ID
        threat_assessments = {},      -- Cached threat calculations
        
        -- Spatial optimization
        spatial_grid_size = 40,
        spatial_grid = {},
        
        -- Behavior settings
        prefer_weak_targets = true,   -- Prefer targeting damaged enemies
        maintain_engagement = true,   -- Continue fighting same target
        allow_target_switching = true, -- Switch to better targets when available
        threat_memory_duration = 2.0, -- How long to remember threats
        
        -- Enhanced detection features
        multi_lane_detection = true,  -- Detect enemies in adjacent lanes
        formation_priority = true,    -- Prioritize based on formation position
        engagement_effects = true,    -- Create visual engagement effects
        
        -- Update frequency
        update_frequency = 1/20,      -- Update detection 20 times per second
        last_update = 0
    }
    setmetatable(system, {__index = CombatDetectionSystem})
    
    debug.log("CombatDetectionSystem created", "COMBAT_DETECTION")
    return system
end
-- }}}

-- {{{ CombatDetectionSystem:update
function CombatDetectionSystem:update(dt)
    self.last_update = self.last_update + dt
    
    if self.last_update < self.update_frequency then
        return
    end
    
    -- Update spatial grid for optimization
    self:update_spatial_grid()
    
    -- Get all combat-capable units
    local units = self.entity_manager:get_entities_with_components({
        "position", "health", "team", "unit_data"
    })
    
    -- Process detection and engagement for each unit
    for _, unit in ipairs(units) do
        if Unit.is_alive(self.entity_manager, unit) then
            self:process_unit_detection(unit, self.last_update)
        end
    end
    
    -- Clean up old threat assessments
    self:cleanup_old_threats(self.last_update)
    
    -- Validate existing engagements
    self:validate_engagements()
    
    -- Update engagement effects
    self:update_engagement_effects(self.last_update)
    
    self.last_update = 0
end
-- }}}

-- {{{ CombatDetectionSystem:update_spatial_grid
function CombatDetectionSystem:update_spatial_grid()
    self.spatial_grid = {}
    
    local units = self.entity_manager:get_entities_with_components({
        "position", "health", "team", "unit_data"
    })
    
    for _, unit in ipairs(units) do
        if Unit.is_alive(self.entity_manager, unit) then
            local position = self.entity_manager:get_component(unit, "position")
            if position then
                local grid_x = math.floor(position.x / self.spatial_grid_size)
                local grid_y = math.floor(position.y / self.spatial_grid_size)
                local grid_key = grid_x .. "," .. grid_y
                
                if not self.spatial_grid[grid_key] then
                    self.spatial_grid[grid_key] = {}
                end
                
                table.insert(self.spatial_grid[grid_key], unit)
            end
        end
    end
end
-- }}}

-- {{{ CombatDetectionSystem:process_unit_detection
function CombatDetectionSystem:process_unit_detection(unit, current_time)
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    local position = self.entity_manager:get_component(unit, "position")
    local team = self.entity_manager:get_component(unit, "team")
    
    if not unit_data or not position or not team then
        return
    end
    
    -- Get unit's detection range
    local detection_range = self.detection_ranges[unit_data.unit_type] or self.detection_ranges.melee
    
    -- Find potential targets
    local potential_targets = self:find_potential_targets(unit, position, detection_range)
    
    -- Current target (if any)
    local current_target_id = self.target_assignments[unit.id]
    local current_target = current_target_id and self.entity_manager:get_entity_by_id(current_target_id) or nil
    
    -- Evaluate and select best target
    local best_target = self:select_best_target(unit, potential_targets, current_target, current_time)
    
    -- Update engagement state
    if best_target then
        self:engage_target(unit, best_target, current_time)
    else
        self:disengage_unit(unit, current_time)
    end
end
-- }}}

-- {{{ CombatDetectionSystem:find_potential_targets
function CombatDetectionSystem:find_potential_targets(unit, position, detection_range)
    local team = self.entity_manager:get_component(unit, "team")
    local unit_pos = Vector2:new(position.x, position.y)
    local potential_targets = {}
    
    if not team then
        return potential_targets
    end
    
    -- Get units from nearby grid cells
    local grid_x = math.floor(position.x / self.spatial_grid_size)
    local grid_y = math.floor(position.y / self.spatial_grid_size)
    local search_radius = math.ceil(detection_range / self.spatial_grid_size)
    
    for dx = -search_radius, search_radius do
        for dy = -search_radius, search_radius do
            local check_x = grid_x + dx
            local check_y = grid_y + dy
            local grid_key = check_x .. "," .. check_y
            
            if self.spatial_grid[grid_key] then
                for _, other_unit in ipairs(self.spatial_grid[grid_key]) do
                    if other_unit.id ~= unit.id and Unit.is_alive(self.entity_manager, other_unit) then
                        local other_team = self.entity_manager:get_component(other_unit, "team")
                        local other_position = self.entity_manager:get_component(other_unit, "position")
                        
                        if other_team and other_position and Unit.are_enemies(self.entity_manager, unit, other_unit) then
                            local other_pos = Vector2:new(other_position.x, other_position.y)
                            local distance = unit_pos:distance_to(other_pos)
                            
                            if distance <= detection_range then
                                table.insert(potential_targets, {
                                    unit = other_unit,
                                    position = other_pos,
                                    distance = distance,
                                    last_seen = love.timer.getTime()
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    
    return potential_targets
end
-- }}}

-- {{{ CombatDetectionSystem:select_best_target
function CombatDetectionSystem:select_best_target(unit, potential_targets, current_target, current_time)
    if #potential_targets == 0 then
        return nil
    end
    
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    if not unit_data then
        return nil
    end
    
    -- If we have a current target and should maintain engagement
    if current_target and self.maintain_engagement and Unit.is_alive(self.entity_manager, current_target) then
        -- Check if current target is still in range
        for _, target_data in ipairs(potential_targets) do
            if target_data.unit.id == current_target.id then
                local engagement_range = self.engagement_ranges[unit_data.unit_type] or self.engagement_ranges.melee
                if target_data.distance <= engagement_range then
                    return current_target
                end
            end
        end
    end
    
    -- Evaluate all potential targets
    local best_target = nil
    local best_score = -1
    
    for _, target_data in ipairs(potential_targets) do
        local score = self:calculate_target_priority(unit, target_data, current_time)
        if score > best_score then
            best_score = score
            best_target = target_data.unit
        end
    end
    
    return best_target
end
-- }}}

-- {{{ CombatDetectionSystem:calculate_target_priority
function CombatDetectionSystem:calculate_target_priority(unit, target_data, current_time)
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    local target_health = self.entity_manager:get_component(target_data.unit, "health")
    local target_unit_data = self.entity_manager:get_component(target_data.unit, "unit_data")
    
    if not unit_data or not target_health or not target_unit_data then
        return 0
    end
    
    local score = 100  -- Base score
    
    -- Distance factor (closer is better)
    local engagement_range = self.engagement_ranges[unit_data.unit_type] or self.engagement_ranges.melee
    local distance_factor = 1.0 - (target_data.distance / (engagement_range * 2))
    score = score * math.max(0.1, distance_factor)
    
    -- Health factor (prefer weak targets if enabled)
    if self.prefer_weak_targets then
        local health_ratio = target_health.current_hp / target_health.max_hp
        local weakness_factor = 1.5 - health_ratio  -- Lower health = higher priority
        score = score * weakness_factor
    end
    
    -- Unit type matchup bonuses
    score = score * self:get_unit_matchup_modifier(unit_data.unit_type, target_unit_data.unit_type)
    
    -- Threat level consideration
    local threat_level = self:assess_threat_level(target_data.unit, current_time)
    score = score * (1.0 + threat_level * 0.3)
    
    -- Formation priority bonus (if enabled)
    if self.formation_priority then
        local formation_bonus = self:calculate_formation_priority_bonus(target_data.unit)
        score = score * (1.0 + formation_bonus * 0.2)
    end
    
    -- Current engagement bonus (slight preference for maintaining target)
    local current_target_id = self.target_assignments[unit.id]
    if current_target_id == target_data.unit.id then
        score = score * 1.1
    end
    
    return score
end
-- }}}

-- {{{ CombatDetectionSystem:get_unit_matchup_modifier
function CombatDetectionSystem:get_unit_matchup_modifier(attacker_type, target_type)
    -- Define rock-paper-scissors style matchups
    local matchups = {
        melee = {
            ranged = 1.3,    -- Melee is good vs ranged
            support = 1.2,   -- Melee is good vs support
            tank = 0.8,      -- Melee struggles vs tank
            melee = 1.0,     -- Even matchup
            special = 1.0
        },
        ranged = {
            tank = 1.2,      -- Ranged is good vs tank
            melee = 0.9,     -- Ranged struggles vs melee
            support = 1.1,   -- Ranged is decent vs support
            ranged = 1.0,    -- Even matchup
            special = 1.0
        },
        tank = {
            melee = 1.2,     -- Tank is good vs melee
            ranged = 0.9,    -- Tank struggles vs ranged
            support = 1.1,   -- Tank is decent vs support
            tank = 1.0,      -- Even matchup
            special = 1.0
        },
        support = {
            tank = 1.1,      -- Support is decent vs tank
            melee = 0.8,     -- Support struggles vs melee
            ranged = 0.9,    -- Support struggles vs ranged
            support = 1.0,   -- Even matchup
            special = 1.0
        },
        special = {
            melee = 1.1,     -- Special is decent vs all
            ranged = 1.1,
            tank = 1.1,
            support = 1.1,
            special = 1.0
        }
    }
    
    return matchups[attacker_type] and matchups[attacker_type][target_type] or 1.0
end
-- }}}

-- {{{ CombatDetectionSystem:assess_threat_level
function CombatDetectionSystem:assess_threat_level(target_unit, current_time)
    local threat_key = target_unit.id
    local cached_threat = self.threat_assessments[threat_key]
    
    -- Use cached threat if recent
    if cached_threat and (current_time - cached_threat.timestamp) < 1.0 then
        return cached_threat.level
    end
    
    -- Calculate new threat level
    local target_health = self.entity_manager:get_component(target_unit, "health")
    local target_unit_data = self.entity_manager:get_component(target_unit, "unit_data")
    
    if not target_health or not target_unit_data then
        return 0
    end
    
    local threat_level = 0.5  -- Base threat
    
    -- Health contributes to threat
    local health_ratio = target_health.current_hp / target_health.max_hp
    threat_level = threat_level + health_ratio * 0.3
    
    -- Unit type threat modifiers
    local type_threats = {
        melee = 0.7,
        ranged = 0.8,
        tank = 0.6,
        support = 0.4,
        special = 0.9
    }
    threat_level = threat_level * (type_threats[target_unit_data.unit_type] or 0.5)
    
    -- Cache the result
    self.threat_assessments[threat_key] = {
        level = threat_level,
        timestamp = current_time
    }
    
    return threat_level
end
-- }}}

-- {{{ CombatDetectionSystem:engage_target
function CombatDetectionSystem:engage_target(unit, target, current_time)
    -- Update target assignment
    local old_target_id = self.target_assignments[unit.id]
    self.target_assignments[unit.id] = target.id
    
    -- Update unit combat state
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    if unit_data then
        unit_data.combat_state = "engaging"
        unit_data.target_unit_id = target.id
        unit_data.last_engagement_time = current_time
    end
    
    -- Create combat engagement record
    local engagement_key = unit.id .. "->" .. target.id
    self.combat_engagements[engagement_key] = {
        attacker = unit,
        target = target,
        start_time = current_time,
        last_update = current_time
    }
    
    -- Log target change if different
    if old_target_id ~= target.id then
        debug.log("Unit " .. unit.name .. " engaging new target " .. target.name, "COMBAT_DETECTION")
    end
end
-- }}}

-- {{{ CombatDetectionSystem:disengage_unit
function CombatDetectionSystem:disengage_unit(unit, current_time)
    local old_target_id = self.target_assignments[unit.id]
    
    if old_target_id then
        -- Clear target assignment
        self.target_assignments[unit.id] = nil
        
        -- Update unit combat state
        local unit_data = self.entity_manager:get_component(unit, "unit_data")
        if unit_data then
            unit_data.combat_state = "idle"
            unit_data.target_unit_id = nil
            unit_data.last_disengagement_time = current_time
        end
        
        -- Remove combat engagement record
        local engagement_key = unit.id .. "->" .. old_target_id
        self.combat_engagements[engagement_key] = nil
        
        debug.log("Unit " .. unit.name .. " disengaged from combat", "COMBAT_DETECTION")
    end
end
-- }}}

-- {{{ CombatDetectionSystem:cleanup_old_threats
function CombatDetectionSystem:cleanup_old_threats(current_time)
    local threats_to_remove = {}
    
    for threat_key, threat_data in pairs(self.threat_assessments) do
        if (current_time - threat_data.timestamp) > self.threat_memory_duration then
            table.insert(threats_to_remove, threat_key)
        end
    end
    
    for _, threat_key in ipairs(threats_to_remove) do
        self.threat_assessments[threat_key] = nil
    end
end
-- }}}

-- {{{ CombatDetectionSystem:validate_engagements
function CombatDetectionSystem:validate_engagements()
    local invalid_engagements = {}
    
    for engagement_key, engagement in pairs(self.combat_engagements) do
        -- Check if both units are still alive
        if not Unit.is_alive(self.entity_manager, engagement.attacker) or
           not Unit.is_alive(self.entity_manager, engagement.target) then
            table.insert(invalid_engagements, engagement_key)
        end
    end
    
    for _, engagement_key in ipairs(invalid_engagements) do
        self.combat_engagements[engagement_key] = nil
    end
end
-- }}}

-- {{{ CombatDetectionSystem:get_unit_target
function CombatDetectionSystem:get_unit_target(unit)
    local target_id = self.target_assignments[unit.id]
    return target_id and self.entity_manager:get_entity_by_id(target_id) or nil
end
-- }}}

-- {{{ CombatDetectionSystem:is_unit_in_combat
function CombatDetectionSystem:is_unit_in_combat(unit)
    return self.target_assignments[unit.id] ~= nil
end
-- }}}

-- {{{ CombatDetectionSystem:force_disengage
function CombatDetectionSystem:force_disengage(unit)
    self:disengage_unit(unit, love.timer.getTime())
end
-- }}}

-- {{{ CombatDetectionSystem:get_units_targeting
function CombatDetectionSystem:get_units_targeting(target_unit)
    local attackers = {}
    
    for unit_id, target_id in pairs(self.target_assignments) do
        if target_id == target_unit.id then
            local attacker = self.entity_manager:get_entity_by_id(unit_id)
            if attacker and Unit.is_alive(self.entity_manager, attacker) then
                table.insert(attackers, attacker)
            end
        end
    end
    
    return attackers
end
-- }}}

-- {{{ CombatDetectionSystem:set_detection_parameters
function CombatDetectionSystem:set_detection_parameters(unit_type, detection_range, engagement_range)
    if self.detection_ranges[unit_type] then
        self.detection_ranges[unit_type] = detection_range
        self.engagement_ranges[unit_type] = engagement_range
        debug.log("Updated detection parameters for " .. unit_type, "COMBAT_DETECTION")
    end
end
-- }}}

-- {{{ CombatDetectionSystem:calculate_formation_priority_bonus
function CombatDetectionSystem:calculate_formation_priority_bonus(target_unit)
    local formation_bonus = 0
    
    -- Check if target is part of a formation
    local target_unit_data = self.entity_manager:get_component(target_unit, "unit_data")
    if target_unit_data and target_unit_data.formation_id then
        -- Get formation information from formation system
        -- This would need to be integrated with the actual formation system
        local formation_position = target_unit_data.formation_position or 0
        
        -- Front-line units get higher priority
        if formation_position <= 3 then
            formation_bonus = 0.3  -- 30% bonus for front-line units
        elseif formation_position <= 6 then
            formation_bonus = 0.1  -- 10% bonus for mid-line units
        else
            formation_bonus = 0.0  -- No bonus for back-line units
        end
        
        -- Leaders get additional priority
        if target_unit_data.formation_role == "leader" then
            formation_bonus = formation_bonus + 0.2
        end
    end
    
    return formation_bonus
end
-- }}}

-- {{{ CombatDetectionSystem:find_multi_lane_targets
function CombatDetectionSystem:find_multi_lane_targets(unit, position, detection_range)
    if not self.multi_lane_detection then
        return {}
    end
    
    local team = self.entity_manager:get_component(unit, "team")
    local unit_pos = Vector2:new(position.x, position.y)
    local multi_lane_targets = {}
    
    if not team then
        return multi_lane_targets
    end
    
    -- This would integrate with the lane system to find adjacent/intersecting lanes
    -- For now, using a simplified approach with spatial grid
    local extended_range = detection_range * 1.2  -- Slightly extended range for multi-lane
    local grid_x = math.floor(position.x / self.spatial_grid_size)
    local grid_y = math.floor(position.y / self.spatial_grid_size)
    local search_radius = math.ceil(extended_range / self.spatial_grid_size)
    
    for dx = -search_radius, search_radius do
        for dy = -search_radius, search_radius do
            local check_x = grid_x + dx
            local check_y = grid_y + dy
            local grid_key = check_x .. "," .. check_y
            
            if self.spatial_grid[grid_key] then
                for _, other_unit in ipairs(self.spatial_grid[grid_key]) do
                    if other_unit.id ~= unit.id and Unit.is_alive(self.entity_manager, other_unit) then
                        local other_team = self.entity_manager:get_component(other_unit, "team")
                        local other_position = self.entity_manager:get_component(other_unit, "position")
                        
                        if other_team and other_position and Unit.are_enemies(self.entity_manager, unit, other_unit) then
                            -- Check if target is in different lane but within detection range
                            local other_pos = Vector2:new(other_position.x, other_position.y)
                            local distance = unit_pos:distance_to(other_pos)
                            
                            if distance <= extended_range then
                                table.insert(multi_lane_targets, {
                                    unit = other_unit,
                                    position = other_pos,
                                    distance = distance,
                                    cross_lane = self:is_cross_lane_target(position, other_position),
                                    last_seen = love.timer.getTime()
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    
    return multi_lane_targets
end
-- }}}

-- {{{ CombatDetectionSystem:is_cross_lane_target
function CombatDetectionSystem:is_cross_lane_target(unit_position, target_position)
    -- Simple lane difference detection
    -- This would be more sophisticated with actual lane system integration
    local lateral_difference = math.abs(unit_position.y - target_position.y)
    return lateral_difference > 30  -- Threshold for different lanes
end
-- }}}

-- {{{ CombatDetectionSystem:create_engagement_effect
function CombatDetectionSystem:create_engagement_effect(unit, target)
    if not self.engagement_effects then
        return
    end
    
    local unit_pos = self.entity_manager:get_component(unit, "position")
    local target_pos = self.entity_manager:get_component(target, "position")
    
    if unit_pos and target_pos then
        local effect = {
            type = "combat_engagement",
            start_position = Vector2:new(unit_pos.x, unit_pos.y),
            end_position = Vector2:new(target_pos.x, target_pos.y),
            duration = 0.5,
            start_time = love.timer.getTime(),
            color = {1.0, 0.8, 0.2, 0.8},  -- Orange engagement line
            thickness = 2
        }
        
        -- This would integrate with an effects system
        -- For now, just log the effect creation
        debug.log("Created engagement effect between " .. unit.name .. " and " .. target.name, "COMBAT_DETECTION")
    end
end
-- }}}

-- {{{ CombatDetectionSystem:calculate_optimal_combat_position
function CombatDetectionSystem:calculate_optimal_combat_position(unit, target)
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    local unit_pos = self.entity_manager:get_component(unit, "position")
    local target_pos = self.entity_manager:get_component(target, "position")
    
    if not unit_data or not unit_pos or not target_pos then
        return nil
    end
    
    local unit_position = Vector2:new(unit_pos.x, unit_pos.y)
    local target_position = Vector2:new(target_pos.x, target_pos.y)
    
    local optimal_distance = self.engagement_ranges[unit_data.unit_type] or self.engagement_ranges.melee
    
    -- Calculate direction to target
    local direction_to_target = target_position:subtract(unit_position):normalize()
    
    -- Calculate ideal combat position
    local combat_position = target_position:subtract(direction_to_target:multiply(optimal_distance))
    
    return combat_position
end
-- }}}

-- {{{ CombatDetectionSystem:get_detection_sub_paths
function CombatDetectionSystem:get_detection_sub_paths(current_sub_path_id)
    local sub_paths = {current_sub_path_id}
    
    if self.multi_lane_detection then
        -- This would integrate with the lane system to get adjacent sub-paths
        -- For now, adding adjacent IDs as a simple approximation
        table.insert(sub_paths, current_sub_path_id - 1)
        table.insert(sub_paths, current_sub_path_id + 1)
        
        -- Filter out invalid sub-path IDs
        local valid_sub_paths = {}
        for _, sub_path_id in ipairs(sub_paths) do
            if sub_path_id >= 1 and sub_path_id <= 10 then  -- Assuming 10 sub-paths max
                table.insert(valid_sub_paths, sub_path_id)
            end
        end
        return valid_sub_paths
    end
    
    return sub_paths
end
-- }}}

-- {{{ CombatDetectionSystem:update_engagement_effects
function CombatDetectionSystem:update_engagement_effects(dt)
    if not self.engagement_effects then
        return
    end
    
    -- Update visual engagement effects
    for engagement_key, engagement in pairs(self.combat_engagements) do
        if engagement.attacker and engagement.target then
            local current_time = love.timer.getTime()
            
            -- Create periodic engagement effects
            if not engagement.last_effect_time or (current_time - engagement.last_effect_time) > 1.0 then
                self:create_engagement_effect(engagement.attacker, engagement.target)
                engagement.last_effect_time = current_time
            end
        end
    end
end
-- }}}

-- {{{ CombatDetectionSystem:get_debug_info
function CombatDetectionSystem:get_debug_info()
    local active_engagements = 0
    local units_in_combat = 0
    local threat_cache_size = 0
    local cross_lane_engagements = 0
    
    for _ in pairs(self.combat_engagements) do
        active_engagements = active_engagements + 1
    end
    
    for _ in pairs(self.target_assignments) do
        units_in_combat = units_in_combat + 1
    end
    
    for _ in pairs(self.threat_assessments) do
        threat_cache_size = threat_cache_size + 1
    end
    
    -- Count cross-lane engagements
    for _, engagement in pairs(self.combat_engagements) do
        if engagement.attacker and engagement.target then
            local attacker_pos = self.entity_manager:get_component(engagement.attacker, "position")
            local target_pos = self.entity_manager:get_component(engagement.target, "position")
            
            if attacker_pos and target_pos and self:is_cross_lane_target(attacker_pos, target_pos) then
                cross_lane_engagements = cross_lane_engagements + 1
            end
        end
    end
    
    return {
        active_engagements = active_engagements,
        units_in_combat = units_in_combat,
        cross_lane_engagements = cross_lane_engagements,
        threat_cache_size = threat_cache_size,
        detection_ranges = self.detection_ranges,
        engagement_ranges = self.engagement_ranges,
        prefer_weak_targets = self.prefer_weak_targets,
        maintain_engagement = self.maintain_engagement,
        multi_lane_detection = self.multi_lane_detection,
        formation_priority = self.formation_priority,
        engagement_effects = self.engagement_effects
    }
end
-- }}}

return CombatDetectionSystem
-- }}}