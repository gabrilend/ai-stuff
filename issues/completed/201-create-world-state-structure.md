# Issue 201: Create World State Structure

## Current Behavior

No world state exists. The main loop renders only placeholder text.

## Intended Behavior

Define core data structures for the pachinko world:
- Peg struct for individual pegs
- ScoreZone struct for scoring slots
- World struct containing all game state
- Header file with type definitions and function declarations

## Suggested Implementation Steps

1. Create src/004-world.h with struct definitions:
   ```c
   typedef struct Peg {
       float x, y;
       float radius;
   } Peg;

   typedef struct ScoreZone {
       float x_min;
       float x_max;
       int points;
   } ScoreZone;

   typedef struct World {
       int width, height;
       Peg* pegs;
       int peg_count;
       ScoreZone* zones;
       int zone_count;
       int score;
   } World;
   ```

2. Create src/005-world.c with initialization functions:
   - world_create(): Allocate and initialize world
   - world_destroy(): Free world resources

3. Add physics constants to header:
   - PEG_RADIUS (12.0f)
   - Default peg grid parameters

4. Create corresponding .info.md documentation files

5. Test compilation with new files

## Related Documents

- [001-architecture-overview.md](../docs/001-architecture-overview.md)
- [003-physics-system.md](../docs/003-physics-system.md)

## Dependencies

- Phase 1 complete (build system, raylib window)

## Status

- [x] Completed

## Implementation Notes

**Files Created:**
- src/004-world.h (world state header)
- src/005-world.c (world state implementation)
- src/005-world.info.md (documentation)

**Implementation Steps Completed:**

1. Created src/004-world.h with struct definitions:
   - Peg struct (x, y, radius)
   - ScoreZone struct (x_min, x_max, points)
   - World struct (dimensions, pegs, zones, score)

2. Created src/005-world.c with functions:
   - world_create(): Allocates and initializes world
   - world_destroy(): Frees all resources (pegs, zones, world)

3. Added physics constants to header:
   - PEG_RADIUS (12.0f)
   - DEFAULT_PEG_ROWS (10)
   - DEFAULT_PEG_COLS (8)
   - DEFAULT_PEG_SPACING (60.0f)

4. Created src/005-world.info.md with function documentation

5. Tested compilation successfully with no warnings

**Current Behavior:**
- World can be created with specified dimensions
- All fields initialized to safe defaults (NULL pointers, 0 counters)
- Clean destruction with proper resource cleanup
- Safe to call world_destroy with NULL pointer
- Compilation successful with all warnings enabled

**Design Notes:**
- Peg and zone arrays start as NULL and will be allocated by generation
  functions in Issues 202 and 203
- World struct uses heap allocation for flexibility
- Error messages printed to stderr on allocation failure
