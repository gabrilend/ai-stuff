# Issue 508: Vertical Slice - Testing Room

**Phase:** 5 - Rendering
**Type:** Integration / Milestone
**Priority:** Critical
**Dependencies:** 501a (raylib demo completed)

---

## Purpose

Create a minimal playable demo as quickly as possible. Rather than completing all
Phase 5 infrastructure before seeing results, this issue cuts a **vertical slice**
through the systems to get:

- Units rendering on screen
- Player input moving units
- Basic UI showing state

This validates the architecture from `docs/render-architecture.md` and provides
a testing ground for subsequent work.

---

## Current Behavior

- Raylib rotating cube demo works (501a complete)
- Threading model documented but not implemented
- No entity rendering, no input, no game integration

---

## Intended Behavior

A runnable demo where:

1. **Map loads** - Terrain grid visible (colored tiles)
2. **Units render** - Colored shapes at positions from ECS
3. **Selection works** - Click to select, visual feedback
4. **Movement works** - Right-click to issue move order, unit moves
5. **UI displays** - Selected unit info, basic resource display

```
┌────────────────────────────────────────────────┐
│  Gold: 500   Lumber: 200   Food: 5/12          │
├────────────────────────────────────────────────┤
│                                                │
│      ┌──┐                                      │
│      │▲ │  ← Selected unit (highlighted)       │
│      └──┘                                      │
│                    ┌──┐ ┌──┐                   │
│                    │● │ │● │  ← Other units    │
│                    └──┘ └──┘                   │
│                                                │
│   [terrain grid with colors]                   │
│                                                │
├────────────────────────────────────────────────┤
│  Unit: Footman   HP: 100/100   [Move] [Stop]   │
└────────────────────────────────────────────────┘
```

---

## Architecture Reference

This implementation follows `docs/render-architecture.md`:

### Threading Model

```
[Updater] → [Worker Inputs] → [Workers] → [Worker Outputs] → [Sync] → [Primary Buffer] → [Draw]
```

- **Workers** compute final render-ready positions (transforms done here)
- **Sync thread** swaps pointers (near-zero work)
- **Draw thread** iterates primary buffer, issues GPU commands

### Component Slot System

Each renderable entity has a `ComponentSlot` with:
- `data` pointer to GPU-ready struct
- `set` function pointer (mise en place - swap + free old)
- `free_fn` for type-specific cleanup

### Numeric Encoding

No division. Directional bitfields for spatial calculations where applicable.
See render-architecture.md for details.

---

## Suggested Implementation Steps

### 508a: Threading Infrastructure (C)

Extend `src/render/main.c`:

1. Add worker thread pool (initially 2 workers)
2. Add sync thread with output pointer swapping
3. Add updater thread with input buffer population
4. Define `ComponentSlot` struct with `set`/`free_fn` pointers
5. Create dispatch table for worker processing

**Output:** Multi-threaded frame loop with empty slot processing

### 508b: Entity Render Slots (C)

1. Define `RenderSlot` struct (pos, color, size, visible, mesh_id)
2. Create slot array (fixed size, e.g., 1024 entities)
3. Implement slot allocation/deallocation (free list)
4. Connect workers to update slot data
5. Connect draw thread to render slots

**Output:** Colored shapes rendered from slot array

### 508c: Lua-C Bridge (C + Lua)

1. Create Lua module for render system (`render.lua`)
2. FFI or C API for: `create_entity`, `destroy_entity`, `set_position`
3. Bridge ECS entity creation to render slot allocation
4. Bridge ECS position updates to slot data

**Output:** Lua can create/move rendered entities

### 508d: Map Integration (Lua)

1. Load test map via `Map.load()`
2. Create render slots for doodads (static)
3. Create render slots for units (dynamic)
4. Basic terrain grid (colored quads from w3e data)

**Output:** Map loads and displays terrain + placed objects

### 508e: Input and Selection (C + Lua)

1. Mouse position tracking in render thread
2. Click detection → ray cast to find entity
3. Selection state in Lua (selected_entities table)
4. Visual feedback for selection (highlight/ring)

**Output:** Click to select entities

### 508f: Movement Orders (Lua)

1. Right-click detection
2. Issue move order via existing order system (404c)
3. Movement system updates ECS positions
4. Position changes flow through bridge to render slots

**Output:** Right-click moves selected unit

### 508g: Minimal UI (C)

1. Resource bar (top) - read from Lua resource system
2. Selection panel (bottom) - unit name, HP
3. Text rendering via raylib
4. Update UI from Lua callbacks

**Output:** Basic HUD showing game state

### 508h: Integration Test

1. Demo script loading a real map
2. Spawns test units
3. Player can select and move them
4. Verify threading model under load

**Output:** Complete vertical slice demo

---

## Dependency Graph

```
508a (threading) ──▶ 508b (slots) ──▶ 508c (bridge) ──▶ 508d (map)
                                                            │
                                        ┌───────────────────┤
                                        ▼                   ▼
                                   508e (input) ──▶ 508f (movement)
                                        │
                                        ▼
                                   508g (UI)
                                        │
                                        ▼
                                   508h (integration)
```

---

## Acceptance Criteria

- [ ] Worker thread pool processes entity updates
- [ ] Sync thread swaps output buffers atomically
- [ ] Draw thread renders from primary buffer at 60 FPS
- [ ] Map terrain displays as colored grid
- [ ] Units from map file render as shapes
- [ ] Click selects entity (visual feedback)
- [ ] Right-click moves selected entity
- [ ] Selected entity info displays in UI panel
- [ ] Resources display in top bar
- [ ] Demo runs on test map without crashes

---

## Files to Create

```
src/render/
├── main.c              (extend existing)
├── threading.c         (508a - thread pool, sync)
├── threading.h
├── slots.c             (508b - render slots, allocation)
├── slots.h
├── bridge.c            (508c - Lua-C interface)
├── bridge.h
├── input.c             (508e - mouse, selection)
├── input.h
├── ui.c                (508g - HUD rendering)
├── ui.h
└── run                 (extend build script)

src/render.lua          (508c - Lua side of bridge)
src/demo/
└── testing_room.lua    (508h - integration demo)
```

---

## Notes

This issue intentionally bypasses some Phase 5 infrastructure to reach a
testable state faster. Once this works, we can:

1. Refactor to match 501-507 architecture more precisely
2. Add features incrementally (terrain detail, sprites, minimap)
3. Profile and optimize the threading model
4. Replace placeholder visuals with real rendering

The goal is **validation**, not perfection. A working demo proves the
architecture; refinement comes after.

---

## Related Documents

- `docs/render-architecture.md` - Threading model and component slots
- `docs/render-system-multithreading.md` - Detailed pipeline stages and task submission
- `issues/501a-raylib-rotating-cube-demo.md` - Foundation this builds on
- `src/render/main.c` - Existing raylib demo code
- Phase 4 systems (ECS, movement, orders) - Integration targets
