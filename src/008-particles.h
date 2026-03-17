// src/008-particles.h
// Particle system for visual effects
// Provides burst effects and floating text for scoring events

#ifndef PARTICLES_H
#define PARTICLES_H

#include <raylib.h>

// {{{ typedef struct Particle
// Particle represents a single visual effect particle.
// Used for score burst effects when balls are captured.
typedef struct Particle {
    float x, y;          // Position in pixels
    float vx, vy;        // Velocity in pixels per second
    float life;          // Remaining lifetime in seconds
    float max_life;      // Initial lifetime (for alpha fade calculation)
    Color color;         // Particle color
} Particle;
// }}}

// {{{ typedef struct ParticleSystem
// ParticleSystem manages a fixed-capacity pool of particles.
// Reuses inactive particle slots to avoid runtime allocation.
typedef struct ParticleSystem {
    Particle* particles; // Particle array
    int capacity;        // Maximum particles
    int active_count;    // Current active particles (for stats)
} ParticleSystem;
// }}}

// {{{ particle_system_create
// Creates and initializes a particle system with the given capacity.
// All particles start inactive (life = 0).
//
// Parameters:
//   capacity: Maximum number of particles
//
// Returns:
//   ParticleSystem pointer on success, NULL on failure
ParticleSystem* particle_system_create(int capacity);
// }}}

// {{{ particle_system_destroy
// Destroys a particle system and frees all associated resources.
//
// Parameters:
//   ps: ParticleSystem instance to destroy
void particle_system_destroy(ParticleSystem* ps);
// }}}

// {{{ particle_system_update
// Updates all active particles by delta time.
// Applies gravity, updates positions, decrements life.
// Particles with life <= 0 become inactive.
//
// Parameters:
//   ps: ParticleSystem instance
//   dt: Delta time in seconds
void particle_system_update(ParticleSystem* ps, float dt);
// }}}

// {{{ particle_system_render
// Renders all active particles.
// Alpha fades based on remaining life.
//
// Parameters:
//   ps: ParticleSystem instance
void particle_system_render(ParticleSystem* ps);
// }}}

// {{{ particle_spawn_burst
// Spawns a burst of particles at the given position.
// Particles get random velocities radiating outward.
//
// Parameters:
//   ps: ParticleSystem instance
//   x: Center x position
//   y: Center y position
//   count: Number of particles to spawn
//   color: Particle color
void particle_spawn_burst(ParticleSystem* ps, float x, float y,
                          int count, Color color);
// }}}

#endif // PARTICLES_H
