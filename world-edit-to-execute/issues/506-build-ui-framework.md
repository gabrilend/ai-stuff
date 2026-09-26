# Issue 506: Build UI Framework

**Phase:** 5 - Rendering
**Type:** Feature
**Priority:** High
**Dependencies:** 501 (the page format), 501d (the camera)
**Re-cut:** 2026-09-26, from "Build UI Framework" (its WoW-mode parts, chat modes and breakout windows, came from the archived 510 and are dropped)

---

## Current Behavior

The vertical slice draws a minimal interface in C (`src/render/ui.c`,
508g): a top bar with resources and game time, and a bottom panel with the
selected unit's name and hit points. Input (`src/render/input.c`) picks
units in the world; nothing checks whether a click landed on the
interface first.

## Intended Behavior

WC3's game interface: the top bar (resources, upkeep, time, menu buttons),
the bottom console (minimap 507, portrait, selection info or group, the
4-by-3 command grid 506e), tooltips (506f), and the screens the game
needs, among them the model-override screen (516, 504).

How it fits the split decided on 2026-09-26: the interface's elements are
**items on the page**, built each frame by C boxes from the game state
(what is selected, what it can do), and drawn by the raylib renderer like
everything else. Layout is worked out when the window's size changes, not
every frame. Clicks are tested against the interface's rectangles before
the world. Whether this is the owner's intent is open question 1.

The sub-issues:

| ID | What |
|----|------|
| 506a | the element list: what an interface element is on the page |
| 506b | layout: anchors resolved to screen rectangles on resize |
| 506c | input: interface first, then the world |
| 506d | the basic elements: panel, text, button, bar, icon |
| 506e | the command grid from the selection's abilities |
| 506f | tooltips from object data and the map's strings |

## Suggested Implementation Steps

1. Settle open question 1.
2. 506a and 506b, then 506c, then 506d; 506e and 506f on top.

## Acceptance Criteria

- [ ] The top bar and bottom console show the game's state as WC3 does
- [ ] Clicks on the interface never reach the world
- [ ] The interface keeps its layout at any window size

## Open Questions

1. Is the interface built into the page by C boxes, as above, or kept in
   Lua writing into a buffer the renderer draws? (`issues/CRITICAL-PATH.md`,
   Q-4; the page split suggests the first.)

---

## Earlier Design (January 2026, for a Lua renderer interface)

Kept as the record; not built as written.

### Current Behavior

No UI system exists. Game information cannot be displayed to players, and there's no way to receive user input through interface elements.

---

### Intended Behavior

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

### Suggested Implementation Steps

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

### Design Questions for User

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

### Acceptance Criteria

- Resource bar shows gold/lumber/food correctly
- Minimap displays and is clickable
- Selected unit info updates correctly
- Command buttons respond to clicks
- Hotkeys work for commands
- Tooltips display on hover
- UI scales with resolution

---

### Notes

UI is half of the player experience. A good UI makes the game playable; a bad UI makes it frustrating even with good gameplay.

**May need successor issues for:**
- Menu system (pause, options)
- Chat/message display
- Alert/notification system
- Custom UI skinning

---

### Initial Analysis

**Analysis Date:** 2025-12-29

#### Recommendation: SPLIT

This is a substantial issue with 6 distinct subsystems. Each is a complete feature:

| ID | Name | Dependencies | Description |
|----|------|--------------|-------------|
| 506a | ui-component-system | 501 | Base component class, panel/button/label/icon/bar primitives |
| 506b | layout-system | 506a | Anchoring, relative/absolute positioning, responsive scaling |
| 506c | input-handling | 506a | Mouse hover, click, keyboard focus, hotkey system |
| 506d | core-ui-elements | 506a-c | Resource bar, minimap panel, unit info, command panel |
| 506e | command-button-grid | 506c, 506d | 12-button grid, hotkey labels, cooldown display |
| 506f | tooltip-system | 506a, 506c | Hover tooltips, hotkey display, unit/ability info |

#### Rationale

1. **Each subsystem is substantial**: Layout alone has 4 features (anchoring, relative, absolute, responsive)
2. **Clear dependencies**: Input handling needs components; core elements need layout
3. **WC3-faithful UI is complex**: The command panel with hotkeys and context-switching is significant
4. **Reusable foundation**: UI framework will be used by both Warcraft and WoW-chat modes

#### Execution Order

```
506a (components) → 506b (layout) → 506d (core elements) → 506e (command grid)
               └─→ 506c (input) ────────────────────────┘
                                                     └─→ 506f (tooltips)
```

#### Dual Interface Note (ref: Issue 500, CRITICAL-PATH OQ-007)

This framework must support both Warcraft RTS and WoW-chat modes:
- **Shared**: Component system, layout engine, input handling
- **Mode-specific**: Visual themes, element arrangement, information density

**Window Management (decided 2025-12-31):**
UI panels can be "breakout windows" that are either:
- **OS-managed**: Standard window decorations, moved via OS window manager
- **Client-managed**: Software window management, drag within client

**WC3 Default Layout:**
- Permanent panels along top and bottom limit viewport
- Overlay menus (ESC menu, etc.) appear on top of all elements
- Single-player: overlays pause the game
- Multiplayer: overlays do not pause

**View Modes:**
- Picture-in-picture (small overlay views)
- Split screen (side by side)
- Separate windows (multi-monitor support)

See Issue 500 "Decided Answers" section D2 for full details.

---

### Related Documents

- issues/501-*.md (render interface)
- issues/505-*.md (default visual mode uses this)
- issues/507-*.md (minimap specific)

---

### Generated Sub-Issues

*Auto-generated on 2025-12-29 19:39*

- 506a-ui-component-system.md
- 506b-layout-system.md
- 506c-input-handling.md
- 506d-core-ui-elements.md
- 506e-command-button-grid.md
- 506f-tooltip-system.md
