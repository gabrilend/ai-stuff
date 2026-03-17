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

## Status

- [ ] Pending
