# Issue 510: Add Scrolling Viewport

## Current Behavior

The game board is fixed to the window size (800x600). If the board
is expanded in the future, there's no way to view areas outside
the viewport.

## Intended Behavior

Implement scrolling mechanic:
- Mouse scroll wheel moves viewport up/down
- View can be scrolled within the game world bounds
- Allows viewing larger boards when expanded
- UI elements stay fixed to screen (not scrolled)

## Suggested Implementation Steps

1. Add viewport offset variables:
   ```c
   float viewport_offset_y = 0.0f;  // Current vertical offset
   float world_height = 600.0f;     // Total world height (can expand)
   ```

2. Handle scroll wheel input:
   ```c
   float scroll = GetMouseWheelMove();
   viewport_offset_y -= scroll * SCROLL_SPEED;
   ```

3. Clamp viewport to valid range:
   ```c
   if (viewport_offset_y < 0) viewport_offset_y = 0;
   if (viewport_offset_y > world_height - screen_height)
       viewport_offset_y = world_height - screen_height;
   ```

4. Apply offset when rendering world elements:
   - Pegs: y - viewport_offset_y
   - Balls: y - viewport_offset_y
   - Zones: y - viewport_offset_y
   - Particles: y - viewport_offset_y

5. Keep UI fixed (don't apply offset):
   - Score panel
   - Controls panel
   - Title

6. Option: Use raylib camera system:
   ```c
   Camera2D camera = { 0 };
   camera.offset = (Vector2){ screen_width/2, screen_height/2 };
   camera.target = (Vector2){ screen_width/2, screen_height/2 + viewport_offset_y };
   camera.zoom = 1.0f;

   BeginMode2D(camera);
   // Draw world elements
   EndMode2D();
   // Draw UI (outside camera)
   ```

7. Add visual indicator showing scroll position (optional)

8. Test with expanded world height

9. Test compilation with no warnings

## Design Notes

Two approaches:
1. Manual offset: Subtract offset from all world element y-positions
2. Camera2D: Use raylib's built-in camera system (cleaner)

Camera2D approach is preferred:
- Built into raylib
- Cleaner separation of world vs UI
- Easier to add zoom later

For now, world_height = screen_height (no scrolling needed).
When board is expanded, increase world_height.

## Success Criteria

- Scroll wheel moves viewport up/down
- World elements scroll correctly
- UI stays fixed to screen
- Viewport clamped to valid range
- No visual glitches when scrolling
- Works when world height equals screen height (no movement)
- Compiles with no warnings

## Related Documents

- [001-main.c](../src/001-main.c)
- [004-raylib-integration.md](../docs/004-raylib-integration.md)

## Dependencies

- None (independent feature)

## Status

- [ ] Pending
