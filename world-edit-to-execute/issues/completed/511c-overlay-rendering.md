# Issue 511c: Overlay Rendering

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 511a (core timing), 511b (thread-safe recording)

---

## Current Behavior

No visual profiler overlay exists.

---

## Intended Behavior

A semi-transparent overlay showing:

1. Frame number, FPS, frame time
2. Per-thread timing bars (Updater, Workers, Sync, Draw, Lua)
3. Percentage of frame budget used
4. Slot usage and swap count

---

## Suggested Implementation Steps

1. Add to `profiler.c`:
   - `profile_draw_overlay()` - render the profiler UI
   - `g_profile_visible` flag
   - Use Raylib's DrawRectangle, DrawText

2. Layout:
   - Position: bottom-left corner
   - Size: 350x200 pixels
   - Background: semi-transparent black
   - Bars: green fill proportional to time

3. Integration in main.c:
   - Call `profile_draw_overlay()` after EndDrawing()
   - F3 key toggles visibility

---

## Acceptance Criteria

- [ ] Overlay renders correctly at 60 FPS
- [ ] Shows frame number, FPS, dt (ms)
- [ ] Per-thread timing bars with names
- [ ] Percentage labels
- [ ] F3 toggles visibility
- [ ] Overlay does not flicker

---

## Notes

Draw overlay after EndDrawing() but before buffer swap, or use a separate drawing pass.
