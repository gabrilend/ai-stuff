# Issue 103: Create Raylib Window

## Current Behavior

No graphics initialization exists.

## Intended Behavior

A raylib window that:
- Opens at specified resolution (800x600 default)
- Runs at 60fps target
- Responds to window close event
- Clears to dark gray background each frame
- Displays basic "Physics Simulator" title

## Suggested Implementation Steps

1. Create src/001-main.c
2. Include raylib.h
3. Implement main():
   - Call InitWindow(800, 600, "Physics Simulator - Pachinko")
   - Call SetTargetFPS(60)
   - Enter main loop while (!WindowShouldClose())
   - In loop: BeginDrawing(), ClearBackground(DARKGRAY), EndDrawing()
   - After loop: CloseWindow()
4. Test compilation and execution
5. Verify window opens and closes cleanly
6. Verify no memory leaks with valgrind

## Related Documents

- [004-raylib-integration.md](../docs/004-raylib-integration.md)
- [006-build-instructions.md](../docs/006-build-instructions.md)

## Dependencies

- Issue 101 (Makefile) must be complete first

## Status

- [ ] Not started
