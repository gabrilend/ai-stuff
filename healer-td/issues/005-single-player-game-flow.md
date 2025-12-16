# Issue #005: Single-Player Game Flow (F004)

**Priority**: High  
**Phase**: 1.5 (Foundation)  
**Estimated Effort**: 3-4 days  
**Dependencies**: #004  

## Problem Description

Implement the complete single-player game flow including wave generation, 
progression, victory/defeat conditions, and basic UI for tower 
information. This creates a complete playable single-player experience.

## Current Behavior

Basic gameplay mechanics exist but no complete game flow.

## Expected Behavior

A complete single-player tower defense game with wave progression, 
victory conditions, and intuitive UI for managing towers and resources.

## Implementation Approach

### Wave Generation System
```lua
-- {{{ WaveManager
local WaveManager = {}

-- {{{ generateWave
function WaveManager:generateWave(waveNumber)
  local wave = {
    number = waveNumber,
    enemies = {},
    spawnDelay = 1.0, -- seconds between spawns
    preview = true
  }
  
  -- Scale difficulty with wave number
  local enemyCount = math.floor(5 + waveNumber * 1.5)
  local enemyTypes = self:selectEnemyTypes(waveNumber)
  
  for i = 1, enemyCount do
    table.insert(wave.enemies, {
      type = enemyTypes[math.random(#enemyTypes)],
      spawnTime = i * wave.spawnDelay
    })
  end
  
  return wave
end
-- }}}

-- {{{ getWavePreview
function WaveManager:getWavePreview(waveNumber)
  -- Generate preview information
  -- Show enemy types and counts
  -- Display estimated difficulty
  return preview
end
-- }}}
```

### Wave Progression
- Increasing enemy count and difficulty
- Introduction of new enemy types over time
- Boss waves every 10 waves
- Resource scaling (income increases with survival)

### Game State Management
```lua
-- {{{ GameFlow
local GameFlow = {}

-- {{{ startWave
function GameFlow:startWave(waveNumber)
  -- Transition from PLACEMENT to COMBAT phase
  -- Begin enemy spawning
  -- Start combat resolution
  self.gameState.phase = "COMBAT"
  self.gameState.currentWave = waveNumber
end
-- }}}

-- {{{ endWave
function GameFlow:endWave()
  -- All enemies defeated or leaked
  -- Award income for survival
  -- Transition to PLACEMENT phase
  -- Check for upgrade opportunities (every 5 waves)
  self:awardIncome()
  self.gameState.phase = "PLACEMENT"
end
-- }}}

-- {{{ checkVictoryConditions
function GameFlow:checkVictoryConditions()
  -- Victory: All waves completed with lives remaining
  -- Defeat: Lives reach zero
  if self.gameState.currentWave > MAX_WAVES and 
     #self.gameState.enemies == 0 then
    return "VICTORY"
  elseif self.gameState.resources.lives <= 0 then
    return "DEFEAT"
  end
  return "ONGOING"
end
-- }}}
```

### Basic UI System
```lua
-- {{{ UI
local UI = {}

-- {{{ drawGameState
function UI:drawGameState(gameState)
  -- Draw map grid
  -- Show towers and enemies
  -- Display resource information
  -- Show wave progress
  self:drawMap(gameState.map)
  self:drawUnits(gameState.towers, gameState.enemies)
  self:drawHUD(gameState.resources, gameState.currentWave)
end
-- }}}

-- {{{ drawTowerInfo
function UI:drawTowerInfo(tower)
  -- Display tower statistics
  -- Show upgrade options (future)
  -- Display range and damage info
  return infoText
end
-- }}}

-- {{{ drawWavePreview
function UI:drawWavePreview(wave)
  -- Show upcoming enemy types
  -- Display enemy count and timing
  -- Show estimated difficulty
  return previewText
end
-- }}}
```

### Victory/Defeat System
- Clear win conditions (survive all waves)
- Clear lose conditions (lives reach zero)
- End game statistics
- Option to restart or quit

### Resource Progression
- Income increases each wave survived
- Bounty gold from defeated enemies
- Resource scarcity creates strategic tension

## Acceptance Criteria

- [ ] Waves generate with increasing difficulty
- [ ] Player can preview upcoming wave before starting
- [ ] Enemies spawn according to wave definition
- [ ] Wave ends when all enemies defeated or leaked
- [ ] Income awarded after successful wave completion
- [ ] Victory achieved after completing all waves
- [ ] Defeat triggered when lives reach zero
- [ ] Game statistics displayed at end
- [ ] Player can restart after game end
- [ ] UI shows current wave progress and information
- [ ] Resource information clearly displayed
- [ ] Basic tower information available on selection

## Technical Notes

### Wave Difficulty Scaling
- Linear enemy count increase
- Exponential health/damage scaling
- Introduction of new enemy types at specific waves
- Boss waves provide major difficulty spikes

### Performance Requirements
- Wave generation < 10ms
- UI updates < 16ms for smooth display
- Game flow transitions instantaneous
- Memory usage stable across waves

### Balance Considerations
- Starting resources allow meaningful choices
- Income progression maintains challenge
- Enemy difficulty matches tower capabilities
- Wave length provides appropriate pacing

## Test Cases

1. **Wave Progression**
   - Waves generate with correct difficulty scaling
   - Enemy spawning follows wave definition
   - Wave completion triggers properly

2. **Victory/Defeat**
   - Victory triggers after final wave completion
   - Defeat triggers immediately when lives reach zero
   - Game state remains stable at end conditions

3. **Resource Management**
   - Income awarded correctly after wave survival
   - Bounty gold awarded for enemy defeats
   - Resource display updates in real-time

4. **UI Functionality**
   - Wave preview displays accurate information
   - Tower information shows correct stats
   - Resource display remains accurate

5. **Edge Cases**
   - Very fast wave completion
   - All towers destroyed but wave continues
   - Simultaneous victory/defeat conditions

## Integration Points

- **Game Engine**: Phase transitions and state management
- **Combat System**: Enemy spawning and defeat detection
- **UI System**: Information display and user feedback
- **Resource System**: Income and spending management

## Future Considerations

- Foundation for essential upgrades system
- Multiplayer wave synchronization
- Replay system hooks
- Achievement system foundation
- Statistics tracking and analysis