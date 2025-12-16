local Item = {}
Item.__index = Item

function Item:new(itemType, x, y, amount)
    local item = {
        type = itemType or "health_potion",
        x = x or 1,
        y = y or 1,
        collected = false,
        amount = amount, -- For gold pieces
        contents = nil,  -- For treasure chests
        opened = false   -- For treasure chests
    }
    setmetatable(item, Item)
    return item
end

function Item:getProperties()
    if self.type == "health_potion" then
        return {
            name = "Health Potion",
            healAmount = 30,
            color = {0.8, 0.2, 0.8}, -- Purple
            canPickup = function(unit) return unit.type == "hero" end,
            canUse = function(unit) 
                return unit.type == "hero" and 
                       (unit.health <= 0 or unit.maxHealth - unit.health >= 30)
            end
        }
    elseif self.type == "ruby" then
        return {
            name = "Ruby",
            value = 100,
            color = {0.8, 0.1, 0.1}, -- Deep red
            canPickup = function(unit) return unit.type == "hero" end
        }
    elseif self.type == "sapphire" then
        return {
            name = "Sapphire",
            value = 120,
            color = {0.1, 0.1, 0.8}, -- Deep blue
            canPickup = function(unit) return unit.type == "hero" end
        }
    elseif self.type == "peridot" then
        return {
            name = "Peridot",
            value = 80,
            color = {0.5, 0.8, 0.1}, -- Green
            canPickup = function(unit) return unit.type == "hero" end
        }
    elseif self.type == "spinel" then
        return {
            name = "Spinel",
            value = 90,
            color = {0.8, 0.4, 0.8}, -- Pink
            canPickup = function(unit) return unit.type == "hero" end
        }
    elseif self.type == "emerald" then
        return {
            name = "Emerald",
            value = 150,
            color = {0.1, 0.6, 0.1}, -- Emerald green
            canPickup = function(unit) return unit.type == "hero" end
        }
    elseif self.type == "gold" then
        return {
            name = "Gold Pieces",
            value = self.amount or 10,
            color = {1.0, 0.8, 0.1}, -- Gold
            canPickup = function(unit) return unit.type == "hero" end
        }
    elseif self.type == "treasure_chest" then
        return {
            name = "Treasure Chest",
            color = {0.6, 0.4, 0.2}, -- Brown
            canPickup = function(unit) return unit.type == "hero" end,
            canOpen = function(unit) return unit.type == "hero" end
        }
    end
    return {}
end

function Item:canBePickedUpBy(unit)
    local props = self:getProperties()
    if props.canPickup then
        return props.canPickup(unit)
    end
    return false
end

function Item:canBeUsedBy(unit)
    local props = self:getProperties()
    if props.canUse then
        return props.canUse(unit)
    end
    return false
end

function Item:use(unit)
    local props = self:getProperties()
    if self.type == "health_potion" and props.healAmount then
        local oldHealth = unit.health
        unit.health = math.min(unit.maxHealth, unit.health + props.healAmount)
        return unit.health - oldHealth
    end
    return 0
end

function Item:createTreasureChest(x, y)
    local chest = Item:new("treasure_chest", x, y)
    chest.contents = {}
    
    -- Generate random loot
    local lootCount = math.random(2, 5)
    for i = 1, lootCount do
        local roll = math.random()
        if roll < 0.3 then
            -- Health potion (30% chance)
            table.insert(chest.contents, {type = "health_potion"})
        elseif roll < 0.5 then
            -- Gold pieces (20% chance)
            local goldAmount = math.random(5, 25)
            table.insert(chest.contents, {type = "gold", amount = goldAmount})
        else
            -- Gemstones (50% chance)
            local gems = {"ruby", "sapphire", "peridot", "spinel", "emerald"}
            local gemType = gems[math.random(#gems)]
            table.insert(chest.contents, {type = gemType})
        end
    end
    
    return chest
end

function Item:canBeOpenedBy(unit)
    local props = self:getProperties()
    if props.canOpen and self.type == "treasure_chest" and not self.opened then
        return props.canOpen(unit)
    end
    return false
end

function Item:open(unit, maze)
    if not self:canBeOpenedBy(unit) then
        return {}
    end
    
    self.opened = true
    local lootItems = {}
    
    -- Create actual item objects from contents and add to maze
    for _, loot in ipairs(self.contents or {}) do
        local item = Item:new(loot.type, self.x, self.y, loot.amount)
        table.insert(lootItems, item)
        if maze then
            table.insert(maze.items, item)
        end
    end
    
    return lootItems
end

function Item:draw(offsetX, offsetY, cellSize)
    if self.collected then
        return
    end
    
    local props = self:getProperties()
    local px = offsetX + (self.x - 1) * cellSize + cellSize / 3
    local py = offsetY + (self.y - 1) * cellSize + cellSize / 3
    local size = cellSize / 3
    
    if self.type == "treasure_chest" then
        -- Draw chest as larger rectangle
        px = offsetX + (self.x - 1) * cellSize + cellSize / 6
        py = offsetY + (self.y - 1) * cellSize + cellSize / 6
        size = cellSize * 2 / 3
        
        if self.opened then
            love.graphics.setColor(0.4, 0.2, 0.1) -- Darker brown when opened
        else
            love.graphics.setColor(props.color[1], props.color[2], props.color[3])
        end
        
        love.graphics.rectangle("fill", px, py, size, size)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", px, py, size, size)
        
        -- Draw chest lid indicator
        if not self.opened then
            love.graphics.setColor(0.8, 0.6, 0.3)
            love.graphics.rectangle("fill", px + size/4, py + size/8, size/2, size/4)
        end
    else
        -- Draw regular items
        if props.color then
            love.graphics.setColor(props.color[1], props.color[2], props.color[3])
        else
            love.graphics.setColor(0.5, 0.5, 0.5)
        end
        
        if self.type == "gold" then
            -- Draw gold as circles
            love.graphics.circle("fill", px + size/2, py + size/2, size/3)
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("line", px + size/2, py + size/2, size/3)
        else
            -- Draw other items as squares/rectangles
            love.graphics.rectangle("fill", px, py, size, size)
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("line", px, py, size, size)
        end
    end
end

return Item