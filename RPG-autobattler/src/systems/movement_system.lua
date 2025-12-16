-- {{{ MovementSystem
local BaseSystem = require("src.systems.base_system")
local Components = require("src.components.init")
local debug = require("src.utils.debug")

local MovementSystem = BaseSystem:new(nil, "movement")

-- {{{ MovementSystem:new
function MovementSystem:new(entity_manager)
    local system = BaseSystem:new(entity_manager, "movement")
    system:set_required_components({Components.POSITION, Components.MOVEABLE})
    return system
end
-- }}}

-- {{{ MovementSystem:process_entity
function MovementSystem:process_entity(entity, dt)
    local position = self.entity_manager:get_component(entity, Components.POSITION)
    local moveable = self.entity_manager:get_component(entity, Components.MOVEABLE)
    
    if not position or not moveable then
        return
    end
    
    -- Store previous position
    position.previous_x = position.x
    position.previous_y = position.y
    
    -- Update position based on velocity
    position.x = position.x + moveable.velocity_x * dt
    position.y = position.y + moveable.velocity_y * dt
    
    -- Check if moving towards target
    if moveable.target_x and moveable.target_y then
        local dx = moveable.target_x - position.x
        local dy = moveable.target_y - position.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance > 1 then -- Not arrived yet
            -- Normalize direction and apply speed
            local dir_x = dx / distance
            local dir_y = dy / distance
            
            moveable.velocity_x = dir_x * moveable.speed
            moveable.velocity_y = dir_y * moveable.speed
            moveable.moving = true
            moveable.arrived_at_target = false
        else
            -- Arrived at target
            position.x = moveable.target_x
            position.y = moveable.target_y
            moveable.velocity_x = 0
            moveable.velocity_y = 0
            moveable.moving = false
            moveable.arrived_at_target = true
            
            debug.debug("Entity " .. entity.name .. " arrived at target", "MOVEMENT")
        end
    else
        -- No target, just apply velocity
        moveable.moving = (moveable.velocity_x ~= 0 or moveable.velocity_y ~= 0)
    end
end
-- }}}

return MovementSystem
-- }}}