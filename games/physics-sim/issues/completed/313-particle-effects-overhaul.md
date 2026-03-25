# Issue 812: Particle Effects Overhaul

## Current Behavior

- Gates spawn burst particles when balls score
- Ball explosions spawn 24 magenta particles in circular burst
- No collision feedback particles
- Simple particle system with position, velocity, lifetime

## Intended Behavior

### Gate Ripple Effect
- When balls pass through gates, spawn a halo/ripple that radiates outward
- Feels like gate is pulsing
- Remove current particle burst from gates

### Collision Splash Effect
- When balls collide but don't destroy each other, spawn small splash
- Particles follow collision tangent, ~30 degree spread in both directions
- Much smaller than current effects

### Explosion Fragment Effect
- Ball splits into thirds, quarters, sixths, or eighths (random)
- Fragments radiate away from explosion point
- 1/5th chance per fragment of corkscrew motion
- Fragments affected by physics objects (pegs, walls) but don't affect them
- Fade out over 1-2 seconds
- Leave iridescent trailing ribbon behind

## Suggested Implementation Steps

### Phase 1: Extend Particle System
1. Add particle types enum (PARTICLE_SIMPLE, PARTICLE_RIPPLE, PARTICLE_FRAGMENT)
2. Add ripple-specific fields (inner_radius, outer_radius, expansion_rate)
3. Add fragment-specific fields (angle, angular_velocity, corkscrew, trail points)
4. Add collision detection for fragments against pegs/bumpers

### Phase 2: Gate Ripple
1. Create ripple spawn function with gate position
2. Ripple expands outward as ring, fades as it grows
3. Remove particle burst from gate scoring in main.c

### Phase 3: Collision Splash
1. Add collision info to ball task data (collision point, normal)
2. Create splash spawn function taking collision point and tangent
3. Spawn 4-6 small particles along tangent with 30 degree spread

### Phase 4: Explosion Fragments
1. Random selection of 3, 4, 6, or 8 fragments
2. Each fragment has 20% chance of corkscrew flag
3. Physics update checks fragment collisions with pegs/bumpers/walls
4. Trail system stores last N positions for ribbon rendering
5. Iridescent color based on time/position

## Technical Considerations

- Fragment physics needs read-only access to world pegs/bumpers
- Trail rendering may need separate pass or stored geometry
- Corkscrew motion: sinusoidal offset perpendicular to velocity
- Iridescent color: hue shift based on angle or time

## Status

Complete

## Implementation Notes

**Gate Ripple Effect:**
- PARTICLE_RIPPLE type with expanding ring rendering
- Replaces burst particles at gate scoring
- Color based on point value (gold/green/blue/gray)
- Fades as radius grows

**Collision Splash:**
- Tracks cross-owner collisions in BallTaskData
- 6 small particles spread along collision tangent
- ~30 degree spread in both directions from tangent

**Explosion Fragments:**
- Random 3, 4, 6, or 8 fragments per explosion
- 20% chance of corkscrew motion per fragment
- Physics collisions with pegs/bumpers/walls (one-way)
- Iridescent trails with hue shift along trail length
- Rotating triangular fragments with center highlight

Files: 006-ball.h, 007-ball.c, 008-particles.h, 009-particles.c, 001-main.c
