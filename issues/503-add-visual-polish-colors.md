# Issue 503: Add Visual Polish and Colors

## Current Behavior

Visual elements use basic colors:
- Background: DARKGRAY
- Pegs: LIGHTGRAY circles
- Balls: ORANGE circles
- Score zones: Basic colored rectangles with text
- UI text: WHITE/GRAY

The visuals are functional but lack polish and visual interest.

## Intended Behavior

Enhanced visual presentation:
- Gradient or themed background
- Peg visual improvements (outlines, highlights)
- Ball visual improvements (gradient, glow effect)
- Score zone visual improvements (borders, highlights)
- Consistent color scheme throughout

## Suggested Implementation Steps

1. Define color palette constants in a new section:
   ```c
   // Visual constants
   #define BG_COLOR (Color){30, 30, 40, 255}        // Dark blue-gray
   #define PEG_COLOR (Color){180, 180, 200, 255}    // Light steel
   #define PEG_OUTLINE (Color){100, 100, 120, 255}  // Darker outline
   #define BALL_COLOR (Color){255, 180, 50, 255}    // Warm orange
   #define BALL_HIGHLIGHT (Color){255, 220, 150, 255} // Lighter center
   ```

2. Update world_render_pegs() with improved peg rendering:
   - Draw filled circle with PEG_COLOR
   - Draw outline circle with PEG_OUTLINE
   - Optional: Add subtle highlight on top-left

3. Update ball_manager_render() with improved ball rendering:
   - Draw main circle with BALL_COLOR
   - Draw smaller highlight circle offset toward top-left
   - Creates 3D sphere illusion

4. Update world_render_zones() with improved zone rendering:
   - Add borders to zones
   - Alternate zone colors for visual distinction
   - Improve point value text readability

5. Update main loop background:
   - Replace ClearBackground(DARKGRAY) with BG_COLOR
   - Consider subtle gradient or pattern

6. Add title bar visual improvement:
   - Semi-transparent background behind title
   - Better text styling

7. Test compilation with no warnings

## Design Notes

Color scheme philosophy:
- Dark background for contrast
- Warm ball colors for visibility
- Cool peg colors for depth
- High contrast score zones

Raylib color utilities:
- Color is {r, g, b, a} struct
- ColorAlpha() for transparency
- Can use DrawCircleGradient() for gradients

Performance considerations:
- Additional draw calls have minimal impact
- Avoid per-pixel operations in rendering
- Batch similar draw operations where possible

Visual hierarchy:
- Balls should be most visible (active gameplay)
- Pegs are environmental (less prominent)
- Score zones are important but static
- UI should be readable but not dominant

## Success Criteria

- Cohesive color scheme throughout
- Improved peg visuals with depth
- Improved ball visuals with highlight
- Improved zone visuals with borders
- Clean background color
- No visual glitches
- Maintains 60fps performance
- Compiles with no warnings

## Related Documents

- [004-raylib-integration.md](../docs/004-raylib-integration.md)
- [005-world.c](../src/005-world.c)
- [007-ball.c](../src/007-ball.c)

## Dependencies

- Issue 502 (Scoring system) - Recommended first

## Status

- [ ] Pending
