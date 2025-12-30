# Issue 506: Build UI Framework

**Phase:** 5 - Rendering
**Type:** Feature
**Priority:** High
**Dependencies:** 501-create-abstract-render-interface

---

## Current Behavior

No UI system exists. Game information cannot be displayed to players, and there's no way to receive user input through interface elements.

---

## Intended Behavior

UI framework that:
- Renders WC3-style game interface elements
- Handles user input (mouse clicks, keyboard)
- Supports customizable layouts
- Separates UI logic from rendering
- Works with placeholder graphics

**WC3 UI Areas:**
```
┌─────────────────────────────────────────────────┐
│  Resources: Gold/Lumber/Food         Game Time │
├─────────────────────────────────────────────────┤
│                                                 │
│                                                 │
│              Main Game Viewport                 │
│                                                 │
│                                                 │
├──────────────┬────────────────┬─────────────────┤
│   Minimap    │  Unit Portrait │ Command Buttons │
│              │  Stats/Info    │ (3x4 grid)      │
│              │                │                 │
└──────────────┴────────────────┴─────────────────┘
```

---

## Suggested Implementation Steps

1. **Create UI component system**
   ```lua
   -- src/ui/init.lua
   local ui = {}

   function ui.create_panel(config) end
   function ui.create_button(config) end
   function ui.create_label(config) end
   function ui.create_icon(config) end
   function ui.create_bar(config) end  -- health/mana/progress
   ```

2. **Implement layout system**
   - Anchoring (top, bottom, left, right, center)
   - Relative positioning (percentage-based)
   - Absolute positioning (pixel-based)
   - Responsive scaling

3. **Build input handling**
   - Mouse hover detection
   - Click handling
   - Keyboard focus
   - Hotkey system

4. **Create core UI elements**
   - Resource bar (top)
   - Minimap panel (bottom-left)
   - Unit info panel (bottom-center)
   - Command panel (bottom-right)
   - Selection frame

5. **Implement command buttons**
   - 12-button grid (3x4)
   - Hotkey labels
   - Cooldown visualization
   - Context-sensitive (changes per unit)

6. **Add tooltip system**
   - Hover tooltips
   - Hotkey display
   - Unit/ability info

---

## Design Questions for User

1. **UI style?**
   - WC3-faithful (stone frame aesthetic)
   - Modern/minimal (flat design)
   - Hybrid (clean with WC3 layout)

2. **Resolution handling?**
   - Fixed UI size (scales with resolution)
   - Adaptive sizing
   - User-configurable scale

3. **Command panel layout?**
   - WC3 standard (3x4)
   - SC2 style (5x3)
   - Customizable

4. **Minimap features?**
   - Basic (terrain + units)
   - Signals/pings
   - Click-to-move camera
   - Attack-move from minimap

---

## Acceptance Criteria

- [ ] Resource bar shows gold/lumber/food correctly
- [ ] Minimap displays and is clickable
- [ ] Selected unit info updates correctly
- [ ] Command buttons respond to clicks
- [ ] Hotkeys work for commands
- [ ] Tooltips display on hover
- [ ] UI scales with resolution

---

## Notes

UI is half of the player experience. A good UI makes the game playable; a bad UI makes it frustrating even with good gameplay.

**May need successor issues for:**
- Menu system (pause, options)
- Chat/message display
- Alert/notification system
- Custom UI skinning

---

## Related Documents

- issues/501-*.md (render interface)
- issues/505-*.md (default visual mode uses this)
- issues/507-*.md (minimap specific)
