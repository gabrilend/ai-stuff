-- {{{ Moveable component
-- Creates a moveable component with velocity and target information
return function(velocity_x, velocity_y, target_x, target_y)
    return {
        velocity_x = velocity_x or 0,
        velocity_y = velocity_y or 0,
        target_x = target_x,
        target_y = target_y,
        speed = 50, -- Units per second
        max_speed = 100,
        acceleration = 200,
        moving = false,
        arrived_at_target = false
    }
end
-- }}}