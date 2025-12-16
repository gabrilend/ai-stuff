# Issue #012: Graphics Modes and Accessibility (F010, F011)

**Priority**: Medium  
**Phase**: 5.1 (User Experience and Polish)  
**Estimated Effort**: 4-5 days  
**Dependencies**: #002  

## Problem Description

Implement multiple graphics rendering modes and accessibility features 
including ASCII, Unicode, Braille, Sixel, colorblind support, and high 
contrast modes as specified in the requirements.

## Current Behavior

Only basic ASCII rendering exists.

## Expected Behavior

Rich graphics mode support with automatic detection and fallback, 
comprehensive accessibility features, and user customization options.

## Implementation Approach

### Graphics Mode System
```lua
-- {{{ GraphicsManager
local GraphicsManager = {
  currentMode = "ascii",
  availableModes = {},
  capabilities = {},
  colorSupport = "none"
}

-- {{{ init
function GraphicsManager:init()
  self:detectCapabilities()
  self:selectBestMode()
  self:initializeRenderer()
end
-- }}}

-- {{{ detectCapabilities
function GraphicsManager:detectCapabilities()
  self.capabilities = {
    colors = self:detectColorSupport(),
    unicode = self:detectUnicodeSupport(),
    braille = self:detectBrailleSupport(),
    sixel = self:detectSixelSupport(),
    terminalSize = self:getTerminalSize()
  }
  
  -- Determine available modes based on capabilities
  self.availableModes = self:getAvailableModes()
end
-- }}}

-- {{{ detectColorSupport
function GraphicsManager:detectColorSupport()
  local term = os.getenv("TERM") or ""
  local colorterm = os.getenv("COLORTERM") or ""
  
  if colorterm:match("truecolor") or colorterm:match("24bit") then
    return "24bit"
  elseif term:match("256color") then
    return "256color"
  elseif term:match("color") then
    return "8color"
  else
    return "none"
  end
end
-- }}}

-- {{{ detectUnicodeSupport
function GraphicsManager:detectUnicodeSupport()
  local lang = os.getenv("LANG") or ""
  local lc_ctype = os.getenv("LC_CTYPE") or ""
  
  return lang:match("UTF%-?8") or lc_ctype:match("UTF%-?8")
end
-- }}}

-- {{{ selectBestMode
function GraphicsManager:selectBestMode()
  -- Priority order: sixel > braille > unicode > ascii
  if self.capabilities.sixel then
    self.currentMode = "sixel"
  elseif self.capabilities.braille then
    self.currentMode = "braille"
  elseif self.capabilities.unicode then
    self.currentMode = "unicode"
  else
    self.currentMode = "ascii"
  end
end
-- }}}
```

### ASCII Renderer
```lua
-- {{{ ASCIIRenderer
local ASCIIRenderer = {
  characters = {
    tower = "T",
    enemy = "E",
    wall = "#",
    floor = ".",
    selected = "*",
    cursor = "+",
    path = "-"
  }
}

-- {{{ renderMap
function ASCIIRenderer:renderMap(gameState)
  local buffer = {}
  local map = gameState.map
  
  for y = 1, map.height do
    local line = {}
    for x = 1, map.width do
      local char = self:getCharAt(x, y, gameState)
      table.insert(line, char)
    end
    buffer[y] = table.concat(line)
  end
  
  return buffer
end
-- }}}

-- {{{ getCharAt
function ASCIIRenderer:getCharAt(x, y, gameState)
  -- Check for towers
  for _, tower in pairs(gameState.towers) do
    if tower.position.x == x and tower.position.y == y then
      return self.characters.tower
    end
  end
  
  -- Check for enemies
  for _, enemy in pairs(gameState.enemies) do
    if enemy.position.x == x and enemy.position.y == y then
      return self.characters.enemy
    end
  end
  
  -- Check for selection
  if gameState.selectedPosition and 
     gameState.selectedPosition.x == x and 
     gameState.selectedPosition.y == y then
    return self.characters.selected
  end
  
  return self.characters.floor
end
-- }}}
```

### Unicode Renderer
```lua
-- {{{ UnicodeRenderer
local UnicodeRenderer = {
  characters = {
    tower = "🏰",
    enemy = "👾",
    wall = "█",
    floor = "·",
    selected = "⭐",
    cursor = "✚",
    path = "→",
    -- Box drawing characters
    boxTopLeft = "┌",
    boxTopRight = "┐",
    boxBottomLeft = "└",
    boxBottomRight = "┘",
    boxHorizontal = "─",
    boxVertical = "│"
  }
}

-- {{{ renderMap
function UnicodeRenderer:renderMap(gameState)
  local buffer = {}
  local map = gameState.map
  
  -- Draw border
  buffer[1] = self:drawTopBorder(map.width)
  
  for y = 1, map.height do
    local line = {self.characters.boxVertical}
    
    for x = 1, map.width do
      local char = self:getCharAt(x, y, gameState)
      table.insert(line, char)
    end
    
    table.insert(line, self.characters.boxVertical)
    buffer[y + 1] = table.concat(line)
  end
  
  buffer[map.height + 2] = self:drawBottomBorder(map.width)
  
  return buffer
end
-- }}}

-- {{{ drawTopBorder
function UnicodeRenderer:drawTopBorder(width)
  local line = {self.characters.boxTopLeft}
  
  for x = 1, width do
    table.insert(line, self.characters.boxHorizontal)
  end
  
  table.insert(line, self.characters.boxTopRight)
  
  return table.concat(line)
end
-- }}}
```

### Braille Renderer
```lua
-- {{{ BrailleRenderer
local BrailleRenderer = {
  -- Braille patterns for high-resolution graphics
  brailleBase = 0x2800,
  dotPositions = {
    {0, 0}, {0, 1}, {0, 2}, {0, 3},
    {1, 0}, {1, 1}, {1, 2}, {1, 3}
  }
}

-- {{{ renderMap
function BrailleRenderer:renderMap(gameState)
  local buffer = {}
  local map = gameState.map
  
  -- Convert game coordinates to high-resolution braille grid
  local brailleWidth = math.ceil(map.width / 2)
  local brailleHeight = math.ceil(map.height / 4)
  
  for by = 1, brailleHeight do
    local line = {}
    
    for bx = 1, brailleWidth do
      local brailleChar = self:createBrailleChar(bx, by, gameState)
      table.insert(line, brailleChar)
    end
    
    buffer[by] = table.concat(line)
  end
  
  return buffer
end
-- }}}

-- {{{ createBrailleChar
function BrailleRenderer:createBrailleChar(bx, by, gameState)
  local pattern = 0
  
  -- Check each dot position in the braille character
  for i, dot in ipairs(self.dotPositions) do
    local x = (bx - 1) * 2 + dot[1] + 1
    local y = (by - 1) * 4 + dot[2] + 1
    
    if self:hasContentAt(x, y, gameState) then
      pattern = pattern | (1 << (i - 1))
    end
  end
  
  return utf8.char(self.brailleBase + pattern)
end
-- }}}

-- {{{ hasContentAt
function BrailleRenderer:hasContentAt(x, y, gameState)
  -- Check if there's a tower or enemy at this position
  for _, tower in pairs(gameState.towers) do
    if tower.position.x == x and tower.position.y == y then
      return true
    end
  end
  
  for _, enemy in pairs(gameState.enemies) do
    if enemy.position.x == x and enemy.position.y == y then
      return true
    end
  end
  
  return false
end
-- }}}
```

### Sixel Renderer
```lua
-- {{{ SixelRenderer
local SixelRenderer = {
  tileSize = 8, -- 8x8 pixel tiles
  colors = {}
}

-- {{{ renderMap
function SixelRenderer:renderMap(gameState)
  if not self:isSixelSupported() then
    return nil, "Sixel not supported"
  end
  
  local map = gameState.map
  local pixelWidth = map.width * self.tileSize
  local pixelHeight = map.height * self.tileSize
  
  -- Create pixel buffer
  local pixels = self:createPixelBuffer(pixelWidth, pixelHeight)
  
  -- Render game objects to pixels
  self:renderGameObjects(pixels, gameState)
  
  -- Convert to sixel format
  return self:pixelsToSixel(pixels, pixelWidth, pixelHeight)
end
-- }}}

-- {{{ isSixelSupported
function SixelRenderer:isSixelSupported()
  -- Query terminal for sixel support
  io.write("\027[c") -- Device attributes query
  io.flush()
  
  -- This is simplified - proper implementation would parse response
  local term = os.getenv("TERM") or ""
  return term:match("xterm") and os.getenv("DISPLAY")
end
-- }}}
```

### Color Management
```lua
-- {{{ ColorManager
local ColorManager = {
  schemes = {
    default = {
      tower = {fg = "blue", bg = "black"},
      enemy = {fg = "red", bg = "black"},
      selected = {fg = "yellow", bg = "black"},
      background = {fg = "white", bg = "black"}
    },
    
    colorblind = {
      tower = {fg = "cyan", bg = "black"},
      enemy = {fg = "magenta", bg = "black"},
      selected = {fg = "white", bg = "blue"},
      background = {fg = "white", bg = "black"}
    },
    
    highContrast = {
      tower = {fg = "white", bg = "black"},
      enemy = {fg = "black", bg = "white"},
      selected = {fg = "black", bg = "yellow"},
      background = {fg = "white", bg = "black"}
    }
  },
  
  currentScheme = "default"
}

-- {{{ setColorScheme
function ColorManager:setColorScheme(schemeName)
  if self.schemes[schemeName] then
    self.currentScheme = schemeName
    return true
  end
  return false
end
-- }}}

-- {{{ getColor
function ColorManager:getColor(element)
  local scheme = self.schemes[self.currentScheme]
  return scheme[element] or scheme.background
end
-- }}}

-- {{{ applyColor
function ColorManager:applyColor(text, element)
  local color = self:getColor(element)
  local colorCode = self:getANSIColor(color)
  
  return colorCode .. text .. "\027[0m" -- Reset
end
-- }}}

-- {{{ getANSIColor
function ColorManager:getANSIColor(color)
  local colors = {
    black = 30, red = 31, green = 32, yellow = 33,
    blue = 34, magenta = 35, cyan = 36, white = 37
  }
  
  local fg = colors[color.fg] or colors.white
  local bg = colors[color.bg] and (colors[color.bg] + 10) or 40
  
  return string.format("\027[%d;%dm", fg, bg)
end
-- }}}
```

### Accessibility Features
```lua
-- {{{ AccessibilityManager
local AccessibilityManager = {
  screenReaderMode = false,
  highContrastMode = false,
  largeTextMode = false,
  soundEnabled = false
}

-- {{{ enableScreenReaderMode
function AccessibilityManager:enableScreenReaderMode()
  self.screenReaderMode = true
  
  -- Provide text descriptions for all visual elements
  self:setupScreenReaderDescriptions()
end
-- }}}

-- {{{ generateScreenReaderText
function AccessibilityManager:generateScreenReaderText(gameState)
  local description = {}
  
  table.insert(description, "Current wave: " .. gameState.currentWave)
  table.insert(description, "Gold: " .. gameState.resources.gold)
  table.insert(description, "Lives: " .. gameState.resources.lives)
  
  table.insert(description, "Towers on field: " .. #gameState.towers)
  table.insert(description, "Enemies remaining: " .. #gameState.enemies)
  
  if gameState.selectedTower then
    table.insert(description, self:describeTower(gameState.selectedTower))
  end
  
  return table.concat(description, ". ")
end
-- }}}

-- {{{ describeTower
function AccessibilityManager:describeTower(tower)
  return string.format(
    "Selected tower at position %d, %d. Type: %s. Health: %d. Damage: %d",
    tower.position.x, tower.position.y,
    tower.type, tower.stats.health, tower.stats.damage
  )
end
-- }}}
```

### Graphics Mode Configuration
```lua
-- {{{ GraphicsConfig
local GraphicsConfig = {
  userPreferences = {
    preferredMode = "auto",
    colorScheme = "default",
    accessibility = {
      screenReader = false,
      highContrast = false,
      largeText = false
    }
  }
}

-- {{{ loadUserPreferences
function GraphicsConfig:loadUserPreferences()
  local configFile = "graphics_config.lua"
  
  if self:fileExists(configFile) then
    local config = dofile(configFile)
    if config then
      self.userPreferences = config
    end
  end
end
-- }}}

-- {{{ saveUserPreferences
function GraphicsConfig:saveUserPreferences()
  local configFile = "graphics_config.lua"
  local file = io.open(configFile, "w")
  
  if file then
    file:write("return " .. self:serializeTable(self.userPreferences))
    file:close()
  end
end
-- }}}
```

## Acceptance Criteria

- [ ] ASCII mode works on all terminals
- [ ] Unicode mode displays correctly when supported
- [ ] Braille mode provides high-resolution graphics
- [ ] Sixel mode works on compatible terminals
- [ ] Automatic mode detection and fallback functional
- [ ] Color schemes switch correctly
- [ ] Colorblind-friendly schemes available
- [ ] High contrast mode improves visibility
- [ ] Screen reader mode provides text descriptions
- [ ] User preferences save and load correctly
- [ ] Manual mode override available
- [ ] Graceful degradation on unsupported features

## Technical Notes

### Performance Requirements
- Mode switching < 100ms
- Rendering performance maintained across modes
- Memory usage reasonable for graphics buffers

### Compatibility Considerations
- Terminal capability detection
- Graceful fallback mechanisms
- Cross-platform consistency

## Test Cases

1. **Mode Detection**
   - Correct capability detection
   - Appropriate mode selection
   - Fallback behavior

2. **Rendering Quality**
   - Visual accuracy in each mode
   - Color scheme application
   - Accessibility compliance

3. **User Preferences**
   - Configuration persistence
   - Manual overrides
   - Real-time switching

4. **Accessibility**
   - Screen reader compatibility
   - High contrast effectiveness
   - Keyboard navigation support

## Integration Points

- **Terminal Interface**: Capability detection and rendering
- **Configuration System**: User preference management
- **Game Engine**: Visual state representation
- **UI System**: Mode-specific rendering

## Future Considerations

- Additional graphics modes
- Animation support
- Custom color themes
- Advanced accessibility features