# Issue 503: Build Sprite/Model Placeholder System

**Phase:** 5 - Rendering
**Type:** Feature
**Priority:** High
**Dependencies:** 501-create-abstract-render-interface

---

## Current Behavior

Units, buildings, and effects exist as ECS entities with position data, but have no visual representation. The runtime tracks their state without rendering anything.

---

## Intended Behavior

Placeholder visual system that:
- Renders units as colored shapes (circles, rectangles)
- Distinguishes unit types by color/size
- Shows player ownership via team colors
- Displays selection indicators
- Renders health bars above units
- Works without any external art assets

**Philosophy:** Per project vision, we're building an "emulator" - community supplies visuals. This system provides functional placeholders until real assets are loaded.

**Placeholder Styles:**
```
Unit Types:
  - Infantry: Small circle
  - Cavalry: Medium circle
  - Siege: Large rectangle
  - Hero: Circle with star
  - Building: Rectangle with fill

Visual Indicators:
  - Team color: Fill/border color
  - Selection: Glowing ring
  - Health: Bar above unit
  - Mana: Secondary bar (heroes)
  - Status effects: Small icons
```

---

## Suggested Implementation Steps

1. **Create sprite system module**
   ```lua
   -- src/render/sprites.lua
   local sprites = {}

   function sprites.register_type(type_id, config) end
   function sprites.draw_entity(entity, renderer, camera) end
   function sprites.draw_selection(entity, renderer) end
   function sprites.draw_health_bar(entity, renderer) end
   ```

2. **Define unit visual mappings**
   - Map WC3 unit type IDs to placeholder shapes
   - Define size categories (tiny, small, medium, large, huge)
   - Assign default colors per race

3. **Implement team color system**
   - 12 player colors (matching WC3)
   - Neutral colors for creeps/neutrals
   - Color-blind friendly options

4. **Create selection visuals**
   - Circle under selected units
   - Multiple selection support
   - Selection box (drag select)

5. **Implement health/mana bars**
   - Position above units
   - Color-coded (green/yellow/red for health)
   - Optional: show on hover only

6. **Add facing indicator**
   - Small line/arrow showing unit direction
   - Important for understanding movement

---

## Design Questions for User

1. **Placeholder aesthetic?**
   - Geometric (circles, squares)
   - Iconic (simple unit silhouettes)
   - Debug (entity IDs, component data)

2. **Information density?**
   - Minimal (just shapes and colors)
   - Standard (health bars, selection)
   - Detailed (all stats visible)

3. **Selection style?**
   - WC3-style (green circle)
   - RTS-style (box outline)
   - Highlight (glow effect)

4. **Scale consistency?**
   - Accurate to WC3 unit sizes
   - Normalized (all similar size)
   - Exaggerated for visibility

---

## Acceptance Criteria

- [ ] Units render as colored shapes
- [ ] Player colors distinguish ownership
- [ ] Selected units have visual indicator
- [ ] Health bars display correctly
- [ ] Different unit types look different
- [ ] Moving units show facing direction
- [ ] Works with camera zoom

---

## Notes

This is the primary visual feedback for gameplay. Even with placeholder graphics, the game should be playable and understandable.

**May need successor issues for:**
- Real sprite/texture loading
- Animation system
- Effect/particle rendering
- Building construction visualization

---

## Initial Analysis

**Analysis Date:** 2025-12-29

### Recommendation: SPLIT

This issue has 6 implementation steps with logically distinct visual systems:

| ID | Name | Dependencies | Description |
|----|------|--------------|-------------|
| 503a | core-sprite-system | 501 | Sprite module, type registration, basic draw_entity function |
| 503b | unit-visual-mappings | 503a | Map WC3 unit IDs to placeholder shapes, size categories, race colors |
| 503c | team-colors-selection | 503a | 12 player colors, neutral colors, selection ring visuals |
| 503d | health-bars-indicators | 503a | Health/mana bars, status icons, positioning above units |
| 503e | facing-direction | 503a | Arrow/line showing unit direction, updates with movement |

### Rationale

1. **Separable visual features**: Health bars and selection rings are independent systems
2. **Team colors shared**: The color system is used by both sprites and health bars - extract early
3. **Facing is optional**: Can ship without facing indicator, add it for polish
4. **Testable in isolation**: Each visual element can be verified independently

### Execution Order

```
503a (core) → 503b (mappings) → 503c (colors + selection)
          └─→ 503d (health bars)
          └─→ 503e (facing)
```

---

## Related Documents

- issues/501-*.md (render interface)
- issues/504-*.md (asset loading)
- src/runtime/ecs/wc3_components.lua (unit data)

---

## Generated Sub-Issues

*Auto-generated on 2025-12-29 19:39*

- 503a-core-sprite-system.md
- 503b-unit-visual-mappings.md
- 503c-team-colors-selection.md
- 503d-health-bars-indicators.md
- 503e-facing-direction.md
