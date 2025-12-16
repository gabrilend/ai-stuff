-- {{{ Position component
-- Creates a position component with x, y coordinates
return function(x, y)
    return {
        x = x or 0,
        y = y or 0,
        previous_x = x or 0,
        previous_y = y or 0
    }
end
-- }}}