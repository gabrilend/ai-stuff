-- {{{ Health component
-- Creates a health component with current and maximum health points
return function(max_hp)
    max_hp = max_hp or 100
    return {
        current_hp = max_hp,
        max_hp = max_hp,
        alive = true,
        damage_taken = 0,
        healing_received = 0
    }
end
-- }}}