# Issue 505: Implement Default Visual Mode

**Phase:** 5 - Rendering
**Type:** Feature
**Priority:** High
**Dependencies:** 501, 502, 503

---

## Current Behavior

No working visual mode exists. The engine runs headlessly with no graphical output.

---

## Intended Behavior

A complete, working visual mode that:
- Runs without any external asset packs
- Uses geometric/wireframe placeholders
- Displays all game elements functionally
- Serves as reference implementation for renderers
- Is actually playable (not just a tech demo)

**This is the "batteries included" mode** - download the engine, load a map, see something working immediately.

**Visual Style:**
```
Terrain:  Colored grid cells (green=grass, brown=dirt, blue=water)
Units:    Colored circles with team colors and facing arrows
Buildings: Colored rectangles with progress bars
Selection: Highlighted ring around selected units
UI:       Simple rectangles with text labels
Minimap:  Scaled-down terrain view with unit dots
```

---

## Suggested Implementation Steps

1. **Create default renderer**
   ```lua
   -- src/render/backends/default.lua
   -- Implements 501 interface using basic primitives
   ```

2. **Wire up all systems**
   - Terrain from 502
   - Sprites from 503
   - Connect to ECS for entity positions
   - Connect to player system for team colors

3. **Implement game view**
   - Main map viewport
   - Camera controls (pan, zoom)
   - Unit rendering with health bars
   - Selection visualization

4. **Add minimal UI**
   - Resource display (gold, lumber, food)
   - Selected unit info panel
   - Minimap in corner
   - Game time display

5. **Create command interface**
   - Click to select
   - Right-click to move
   - Drag to box select
   - Keyboard shortcuts

6. **Add debug overlays (toggle-able)**
   - Pathing grid
   - Collision shapes
   - Entity IDs
   - FPS counter

---

## Design Questions for User

1. **Renderer backend for default mode?**
   - Terminal/TUI (no dependencies, limited visuals)
   - LÖVE2D (recommended - easy, powerful)
   - SDL2 + Lua bindings
   - Raylib

2. **Minimum resolution?**
   - 800x600 (retro)
   - 1280x720 (modern minimum)
   - 1920x1080 (full HD)
   - Adaptive

3. **Input handling?**
   - Mouse only
   - Keyboard + Mouse
   - Gamepad support?

4. **Debug features scope?**
   - Developer only (hidden)
   - User accessible (toggle menu)
   - Always visible option

---

## Acceptance Criteria

- [ ] Engine starts and shows visual output
- [ ] Map terrain is visible
- [ ] Units render and are distinguishable
- [ ] Selection works (click and drag)
- [ ] Movement orders work (right-click)
- [ ] Resources display correctly
- [ ] Camera pan and zoom work
- [ ] Minimap shows map overview
- [ ] 60 FPS on reasonable hardware

---

## Notes

This is the "moment of truth" - where the engine becomes visually real. Everything before this was infrastructure; this is where users can see the game.

**May need successor issues for:**
- Terminal-only mode (for servers/CI)
- GPU-accelerated mode
- Multiple window support
- Recording/replay visualization

---

## Initial Analysis

**Analysis Date:** 2025-12-29

### Recommendation: SPLIT

This is the integration issue that brings together 501-504. It has distinct subsystems:

| ID | Name | Dependencies | Description |
|----|------|--------------|-------------|
| 505a | default-renderer-backend | 501 | Concrete renderer implementation (LÖVE2D/SDL/terminal) |
| 505b | wire-render-systems | 505a, 502, 503 | Connect terrain, sprites, ECS, player systems |
| 505c | game-view-camera | 505b, 501d | Main viewport, pan/zoom controls, unit rendering |
| 505d | minimal-ui | 505b, 506 | Resource display, unit info panel, game time |
| 505e | input-commands | 505c | Click select, right-click move, box select, hotkeys |
| 505f | debug-overlays | 505b | Pathing grid, collision shapes, entity IDs, FPS counter |

### Rationale

1. **Backend choice critical**: The specific renderer backend affects all other sub-issues
2. **Input handling complex**: Selection, movement, drag-select - significant interaction logic
3. **Debug overlays optional**: Can ship without, add for developer convenience
4. **Testable progression**: Each stage is visually verifiable

### Execution Order

```
505a (backend) → 505b (wiring) → 505c (game view) → 505e (input)
                            └─→ 505d (UI)
                            └─→ 505f (debug)
```

### Note

This issue depends heavily on 501-504. Several sub-issues here require those foundations:
- 505a requires 501a-c to implement against the interface
- 505d requires 506 (UI framework) - consider ordering
- 505b requires 502 and 503 to have functional renderers

---

## Related Documents

- issues/501-507 (all Phase 5 issues)
- issues/408e (Phase 4 visual demo - simpler version)
- docs/roadmap.md

---

## Generated Sub-Issues

*Auto-generated on 2025-12-29 19:39*

- 505a-default-renderer-backend.md
- 505b-wire-render-systems.md
- 505c-game-view-camera.md
- 505d-minimal-ui.md
- 505e-input-commands.md
- 505f-debug-overlays.md
