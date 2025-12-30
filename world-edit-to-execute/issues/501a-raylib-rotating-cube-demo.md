# Issue 501a: Raylib Rotating Cube Demo

## Current Behavior

No rendering system exists for the project. Phase 5 focuses on visual abstraction, but we need a foundation to build upon.

## Intended Behavior

A minimal raylib-based renderer that:
- Displays a rotating blue cube in 3D space
- Uses the thread-pool pattern from `/home/ritz/programming/c/games/template/`
- Separates render thread from game logic thread
- Provides a foundation for future terrain and entity rendering

## Suggested Implementation Steps

### 1. Create Directory Structure

```
src/render/
├── main.c          # Entry point with thread setup
├── cube_demo.c     # Rotating cube demo implementation
└── run             # Build and run script
```

### 2. Implement Rotating Cube

Using raylib's 3D API:
- `Camera3D` for perspective view
- `BeginMode3D()` / `EndMode3D()` for 3D drawing context
- `DrawCube()` or `DrawCubeWires()` for the cube
- Rotation via angle increment per frame

### 3. Thread Architecture

Following template pattern:
- `draw()` thread handles rendering loop
- `game()` thread handles logic updates
- Shared state via struct pointer passed to both threads
- pthread for thread management

### 4. Build Script

Based on template's run script:
- Links against raylib
- Uses `-pthread` flag
- Outputs compiler log for debugging

## Related Documents

- Template: `/home/ritz/programming/c/games/template/`
- Issue 501 - Create abstract render interface (parent)
- Phase 5 roadmap

## Acceptance Criteria

- [ ] Blue cube renders in 3D perspective
- [ ] Cube rotates continuously
- [ ] Render thread separated from game thread
- [ ] Build script compiles and runs successfully
- [ ] Window closes cleanly on exit

---

**Status:** In Progress
**Dependencies:** None (Phase 5 starter)
**Priority:** High

