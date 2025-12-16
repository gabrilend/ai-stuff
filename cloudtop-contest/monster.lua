local Unit = require("unit")
local Monster = {}
setmetatable(Monster, {__index = Unit})
Monster.__index = Monster

function Monster:new()
    local monster = Unit:new()
    setmetatable(monster, Monster)
    
    monster.type = "monster"
    monster.health = 80
    monster.maxHealth = 80
    monster.damage = 12
    monster.speed = 1.0 + math.random() * 0.8
    monster.color = {1.0, 0.3, 0.2}
    monster.baseColor = {1.0, 0.3, 0.2}
    
    return monster
end

function Monster:chooseBestMove(moves, maze)
    local result = Unit.chooseBestMove(self, moves, maze)
    if result then
        return result
    end
    
    for _, move in ipairs(moves) do
        if move.undesirable and math.random() < 0.4 then
            return move
        end
    end
    
    return nil
end

return Monster