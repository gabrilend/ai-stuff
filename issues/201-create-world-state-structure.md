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

- [ ] Not started
