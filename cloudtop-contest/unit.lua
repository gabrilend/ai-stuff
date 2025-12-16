local Unit = {}
Unit.__index = Unit

function Unit:new()
    local unit = {
        x = 1,
        y = 1,
        renderX = 1,
        renderY = 1,
        targetX = 1,
        targetY = 1,
        startX = 1,
        startY = 1,
        previousX = nil,
        previousY = nil,
        health = 100,
        maxHealth = 100,
        damage = 10,
        speed = 1.0,
        moveProgress = 0,
        isMoving = false,
        skipTurn = false,
        restingFlash = 0,
        isResting = false,
        restingTurns = 0,
        restingGoal = 0,
        type = "unit",
        exploredCells = {},
        undesirablePaths = {},
        exitingDeadEnd = false,
        deadEndPath = {},
        deadEndIndex = 1,
        inCombat = false,
        color = {1, 1, 1},
        baseColor = {1, 1, 1}
    }
    setmetatable(unit, Unit)
    return unit
end

function Unit:setPosition(x, y, maze)
    if maze then
        maze:removeUnit(self, self.x, self.y)
        if maze:addUnit(self, x, y) then
            self.x = x
            self.y = y
            self.renderX = x
            self.renderY = y
            self.targetX = x
            self.targetY = y
            self.moveProgress = 0
            self.isMoving = false
            self:markExplored(x, y)
            return true
        else
            maze:addUnit(self, self.x, self.y)
            return false
        end
    else
        self.x = x
        self.y = y
        self.renderX = x
        self.renderY = y
        self.targetX = x
        self.targetY = y
        self.moveProgress = 0
        self.isMoving = false
        self:markExplored(x, y)
        return true
    end
end

function Unit:startMoveTo(newX, newY)
    self.startX = self.renderX
    self.startY = self.renderY
    self.targetX = newX
    self.targetY = newY
    self.moveProgress = 0
    self.isMoving = true
end

function Unit:updateMovement(dt)
    if self.isMoving then
        self.moveProgress = self.moveProgress + dt * self.speed * 3
        
        if self.moveProgress >= 1.0 then
            self.moveProgress = 1.0
            self.isMoving = false
            self.renderX = self.targetX
            self.renderY = self.targetY
        else
            self.renderX = self.startX + (self.targetX - self.startX) * self.moveProgress
            self.renderY = self.startY + (self.targetY - self.startY) * self.moveProgress
        end
    end
    
    if self.restingFlash > 0 then
        self.restingFlash = self.restingFlash - dt * 4
        if self.restingFlash <= 0 then
            self.restingFlash = 0
            self.color = {self.baseColor[1], self.baseColor[2], self.baseColor[3]}
        else
            local flashIntensity = math.sin(self.restingFlash * 10) * 0.3 + 0.7
            self.color = {
                self.baseColor[1] * flashIntensity + 0.8 * (1 - flashIntensity),
                self.baseColor[2] * flashIntensity + 0.8 * (1 - flashIntensity),
                self.baseColor[3] * flashIntensity + 0.8 * (1 - flashIntensity)
            }
        end
    end
end

function Unit:markExplored(x, y)
    local key = x .. "," .. y
    self.exploredCells[key] = true
end

function Unit:hasExplored(x, y)
    local key = x .. "," .. y
    return self.exploredCells[key] == true
end

function Unit:isPathUndesirable(x, y)
    local key = x .. "," .. y
    return self.undesirablePaths[key] == true
end

function Unit:markPathUndesirable(x, y)
    local key = x .. "," .. y
    self.undesirablePaths[key] = true
end

function Unit:rest()
    self.restingFlash = 1.0
    if self.health < self.maxHealth then
        self.health = self.health + 1
    end
    if not self.isResting then
        self.isResting = true
        self.restingTurns = 0
    end
    self.restingTurns = self.restingTurns + 1
end

function Unit:stopResting()
    self.isResting = false
    self.restingTurns = 0
    self.restingGoal = 0
end

function Unit:shouldVoluntaryRest()
    if self.health >= self.maxHealth then
        return false
    end
    
    -- Heroes should consider using health potions instead of resting
    if self.type == "hero" and self.hasHealthPotion and self:hasHealthPotion() then
        local healthMissing = self.maxHealth - self.health
        if healthMissing >= 30 and math.random() < 0.7 then
            -- Use potion instead of resting
            local healAmount = self:useHealthPotion()
            if healAmount > 0 then
                self.restingFlash = 1.0  -- Show visual feedback
                return false  -- Don't rest, we used a potion
            end
        end
    end
    
    local healthPercent = self.health / self.maxHealth
    local restChance
    
    if healthPercent <= 0.3 then
        restChance = 0.4
    elseif healthPercent <= 0.5 then
        restChance = 0.25
    elseif healthPercent <= 0.7 then
        restChance = 0.1
    else
        restChance = 0.02
    end
    
    return math.random() < restChance
end

function Unit:startVoluntaryRest()
    local healthPercent = self.health / self.maxHealth
    local restGoal
    
    if healthPercent <= 0.3 then
        restGoal = math.random(8, 10)
    elseif healthPercent <= 0.5 then
        restGoal = math.random(5, 8)
    elseif healthPercent <= 0.7 then
        restGoal = math.random(3, 6)
    else
        restGoal = math.random(1, 3)
    end
    
    self.isResting = true
    self.restingTurns = 0
    self.restingGoal = restGoal
    self:rest()
end

function Unit:getValidMoves(maze)
    local moves = {}
    local directions = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}}
    
    for _, dir in ipairs(directions) do
        local newX = self.x + dir[1]
        local newY = self.y + dir[2]
        
        if maze:isWalkable(newX, newY) then
            local unitsAt = maze:getUnitsAt(newX, newY)
            if #unitsAt == 0 then
                local isBacktrack = (self.previousX == newX and self.previousY == newY)
                
                table.insert(moves, {
                    x = newX, 
                    y = newY, 
                    explored = self:hasExplored(newX, newY),
                    undesirable = self:isPathUndesirable(newX, newY),
                    isBacktrack = isBacktrack
                })
            end
        end
    end
    
    return moves
end


function Unit:chooseBestMove(moves, maze)
    if self.skipTurn then
        self.skipTurn = false
        self:rest()
        return nil
    end
    
    if self.isResting then
        if self.restingTurns < self.restingGoal and self.health < self.maxHealth then
            self:rest()
            return nil
        else
            self:stopResting()
        end
    end
    
    if self.exitingDeadEnd then
        local pathMove = self:getDeadEndPathMove()
        if pathMove then
            for _, move in ipairs(moves) do
                if move.x == pathMove.x and move.y == pathMove.y then
                    return move
                end
            end
            for _, move in ipairs(moves) do
                if move.x == pathMove.x and move.y == pathMove.y and move.isBacktrack then
                    return move
                end
            end
        end
        self.exitingDeadEnd = false
    end
    
    local nonBacktrackMoves = {}
    local backtrackMoves = {}
    
    for _, move in ipairs(moves) do
        if move.isBacktrack then
            table.insert(backtrackMoves, move)
        else
            table.insert(nonBacktrackMoves, move)
        end
    end
    
    if #nonBacktrackMoves == 0 and #backtrackMoves > 0 then
        local deadEndExit = maze:getDeadEndExit(self.x, self.y)
        if deadEndExit then
            self:startExitingDeadEnd(deadEndExit)
            return backtrackMoves[1]
        else
            self.skipTurn = true
            return nil
        end
    end
    
    -- Handle case where no moves are available at all (likely ally collision)
    if #moves == 0 then
        -- Check if there are allies adjacent that might be blocking us
        local hasAdjacentAllies = false
        local directions = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}}
        
        for _, dir in ipairs(directions) do
            local newX = self.x + dir[1]
            local newY = self.y + dir[2]
            
            if maze:isWalkable(newX, newY) then
                local unitsAt = maze:getUnitsAt(newX, newY)
                for _, unit in ipairs(unitsAt) do
                    if unit.type == self.type and unit.health > 0 then
                        hasAdjacentAllies = true
                        break
                    end
                end
            end
            if hasAdjacentAllies then break end
        end
        
        if hasAdjacentAllies then
            -- Clear movement history to allow backtracking
            self.previousX = nil
            self.previousY = nil
            
            -- Try to get moves again
            moves = self:getValidMoves(maze)
            
            if #moves > 0 then
                -- Prefer any move that gets us away from current position
                return moves[math.random(#moves)]
            end
        end
        
        -- If still no moves available, skip turn
        self.skipTurn = true
        return nil
    end
    
    local unexploredGood = {}
    local exploredGood = {}
    local unexploredUndesirable = {}
    local exploredUndesirable = {}
    
    for _, move in ipairs(nonBacktrackMoves) do
        if move.explored then
            if move.undesirable then
                table.insert(exploredUndesirable, move)
            else
                table.insert(exploredGood, move)
            end
        else
            if move.undesirable then
                table.insert(unexploredUndesirable, move)
            else
                table.insert(unexploredGood, move)
            end
        end
    end
    
    if self:shouldVoluntaryRest() then
        self:startVoluntaryRest()
        return nil
    end
    
    if #unexploredGood > 0 then
        return unexploredGood[math.random(#unexploredGood)]
    elseif #exploredGood > 0 then
        return exploredGood[math.random(#exploredGood)]
    elseif #unexploredUndesirable > 0 then
        return unexploredUndesirable[math.random(#unexploredUndesirable)]
    elseif #exploredUndesirable > 0 then
        return exploredUndesirable[math.random(#exploredUndesirable)]
    else
        local deadEndExit = maze:getDeadEndExit(self.x, self.y)
        if deadEndExit then
            self:startExitingDeadEnd(deadEndExit)
            return self:chooseBestMove(moves, maze)
        end
    end
    
    return nil
end

function Unit:startExitingDeadEnd(deadEndExit)
    self.exitingDeadEnd = true
    self.deadEndPath = deadEndExit.path
    self.deadEndTarget = {x = deadEndExit.x, y = deadEndExit.y}
    self.deadEndIndex = 1
    self:markPathUndesirable(self.x, self.y)
end

function Unit:getDeadEndPathMove()
    if self.deadEndIndex <= #self.deadEndPath then
        local move = self.deadEndPath[self.deadEndIndex]
        self.deadEndIndex = self.deadEndIndex + 1
        return move
    elseif self.deadEndIndex == #self.deadEndPath + 1 then
        self.deadEndIndex = self.deadEndIndex + 1
        return self.deadEndTarget
    end
    return nil
end

function Unit:getAdjacentEnemies(maze)
    local enemies = {}
    local directions = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}}
    
    for _, dir in ipairs(directions) do
        local checkX = self.x + dir[1]
        local checkY = self.y + dir[2]
        local unitsAt = maze:getUnitsAt(checkX, checkY)
        
        for _, unit in ipairs(unitsAt) do
            if unit.type ~= self.type and unit.health > 0 then
                table.insert(enemies, unit)
            end
        end
    end
    
    return enemies
end

function Unit:update(maze)
    if self.inCombat or self.isMoving then
        return
    end
    
    local adjacentEnemies = self:getAdjacentEnemies(maze)
    if #adjacentEnemies > 0 then
        self.inCombat = true
        for _, enemy in ipairs(adjacentEnemies) do
            enemy.inCombat = true
        end
        return adjacentEnemies
    end
    
    local moves = self:getValidMoves(maze)
    
    if #moves > 0 then
        local chosenMove = self:chooseBestMove(moves, maze)
        if chosenMove then
            if maze:moveUnit(self, self.x, self.y, chosenMove.x, chosenMove.y) then
                self:startMoveTo(chosenMove.x, chosenMove.y)
                self.previousX = self.x
                self.previousY = self.y
                self.x = chosenMove.x
                self.y = chosenMove.y
                self:markExplored(self.x, self.y)
                self:checkForItems(maze)
            end
        end
    end
    
    return nil
end

function Unit:checkForItems(maze)
    local item = maze:getItemAt(self.x, self.y)
    if item and item:canBePickedUpBy(self) then
        if self.type == "hero" and self.addToInventory then
            -- Check if it's a treasure chest
            if item.type == "treasure_chest" and item:canBeOpenedBy(self) then
                local lootItems = item:open(self, maze)
                for _, loot in ipairs(lootItems) do
                    self:addToInventory(loot)
                    maze:collectItem(loot)
                end
                -- Don't collect the chest itself, just mark it as opened
            else
                self:addToInventory(item)
                maze:collectItem(item)
            end
        end
    end
end

function Unit:takeDamage(amount)
    self.health = self.health - amount
    if self.health <= 0 then
        if self.type == "hero" and self.hasHealthPotion and self:hasHealthPotion() then
            self.health = 0
            local healAmount = self:useHealthPotion()
            self.health = healAmount
        else
            self.health = 0
        end
    end
end

function Unit:draw(offsetX, offsetY, cellSize)
    local px = offsetX + (self.renderX - 1) * cellSize + cellSize / 4
    local py = offsetY + (self.renderY - 1) * cellSize + cellSize / 4
    local size = cellSize / 2
    
    love.graphics.setColor(self.color[1], self.color[2], self.color[3])
    love.graphics.circle("fill", px + size/2, py + size/2, size/2)
    
    local healthPercent = self.health / self.maxHealth
    love.graphics.setColor(1 - healthPercent, healthPercent, 0)
    love.graphics.rectangle("fill", px, py - 5, size * healthPercent, 3)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("line", px, py - 5, size, 3)
end

return Unit