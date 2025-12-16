# Issue #006: Design and Implement Game State System

## Current Behavior
No game state management system exists to handle different screens and game modes.

## Intended Behavior
A robust game state system should manage transitions between menu, gameplay, unit editor, and other game states with clean separation of logic.

## Implementation Details

### State Manager (src/systems/state_manager.lua)
```lua
local StateManager = {}
StateManager.states = {}
StateManager.current_state = nil

function StateManager:add_state(name, state)
    self.states[name] = state
end

function StateManager:change_state(name)
    if self.current_state and self.current_state.exit then
        self.current_state:exit()
    end
    
    self.current_state = self.states[name]
    
    if self.current_state and self.current_state.enter then
        self.current_state:enter()
    end
end

function StateManager:update(dt)
    if self.current_state and self.current_state.update then
        self.current_state:update(dt)
    end
end

function StateManager:draw()
    if self.current_state and self.current_state.draw then
        self.current_state:draw()
    end
end

return StateManager
```

### Base State Class (src/systems/base_state.lua)
```lua
local BaseState = {}
BaseState.__index = BaseState

function BaseState:new()
    local state = {}
    setmetatable(state, BaseState)
    return state
end

function BaseState:enter() end
function BaseState:exit() end
function BaseState:update(dt) end
function BaseState:draw() end
function BaseState:keypressed(key) end
function BaseState:mousepressed(x, y, button) end

return BaseState
```

### Initial States
1. **MenuState**: Main menu with options
2. **GameState**: Core gameplay
3. **EditorState**: Unit template editor
4. **PauseState**: Pause overlay

### Integration with main.lua
- Route all Love2D callbacks through StateManager
- Handle state transitions smoothly
- Maintain state-specific data isolation

### Considerations
- Ensure states don't interfere with each other
- Plan for state data persistence
- Consider state history/stack for complex transitions
- Add transition animations framework
- Handle resource loading per state

### Tool Suggestions
- Use Write tool to create state manager and base state
- Use Edit tool to integrate with main.lua
- Test state transitions thoroughly
- Verify memory cleanup between states

### Acceptance Criteria
- [ ] StateManager handles state transitions correctly
- [ ] Multiple states can be defined and switched between
- [ ] Love2D callbacks are properly routed to current state
- [ ] State data is isolated and doesn't leak
- [ ] Transitions are smooth and error-free
- [ ] Memory usage is stable during state changes