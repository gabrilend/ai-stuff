// src/009-particles.c
// Particle system implementation
// Provides visual effects for scoring and gameplay events

#include "008-particles.h"
#include "004-world.h"
#include "003-threadpool.h"
#include <stdlib.h>
#include <stdio.h>
#include <math.h>

// Simple particle physics constants
#define PARTICLE_GRAVITY 200.0f       // Downward acceleration (px/s^2)
#define PARTICLE_BURST_SPEED 220.0f   // Initial particle speed (px/s)
#define PARTICLE_SPEED_VARIANCE 80.0f // Random speed variation (+/-)
#define PARTICLE_LIFETIME 1.0f        // Particle duration (seconds)
#define PARTICLE_RADIUS 2.0f          // Base particle render radius
#define PARTICLE_HUE_SHIFT 60.0f      // Hue shift over lifetime (degrees)

// Ripple constants
#define RIPPLE_EXPANSION_SPEED 150.0f // Pixels per second
#define RIPPLE_MAX_RADIUS 60.0f       // Maximum ripple size
#define RIPPLE_THICKNESS 4.0f         // Ring thickness
#define RIPPLE_LIFETIME 0.5f          // Ripple duration

// Splash constants
#define SPLASH_PARTICLE_COUNT 6       // Particles per splash
#define SPLASH_SPEED 80.0f            // Splash particle speed
#define SPLASH_SPREAD 0.52f           // ~30 degrees in radians
#define SPLASH_LIFETIME 0.3f          // Short-lived splash

// Fragment constants
#define FRAGMENT_LIFETIME 1.5f        // Fragment duration
#define FRAGMENT_GRAVITY 400.0f       // Heavier gravity for fragments
#define FRAGMENT_SIZE 4.0f            // Fragment visual size
#define FRAGMENT_SPEED 120.0f         // Base fragment speed
#define FRAGMENT_ANGULAR_SPEED 8.0f   // Rotation speed (rad/s)
#define CORKSCREW_AMPLITUDE 50.0f     // Corkscrew lateral amplitude (pronounced swing)
#define CORKSCREW_FREQUENCY 18.0f     // Corkscrew oscillation frequency (tighter spirals)
#define TRAIL_INTERVAL 0.02f          // Time between trail points

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

    // Allocate current particle buffer
    ps->particles_current = (Particle*)calloc(capacity, sizeof(Particle));
    if (!ps->particles_current) {
        fprintf(stderr, "ERROR: Failed to allocate particle current buffer\n");
        free(ps);
        return NULL;
    }

    // Allocate next particle buffer
    ps->particles_next = (Particle*)calloc(capacity, sizeof(Particle));
    if (!ps->particles_next) {
        fprintf(stderr, "ERROR: Failed to allocate particle next buffer\n");
        free(ps->particles_current);
        free(ps);
        return NULL;
    }

    // Allocate task data array
    ps->task_data = (ParticleTaskData*)malloc(capacity * sizeof(ParticleTaskData));
    if (!ps->task_data) {
        fprintf(stderr, "ERROR: Failed to allocate particle task data\n");
        free(ps->particles_next);
        free(ps->particles_current);
        free(ps);
        return NULL;
    }

    // Initialize all particles as inactive (life = 0)
    for (int i = 0; i < capacity; i++) {
        ps->particles_current[i].life = 0.0f;
        ps->particles_next[i].life = 0.0f;
        ps->task_data[i].particle_index = i;  // Immutable index
    }

    return ps;
}
// }}}

// {{{ particle_system_destroy
void particle_system_destroy(ParticleSystem* ps) {
    if (!ps) return;

    if (ps->particles_current) {
        free(ps->particles_current);
    }
    if (ps->particles_next) {
        free(ps->particles_next);
    }
    if (ps->task_data) {
        free(ps->task_data);
    }
    free(ps);
}
// }}}

// {{{ particle_system_update
void particle_system_update(ParticleSystem* ps, float dt) {
    // Use null world for basic update (no fragment collisions)
    particle_system_update_with_world(ps, NULL, dt);
}
// }}}

// {{{ particle_system_update_with_world
// Legacy single-threaded update. Modifies particles_current in-place.
// For parallel updates, use prepare_tasks/submit_tasks/finalize/swap pattern.
void particle_system_update_with_world(ParticleSystem* ps, World* world, float dt) {
    if (!ps) return;

    int active = 0;

    for (int i = 0; i < ps->capacity; i++) {
        Particle* p = &ps->particles_current[i];

        // Skip inactive particles
        if (p->life <= 0.0f) continue;

        switch (p->type) {
            case PARTICLE_SIMPLE:
                // Simple particles: gravity and movement
                p->vy += PARTICLE_GRAVITY * dt;
                p->x += p->vx * dt;
                p->y += p->vy * dt;
                break;

            case PARTICLE_RIPPLE:
                // Ripple: expand radius over lifetime
                p->radius += RIPPLE_EXPANSION_SPEED * dt;
                if (p->radius > p->max_radius) {
                    p->radius = p->max_radius;
                }
                break;

            case PARTICLE_FRAGMENT: {
                // Fragment: gravity, movement, rotation, corkscrew, trail, collisions
                p->vy += FRAGMENT_GRAVITY * dt;

                // Calculate base movement
                float move_x = p->vx * dt;
                float move_y = p->vy * dt;

                // Apply corkscrew motion (perpendicular oscillation)
                if (p->corkscrew) {
                    float elapsed = p->max_life - p->life;
                    float phase = elapsed * CORKSCREW_FREQUENCY + p->corkscrew_phase;
                    float offset = sinf(phase) * CORKSCREW_AMPLITUDE * dt;

                    // Perpendicular to velocity direction
                    float vel_mag = sqrtf(p->vx * p->vx + p->vy * p->vy);
                    if (vel_mag > 0.1f) {
                        float perp_x = -p->vy / vel_mag;
                        float perp_y = p->vx / vel_mag;
                        move_x += perp_x * offset;
                        move_y += perp_y * offset;
                    }
                }

                p->x += move_x;
                p->y += move_y;
                p->angle += p->angular_vel * dt;

                // Update trail
                p->trail_timer -= dt;
                if (p->trail_timer <= 0.0f) {
                    p->trail_timer = TRAIL_INTERVAL;
                    p->trail_x[p->trail_head] = p->x;
                    p->trail_y[p->trail_head] = p->y;
                    p->trail_head = (p->trail_head + 1) % TRAIL_LENGTH;
                }

                // Fragment collision with pegs (if world provided)
                if (world) {
                    // Check player pegs
                    for (int j = 0; j < world->peg_count; j++) {
                        float dx = p->x - world->pegs[j].x;
                        float dy = p->y - world->pegs[j].y;
                        float dist = sqrtf(dx * dx + dy * dy);
                        float min_dist = world->pegs[j].radius + p->size;

                        if (dist < min_dist && dist > 0.001f) {
                            // Bounce off peg
                            float nx = dx / dist;
                            float ny = dy / dist;
                            float dot = p->vx * nx + p->vy * ny;
                            p->vx -= 2.0f * dot * nx * 0.6f;  // Damped bounce
                            p->vy -= 2.0f * dot * ny * 0.6f;
                            // Push out
                            p->x = world->pegs[j].x + nx * min_dist;
                            p->y = world->pegs[j].y + ny * min_dist;
                        }
                    }

                    // Check adversary pegs
                    for (int j = 0; j < world->adversary_peg_count; j++) {
                        float dx = p->x - world->adversary_pegs[j].x;
                        float dy = p->y - world->adversary_pegs[j].y;
                        float dist = sqrtf(dx * dx + dy * dy);
                        float min_dist = world->adversary_pegs[j].radius + p->size;

                        if (dist < min_dist && dist > 0.001f) {
                            float nx = dx / dist;
                            float ny = dy / dist;
                            float dot = p->vx * nx + p->vy * ny;
                            p->vx -= 2.0f * dot * nx * 0.6f;
                            p->vy -= 2.0f * dot * ny * 0.6f;
                            p->x = world->adversary_pegs[j].x + nx * min_dist;
                            p->y = world->adversary_pegs[j].y + ny * min_dist;
                        }
                    }

                    // Check bumpers
                    for (int j = 0; j < world->bumper_count; j++) {
                        float dx = p->x - world->bumpers[j].x;
                        float dy = p->y - world->bumpers[j].y;
                        float dist = sqrtf(dx * dx + dy * dy);
                        float min_dist = world->bumpers[j].radius + p->size;

                        if (dist < min_dist && dist > 0.001f) {
                            float nx = dx / dist;
                            float ny = dy / dist;
                            float dot = p->vx * nx + p->vy * ny;
                            p->vx -= 2.0f * dot * nx * 0.4f;  // Extra damped
                            p->vy -= 2.0f * dot * ny * 0.4f;
                            p->x = world->bumpers[j].x + nx * min_dist;
                            p->y = world->bumpers[j].y + ny * min_dist;
                        }
                    }

                    // Check adversary bumpers
                    for (int j = 0; j < world->adversary_bumper_count; j++) {
                        float dx = p->x - world->adversary_bumpers[j].x;
                        float dy = p->y - world->adversary_bumpers[j].y;
                        float dist = sqrtf(dx * dx + dy * dy);
                        float min_dist = world->adversary_bumpers[j].radius + p->size;

                        if (dist < min_dist && dist > 0.001f) {
                            float nx = dx / dist;
                            float ny = dy / dist;
                            float dot = p->vx * nx + p->vy * ny;
                            p->vx -= 2.0f * dot * nx * 0.4f;
                            p->vy -= 2.0f * dot * ny * 0.4f;
                            p->x = world->adversary_bumpers[j].x + nx * min_dist;
                            p->y = world->adversary_bumpers[j].y + ny * min_dist;
                        }
                    }

                    // Wall bounces
                    float wall_left = world->table_x;
                    float wall_right = world->table_x + world->table_width;
                    if (p->x - p->size < wall_left) {
                        p->x = wall_left + p->size;
                        p->vx = -p->vx * 0.5f;
                    }
                    if (p->x + p->size > wall_right) {
                        p->x = wall_right - p->size;
                        p->vx = -p->vx * 0.5f;
                    }
                }
                break;
            }
        }

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
        Particle* p = &ps->particles_current[i];

        // Skip inactive particles
        if (p->life <= 0.0f) continue;

        // Calculate life ratio for effects (1.0 = new, 0.0 = dying)
        float life_ratio = p->life / p->max_life;

        switch (p->type) {
            case PARTICLE_SIMPLE: {
                // Iridescence: shift hue over lifetime for sparkle effect
                float h, s, v;
                rgb_to_hsv(p->color, &h, &s, &v);

                // Shift hue as particle ages (creates rainbow shimmer)
                float hue_shift = (1.0f - life_ratio) * PARTICLE_HUE_SHIFT;
                h += hue_shift;

                // Boost saturation and brightness for more vibrant colors
                s = fminf(1.0f, s * 1.2f);
                v = fminf(1.0f, v * 1.1f);

                Color render_color = hsv_to_rgb(h, s, v);
                render_color.a = (unsigned char)(life_ratio * 255.0f);

                DrawCircle((int)p->x, (int)p->y, PARTICLE_RADIUS, render_color);
                break;
            }

            case PARTICLE_RIPPLE: {
                // Ripple: expanding ring that fades as it grows
                Color render_color = p->color;
                render_color.a = (unsigned char)(life_ratio * 200.0f);

                // Draw ring using DrawRing
                DrawRing((Vector2){p->x, p->y},
                        p->radius - p->thickness / 2.0f,
                        p->radius + p->thickness / 2.0f,
                        0, 360, 32, render_color);
                break;
            }

            case PARTICLE_FRAGMENT: {
                // Fragment: draw iridescent trail ribbon first, then fragment
                float h, s, v;
                rgb_to_hsv(p->color, &h, &s, &v);

                // Draw trail ribbon (oldest to newest)
                for (int t = 0; t < TRAIL_LENGTH - 1; t++) {
                    int idx = (p->trail_head + t) % TRAIL_LENGTH;
                    int next_idx = (p->trail_head + t + 1) % TRAIL_LENGTH;

                    float trail_ratio = (float)t / (float)TRAIL_LENGTH;
                    float trail_alpha = trail_ratio * life_ratio * 180.0f;

                    // Iridescent hue shift along trail
                    float trail_hue = h + trail_ratio * 120.0f;
                    Color trail_color = hsv_to_rgb(trail_hue, s, v);
                    trail_color.a = (unsigned char)trail_alpha;

                    // Draw trail segment as thick line
                    DrawLineEx(
                        (Vector2){p->trail_x[idx], p->trail_y[idx]},
                        (Vector2){p->trail_x[next_idx], p->trail_y[next_idx]},
                        2.0f * trail_ratio + 0.5f,
                        trail_color
                    );
                }

                // Draw fragment as pie slice of the original ball
                // Iridescent color based on time
                float elapsed = p->max_life - p->life;
                float frag_hue = h + elapsed * 60.0f;
                Color frag_color = hsv_to_rgb(frag_hue, s, v);
                frag_color.a = (unsigned char)(life_ratio * 255.0f);

                // Convert angles from radians to degrees for raylib
                // Center the slice on p->angle (slice spans angle +/- half_slice)
                float half_slice_deg = (p->slice_angle * 0.5f) * 57.2958f;  // radians to degrees
                float center_angle_deg = p->angle * 57.2958f;
                float start_angle = center_angle_deg - half_slice_deg;
                float end_angle = center_angle_deg + half_slice_deg;

                // Draw pie slice (filled sector)
                DrawCircleSector((Vector2){p->x, p->y}, p->size,
                                start_angle, end_angle, 8, frag_color);

                // Draw outline for definition
                Color outline_color = frag_color;
                outline_color.a = (unsigned char)(life_ratio * 180.0f);
                DrawCircleSectorLines((Vector2){p->x, p->y}, p->size,
                                     start_angle, end_angle, 8, outline_color);
                break;
            }
        }
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
        Particle* p = &ps->particles_current[i];

        // Skip active particles
        if (p->life > 0.0f) continue;

        p->type = PARTICLE_SIMPLE;

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

// {{{ particle_spawn_ripple
void particle_spawn_ripple(ParticleSystem* ps, float x, float y, Color color) {
    if (!ps) return;

    // Find an inactive particle slot
    for (int i = 0; i < ps->capacity; i++) {
        Particle* p = &ps->particles_current[i];
        if (p->life > 0.0f) continue;

        p->type = PARTICLE_RIPPLE;
        p->x = x;
        p->y = y;
        p->vx = 0.0f;
        p->vy = 0.0f;
        p->color = color;
        p->life = RIPPLE_LIFETIME;
        p->max_life = RIPPLE_LIFETIME;
        p->radius = 0.0f;
        p->max_radius = RIPPLE_MAX_RADIUS;
        p->thickness = RIPPLE_THICKNESS;
        return;
    }
}
// }}}

// {{{ particle_spawn_splash
void particle_spawn_splash(ParticleSystem* ps, float x, float y,
                           float tangent_x, float tangent_y, Color color) {
    if (!ps) return;

    // Base angle from tangent direction
    float base_angle = atan2f(tangent_y, tangent_x);

    int spawned = 0;
    for (int i = 0; i < ps->capacity && spawned < SPLASH_PARTICLE_COUNT; i++) {
        Particle* p = &ps->particles_current[i];
        if (p->life > 0.0f) continue;

        p->type = PARTICLE_SIMPLE;
        p->x = x;
        p->y = y;

        // Spread particles along tangent direction (+/- 30 degrees on each side)
        // Half go one direction, half go the other
        float side = (spawned < SPLASH_PARTICLE_COUNT / 2) ? 1.0f : -1.0f;
        float spread_offset = ((float)(rand() % 100) / 100.0f) * SPLASH_SPREAD;
        float angle = base_angle + side * (3.14159f + spread_offset);

        float speed = SPLASH_SPEED * (0.8f + 0.4f * (float)(rand() % 100) / 100.0f);
        p->vx = cosf(angle) * speed;
        p->vy = sinf(angle) * speed;

        p->color = color;
        p->life = SPLASH_LIFETIME * (0.8f + 0.4f * (float)(rand() % 100) / 100.0f);
        p->max_life = p->life;

        spawned++;
    }
}
// }}}

// {{{ particle_spawn_fragments
void particle_spawn_fragments(ParticleSystem* ps, float x, float y,
                              float vx, float vy, Color color,
                              FragmentMode mode, float nx, float ny) {
    if (!ps) return;

    // Choose number of fragments: 3, 4, 6, or 8
    int fragment_options[] = {3, 4, 6, 8};
    int num_fragments = fragment_options[rand() % 4];
    float slice_angle = 6.28318f / (float)num_fragments;  // Pie slice width

    float base_h, base_s, base_v;
    rgb_to_hsv(color, &base_h, &base_s, &base_v);

    // Calculate base angle for directional modes
    // Normal points away from collision; tangent is perpendicular
    float normal_angle = atan2f(ny, nx);
    float tangent_angle = normal_angle + 1.5708f;  // +90 degrees

    int spawned = 0;
    for (int i = 0; i < ps->capacity && spawned < num_fragments; i++) {
        Particle* p = &ps->particles_current[i];
        if (p->life > 0.0f) continue;

        p->type = PARTICLE_FRAGMENT;
        p->x = x;
        p->y = y;

        // Calculate outward angle based on fragment mode
        float outward_angle;
        switch (mode) {
            case FRAG_TANGENT:
                // "Wall" ball shatters along impact tangent in both directions
                // Fragments spread ±90° from tangent with some randomness
                {
                    // Alternate sides: even fragments go one way, odd the other
                    float side = (spawned % 2 == 0) ? 1.0f : -1.0f;
                    // Spread within ±45° of tangent direction
                    float spread = ((float)(rand() % 100) / 100.0f - 0.5f) * 1.5708f;
                    outward_angle = tangent_angle + side * 1.5708f + spread;
                }
                break;

            case FRAG_AWAY:
                // "Projectile" ball explodes away from impact point
                // Fragments spread in hemisphere opposite to normal (toward normal direction)
                {
                    // Distribute across 180° hemisphere in direction of normal
                    float spread = ((float)spawned / (float)num_fragments - 0.5f) * 3.14159f;
                    outward_angle = normal_angle + spread;
                }
                break;

            case FRAG_RADIAL:
            default:
                // Default 360° outward spread
                outward_angle = (float)spawned / (float)num_fragments * 6.28318f;
                break;
        }

        float speed = FRAGMENT_SPEED * (0.7f + 0.6f * (float)(rand() % 100) / 100.0f);
        p->vx = cosf(outward_angle) * speed + vx * 0.3f;
        p->vy = sinf(outward_angle) * speed + vy * 0.3f;

        // Fragment is a pie slice of the ball
        p->size = 8.0f;  // Ball radius (BALL_RADIUS)
        p->angle = outward_angle;  // Slice points in direction of travel
        p->slice_angle = slice_angle;
        p->angular_vel = FRAGMENT_ANGULAR_SPEED * (rand() % 2 ? 1.0f : -1.0f);

        // 1/5th chance of corkscrew motion
        p->corkscrew = (rand() % 5 == 0) ? 1 : 0;
        p->corkscrew_phase = (float)(rand() % 628) / 100.0f;

        // Initialize trail
        p->trail_head = 0;
        p->trail_timer = 0.0f;
        for (int t = 0; t < TRAIL_LENGTH; t++) {
            p->trail_x[t] = x;
            p->trail_y[t] = y;
        }

        // Vary hue for iridescent effect
        float hue_offset = ((float)spawned / (float)num_fragments) * 60.0f;
        p->color = hsv_to_rgb(base_h + hue_offset, base_s, base_v);

        p->life = FRAGMENT_LIFETIME * (0.8f + 0.4f * (float)(rand() % 100) / 100.0f);
        p->max_life = p->life;

        spawned++;
    }
}
// }}}

// {{{ particle_system_swap_buffers
void particle_system_swap_buffers(ParticleSystem* ps) {
    if (!ps) return;

    Particle* temp = ps->particles_current;
    ps->particles_current = ps->particles_next;
    ps->particles_next = temp;
}
// }}}

// {{{ particle_system_prepare_tasks
void particle_system_prepare_tasks(ParticleSystem* ps, World* world, float dt) {
    if (!ps) return;

    for (int i = 0; i < ps->capacity; i++) {
        ps->task_data[i].read_buffer = ps->particles_current;
        ps->task_data[i].write_buffer = ps->particles_next;
        ps->task_data[i].world = world;
        ps->task_data[i].dt = dt;

        // Propagate inactive state from current to next buffer
        // When a particle is inactive, no task is submitted. Without this,
        // particles_next retains stale active state from previous frames.
        if (ps->particles_current[i].life <= 0.0f) {
            ps->particles_next[i].life = 0.0f;
        }
    }
}
// }}}

// {{{ particle_system_submit_tasks
void particle_system_submit_tasks(ParticleSystem* ps, ThreadPool* pool) {
    if (!ps || !pool) return;

    for (int i = 0; i < ps->capacity; i++) {
        // Only submit tasks for active particles
        if (ps->particles_current[i].life > 0.0f) {
            threadpool_submit(pool, particle_update_task, &ps->task_data[i]);
        }
    }
}
// }}}

// {{{ particle_system_finalize_update
void particle_system_finalize_update(ParticleSystem* ps) {
    if (!ps) return;

    // Count active particles in next buffer
    int active = 0;
    for (int i = 0; i < ps->capacity; i++) {
        if (ps->particles_next[i].life > 0.0f) {
            active++;
        }
    }
    ps->active_count = active;
}
// }}}

// {{{ particle_update_task
void particle_update_task(void* data) {
    ParticleTaskData* task = (ParticleTaskData*)data;
    if (!task) return;

    int idx = task->particle_index;
    Particle* current = &task->read_buffer[idx];
    Particle* next = &task->write_buffer[idx];

    // Skip inactive particles
    if (current->life <= 0.0f) {
        next->life = 0.0f;
        return;
    }

    // Copy current state to next
    *next = *current;

    float dt = task->dt;
    World* world = task->world;

    switch (next->type) {
        case PARTICLE_SIMPLE:
            // Simple particles: gravity and movement
            next->vy += PARTICLE_GRAVITY * dt;
            next->x += next->vx * dt;
            next->y += next->vy * dt;
            break;

        case PARTICLE_RIPPLE:
            // Ripple: expand radius over lifetime
            next->radius += RIPPLE_EXPANSION_SPEED * dt;
            if (next->radius > next->max_radius) {
                next->radius = next->max_radius;
            }
            break;

        case PARTICLE_FRAGMENT: {
            // Fragment: gravity, movement, rotation, corkscrew, trail, collisions
            next->vy += FRAGMENT_GRAVITY * dt;

            // Calculate base movement
            float move_x = next->vx * dt;
            float move_y = next->vy * dt;

            // Apply corkscrew motion (perpendicular oscillation)
            if (next->corkscrew) {
                float elapsed = next->max_life - next->life;
                float phase = elapsed * CORKSCREW_FREQUENCY + next->corkscrew_phase;
                float offset = sinf(phase) * CORKSCREW_AMPLITUDE * dt;

                // Perpendicular to velocity direction
                float vel_mag = sqrtf(next->vx * next->vx + next->vy * next->vy);
                if (vel_mag > 0.1f) {
                    float perp_x = -next->vy / vel_mag;
                    float perp_y = next->vx / vel_mag;
                    move_x += perp_x * offset;
                    move_y += perp_y * offset;
                }
            }

            next->x += move_x;
            next->y += move_y;
            next->angle += next->angular_vel * dt;

            // Update trail
            next->trail_timer -= dt;
            if (next->trail_timer <= 0.0f) {
                next->trail_timer = TRAIL_INTERVAL;
                next->trail_x[next->trail_head] = next->x;
                next->trail_y[next->trail_head] = next->y;
                next->trail_head = (next->trail_head + 1) % TRAIL_LENGTH;
            }

            // Fragment collision with pegs (if world provided)
            if (world) {
                // Check player pegs
                for (int j = 0; j < world->peg_count; j++) {
                    float dx = next->x - world->pegs[j].x;
                    float dy = next->y - world->pegs[j].y;
                    float dist = sqrtf(dx * dx + dy * dy);
                    float min_dist = world->pegs[j].radius + next->size;

                    if (dist < min_dist && dist > 0.001f) {
                        float nx = dx / dist;
                        float ny = dy / dist;
                        float dot = next->vx * nx + next->vy * ny;
                        next->vx -= 2.0f * dot * nx * 0.6f;
                        next->vy -= 2.0f * dot * ny * 0.6f;
                        next->x = world->pegs[j].x + nx * min_dist;
                        next->y = world->pegs[j].y + ny * min_dist;
                    }
                }

                // Check adversary pegs
                for (int j = 0; j < world->adversary_peg_count; j++) {
                    float dx = next->x - world->adversary_pegs[j].x;
                    float dy = next->y - world->adversary_pegs[j].y;
                    float dist = sqrtf(dx * dx + dy * dy);
                    float min_dist = world->adversary_pegs[j].radius + next->size;

                    if (dist < min_dist && dist > 0.001f) {
                        float nx = dx / dist;
                        float ny = dy / dist;
                        float dot = next->vx * nx + next->vy * ny;
                        next->vx -= 2.0f * dot * nx * 0.6f;
                        next->vy -= 2.0f * dot * ny * 0.6f;
                        next->x = world->adversary_pegs[j].x + nx * min_dist;
                        next->y = world->adversary_pegs[j].y + ny * min_dist;
                    }
                }

                // Check bumpers
                for (int j = 0; j < world->bumper_count; j++) {
                    float dx = next->x - world->bumpers[j].x;
                    float dy = next->y - world->bumpers[j].y;
                    float dist = sqrtf(dx * dx + dy * dy);
                    float min_dist = world->bumpers[j].radius + next->size;

                    if (dist < min_dist && dist > 0.001f) {
                        float nx = dx / dist;
                        float ny = dy / dist;
                        float dot = next->vx * nx + next->vy * ny;
                        next->vx -= 2.0f * dot * nx * 0.4f;
                        next->vy -= 2.0f * dot * ny * 0.4f;
                        next->x = world->bumpers[j].x + nx * min_dist;
                        next->y = world->bumpers[j].y + ny * min_dist;
                    }
                }

                // Check adversary bumpers
                for (int j = 0; j < world->adversary_bumper_count; j++) {
                    float dx = next->x - world->adversary_bumpers[j].x;
                    float dy = next->y - world->adversary_bumpers[j].y;
                    float dist = sqrtf(dx * dx + dy * dy);
                    float min_dist = world->adversary_bumpers[j].radius + next->size;

                    if (dist < min_dist && dist > 0.001f) {
                        float nx = dx / dist;
                        float ny = dy / dist;
                        float dot = next->vx * nx + next->vy * ny;
                        next->vx -= 2.0f * dot * nx * 0.4f;
                        next->vy -= 2.0f * dot * ny * 0.4f;
                        next->x = world->adversary_bumpers[j].x + nx * min_dist;
                        next->y = world->adversary_bumpers[j].y + ny * min_dist;
                    }
                }

                // Wall bounces
                float wall_left = world->table_x;
                float wall_right = world->table_x + world->table_width;

                if (next->x - next->size < wall_left) {
                    next->x = wall_left + next->size;
                    next->vx = -next->vx * 0.5f;
                }
                if (next->x + next->size > wall_right) {
                    next->x = wall_right - next->size;
                    next->vx = -next->vx * 0.5f;
                }
            }
            break;
        }
    }

    // Decrement life
    next->life -= dt;
}
// }}}
