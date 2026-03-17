// src/009-particles.c
// Particle system implementation
// Provides visual effects for scoring and gameplay events

#include "008-particles.h"
#include <stdlib.h>
#include <stdio.h>
#include <math.h>

// Particle physics constants
#define PARTICLE_GRAVITY 300.0f       // Downward acceleration (px/s^2)
#define PARTICLE_BURST_SPEED 120.0f   // Initial particle speed (px/s)
#define PARTICLE_LIFETIME 0.8f        // Particle duration (seconds)
#define PARTICLE_RADIUS 3.0f          // Particle render radius

// {{{ particle_system_create
ParticleSystem* particle_system_create(int capacity) {
    ParticleSystem* ps = (ParticleSystem*)malloc(sizeof(ParticleSystem));
    if (!ps) {
        fprintf(stderr, "ERROR: Failed to allocate particle system\n");
        return NULL;
    }

    ps->capacity = capacity;
    ps->active_count = 0;

    // Allocate particle array
    ps->particles = (Particle*)calloc(capacity, sizeof(Particle));
    if (!ps->particles) {
        fprintf(stderr, "ERROR: Failed to allocate particle array\n");
        free(ps);
        return NULL;
    }

    // Initialize all particles as inactive (life = 0)
    for (int i = 0; i < capacity; i++) {
        ps->particles[i].life = 0.0f;
    }

    return ps;
}
// }}}

// {{{ particle_system_destroy
void particle_system_destroy(ParticleSystem* ps) {
    if (!ps) return;

    if (ps->particles) {
        free(ps->particles);
    }
    free(ps);
}
// }}}

// {{{ particle_system_update
void particle_system_update(ParticleSystem* ps, float dt) {
    if (!ps) return;

    int active = 0;

    for (int i = 0; i < ps->capacity; i++) {
        Particle* p = &ps->particles[i];

        // Skip inactive particles
        if (p->life <= 0.0f) continue;

        // Apply gravity to vertical velocity
        p->vy += PARTICLE_GRAVITY * dt;

        // Update position
        p->x += p->vx * dt;
        p->y += p->vy * dt;

        // Decrement lifetime
        p->life -= dt;

        // Count active particles
        if (p->life > 0.0f) {
            active++;
        }
    }

    ps->active_count = active;
}
// }}}

// {{{ particle_system_render
void particle_system_render(ParticleSystem* ps) {
    if (!ps) return;

    for (int i = 0; i < ps->capacity; i++) {
        Particle* p = &ps->particles[i];

        // Skip inactive particles
        if (p->life <= 0.0f) continue;

        // Calculate alpha based on remaining life (fade out)
        float life_ratio = p->life / p->max_life;
        unsigned char alpha = (unsigned char)(life_ratio * 255.0f);

        // Apply alpha to particle color
        Color render_color = p->color;
        render_color.a = alpha;

        // Draw particle as small circle
        DrawCircle((int)p->x, (int)p->y, PARTICLE_RADIUS, render_color);
    }
}
// }}}

// {{{ particle_spawn_burst
void particle_spawn_burst(ParticleSystem* ps, float x, float y,
                          int count, Color color) {
    if (!ps || count <= 0) return;

    int spawned = 0;

    // Find inactive particle slots and spawn particles
    for (int i = 0; i < ps->capacity && spawned < count; i++) {
        Particle* p = &ps->particles[i];

        // Skip active particles
        if (p->life > 0.0f) continue;

        // Initialize particle position
        p->x = x;
        p->y = y;

        // Random velocity in all directions
        // Angle distributed evenly around circle
        float angle = (float)spawned / (float)count * 6.28318f;  // 2*PI
        p->vx = cosf(angle) * PARTICLE_BURST_SPEED;
        p->vy = sinf(angle) * PARTICLE_BURST_SPEED;

        // Set lifetime and color
        p->life = PARTICLE_LIFETIME;
        p->max_life = PARTICLE_LIFETIME;
        p->color = color;

        spawned++;
    }
}
// }}}
