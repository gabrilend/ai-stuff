local Unit = require("unit")
local Hero = {}
setmetatable(Hero, {__index = Unit})
Hero.__index = Hero

function Hero:new()
    local hero = Unit:new()
    setmetatable(hero, Hero)
    
    hero.type = "hero"
    hero.health = 120
    hero.maxHealth = 120
    hero.damage = 15
    hero.speed = 0.8 + math.random() * 0.6
    hero.color = {0.2, 0.6, 1.0}
    hero.baseColor = {0.2, 0.6, 1.0}
    hero.inventory = {}
    hero.gold = 0
    
    return hero
end

function Hero:addToInventory(item)
    if item.type == "gold" then
        -- Add gold to total instead of inventory
        self.gold = self.gold + (item.amount or 10)
    else
        table.insert(self.inventory, item)
    end
end

function Hero:hasHealthPotion()
    for _, item in ipairs(self.inventory) do
        if item.type == "health_potion" then
            return true
        end
    end
    return false
end

function Hero:useHealthPotion()
    for i, item in ipairs(self.inventory) do
        if item.type == "health_potion" then
            local healAmount = item:use(self)
            table.remove(self.inventory, i)
            return healAmount
        end
    end
    return 0
end

function Hero:shouldUsePotion()
    if not self:hasHealthPotion() then
        return false
    end
    
    local healthMissing = self.maxHealth - self.health
    return healthMissing >= 30
end

function Hero:getItemCount(itemType)
    local count = 0
    for _, item in ipairs(self.inventory) do
        if item.type == itemType then
            count = count + 1
        end
    end
    return count
end

function Hero:getTotalValue()
    local value = self.gold
    for _, item in ipairs(self.inventory) do
        local props = item:getProperties()
        if props.value then
            value = value + props.value
        end
    end
    return value
end

function Hero:getInventorySummary()
    local summary = {}
    summary.gold = self.gold
    summary.healthPotions = self:getItemCount("health_potion")
    summary.ruby = self:getItemCount("ruby")
    summary.sapphire = self:getItemCount("sapphire")
    summary.peridot = self:getItemCount("peridot")
    summary.spinel = self:getItemCount("spinel")
    summary.emerald = self:getItemCount("emerald")
    summary.totalValue = self:getTotalValue()
    return summary
end

function Hero:chooseBestMove(moves, maze)
    local result = Unit.chooseBestMove(self, moves, maze)
    if result then
        return result
    end
    
    for _, move in ipairs(moves) do
        if move.undesirable and math.random() < 0.2 then
            return move
        end
    end
    
    return nil
end

return Hero