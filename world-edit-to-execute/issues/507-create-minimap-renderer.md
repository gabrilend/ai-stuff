# Issue 507: Create Minimap Renderer

**Phase:** 5 - Rendering
**Type:** Feature
**Priority:** Medium
**Dependencies:** 501, 502, 506

---

## Current Behavior

No minimap exists. Players have no way to see the full map at a glance or quickly navigate to different areas.

---

## Intended Behavior

Minimap system that:
- Shows scaled-down view of entire map
- Displays terrain types as colors
- Shows unit positions as colored dots
- Indicates camera viewport position
- Supports click-to-move camera
- Updates in real-time

**Minimap Features:**
```
┌──────────────────┐
│  ░░░▓▓░░░░░░░░  │  ░ = Land (various colors by type)
│  ░░░▓▓▓░░░░█░░  │  ▓ = Trees/obstacles
│  ░░░░░░░░░░░░░  │  █ = Buildings
│  ░●░░░░░░░○░░░  │  ● = Your units (team color)
│  ┌───┐░░░░░░░░  │  ○ = Enemy units (if visible)
│  │   │░░░░░░░░  │  ┌─┐ = Camera viewport
│  └───┘░░░░░░░░  │
└──────────────────┘
```

---

## Suggested Implementation Steps

1. **Create minimap module**
   ```lua
   -- src/render/minimap.lua
   local minimap = {}

   function minimap.init(terrain_data, size) end
   function minimap.update(entities, camera) end
   function minimap.draw(renderer, x, y) end
   function minimap.handle_click(mx, my) end
   ```

2. **Generate terrain texture**
   - Pre-render terrain to small texture
   - Color-code by tile type
   - Cache and update only when needed

3. **Render unit dots**
   - Scale world positions to minimap
   - Use team colors
   - Size by unit type (heroes bigger)
   - Blink for alerts

4. **Show camera viewport**
   - Rectangle showing visible area
   - Update as camera moves
   - Visible bounds indicator

5. **Implement interaction**
   - Left-click: move camera to location
   - Right-click: issue move command
   - Drag: pan camera continuously

6. **Add ping system**
   - Players can ping locations
   - Visual + audio feedback
   - Temporary markers on minimap

---

## Design Questions for User

1. **Minimap shape?**
   - Square (WC3 default)
   - Rectangular (matches map aspect)
   - Circular (SC2 style)

2. **Minimap position?**
   - Bottom-left (WC3)
   - Bottom-right
   - Configurable

3. **Zoom levels?**
   - Fixed scale
   - Scroll to zoom minimap
   - Strategic zoom mode

4. **Fog of war on minimap?**
   - Yes (realistic)
   - Partial (show terrain, hide units)
   - No (god mode)

---

## Acceptance Criteria

- [ ] Minimap renders terrain colors correctly
- [ ] Unit positions shown as dots
- [ ] Team colors distinguish ownership
- [ ] Camera viewport rectangle visible
- [ ] Left-click moves camera
- [ ] Updates in real-time
- [ ] Doesn't impact performance significantly

---

## Notes

The minimap is essential for strategic gameplay. Players need to quickly assess the whole map and navigate to action.

**May need successor issues for:**
- Fog of war integration
- Ping/signal system
- Minimap alerts (under attack)
- Recording indicators

---

## Initial Analysis

**Analysis Date:** 2025-12-29

### Recommendation: SPLIT

This issue has 6 steps with distinct rendering and interaction concerns:

| ID | Name | Dependencies | Description |
|----|------|--------------|-------------|
| 507a | minimap-module | 506 | Core module, init from terrain data, basic draw function |
| 507b | terrain-texture | 507a, 502 | Pre-render terrain to small texture, color-code by tile type |
| 507c | unit-dots | 507a, 503 | Scale positions to minimap, team colors, size by unit type |
| 507d | camera-viewport | 507a, 501d | Rectangle showing visible area, updates with camera |
| 507e | minimap-interaction | 507a-d | Left-click to move camera, right-click for commands, drag pan |
| 507f | ping-system | 507e | Player pings, visual + audio feedback, temporary markers |

### Rationale

1. **Terrain texture is cached**: Pre-rendering logic is distinct from real-time updates
2. **Interaction is complex**: Three input types (left-click, right-click, drag) with different behaviors
3. **Ping system optional**: Social feature, can ship without initially
4. **Unit dots update frequently**: Different update cadence than terrain

### Execution Order

```
507a (module) → 507b (terrain) ──────────────────┐
           └─→ 507c (units) ─────────────────────┼→ 507e (interaction) → 507f (pings)
           └─→ 507d (viewport) ──────────────────┘
```

---

## Related Documents

- issues/502-*.md (terrain data)
- issues/506-*.md (UI framework)
- src/parsers/w3e.lua (terrain source)

---

## Generated Sub-Issues

*Auto-generated on 2025-12-29 19:39*

- 507a-minimap-module.md
- 507b-terrain-texture.md
- 507c-unit-dots.md
- 507d-camera-viewport.md
- 507e-minimap-interaction.md
- 507f-ping-system.md
