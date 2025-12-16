local Maze = require("maze")
local Unit = require("unit")
local Hero = require("hero")
local Monster = require("monster")
local Combat = require("combat")

local game = {}

function love.load()
    love.window.setTitle("Maze Battle Simulation")
    love.window.setMode(800 * 1.5, 600 * 1.5)
    
    game.maze = Maze:new(25 * 2, 19 * 2)
    game.combatPairs = {}
    game.cellSize = 20
    game.offsetX = 50
    game.offsetY = 50
    game.updateTimer = 0
    game.updateInterval = 0.3
    
    for i = 1, 6 do
        local hero = Hero:new()
        local x, y = game.maze:getRandomWalkablePosition()
        hero:setPosition(x, y, game.maze)
    end
    
    for i = 1, 10 do
        local monster = Monster:new()
        local x, y = game.maze:getRandomWalkablePosition()
        monster:setPosition(x, y, game.maze)
    end
end

function love.update(dt)
    game.updateTimer = game.updateTimer + dt
    
    local allUnits = game.maze:getAllUnits()
    
    for _, unit in ipairs(allUnits) do
        unit:updateMovement(dt)
    end
    
    if game.updateTimer >= game.updateInterval then
        game.updateTimer = 0
        
        for _, unit in ipairs(allUnits) do
            if unit.health <= 0 then
                game.maze:removeUnit(unit, unit.x, unit.y)
            elseif not unit.inCombat then
                local enemies = unit:update(game.maze)
                if enemies then
                    table.insert(game.combatPairs, {unit, enemies})
                end
            end
        end
        
        for _, combatPair in ipairs(game.combatPairs) do
            local attacker = combatPair[1]
            local defenders = combatPair[2]
            
            for _, defender in ipairs(defenders) do
                if attacker.health > 0 and defender.health > 0 then
                    Combat.battle(attacker, defender)
                end
            end
            
            attacker.inCombat = false
            for _, defender in ipairs(defenders) do
                defender.inCombat = false
            end
        end
        
        game.combatPairs = {}
    end
end

function love.draw()
    game.maze:draw(game.offsetX, game.offsetY, game.cellSize)
    game.maze:drawItems(game.offsetX, game.offsetY, game.cellSize)
    
    local allUnits = game.maze:getAllUnits()
    for _, unit in ipairs(allUnits) do
        unit:draw(game.offsetX, game.offsetY, game.cellSize)
    end
    
    local heroCount = 0
    local monsterCount = 0
    for _, unit in ipairs(allUnits) do
        if unit.type == "hero" then
            heroCount = heroCount + 1
        elseif unit.type == "monster" then
            monsterCount = monsterCount + 1
        end
    end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Heroes: " .. heroCount, 10, 10)
    love.graphics.print("Monsters: " .. monsterCount, 10, 30)
    love.graphics.print("Press R to reset", 10, 50)
end

function love.keypressed(key)
    if key == "r" then
        love.load()
    end
    if key == "escape" then
        love.event.quit()
    end
end
