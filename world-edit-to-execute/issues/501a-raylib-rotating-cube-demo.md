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

- [x] Blue cube renders in 3D perspective
- [x] Cube rotates continuously
- [x] Render thread separated from game thread
- [x] Build script compiles and runs successfully
- [x] Window closes cleanly on exit

---

**Status:** Completed
**Dependencies:** None (Phase 5 starter)
**Priority:** High

---

## Implementation Notes

*Completed 2025-12-29*

### Files Created

1. **src/render/main.c** (~280 lines)
   - Thread-pool architecture with pthread
   - `draw()` thread handles raylib rendering
   - `game()` thread updates rotation state
   - Mutex-protected shared GameState struct
   - Camera3D for perspective view
   - rlgl transformations for rotation

2. **src/render/run** - Build script
   - Based on template pattern
   - Links raylib, pthread, GL, X11
   - Accepts DIR as argument for portability

### Key Design Decisions

- **Data-driven architecture**: Cube defined only by mesh data + material pointer
- **Minimal mesh storage**: Just `float size` + optional EdgeMod array
  - EdgeMod allows storing modified edges between vertices (indices 0-7)
  - NULL edge_mods = perfect cube, no vertex array needed
- Used `rlPushMatrix()/rlRotatef()/rlPopMatrix()` for cube rotation
- Added gentle X-axis wobble using sine wave for visual interest
- Pure black background for contrast
- Chunky/fuzzy voxel-like appearance (not smooth blender-render)
- Color variation per chunk for textured effect
- Renamed `Material` to `ChunkMaterial` to avoid raylib conflict

### Data Structures

```c
MeshData:    float size, EdgeMod* edge_mods, int edge_mod_count
EdgeMod:     int v1, int v2, float offset
ChunkMaterial: Color base_color, edge_color, float chunk_size, bool wireframe
Entity:      MeshData*, ChunkMaterial*, Vector3 position, Vector3 rotation
```

### To Run

```bash
./src/render/run
# or with custom directory:
./src/render/run /path/to/project
```

### Dependencies

- raylib (at /home/ritz/programming/c/libs/raylib/src/)
- pthread
- X11, GL, dl, rt (standard Linux libs)

