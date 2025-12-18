-- {{{ Renderable component
-- Creates a renderable component with shape, color, and size information
return function(shape, color, size)
    return {
        shape = shape or "circle", -- circle, rectangle, triangle, line
        color = color or {1, 1, 1}, -- RGB values (0-1)
        size = size or 10,
        visible = true,
        opacity = 1.0,
        rotation = 0,
        scale_x = 1.0,
        scale_y = 1.0
    }
end
-- }}}