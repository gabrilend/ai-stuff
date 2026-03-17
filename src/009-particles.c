// src/009-particles.c
// Particle system implementation
// Provides visual effects for scoring and gameplay events

#include "008-particles.h"
#include <stdlib.h>
#include <stdio.h>
#include <math.h>

// Particle physics constants
#define PARTICLE_GRAVITY 200.0f       // Downward acceleration (px/s^2)
#define PARTICLE_BURST_SPEED 220.0f   // Initial particle speed (px/s)
#define PARTICLE_SPEED_VARIANCE 80.0f // Random speed variation (+/-)
#define PARTICLE_LIFETIME 1.0f        // Particle duration (seconds)
#define PARTICLE_RADIUS 2.0f          // Base particle render radius
#define PARTICLE_HUE_SHIFT 60.0f      // Hue shift over lifetime (degrees)

// {{{ hsv_to_rgb
// Converts HSV color to RGB color.
// H: 0-360 (hue in degrees)
// S: 0-1 (saturation)
// V: 0-1 (value/brightness)
// Returns raylib Color struct with alpha=255.
static Color hsv_to_rgb(float h, float s, float v) {
    // Normalize hue to 0-360 range
    while (h < 0) h += 360.0f;
    while (h >= 360.0f) h -= 360.0f;

    float c = v * s;
    float x = c * (1.0f - fabsf(fmodf(h / 60.0f, 2.0f) - 1.0f));
    float m = v - c;

    float r, g, b;
    if (h < 60) {
        r = c; g = x; b = 0;
    } else if (h < 120) {
        r = x; g = c; b = 0;
    } else if (h < 180) {
        r = 0; g = c; b = x;
    } else if (h < 240) {
        r = 0; g = x; b = c;
    } else if (h < 300) {
        r = x; g = 0; b = c;
    } else {
        r = c; g = 0; b = x;
    }

    Color result;
    result.r = (unsigned char)((r + m) * 255.0f);
    result.g = (unsigned char)((g + m) * 255.0f);
    result.b = (unsigned char)((b + m) * 255.0f);
    result.a = 255;
    return result;
}
// }}}

// {{{ rgb_to_hsv
// Converts RGB color to HSV values.
// Returns hue (0-360), saturation (0-1), value (0-1) via pointers.
static void rgb_to_hsv(Color c, float* h, float* s, float* v) {
    float r = c.r / 255.0f;
    float g = c.g / 255.0f;
    float b = c.b / 255.0f;

    float max = r > g ? (r > b ? r : b) : (g > b ? g : b);
    float min = r < g ? (r < b ? r : b) : (g < b ? g : b);
    float delta = max - min;

    *v = max;
    *s = (max > 0.0f) ? (delta / max) : 0.0f;

    if (delta < 0.0001f) {
        *h = 0;
    } else if (max == r) {
        *h = 60.0f * fmodf((g - b) / delta, 6.0f);
    } else if (max == g) {
        *h = 60.0f * ((b - r) / delta + 2.0f);
    } else {
        *h = 60.0f * ((r - g) / delta + 4.0f);
    }
    if (*h < 0) *h += 360.0f;
}
// }}}

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

        // Calculate life ratio for effects (1.0 = new, 0.0 = dying)
        float life_ratio = p->life / p->max_life;

        // Iridescence: shift hue over lifetime for sparkle effect
        // Convert base color to HSV, shift hue, convert back
        float h, s, v;
        rgb_to_hsv(p->color, &h, &s, &v);

        // Shift hue as particle ages (creates rainbow shimmer)
        float hue_shift = (1.0f - life_ratio) * PARTICLE_HUE_SHIFT;
        h += hue_shift;

        // Boost saturation and brightness for more vibrant colors
        s = fminf(1.0f, s * 1.2f);
        v = fminf(1.0f, v * 1.1f);

        Color render_color = hsv_to_rgb(h, s, v);

        // Apply alpha fade based on remaining life
        render_color.a = (unsigned char)(life_ratio * 255.0f);

        // Draw particle as small circle
        DrawCircle((int)p->x, (int)p->y, PARTICLE_RADIUS, render_color);
    }
}
// }}}

// {{{ particle_spawn_burst
void particle_spawn_burst(ParticleSystem* ps, float x, float y,
                          int count, Color color) {
    if (!ps || count <= 0) return;

    // Convert base color to HSV for hue randomization
    float base_h, base_s, base_v;
    rgb_to_hsv(color, &base_h, &base_s, &base_v);

    int spawned = 0;

    // Find inactive particle slots and spawn particles
    for (int i = 0; i < ps->capacity && spawned < count; i++) {
        Particle* p = &ps->particles[i];

        // Skip active particles
        if (p->life > 0.0f) continue;

        // Initialize particle position with slight random offset
        float offset_x = ((float)(rand() % 100) / 100.0f - 0.5f) * 4.0f;
        float offset_y = ((float)(rand() % 100) / 100.0f - 0.5f) * 4.0f;
        p->x = x + offset_x;
        p->y = y + offset_y;

        // Random velocity with speed variation
        // Angle distributed evenly with slight randomization
        float base_angle = (float)spawned / (float)count * 6.28318f;
        float angle_jitter = ((float)(rand() % 100) / 100.0f - 0.5f) * 0.5f;
        float angle = base_angle + angle_jitter;

        // Add random speed variation for more dynamic burst
        float speed_variance = ((float)(rand() % 100) / 100.0f - 0.5f) * 2.0f
                               * PARTICLE_SPEED_VARIANCE;
        float speed = PARTICLE_BURST_SPEED + speed_variance;

        p->vx = cosf(angle) * speed;
        p->vy = sinf(angle) * speed;

        // Randomize color hue for variety (+/- 30 degrees)
        float hue_variation = ((float)(rand() % 100) / 100.0f - 0.5f) * 60.0f;
        float h = base_h + hue_variation;
        // Ensure high saturation and brightness for vibrant colors
        float s = fminf(1.0f, base_s + 0.2f);
        float v = fminf(1.0f, base_v + 0.1f);
        p->color = hsv_to_rgb(h, s, v);

        // Set lifetime with slight variation
        float life_variance = ((float)(rand() % 100) / 100.0f) * 0.3f;
        p->life = PARTICLE_LIFETIME + life_variance;
        p->max_life = p->life;

        spawned++;
    }
}
// }}}
