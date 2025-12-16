-- {{{ Team component
-- Creates a team component with player ID and team color
return function(player_id, team_color)
    return {
        player_id = player_id or 1,
        team_color = team_color or {1, 1, 1}, -- Default white
        is_friendly = function(other_team)
            return other_team.player_id == player_id
        end
    }
end
-- }}}