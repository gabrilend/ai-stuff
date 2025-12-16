# Issue #016: Create Unit Entity with Core Properties

## Current Behavior
Basic unit entity exists but needs standardization and core property validation.

## Intended Behavior
A robust unit entity should have all necessary core properties (position, health, team) with proper initialization and validation.

## Implementation Details

### Unit Entity Enhancement (src/entities/unit.lua)
```lua
-- {{{ local function create_unit
local function create_unit(template, team, spawn_position, sub_path_id)
    local unit_id = EntityManager:create_entity()
    
    -- Core properties
    EntityManager:add_component(unit_id, "position", {
        x = spawn_position.x,
        y = spawn_position.y,
        previous_x = spawn_position.x,
        previous_y = spawn_position.y,
        sub_path_id = sub_path_id
    })
    
    EntityManager:add_component(unit_id, "health", {
        current = template.max_health,
        maximum = template.max_health,
        is_alive = true,
        last_damage_time = 0
    })
    
    EntityManager:add_component(unit_id, "team", {
        id = team,
        alliance = team == 1 and "player" or "enemy"
    })
    
    EntityManager:add_component(unit_id, "unit", {
        template_id = template.id,
        unit_type = template.unit_type,  -- "melee" or "ranged"
        speed = template.speed,
        size = template.size or 8,
        state = "spawning"  -- spawning, moving, combat, dead
    })
    
    EntityManager:add_component(unit_id, "moveable", {
        velocity_x = 0,
        velocity_y = 0,
        target_x = spawn_position.x,
        target_y = spawn_position.y,
        is_moving = false,
        path_progress = 0
    })
    
    EntityManager:add_component(unit_id, "renderable", {
        shape = template.shape or "circle",
        color = team == 1 and Colors.PLAYER_UNIT or Colors.ENEMY_UNIT,
        size = template.size or 8,
        visible = true,
        render_layer = "units"
    })
    
    return unit_id
end
-- }}}

-- {{{ local function validate_unit_template
local function validate_unit_template(template)
    local required_fields = {
        "id", "max_health", "unit_type", "speed"
    }
    
    for _, field in ipairs(required_fields) do
        if not template[field] then
            error("Unit template missing required field: " .. field)
        end
    end
    
    if template.unit_type ~= "melee" and template.unit_type ~= "ranged" then
        error("Invalid unit_type: " .. tostring(template.unit_type))
    end
    
    if template.max_health <= 0 then
        error("Unit max_health must be positive")
    end
    
    if template.speed <= 0 then
        error("Unit speed must be positive")
    end
    
    return true
end
-- }}}
```

### Core Properties
1. **Position**: Current location and sub-path assignment
2. **Health**: Current/max health and alive status
3. **Team**: Team ID and alliance information
4. **Unit Data**: Template reference and unit type
5. **Movement**: Velocity and movement state
6. **Rendering**: Visual representation data

### Validation System
- Template validation before unit creation
- Property bounds checking
- Error handling for invalid configurations

### Considerations
- Ensure all core properties are properly initialized
- Add validation for edge cases and invalid data
- Consider memory efficiency with many units
- Plan for future property extensions

### Tool Suggestions
- Use Edit tool to enhance existing unit entity
- Test unit creation with various templates
- Verify all properties are properly set
- Check integration with existing systems

### Acceptance Criteria
- [ ] Unit entities have all required core properties
- [ ] Template validation prevents invalid units
- [ ] Units can be created with different teams
- [ ] Position and health systems work correctly
- [ ] Integration with existing ECS functions properly