# Issue #003: Core Game Engine (F001 partial)

**Priority**: Critical  
**Phase**: 1.3 (Foundation)  
**Estimated Effort**: 4-5 days  
**Dependencies**: #001, #002  

## Problem Description

Implement the core game engine that manages game state, provides the 
turn-based game loop, handles events, and processes user input. This 
forms the central coordination system for all game functionality.

## Current Behavior

No game engine exists.

## Expected Behavior

A robust game engine that manages game state, processes turns, handles 
events, and coordinates between UI and game logic components.

## Implementation Approach

### Game State Management
```lua
-- {{{ GameState
local GameState = {
  tick = 0,
  players = {},
  currentWave = 1,
  gamePhase = "PLACEMENT", -- PLACEMENT, COMBAT, UPGRADE, GAME_OVER
  map = nil,
  towers = {},
  enemies = {},
  resources = {
    gold = 100,
    lives = 20,
    income = 10
  }
}
-- }}}

-- {{{ GameEngine
local GameEngine = {}

-- {{{ init
function GameEngine:init(config)
  -- Initialize game state
  -- Set up event system
  -- Load configuration
  -- Initialize random seed deterministically
end
-- }}}

-- {{{ processTick
function GameEngine:processTick()
  -- Update game state for one tick
  -- Process player actions
  -- Update entity positions
  -- Check victory/defeat conditions
  -- Generate events
end
-- }}}
```

### Event System
- Observer pattern for game events
- Event types: TOWER_PLACED, ENEMY_DEFEATED, WAVE_COMPLETE, etc.
- Event queuing and processing
- Event persistence for replay/debugging

### Turn-Based Game Loop
- Fixed timestep processing (60 FPS capability)
- Phase management (placement, combat, upgrades)
- Input validation and queuing
- State consistency checks

### Input Command Processing
- Command pattern for user actions
- Action validation against game rules
- Undo/redo capability foundation
- Action serialization for networking

### Configuration System
```lua
-- {{{ Config
local Config = {
  graphics = {
    mode = "ascii",
    colorScheme = "default"
  },
  controls = {
    up = {"w", "k", "up"},
    down = {"s", "j", "down"},
    left = {"a", "h", "left"},
    right = {"d", "l", "right"}
  },
  game = {
    startingGold = 100,
    startingLives = 20,
    waveCount = 50
  }
}
-- }}}
```

### Save/Load System
- Game state serialization
- Save game compatibility
- Configuration persistence
- Error recovery for corrupted saves

## Acceptance Criteria

- [ ] Game engine initializes with default configuration
- [ ] Game loop runs at stable 60 FPS
- [ ] Game state updates correctly each tick
- [ ] Events generated and processed properly
- [ ] Input commands validated and executed
- [ ] Configuration loads from file and command line
- [ ] Save/load functionality works
- [ ] Game phases transition correctly
- [ ] Victory/defeat conditions detected
- [ ] Resource management (gold/lives) functions

## Technical Notes

### State Management
- Immutable state objects where possible
- Clear state transition rules
- State validation and consistency checks
- Memory-efficient data structures

### Performance Requirements
- Game loop must maintain 60 FPS
- State updates < 5ms per tick
- Memory usage < 10MB for game state
- Save/load operations < 100ms

### Error Handling
- Graceful handling of invalid states
- Recovery from corrupted game data
- Clear error messages for game rule violations
- Rollback capability for failed operations

## Test Cases

1. **Basic Operation**
   - Engine starts and stops cleanly
   - Game loop runs at correct frequency
   - State updates produce expected results

2. **Configuration**
   - Default config loads correctly
   - File-based config overrides defaults
   - Command-line args override file config
   - Invalid config handled gracefully

3. **Save/Load**
   - Game state saves and loads identically
   - Corrupted save files handled properly
   - Version compatibility maintained

4. **Event System**
   - Events generated at correct times
   - Event handlers receive correct data
   - Event ordering maintained properly

5. **Input Processing**
   - Valid commands execute correctly
   - Invalid commands rejected properly
   - Command queuing works under load

## Integration Points

- **UI System**: Receives events and sends commands
- **Networking**: State synchronization hooks
- **Terminal**: Input polling and display updates
- **Configuration**: Settings management

## Future Considerations

- Networking hooks for multiplayer state sync
- Replay system foundation
- Performance profiling integration
- Modding API foundations