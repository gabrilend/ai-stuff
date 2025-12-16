local Maze = {}
Maze.__index = Maze

function Maze:new(width, height)
    local maze = {
        width = width or 21,
        height = height or 21,
        grid = {},
        units = {},
        items = {},
        deadEndExits = {},
        WALL = 1,
        PATH = 0
    }
    setmetatable(maze, Maze)
    maze:generate()
    maze:computeDeadEndExits()
    maze:spawnItems()
    maze:initializeUnitGrid()
    return maze
end

function Maze:generate()
    for y = 1, self.height do
        self.grid[y] = {}
        for x = 1, self.width do
            self.grid[y][x] = self.WALL
        end
    end
    
    local function isValid(x, y)
        return x > 0 and x <= self.width and y > 0 and y <= self.height
    end
    
    local function carve(x, y)
        self.grid[y][x] = self.PATH
        
        local directions = {{0, -2}, {2, 0}, {0, 2}, {-2, 0}}
        for i = #directions, 2, -1 do
            local j = math.random(i)
            directions[i], directions[j] = directions[j], directions[i]
        end
        
        for _, dir in ipairs(directions) do
            local nx, ny = x + dir[1], y + dir[2]
            if isValid(nx, ny) and self.grid[ny][nx] == self.WALL then
                self.grid[y + dir[2]/2][x + dir[1]/2] = self.PATH
                carve(nx, ny)
            end
        end
    end
    
    carve(1, 1)
    
    local pathCount = 0
    for y = 1, self.height do
        for x = 1, self.width do
            if self.grid[y][x] == self.PATH then
                pathCount = pathCount + 1
            end
        end
    end
    
    local extraPaths = math.floor(pathCount * 0.1)
    for i = 1, extraPaths do
        local x = math.random(2, self.width - 1)
        local y = math.random(2, self.height - 1)
        if self.grid[y][x] == self.WALL then
            local neighbors = 0
            if self.grid[y-1] and self.grid[y-1][x] == self.PATH then neighbors = neighbors + 1 end
            if self.grid[y+1] and self.grid[y+1][x] == self.PATH then neighbors = neighbors + 1 end
            if self.grid[y][x-1] == self.PATH then neighbors = neighbors + 1 end
            if self.grid[y][x+1] == self.PATH then neighbors = neighbors + 1 end
            
            if neighbors >= 2 then
                self.grid[y][x] = self.PATH
            end
        end
    end
end

function Maze:isWalkable(x, y)
    if x < 1 or x > self.width or y < 1 or y > self.height then
        return false
    end
    return self.grid[y][x] == self.PATH
end

function Maze:getRandomWalkablePosition()
    local attempts = 0
    while attempts < 1000 do
        local x = math.random(1, self.width)
        local y = math.random(1, self.height)
        if self:isWalkable(x, y) then
            return x, y
        end
        attempts = attempts + 1
    end
    return 1, 1
end

function Maze:initializeUnitGrid()
    for y = 1, self.height do
        self.units[y] = {}
        for x = 1, self.width do
            self.units[y][x] = {}
        end
    end
end

function Maze:addUnit(unit, x, y)
    if self:isWalkable(x, y) then
        table.insert(self.units[y][x], unit)
        return true
    end
    return false
end

function Maze:removeUnit(unit, x, y)
    if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
        for i, u in ipairs(self.units[y][x]) do
            if u == unit then
                table.remove(self.units[y][x], i)
                break
            end
        end
    end
end

function Maze:getUnitsAt(x, y)
    if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
        return self.units[y][x]
    end
    return {}
end

function Maze:moveUnit(unit, oldX, oldY, newX, newY)
    self:removeUnit(unit, oldX, oldY)
    return self:addUnit(unit, newX, newY)
end

function Maze:getAllUnits()
    local allUnits = {}
    for y = 1, self.height do
        for x = 1, self.width do
            for _, unit in ipairs(self.units[y][x]) do
                table.insert(allUnits, unit)
            end
        end
    end
    return allUnits
end

function Maze:isIntersection(x, y)
    if not self:isWalkable(x, y) then
        return false
    end
    
    local pathCount = 0
    local directions = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}}
    
    for _, dir in ipairs(directions) do
        local nx, ny = x + dir[1], y + dir[2]
        if self:isWalkable(nx, ny) then
            pathCount = pathCount + 1
        end
    end
    
    return pathCount > 2
end

function Maze:isDeadEnd(x, y)
    if not self:isWalkable(x, y) then
        return false
    end
    
    local pathCount = 0
    local directions = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}}
    
    for _, dir in ipairs(directions) do
        local nx, ny = x + dir[1], y + dir[2]
        if self:isWalkable(nx, ny) then
            pathCount = pathCount + 1
        end
    end
    
    return pathCount == 1
end

function Maze:computeDeadEndExits()
    for y = 1, self.height do
        for x = 1, self.width do
            if self:isDeadEnd(x, y) then
                local exitIntersection = self:findNearestIntersection(x, y)
                if exitIntersection then
                    self.deadEndExits[y .. "," .. x] = exitIntersection
                end
            end
        end
    end
end

function Maze:findNearestIntersection(startX, startY)
    local visited = {}
    local queue = {{x = startX, y = startY, path = {}}}
    local directions = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}}
    
    while #queue > 0 do
        local current = table.remove(queue, 1)
        local key = current.y .. "," .. current.x
        
        if visited[key] then
            goto continue
        end
        visited[key] = true
        
        if self:isIntersection(current.x, current.y) then
            return {x = current.x, y = current.y, path = current.path}
        end
        
        for _, dir in ipairs(directions) do
            local nx, ny = current.x + dir[1], current.y + dir[2]
            local nkey = ny .. "," .. nx
            
            if self:isWalkable(nx, ny) and not visited[nkey] then
                local newPath = {}
                for i, step in ipairs(current.path) do
                    table.insert(newPath, step)
                end
                table.insert(newPath, {x = nx, y = ny})
                
                table.insert(queue, {x = nx, y = ny, path = newPath})
            end
        end
        
        ::continue::
    end
    
    return nil
end

function Maze:getDeadEndExit(x, y)
    local key = y .. "," .. x
    return self.deadEndExits[key]
end

function Maze:spawnItems()
    local Item = require("item")
    local potionCount = math.floor((self.width * self.height) / 300) + 1
    local chestCount = math.floor((self.width * self.height) / 400) + 1
    
    -- Spawn health potions
    for i = 1, potionCount do
        local attempts = 0
        while attempts < 100 do
            local x = math.random(1, self.width)
            local y = math.random(1, self.height)
            
            if self:isWalkable(x, y) and not self:hasItemAt(x, y) then
                local potion = Item:new("health_potion", x, y)
                table.insert(self.items, potion)
                break
            end
            attempts = attempts + 1
        end
    end
    
    -- Spawn treasure chests
    for i = 1, chestCount do
        local attempts = 0
        while attempts < 100 do
            local x = math.random(1, self.width)
            local y = math.random(1, self.height)
            
            if self:isWalkable(x, y) and not self:hasItemAt(x, y) then
                local chest = Item:createTreasureChest(x, y)
                table.insert(self.items, chest)
                break
            end
            attempts = attempts + 1
        end
    end
end

function Maze:hasItemAt(x, y)
    for _, item in ipairs(self.items) do
        if not item.collected and item.x == x and item.y == y then
            return true
        end
    end
    return false
end

function Maze:getItemAt(x, y)
    for _, item in ipairs(self.items) do
        if not item.collected and item.x == x and item.y == y then
            return item
        end
    end
    return nil
end

function Maze:collectItem(item)
    item.collected = true
end

function Maze:drawItems(offsetX, offsetY, cellSize)
    for _, item in ipairs(self.items) do
        if not item.collected then
            item:draw(offsetX, offsetY, cellSize)
        end
    end
end

function Maze:draw(offsetX, offsetY, cellSize)
    for y = 1, self.height do
        for x = 1, self.width do
            local px = offsetX + (x - 1) * cellSize
            local py = offsetY + (y - 1) * cellSize
            
            if self.grid[y][x] == self.WALL then
                love.graphics.setColor(0.2, 0.2, 0.2)
            else
                love.graphics.setColor(0.9, 0.9, 0.9)
            end
            
            love.graphics.rectangle("fill", px, py, cellSize, cellSize)
            
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.rectangle("line", px, py, cellSize, cellSize)
        end
    end
end

return Maze