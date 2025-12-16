# Issue #004: Basic Gameplay Mechanics (F001 continued)

**Priority**: Critical  
**Phase**: 1.4 (Foundation)  
**Estimated Effort**: 5-6 days  
**Dependencies**: #003  

## Problem Description

Implement the core gameplay mechanics including grid-based map, tower 
placement, basic pathfinding, combat system, and resource management. 
This provides the fundamental tower defense gameplay.

## Current Behavior

Game engine exists but no actual gameplay mechanics.

## Expected Behavior

Functional tower defense gameplay with tower placement, enemy movement, 
combat resolution, and resource management working correctly.

## Implementation Approach

### Grid-Based Map System
```lua
-- {{{ Map
local Map = {
  width = 20,
  height = 24,
  playerArea = {startY = 8, endY = 24}, -- Bottom 2/3
  enemyArea = {startY = 1, endY = 8},   -- Top 1/3
  grid = {}
}

-- {{{ isValidPosition
function Map:isValidPosition(x, y, forPlayer)
  -- Check if position is valid for placement
  -- Verify within player area bounds
  -- Check for existing towers
  return valid
end
-- }}}
```

### Tower System
```lua
-- {{{ Tower
local Tower = {
  id = nil,
  type = "basic",
  position = {x = 0, y = 0},
  stats = {
    health = 100,
    damage = 25,
    speed = 1,
    range = 3,
    cost = 50
  },
  state = "IDLE" -- IDLE, MOVING, COMBAT
}

-- {{{ Tower:new
function Tower:new(type, x, y)
  -- Create new tower instance
  -- Set stats based on type
  -- Initialize position
  return tower
end
-- }}}
```

### Enemy System
```lua
-- {{{ Enemy
local Enemy = {
  id = nil,
  type = "basic",
  position = {x = 0, y = 0},
  target = {x = 0, y = 24}, -- Move toward bottom
  stats = {
    health = 50,
    damage = 10,
    speed = 1,
    bounty = 10
  },
  path = {}
}
```

### Basic Pathfinding (A*)
```lua
-- {{{ Pathfinding
local Pathfinding = {}

-- {{{ findPath
function Pathfinding:findPath(start, goal, obstacles)
  -- A* algorithm implementation
  -- Handle dynamic obstacles (other units)
  -- Return path as array of positions
  return path
end
-- }}}

-- {{{ updatePaths
function Pathfinding:updatePaths(entities)
  -- Recalculate paths when obstacles change
  -- Efficient incremental updates
  -- Handle collisions and avoidance
end
-- }}}
```

### Combat System
```lua
-- {{{ Combat
local Combat = {}

-- {{{ resolveCombat
function Combat:resolveCombat(attacker, defender)
  -- Calculate damage based on stats
  -- Apply damage to defender
  -- Handle death and cleanup
  -- Award bounty if applicable
  return {damage, killed, bounty}
end
-- }}}

-- {{{ processCombatPhase
function Combat:processCombatPhase(towers, enemies)
  -- Move all units one step
  -- Detect collisions and combat
  -- Resolve all combat simultaneously
  -- Update positions and states
end
-- }}}
```

### Resource Management
```lua
-- {{{ Resources
local Resources = {
  gold = 100,
  lives = 20,
  income = 10,
  wave = 1
}

-- {{{ canAfford
function Resources:canAfford(cost)
  return self.gold >= cost
end
-- }}}

-- {{{ spendGold
function Resources:spendGold(amount)
  if self:canAfford(amount) then
    self.gold = self.gold - amount
    return true
  end
  return false
end
-- }}}

-- {{{ loseLife
function Resources:loseLife()
  self.lives = self.lives - 1
  return self.lives <= 0 -- Game over
end
-- }}}
```

### Tower Placement System
- Validate placement positions
- Check resource requirements
- Update game state and UI
- Handle placement conflicts

### Basic Unit Types
- **Basic Tower**: Balanced stats, medium cost
- **Fast Tower**: High speed, low health
- **Heavy Tower**: High health, slow speed
- **Basic Enemy**: Standard enemy unit
- **Fast Enemy**: Quick but weak
- **Heavy Enemy**: Slow but strong

## Acceptance Criteria

- [ ] Player can place towers in valid positions (bottom 2/3 of map)
- [ ] Tower placement rejected in invalid positions
- [ ] Towers cost appropriate gold and spending validated
- [ ] Enemies spawn from top and pathfind toward bottom
- [ ] Towers move toward enemies and engage in combat
- [ ] Combat resolves with damage calculations
- [ ] Defeated enemies award bounty gold
- [ ] Enemies reaching bottom cost lives
- [ ] Game over when lives reach zero
- [ ] Resource management works correctly
- [ ] Pathfinding avoids obstacles and other units
- [ ] Multiple towers and enemies can exist simultaneously

## Technical Notes

### Performance Requirements
- Pathfinding < 5ms per unit per update
- Combat resolution < 1ms per interaction
- Support 50+ simultaneous units
- Grid operations O(1) lookup time

### Game Balance Considerations
- Tower costs balanced against income
- Enemy difficulty appropriate for tower capabilities
- Resource management creates meaningful choices
- Combat feels responsive and clear

### Data Structures
- Efficient spatial indexing for collision detection
- Memory pools for frequent allocation/deallocation
- Cache-friendly data layout for performance

## Test Cases

1. **Tower Placement**
   - Valid placements succeed and cost gold
   - Invalid placements rejected with clear feedback
   - Insufficient gold prevents placement

2. **Pathfinding**
   - Enemies find path from spawn to goal
   - Path updates when obstacles change
   - Units avoid collisions with each other

3. **Combat**
   - Towers engage enemies within range
   - Damage calculations correct
   - Death and bounty handled properly

4. **Resources**
   - Gold spending and earning work correctly
   - Lives lost when enemies leak
   - Game over triggers at zero lives

5. **Edge Cases**
   - Blocked paths force enemy routing
   - Simultaneous combat interactions
   - Resource overflow/underflow

## Integration Points

- **Game Engine**: State updates and event generation
- **UI System**: Visual representation of game state
- **Input System**: Tower placement commands
- **Configuration**: Game balance parameters

## Future Considerations

- Foundation for multiple tower/enemy types
- Upgrade system hooks
- Animation system integration
- Multiplayer synchronization points