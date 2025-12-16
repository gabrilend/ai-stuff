# Issue #006: Tower Selection System (F003)

**Priority**: High  
**Phase**: 2.2 (Enhanced Single-Player)  
**Estimated Effort**: 3-4 days  
**Dependencies**: #005  

## Problem Description

Implement the intelligent tower selection and navigation system that 
allows players to efficiently move between placed towers using keyboard 
controls, with configurable selection preferences and clear visual 
feedback.

## Current Behavior

Basic tower placement exists but no navigation between towers.

## Expected Behavior

Intuitive keyboard navigation between towers with intelligent selection 
algorithms, clear visual feedback, and configurable preferences matching 
the vision document specifications.

## Implementation Approach

### Tower Selection Algorithm
```lua
-- {{{ TowerSelector
local TowerSelector = {
  selectedTower = nil,
  selectionPreference = "right", -- "right" or "left"
  cursorPosition = {x = 10, y = 12}
}

-- {{{ selectTowerInDirection
function TowerSelector:selectTowerInDirection(direction, towers)
  local current = self.cursorPosition
  local candidates = {}
  
  if direction == "up" then
    candidates = self:findTowersAbove(current, towers)
  elseif direction == "down" then
    candidates = self:findTowersBelow(current, towers)
  elseif direction == "left" or direction == "right" then
    candidates = self:findTowersHorizontal(current, direction, towers)
  end
  
  if #candidates == 0 then
    return self:fallbackSelection(direction, towers)
  end
  
  return self:selectClosestTower(candidates, current)
end
-- }}}

-- {{{ findTowersAbove
function TowerSelector:findTowersAbove(current, towers)
  local candidates = {}
  
  -- Find closest tower on row above current position
  for row = current.y - 1, 1, -1 do
    local rowTowers = self:getTowersOnRow(row, towers)
    if #rowTowers > 0 then
      -- Find closest tower horizontally on this row
      local closest = self:findClosestHorizontally(current.x, rowTowers)
      if closest then
        table.insert(candidates, closest)
        break -- Use first row found with towers
      end
    end
  end
  
  return candidates
end
-- }}}

-- {{{ findTowersHorizontal
function TowerSelector:findTowersHorizontal(current, direction, towers)
  local candidates = {}
  local rowTowers = self:getTowersOnRow(current.y, towers)
  
  -- Filter towers in the requested direction
  for _, tower in ipairs(rowTowers) do
    if direction == "left" and tower.position.x < current.x then
      table.insert(candidates, tower)
    elseif direction == "right" and tower.position.x > current.x then
      table.insert(candidates, tower)
    end
  end
  
  -- If no towers on same line, use fallback algorithm
  if #candidates == 0 then
    return self:alternatingRowSearch(current, direction, towers)
  end
  
  return candidates
end
-- }}}

-- {{{ alternatingRowSearch
function TowerSelector:alternatingRowSearch(current, direction, towers)
  -- Search alternating rows: +1, -1, +2, -2, +3, -3, etc.
  local candidates = {}
  local maxDistance = 12 -- Reasonable search limit
  
  for distance = 1, maxDistance do
    -- Check row above (+distance)
    local upRow = current.y - distance
    if upRow >= 1 then
      local upTowers = self:getTowersInDirection(upRow, current.x, direction, towers)
      if #upTowers > 0 then
        return upTowers
      end
    end
    
    -- Check row below (-distance)
    local downRow = current.y + distance
    if downRow <= MAP_HEIGHT then
      local downTowers = self:getTowersInDirection(downRow, current.x, direction, towers)
      if #downTowers > 0 then
        return downTowers
      end
    end
  end
  
  return candidates
end
-- }}}
```

### Selection Preferences
```lua
-- {{{ handleEquidistantTowers
function TowerSelector:handleEquidistantTowers(towers, reference)
  if #towers <= 1 then
    return towers[1]
  end
  
  -- Sort by horizontal distance from reference
  table.sort(towers, function(a, b)
    local distA = math.abs(a.position.x - reference.x)
    local distB = math.abs(b.position.x - reference.x)
    
    if distA == distB then
      -- Same distance - use preference setting
      if self.selectionPreference == "right" then
        return a.position.x > b.position.x
      else
        return a.position.x < b.position.x
      end
    end
    
    return distA < distB
  end)
  
  return towers[1]
end
-- }}}
```

### Visual Feedback System
```lua
-- {{{ SelectionRenderer
local SelectionRenderer = {}

-- {{{ drawSelection
function SelectionRenderer:drawSelection(tower, cursorPos)
  if tower then
    -- Highlight selected tower
    self:drawTowerHighlight(tower.position)
    self:drawTowerInfo(tower)
  else
    -- Show cursor position
    self:drawCursor(cursorPos)
  end
end
-- }}}

-- {{{ drawTowerHighlight
function SelectionRenderer:drawTowerHighlight(position)
  -- Draw border around selected tower
  -- Use different color or character pattern
  -- Ensure visibility in all graphics modes
end
-- }}}
```

### Input Handling
```lua
-- {{{ SelectionInputHandler
local SelectionInputHandler = {}

-- {{{ processInput
function SelectionInputHandler:processInput(key, selector, towers)
  local direction = self:keyToDirection(key)
  
  if direction then
    local newTower = selector:selectTowerInDirection(direction, towers)
    if newTower then
      selector:selectTower(newTower)
      return true
    end
  elseif key == "i" or key == "info" then
    self:showTowerInfo(selector.selectedTower)
    return true
  end
  
  return false
end
-- }}}

-- {{{ keyToDirection
function SelectionInputHandler:keyToDirection(key)
  local keyMap = {
    w = "up", k = "up", up = "up",
    s = "down", j = "down", down = "down",
    a = "left", h = "left", left = "left",
    d = "right", l = "right", right = "right"
  }
  return keyMap[key]
end
-- }}}
```

## Acceptance Criteria

- [ ] Up movement (K/W/↑) selects closest tower on row above
- [ ] Down movement (S/J/↓) selects closest tower on row below
- [ ] Left/right movement selects tower in same row
- [ ] Fallback search works when no tower in direction (alternating rows)
- [ ] Equidistant towers use configurable preference (right/left)
- [ ] Selected tower clearly highlighted visually
- [ ] Tower information displays when tower selected
- [ ] Cursor shows current position when no tower selected
- [ ] All supported key bindings work (WASD, vim keys, arrows)
- [ ] Selection preference configurable in settings
- [ ] Smooth transitions between tower selections
- [ ] Tower stats and information easily readable

## Technical Notes

### Performance Requirements
- Tower selection < 5ms for typical tower counts
- Visual updates < 16ms for smooth feedback
- Memory usage minimal for selection state

### Algorithm Complexity
- O(n) tower search in worst case
- O(log n) sorting for equidistant towers
- Spatial indexing for large tower counts

### Configuration Integration
```lua
config.controls.selectionPreference = "right" -- or "left"
config.controls.keyBindings = {
  up = {"w", "k", "up"},
  down = {"s", "j", "down"},
  left = {"a", "h", "left"},
  right = {"d", "l", "right"},
  info = {"i"}
}
```

## Test Cases

1. **Basic Direction Selection**
   - Up/down movement finds towers correctly
   - Left/right movement works on same row
   - No tower in direction handled gracefully

2. **Fallback Algorithm**
   - Alternating row search finds towers
   - Search terminates appropriately
   - Handles edge cases (map boundaries)

3. **Selection Preferences**
   - Right preference works for equidistant towers
   - Left preference works when configured
   - Preference applies consistently

4. **Visual Feedback**
   - Selected towers highlighted clearly
   - Tower information displays correctly
   - Cursor visible when no selection

5. **Input Handling**
   - All key bindings work correctly
   - Key mapping configurable
   - Invalid input handled gracefully

## Integration Points

- **Game Engine**: Tower state and position queries
- **UI System**: Visual feedback and information display
- **Input System**: Keyboard event processing
- **Configuration**: Selection preferences and key bindings

## Future Considerations

- Mouse support for direct tower selection
- Multi-tower selection capabilities
- Selection history and bookmarks
- Advanced tower filtering and search