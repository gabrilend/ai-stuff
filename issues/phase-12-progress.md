# Phase 12 Progress

## Phase Goal

Editor Modularization. Extract the board editor into a standalone application, removing it from the game to reduce complexity and improve separation of concerns.

## Issues

| ID   | Description                        | Status    |
|------|------------------------------------|-----------|
| 1201 | Standalone editor application      | Complete  |
| 1202 | Remove editor from game            | Complete  |

## Progress Summary

**Completed:** 2/2 issues (100%)
**Status:** Phase complete

## Design Overview

### Motivation

The current architecture embeds the board editor within the game as an overlay panel. While functional, this approach has drawbacks:

1. **Complexity**: Game main loop handles both gameplay and editing
2. **Binary size**: Editor code compiled into game even if unused
3. **UX limitations**: Overlay constrains editor to smaller area
4. **Coupling**: Editor changes require game recompilation

### Solution

Create two separate applications:

```
bin/
  physics-sim      # Game only - loads boards from boards/
  board-editor     # Editor only - creates/edits boards
```

### Shared Components

Both applications use:
- `020-board-data.h/c` - Board data structures and JSON I/O
- `022-grid.h/c` - Grid coordinate conversion
- `028-portal.h/c` - Portal zone definitions
- `libs/cjson/` - JSON parsing

### Game-Only Components

- `001-main.c` - Game main loop
- `002-threadpool.h/c` - Parallel physics
- `004-world.h/c` - Game world state
- `006-ball.h/c` - Ball physics
- `008-particles.h/c` - Particle effects
- `011-upgrades.h/c` - Upgrade system
- `013-adversary.h/c` - AI system
- `014-stage.h/c` - Stage management
- `026-stage-pool.h/c` - Random stage selection

### Editor-Only Components (new)

- `030-editor-main.c` - Editor entry point
- `031-editor-app.h/c` - Editor application state
- `032-editor-render.c` - Editor rendering
- `033-object-render.h/c` - Object rendering utilities

## Implementation Order

1. **1201** - Create standalone editor (must work independently)
2. **1202** - Remove editor from game (after 1201 is tested)

## Expected Benefits

| Aspect | Before | After |
|--------|--------|-------|
| Game binary size | ~500KB | ~400KB |
| Game main.c lines | ~950 | ~850 |
| Editor canvas area | Overlay (constrained) | Full window |
| Build time (game) | Compiles editor | Skips editor |
| Separation | Mixed | Clean |

## Makefile Changes

```makefile
# Game build (default)
game: $(GAME_OBJS)
    $(CC) $(GAME_OBJS) -o bin/physics-sim $(LDFLAGS)

# Editor build
editor: $(EDITOR_OBJS)
    $(CC) $(EDITOR_OBJS) -o bin/board-editor $(LDFLAGS)

# Build both
all: game editor
```

## Dependencies

Phase 11 must be complete (provides board data format, grid system, and portal zones).
