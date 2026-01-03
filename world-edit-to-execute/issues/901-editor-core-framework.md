# Issue 901: Editor Core Framework

**Phase:** 9
**Type:** Implementation
**Priority:** Critical
**Dependencies:** Phase 5 (Rendering), Phase 6 (Assets)

---

## Current Behavior

No map editor exists. Users cannot create or modify WC3-compatible maps.

## Intended Behavior

A foundational editor framework that:
1. Provides the main editor window and viewport
2. Manages editor state (current tool, selection, clipboard)
3. Implements undo/redo system
4. Handles keyboard shortcuts and input
5. Provides the toolbar and palette system
6. Supports play-test mode (run map in engine)

### Editor Layout

```
┌──────────────────────────────────────────────────────────────────┐
│ File  Edit  View  Tools  Module  Window  Help                    │
├──────────────────────────────────────────────────────────────────┤
│ [Terrain] [Doodads] [Units] [Regions] [Cameras] [Triggers] [AI]  │
├────────────────┬─────────────────────────────────┬───────────────┤
│                │                                 │               │
│   PALETTE      │         VIEWPORT                │  PROPERTIES   │
│                │                                 │               │
│  ┌──────────┐  │    ┌─────────────────────┐     │  ┌─────────┐  │
│  │ Brush    │  │    │                     │     │  │ Name:   │  │
│  │ [====]   │  │    │   3D/2D Map View    │     │  │ X: 100  │  │
│  │          │  │    │                     │     │  │ Y: 200  │  │
│  │ Objects: │  │    │   Click to select   │     │  │ Scale:  │  │
│  │ ○ Tree   │  │    │   Drag to move      │     │  │ Angle:  │  │
│  │ ○ Rock   │  │    │   Ctrl+Z to undo    │     │  │         │  │
│  │ ○ Shrub  │  │    │                     │     │  └─────────┘  │
│  └──────────┘  │    └─────────────────────┘     │               │
│                │                                 │               │
├────────────────┴─────────────────────────────────┴───────────────┤
│ Status: Ready | Objects: 1,234 | Selection: Footman | Pos: 100,50│
└──────────────────────────────────────────────────────────────────┘
```

### Core Systems

| System | Description |
|--------|-------------|
| **Viewport** | 3D map view with camera controls (pan, zoom, rotate) |
| **Palette** | Context-sensitive tool/object selection |
| **Properties** | Inspector for selected object properties |
| **Toolbar** | Quick access to common tools |
| **Undo/Redo** | Command pattern with unlimited history |
| **Clipboard** | Cut/copy/paste objects |
| **Shortcuts** | Configurable keyboard bindings |

### API Design

```lua
local editor = require("editor")

-- Initialize editor
editor.init({
    window_title = "World Editor",
    width = 1920,
    height = 1080,
})

-- State management
editor.set_tool("terrain_raise")
editor.set_selection({unit1, unit2})
local selected = editor.get_selection()

-- Undo/redo
editor.begin_action("Move Units")
-- ... modify objects ...
editor.end_action()

editor.undo()  -- Revert last action
editor.redo()  -- Reapply

-- Clipboard
editor.copy()
editor.paste()
editor.delete()

-- Play test
editor.test_map()  -- Launch map in engine
editor.stop_test()

-- Module registration
editor.register_module("terrain", terrain_module)
editor.register_module("triggers", trigger_module)
```

### Undo/Redo System

```lua
-- Command pattern
local Command = {}

function Command:new(name, do_fn, undo_fn)
    return {
        name = name,
        execute = do_fn,
        undo = undo_fn,
    }
end

-- Example: Move unit command
local move_cmd = Command:new(
    "Move Unit",
    function() unit.x, unit.y = new_x, new_y end,
    function() unit.x, unit.y = old_x, old_y end
)

-- History stack
editor.history:push(move_cmd)
editor.history:undo()  -- Calls move_cmd.undo()
editor.history:redo()  -- Calls move_cmd.execute()
```

## Suggested Implementation Steps

1. Create `src/editor/` directory structure
2. Implement `src/editor/init.lua` - Main editor module
3. Implement `src/editor/viewport.lua` - 3D view with camera
4. Implement `src/editor/palette.lua` - Tool/object palette
5. Implement `src/editor/properties.lua` - Property inspector
6. Implement `src/editor/history.lua` - Undo/redo system
7. Implement `src/editor/clipboard.lua` - Cut/copy/paste
8. Implement `src/editor/shortcuts.lua` - Keyboard bindings
9. Implement `src/editor/modules.lua` - Module registration
10. Create play-test launcher
11. Create tests

## Acceptance Criteria

- [ ] Editor window opens with viewport, palette, properties panels
- [ ] Camera controls work (pan, zoom, rotate)
- [ ] Tool selection changes cursor and behavior
- [ ] Undo/redo works for all modifications
- [ ] Keyboard shortcuts are functional (Ctrl+Z, Ctrl+Y, etc.)
- [ ] Clipboard operations work (Ctrl+C, Ctrl+V, etc.)
- [ ] Play-test launches map in engine
- [ ] Modules can register themselves with editor

## Related Documents

- Phase 5 - Render interface (viewport rendering)
- Phase 6 - Asset system (loading editor assets)
- Issue 506 - UI framework (panel system)

## Notes

- Consider using immediate-mode GUI (like Dear ImGui) for editor UI
- Undo history should have configurable depth limit
- May want "action grouping" for related changes (e.g., multi-select move)
- Autosave feature important for editor
- Consider "preferences" system for user settings
