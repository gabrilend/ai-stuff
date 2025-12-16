local player = {
    gold = 10,
    hearts = 3,
    king_x = 100,
    king_y = 100
}

local enemy = {
    gold = 10,
    hearts = 3,
    king_x = 1000,
    king_y = 700
}

function player_init()
    player.gold = 10
    player.hearts = 3
    enemy.gold = 10
    enemy.hearts = 3
end

function player_add_gold(amount)
    player.gold = player.gold + amount
end

function player_spend_gold(amount)
    if player.gold >= amount then
        player.gold = player.gold - amount
        return true
    end
    return false
end

function player_get_gold()
    return player.gold
end

function player_get_hearts()
    return player.hearts
end

function enemy_get_hearts()
    return enemy.hearts
end

function player_add_gold_for_captured_rooms()
    local controlled_rooms = get_player_controlled_rooms()
    local bonus_gold = #controlled_rooms
    player_add_gold(bonus_gold)
    
    -- Also give enemy gold for their controlled rooms
    local enemy_controlled_rooms = get_enemy_controlled_rooms()
    local enemy_bonus_gold = #enemy_controlled_rooms
    enemy.gold = enemy.gold + enemy_bonus_gold + 1  -- +1 base income
end

function get_enemy_gold()
    return enemy.gold
end

function enemy_add_gold(amount)
    enemy.gold = enemy.gold + amount
end

function enemy_spend_gold(amount)
    if enemy.gold >= amount then
        enemy.gold = enemy.gold - amount
        return true
    end
    return false
end

function player_lose_heart()
    player.hearts = player.hearts - 1
    if player.hearts <= 0 then
        gamestate = "menu"
        menu_init()
    else
        clear_enemy_units()
    end
end

function enemy_lose_heart()
    enemy.hearts = enemy.hearts - 1
    if enemy.hearts <= 0 then
        gamestate = "menu"
        menu_init()
    else
        clear_player_units()
    end
end

function clear_player_units()
    local rooms = get_rooms()
    for _, room in ipairs(rooms) do
        for i = #room.units, 1, -1 do
            if room.units[i].owner == 1 then
                table.remove(room.units, i)
            end
        end
    end
end

function clear_enemy_units()
    local rooms = get_rooms()
    for _, room in ipairs(rooms) do
        for i = #room.units, 1, -1 do
            if room.units[i].owner == 2 then
                table.remove(room.units, i)
            end
        end
    end
end