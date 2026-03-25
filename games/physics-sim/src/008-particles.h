// src/008-particles.h
// Particle system for visual effects
// Provides burst effects, ripples, collision splashes, and explosion fragments

#ifndef PARTICLES_H
#define PARTICLES_H

#include <raylib.h>

// Forward declarations
typedef struct World World;

// Particle type enum
typedef enum {
    PARTICLE_SIMPLE,     // Basic particle (burst effects)
    PARTICLE_RIPPLE,     // Expanding ring (gate effects)
    PARTICLE_FRAGMENT    // Physics-enabled ball fragment (explosions)
} ParticleType;

// Fragment explosion direction mode
typedef enum {
    FRAG_RADIAL,     // 360° outward spread (default/fallback)
    FRAG_TANGENT,    // Shatter along impact tangent (wall hit by projectile)
    FRAG_AWAY        // Explode away from impact point (projectile hitting wall)
} FragmentMode;

// Trail point for fragment ribbons
#define TRAIL_LENGTH 16

// {{{ typedef struct Particle
// Particle represents a single visual effect particle.
// Union-style struct supports multiple particle behaviors.
typedef struct Particle {
    ParticleType type;   // Particle behavior type
    float x, y;          // Position in pixels
    float vx, vy;        // Velocity in pixels per second
    float life;          // Remaining lifetime in seconds
    float max_life;      // Initial lifetime (for alpha fade calculation)
    Color color;         // Particle color

    // Ripple-specific fields (type == PARTICLE_RIPPLE)
    float radius;        // Current ripple radius
    float max_radius;    // Maximum expansion radius
    float thickness;     // Ring thickness

    // Fragment-specific fields (type == PARTICLE_FRAGMENT)
    float size;          // Fragment visual size (ball radius)
    float angle;         // Current rotation angle (radians)
    float slice_angle;   // Pie slice width (radians, e.g. PI/2 for quarters)
    float angular_vel;   // Rotation speed (radians/sec)
    int corkscrew;       // 1 if doing corkscrew motion
    float corkscrew_phase; // Phase offset for corkscrew
    float trail_x[TRAIL_LENGTH];  // Trail X positions
    float trail_y[TRAIL_LENGTH];  // Trail Y positions
    int trail_head;      // Current trail write index
    float trail_timer;   // Time until next trail point
} Particle;
// }}}

// {{{ typedef struct ParticleTaskData
// ParticleTaskData encapsulates all information needed for a worker thread
// to process a single particle update. Pre-allocated at startup.
typedef struct ParticleTaskData {
    int particle_index;        // Index into particle arrays (immutable)
    Particle* read_buffer;     // Current state (read-only)
    Particle* write_buffer;    // Next state (write target)
    World* world;              // World for fragment collision detection
    float dt;                  // Delta time in seconds
} ParticleTaskData;
// }}}

// {{{ typedef struct ParticleSystem
// ParticleSystem manages a fixed-capacity pool of particles.
// Uses double-buffering for thread-safe parallel updates.
// Reuses inactive particle slots to avoid runtime allocation.
typedef struct ParticleSystem {
    Particle* particles_current; // Current frame state (read-only during update)
    Particle* particles_next;    // Next frame state (write during update)
    int capacity;                // Maximum particles
    int active_count;            // Current active particles (for stats)
    ParticleTaskData* task_data; // Pre-allocated task data for parallel processing
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

// {{{ particle_spawn_ripple
// Spawns an expanding ripple ring at the given position.
// Used for gate scoring effects.
//
// Parameters:
//   ps: ParticleSystem instance
//   x: Center x position
//   y: Center y position
//   color: Ripple color
void particle_spawn_ripple(ParticleSystem* ps, float x, float y, Color color);
// }}}

// {{{ particle_spawn_splash
// Spawns a small collision splash along the tangent direction.
// Particles spread ~30 degrees from the tangent in both directions.
//
// Parameters:
//   ps: ParticleSystem instance
//   x: Collision x position
//   y: Collision y position
//   tangent_x: Tangent direction x (normalized)
//   tangent_y: Tangent direction y (normalized)
//   color: Splash color
void particle_spawn_splash(ParticleSystem* ps, float x, float y,
                           float tangent_x, float tangent_y, Color color);
// }}}

// {{{ particle_spawn_fragments
// Spawns explosion fragments that split into thirds, quarters, sixths, or eighths.
// Fragments have physics, optional corkscrew motion, and iridescent trails.
// All fragments fall downward regardless of ball owner (looks better visually).
//
// Parameters:
//   ps: ParticleSystem instance
//   x: Explosion x position
//   y: Explosion y position
//   vx: Ball velocity x (fragments inherit momentum)
//   vy: Ball velocity y
//   color: Base fragment color
//   mode: Fragment direction mode (FRAG_RADIAL, FRAG_TANGENT, FRAG_AWAY)
//   nx, ny: Collision normal (used for FRAG_TANGENT and FRAG_AWAY modes)
void particle_spawn_fragments(ParticleSystem* ps, float x, float y,
                              float vx, float vy, Color color,
                              FragmentMode mode, float nx, float ny);
// }}}

// {{{ particle_system_update_with_world
// Updates all active particles with world collision for fragments.
// Fragments collide with pegs/bumpers but don't affect them.
// NOTE: Legacy single-threaded update. Use parallel functions for new code.
//
// Parameters:
//   ps: ParticleSystem instance
//   world: World for fragment collision detection
//   dt: Delta time in seconds
void particle_system_update_with_world(ParticleSystem* ps, World* world, float dt);
// }}}

// Forward declaration for threadpool
typedef struct ThreadPool ThreadPool;

// {{{ particle_system_swap_buffers
// Swaps current and next particle buffers after parallel update completes.
// Call after threadpool_wait_all() to make updated state visible.
//
// Parameters:
//   ps: ParticleSystem instance
void particle_system_swap_buffers(ParticleSystem* ps);
// }}}

// {{{ particle_system_prepare_tasks
// Prepares task data for parallel particle update.
// Sets buffer pointers, world reference, and delta time for each task.
// Propagates inactive state from current to next buffer.
//
// Parameters:
//   ps: ParticleSystem instance
//   world: World for fragment collision detection
//   dt: Delta time in seconds
void particle_system_prepare_tasks(ParticleSystem* ps, World* world, float dt);
// }}}

// {{{ particle_system_submit_tasks
// Submits particle update tasks to the threadpool.
// Only submits tasks for active particles (life > 0).
//
// Parameters:
//   ps: ParticleSystem instance
//   pool: ThreadPool for parallel execution
void particle_system_submit_tasks(ParticleSystem* ps, ThreadPool* pool);
// }}}

// {{{ particle_system_finalize_update
// Counts active particles after parallel update completes.
// Call after threadpool_wait_all() and before swap_buffers().
//
// Parameters:
//   ps: ParticleSystem instance
void particle_system_finalize_update(ParticleSystem* ps);
// }}}

// {{{ particle_update_task
// Worker function for parallel particle update.
// Updates a single particle: physics, collision, lifetime.
//
// Parameters:
//   data: ParticleTaskData pointer
void particle_update_task(void* data);
// }}}

#endif // PARTICLES_H
