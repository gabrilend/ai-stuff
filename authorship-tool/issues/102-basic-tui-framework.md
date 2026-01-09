# Issue 102: Basic TUI Framework

**Phase**: 1 - Foundation & Core Infrastructure
**Status**: Open
**Priority**: High
**Created**: 2026-01-08

---

## Current Behavior

No user interface exists. The project needs a terminal-based interface for displaying content and receiving input.

---

## Intended Behavior

The system should:
- Display text content in a structured layout
- Handle keyboard input (navigation, commands)
- Support basic screen regions (header, content, status bar)
- Blit character codes to TTY memory for efficient updates
- Maintain frame-based rendering with dirty region tracking
- Separate data model from display logic
- Provide basic text viewing/scrolling capabilities
- Support vim-style keybindings for navigation

---

## Suggested Implementation Steps

1. Research TUI library options for Lua (check /home/ritz/programming/ai-stuff/libs/)
2. Create `src/tui/` directory for TUI components
3. Create `src/tui/screen.lua` for screen management
4. Implement basic layout system (header, content, status)
5. Implement character blitting to TTY memory
6. Create input handler for keyboard events
7. Implement scrolling for content area
8. Create basic text renderer
9. Implement dirty region tracking for efficient updates
10. Add vim-style navigation (j/k for up/down, etc.)
11. Create test program that displays sample text
12. Document TUI interface in src/tui/screen.info.md

---

## Related Documents

- docs/technical-design.md (TUI Implementation section)
- docs/roadmap.md (Phase 1)
- User's global libs at /home/ritz/programming/ai-stuff/libs/

---

## Implementation Notes

**Screen Layout**:
```
┌─────────────────────────────────────────────────────┐
│ Authorship Tool v1.0          [Status]             │  <- Header
├─────────────────────────────────────────────────────┤
│                                                     │
│  Content Area                                       │  <- Content
│  (scrollable text display)                          │
│                                                     │
├─────────────────────────────────────────────────────┤
│ Status: Ready                                       │  <- Status
└─────────────────────────────────────────────────────┘
```

**Key Bindings** (initial set):
- j/k or arrow keys: scroll up/down
- q: quit
- h: help
- r: refresh

**Performance Considerations**:
- Only update changed regions (dirty tracking)
- Use double-buffering to prevent flicker
- Batch screen updates per frame

---

## Testing Criteria

- [ ] Screen displays correctly in terminal
- [ ] Layout regions render in correct positions
- [ ] Keyboard input handled correctly
- [ ] Scrolling works smoothly
- [ ] Vim-style navigation responsive
- [ ] No screen flicker during updates
- [ ] Can display long text documents
- [ ] Status bar updates correctly

---

## Dependencies

- 101 (module loading framework) - TUI will be loaded as module

---

## Blocks

- 103 (document reader needs display)
- Phase 1 demo (needs TUI for display)
