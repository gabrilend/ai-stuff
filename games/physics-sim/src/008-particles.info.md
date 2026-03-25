# src/008-particles.h - Particle System API

Particle system for visual effects in the pachinko simulator.

## External Functions

### particle_system_create
```c
ParticleSystem* particle_system_create(int capacity);
```
Creates and initializes a particle system with fixed capacity.

**Parameters:**
- `capacity`: Maximum number of particles

**Returns:**
- ParticleSystem pointer on success, NULL on allocation failure

### particle_system_destroy
```c
void particle_system_destroy(ParticleSystem* ps);
```
Destroys a particle system and frees all associated resources.

**Parameters:**
- `ps`: ParticleSystem instance to destroy

### particle_system_update
```c
void particle_system_update(ParticleSystem* ps, float dt);
```
Updates all active particles by delta time. Applies gravity, updates positions, and decrements life. Particles with life <= 0 become inactive.

**Parameters:**
- `ps`: ParticleSystem instance
- `dt`: Delta time in seconds

### particle_system_render
```c
void particle_system_render(ParticleSystem* ps);
```
Renders all active particles with alpha fade based on remaining life.

**Parameters:**
- `ps`: ParticleSystem instance

### particle_spawn_burst
```c
void particle_spawn_burst(ParticleSystem* ps, float x, float y,
                          int count, Color color);
```
Spawns a burst of particles at the given position with random velocities radiating outward.

**Parameters:**
- `ps`: ParticleSystem instance
- `x`: Center x position in pixels
- `y`: Center y position in pixels
- `count`: Number of particles to spawn
- `color`: Particle color (alpha will be controlled by lifetime)

**Behavior:**
- Finds inactive particle slots (life <= 0)
- Distributes particles evenly around a circle
- Each particle gets velocity in radial direction
- If capacity is full, some particles may not spawn

## Data Structures

### Particle
```c
typedef struct Particle {
    float x, y;          // Position in pixels
    float vx, vy;        // Velocity in pixels per second
    float life;          // Remaining lifetime in seconds
    float max_life;      // Initial lifetime (for alpha fade calculation)
    Color color;         // Particle color
} Particle;
```

Represents a single visual effect particle.

### ParticleSystem
```c
typedef struct ParticleSystem {
    Particle* particles; // Particle array
    int capacity;        // Maximum particles
    int active_count;    // Current active particles (for stats)
} ParticleSystem;
```

Manages a fixed-capacity pool of particles with automatic slot reuse.

## Constants

### Physics Constants (in src/009-particles.c)
- `PARTICLE_GRAVITY`: 300.0f - Downward acceleration in pixels per second squared
- `PARTICLE_BURST_SPEED`: 120.0f - Initial particle speed for bursts
- `PARTICLE_LIFETIME`: 0.8f - Particle duration in seconds
- `PARTICLE_RADIUS`: 3.0f - Particle render radius in pixels

## Usage Pattern

```c
// Initialization
ParticleSystem* ps = particle_system_create(256);

// Game loop
while (running) {
    // Update
    particle_system_update(ps, dt);

    // Spawn burst when ball scores
    if (ball_scored) {
        particle_spawn_burst(ps, ball_x, ball_y, 12, zone_color);
    }

    // Render
    particle_system_render(ps);
}

// Cleanup
particle_system_destroy(ps);
```
