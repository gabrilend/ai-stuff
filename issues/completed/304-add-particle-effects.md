# Issue 504: Add Particle Effects

## Current Behavior

No particle effects exist. When balls score or collide with pegs, there
is no visual feedback beyond the ball's movement. The game feels static
and lacks "juice" (game feel polish).

## Intended Behavior

Simple particle system for visual effects:
- Score particles: Burst of particles when ball enters score zone
- Collision sparks: Small particles on peg bounces (optional)
- Floating score text: Point value rises from capture location

## Suggested Implementation Steps

1. Create particle structures:
   ```c
   typedef struct Particle {
       float x, y;          // Position
       float vx, vy;        // Velocity
       float life;          // Remaining lifetime (seconds)
       float max_life;      // Initial lifetime
       Color color;         // Particle color
   } Particle;

   typedef struct ParticleSystem {
       Particle* particles; // Particle array
       int capacity;        // Maximum particles
       int active_count;    // Current active particles
   } ParticleSystem;
   ```

2. Create src/008-particles.h and src/009-particles.c

3. Implement particle system functions:
   - particle_system_create(int capacity)
   - particle_system_destroy(ParticleSystem* ps)
   - particle_system_update(ParticleSystem* ps, float dt)
   - particle_system_render(ParticleSystem* ps)
   - particle_spawn_burst(ParticleSystem* ps, float x, float y, int count, Color color)

4. Implement floating score text:
   ```c
   typedef struct FloatingText {
       float x, y;          // Position
       float vy;            // Upward velocity
       float life;          // Remaining lifetime
       int value;           // Point value to display
   } FloatingText;
   ```

5. Integrate with scoring system:
   - When ball scores, spawn particle burst at ball position
   - Spawn floating text showing point value
   - Color matches zone color for visual association

6. Update main loop:
   - Call particle_system_update() with delta time
   - Call particle_system_render() after balls, before UI

7. Update src/008-particles.info.md documentation

8. Test compilation with no warnings

## Design Notes

Particle behavior:
- Gravity-affected downward acceleration
- Velocity decay over lifetime
- Alpha fade as lifetime decreases
- Simple circle rendering

Performance considerations:
- Fixed capacity (e.g., 256 particles)
- Reuse inactive particle slots
- Skip rendering for dead particles
- Single-threaded update (simple, fast enough)

Floating text behavior:
- Rises slowly from capture point
- Fades out over 1-2 seconds
- White text with outline for visibility
- Shows point value (e.g., "+100")

Visual tuning:
- Burst: 8-16 particles per score
- Colors: Match zone color for cohesion
- Lifetime: 0.5-1.0 seconds
- Spread: Random velocity in all directions

## Success Criteria

- Particle burst on ball capture
- Floating score text rises from capture point
- Particles fade and disappear naturally
- No memory leaks (particle reuse)
- Maintains 60fps with many particles
- Compiles with no warnings

## Related Documents

- [007-ball.c](../src/007-ball.c)
- [004-raylib-integration.md](../docs/004-raylib-integration.md)

## Dependencies

- Issue 502 (Scoring system) - Required (triggers particles)
- Issue 503 (Visual polish) - Recommended first

## Implementation Notes

Implemented particle system for visual feedback when balls score:

1. Created particle structures in src/008-particles.h
   - Particle: individual particle with position, velocity, life, color
   - ParticleSystem: manages fixed-capacity pool (256 particles)

2. Implemented particle system in src/009-particles.c
   - particle_system_create/destroy for lifecycle management
   - particle_system_update: applies gravity, updates positions, handles lifetime
   - particle_system_render: renders with alpha fade based on remaining life
   - particle_spawn_burst: spawns particles with radial velocities

3. Created API documentation in src/008-particles.info.md
   - Documents all functions, structures, constants
   - Includes usage pattern example

4. Extended BallTaskData in src/006-ball.h:58-60
   - Added scored flag (1 if ball scored this frame)
   - Added score_pos_x, score_pos_y to track scoring position

5. Updated ball_update_task in src/007-ball.c:374
   - Sets scored=1 and records position when ball enters zone
   - Thread-safe: each task writes only to its own fields

6. Integrated particle system in src/001-main.c
   - Creates particle system with 256 capacity (line 82)
   - Updates particles each frame (line 104)
   - Spawns burst (12 particles) when balls score (line 122)
   - Particle color matches zone color (gold/green/blue/gray)
   - Renders particles after balls, before UI (line 141)
   - Destroys particle system on cleanup (line 174)

Particle physics: 300px/s^2 gravity, 120px/s burst speed, 0.8s lifetime. Particles
fade out (alpha) as lifetime decreases. Colors match score zones for visual cohesion.

Compilation tested: No warnings.

## Status

- [x] Complete

---

## Post-Implementation Bug Fixes

### Issue 1001f - Particle Effect Positioning (Phase 10)

**Problem:** Particle effects had multiple issues:
1. Only spawned on the left side of the map
2. Sometimes spawned multiple times after exiting a gate
3. Ring particles appeared but only for some gates

**Root Cause:** zone_grid->origin_x was not updated when window was resized. After resize, zone dispatch used stale coordinates, causing zone detection to fail for gates on the right side.

**Fix:** Added zone grid origin update in resize handler:
```c
// Update zone grid origin to match new table position
if (zone_grid) {
    zone_grid->origin_x = world->table_x;
}
```

Also added polygon vertex shifting on resize to keep polygon fills aligned:
```c
if (world->polygon_manager) {
    for (int p = 0; p < world->polygon_manager->polygon_count; p++) {
        Polygon* poly = &world->polygon_manager->polygons[p];
        for (int v = 0; v < poly->vertex_count; v++) {
            poly->vertices[v].x += dx;
        }
        poly->centroid.x += dx;
    }
}
```

**Files Modified:** src/001-main.c
