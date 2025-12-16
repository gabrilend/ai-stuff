-- {{{ RenderSystem
local BaseSystem = require("src.systems.base_system")
local Components = require("src.components.init")
local debug = require("src.utils.debug")

local RenderSystem = BaseSystem:new(nil, "render")

-- {{{ RenderSystem:new
function RenderSystem:new(entity_manager)
    local system = BaseSystem:new(entity_manager, "render")
    system:set_required_components({Components.POSITION, Components.RENDERABLE})
    return system
end
-- }}}

-- {{{ RenderSystem:draw_entity
function RenderSystem:draw_entity(entity)
    local position = self.entity_manager:get_component(entity, Components.POSITION)
    local renderable = self.entity_manager:get_component(entity, Components.RENDERABLE)
    
    if not position or not renderable or not renderable.visible then
        return
    end
    
    -- Set color with opacity
    love.graphics.setColor(
        renderable.color[1], 
        renderable.color[2], 
        renderable.color[3], 
        renderable.opacity
    )
    
    -- Apply transformations
    love.graphics.push()
    love.graphics.translate(position.x, position.y)
    love.graphics.rotate(renderable.rotation)
    love.graphics.scale(renderable.scale_x, renderable.scale_y)
    
    -- Draw based on shape
    if renderable.shape == "circle" then
        love.graphics.circle("fill", 0, 0, renderable.size)
    elseif renderable.shape == "rectangle" then
        local half_size = renderable.size / 2
        love.graphics.rectangle("fill", -half_size, -half_size, renderable.size, renderable.size)
    elseif renderable.shape == "triangle" then
        local points = {
            0, -renderable.size,
            -renderable.size * 0.866, renderable.size * 0.5,
            renderable.size * 0.866, renderable.size * 0.5
        }
        love.graphics.polygon("fill", points)
    elseif renderable.shape == "line" then
        love.graphics.setLineWidth(3)
        love.graphics.line(-renderable.size, 0, renderable.size, 0)
    else
        -- Default to circle
        love.graphics.circle("fill", 0, 0, renderable.size)
    end
    
    love.graphics.pop()
end
-- }}}

-- {{{ RenderSystem:draw
function RenderSystem:draw()
    if not self.enabled then
        return
    end
    
    local entities = self:get_entities()
    
    -- Sort entities by some criteria if needed (e.g., z-order)
    -- For now, just draw in order
    
    for _, entity in ipairs(entities) do
        self:draw_entity(entity)
    end
    
    -- Reset graphics state
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end
-- }}}

return RenderSystem
-- }}}