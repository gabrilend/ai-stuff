# Issue #003: Create Basic Window and Rendering Loop

## Current Behavior
No window configuration or rendering setup exists.

## Intended Behavior
A properly configured Love2D window should open with a basic rendering loop that displays a simple test pattern to verify the graphics system is working.

## Implementation Details

### Window Configuration (conf.lua)
```lua
function love.conf(t)
    t.title = "RPG-Autobattler"
    t.version = "11.4"
    t.window.width = 1024
    t.window.height = 768
    t.window.resizable = false
    t.window.vsync = 1
end
```

### Basic Rendering (main.lua)
1. Clear screen with black background
2. Draw simple test shapes (rectangle, circle, line)
3. Display FPS counter
4. Add basic text showing the game is running

### Test Pattern Elements
- Central rectangle (represents future game area)
- Corner circles (test shape rendering)
- Diagonal lines (test line rendering)
- Text display (test font rendering)
- Different colors to verify color system

### Considerations
- Ensure proper coordinate system setup
- Test different graphics primitives
- Verify color rendering works correctly
- Check that rendering scales properly
- Add performance monitoring (FPS)

### Tool Suggestions
- Use Write tool to create conf.lua and update main.lua
- Test rendering with Love2D
- Verify window opens with correct dimensions
- Check that all graphics primitives render correctly

### Acceptance Criteria
- [ ] Game window opens at specified dimensions
- [ ] Black background renders correctly
- [ ] Test shapes display in different colors
- [ ] FPS counter shows and updates
- [ ] Text renders correctly
- [ ] No rendering errors or warnings