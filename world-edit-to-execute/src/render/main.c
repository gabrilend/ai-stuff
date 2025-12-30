/*
 * WC3 Engine - Interactive Threaded Renderer Demo
 *
 * Demonstrates the staged threading architecture from docs/render-architecture.md:
 * - Updater thread: populates worker inputs from game state
 * - Worker threads: compute GPU-ready render data (always busy)
 * - Sync thread: swaps worker outputs to primary buffer (minimal work)
 * - Draw thread: renders from primary buffer (minimal work)
 *
 * Interactive features:
 * - UI sliders for speed controls (orbit, spin, clock)
 * - Left-click on chunk: cycle color (blue -> green -> red)
 * - Right-click on chunk: destroy with spark particles
 *
 * Based on template at: /home/ritz/programming/c/games/template/
 */

#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include "pthread.h"
#include "raylib.h"
#include "rlgl.h"
#include "threading.h"
#include "slots.h"
#include "bridge.h"

/* {{{ Constants */
#define WINDOW_WIDTH 800
#define WINDOW_HEIGHT 600
#define TARGET_FPS 60
#define NUM_WORKERS 2
#define DEMO_MAX_SLOTS 64
#define MAX_PARTICLES 256
#define MAX_CHUNKS 1024
/* }}} */

/* {{{ Speed Parameters - adjustable via sliders */
typedef struct speed_params {
    float clock_speed;    /* clock rotation speed */
    float spin_speed;     /* in-place spin speed */
    float orbit_radius;   /* distance from center pillar */
} SpeedParams;

static SpeedParams g_speeds = {
    .clock_speed = 0.15f,
    .spin_speed = 0.5f,
    .orbit_radius = 3.0f
};
/* }}} */

/* {{{ UISlider - simple horizontal slider */
typedef struct ui_slider {
    float x, y;           /* position */
    float width, height;  /* size */
    float min, max;       /* value range */
    float* value;         /* pointer to value being controlled */
    const char* label;    /* display name */
    bool dragging;        /* currently being dragged */
} UISlider;
/* }}} */

/* {{{ ChunkState - mutable state per chunk */
typedef struct chunk_state {
    int color_index;      /* 0=blue, 1=green, 2=red */
    bool destroyed;       /* right-click destroys */
} ChunkState;
/* }}} */

/* {{{ Particle - spark effect */
typedef struct particle {
    float x, y, z;        /* position */
    float vx, vy, vz;     /* velocity */
    float life;           /* remaining lifetime (0-1) */
    unsigned char r, g, b;
    bool active;
} Particle;
/* }}} */

/* {{{ PrimaryBuffer - what the draw thread reads from */
typedef struct primary_buffer {
    SlotArray* slots;
    pthread_mutex_t lock;
} PrimaryBuffer;
/* }}} */

/* {{{ ChunkData - pre-computed chunk for mesh rendering */
typedef struct chunk_data {
    float x, y, z;
    float size;
    unsigned char r, g, b;
    bool is_solid;
} ChunkData;
/* }}} */

/* {{{ MeshData - cube mesh definition */
typedef struct mesh_data {
    float size;
    ChunkData* chunks;
    int chunk_count;
} MeshData;
/* }}} */

/* {{{ Global State */
static MeshData* g_cube_mesh = NULL;
static PrimaryBuffer g_primary;
static atomic_bool g_running = true;
static unsigned int g_tick = 0;
static float g_game_time = 0.0f;
static int g_demo_slot_index = -1;

/* Interactive state */
static ChunkState g_chunk_states[MAX_CHUNKS];
static Particle g_particles[MAX_PARTICLES];
static UISlider g_sliders[3];
static int g_slider_count = 3;

/* Lua state for 508c bridge */
static lua_State* g_lua = NULL;
static int g_lua_entity_count = 0;  /* Entities created via Lua bridge */

/* LuaJIT/Lua 5.1 compatibility: lua_rawlen doesn't exist */
#ifndef lua_rawlen
#define lua_rawlen(L, idx) lua_objlen(L, idx)
#endif
/* }}} */

/* {{{ Color Palette - for chunk color cycling */
static const unsigned char COLOR_PALETTE[3][3] = {
    { 40, 90, 200 },   /* 0: blue */
    { 40, 180, 60 },   /* 1: green */
    { 200, 60, 40 }    /* 2: red */
};
/* }}} */

/* {{{ init_sliders
 * Creates UI sliders for speed controls */
void init_sliders(void) {
    float y_start = WINDOW_HEIGHT - 100;
    float x = 20;
    float w = 150;
    float h = 16;
    float spacing = 26;

    g_sliders[0] = (UISlider){
        .x = x, .y = y_start,
        .width = w, .height = h,
        .min = 0.01f, .max = 1.0f,
        .value = &g_speeds.clock_speed,
        .label = "Clock",
        .dragging = false
    };

    g_sliders[1] = (UISlider){
        .x = x, .y = y_start + spacing,
        .width = w, .height = h,
        .min = 0.0f, .max = 2.0f,
        .value = &g_speeds.spin_speed,
        .label = "Spin",
        .dragging = false
    };

    g_sliders[2] = (UISlider){
        .x = x, .y = y_start + spacing * 2,
        .width = w, .height = h,
        .min = 1.0f, .max = 6.0f,
        .value = &g_speeds.orbit_radius,
        .label = "Orbit R",
        .dragging = false
    };
}
/* }}} */

/* {{{ update_sliders
 * Process mouse input for sliders.
 * Returns true if any slider is being interacted with */
bool update_sliders(void) {
    Vector2 mouse = GetMousePosition();
    bool left_down = IsMouseButtonDown(MOUSE_LEFT_BUTTON);
    bool left_pressed = IsMouseButtonPressed(MOUSE_LEFT_BUTTON);
    bool any_active = false;

    for (int i = 0; i < g_slider_count; i++) {
        UISlider* s = &g_sliders[i];

        /* Check if mouse is over slider track */
        bool over = (mouse.x >= s->x && mouse.x <= s->x + s->width &&
                     mouse.y >= s->y && mouse.y <= s->y + s->height);

        if (left_pressed && over) {
            s->dragging = true;
        }

        if (!left_down) {
            s->dragging = false;
        }

        if (s->dragging) {
            any_active = true;
            /* Compute normalized position */
            float t = (mouse.x - s->x) / s->width;
            if (t < 0) t = 0;
            if (t > 1) t = 1;
            /* Map to value range */
            *s->value = s->min + t * (s->max - s->min);
        }
    }

    return any_active;
}
/* }}} */

/* {{{ draw_sliders
 * Render sliders with labels and current values */
void draw_sliders(void) {
    for (int i = 0; i < g_slider_count; i++) {
        UISlider* s = &g_sliders[i];

        /* Track background */
        DrawRectangle((int)s->x, (int)s->y, (int)s->width, (int)s->height, DARKGRAY);

        /* Fill based on value */
        float t = (*s->value - s->min) / (s->max - s->min);
        int fill_w = (int)(s->width * t);
        DrawRectangle((int)s->x, (int)s->y, fill_w, (int)s->height, GRAY);

        /* Handle */
        int handle_x = (int)(s->x + fill_w - 3);
        DrawRectangle(handle_x, (int)s->y - 2, 6, (int)s->height + 4, WHITE);

        /* Label and value */
        char buf[32];
        snprintf(buf, sizeof(buf), "%s: %.2f", s->label, *s->value);
        DrawText(buf, (int)s->x + (int)s->width + 10, (int)s->y, 14, LIGHTGRAY);
    }
}
/* }}} */

/* {{{ init_chunk_states
 * Initialize chunk states (all blue, not destroyed) */
void init_chunk_states(int chunk_count) {
    for (int i = 0; i < chunk_count && i < MAX_CHUNKS; i++) {
        g_chunk_states[i].color_index = 0;
        g_chunk_states[i].destroyed = false;
    }
}
/* }}} */

/* {{{ spawn_particles
 * Create spark particles at given world position */
void spawn_particles(float wx, float wy, float wz, unsigned char r, unsigned char g, unsigned char b) {
    int spawned = 0;
    for (int i = 0; i < MAX_PARTICLES && spawned < 12; i++) {
        if (!g_particles[i].active) {
            Particle* p = &g_particles[i];
            p->x = wx;
            p->y = wy;
            p->z = wz;
            /* Random velocity in all directions */
            p->vx = ((float)(rand() % 200 - 100) / 100.0f) * 2.0f;
            p->vy = ((float)(rand() % 100) / 100.0f) * 3.0f;
            p->vz = ((float)(rand() % 200 - 100) / 100.0f) * 2.0f;
            p->life = 1.0f;
            p->r = r;
            p->g = g;
            p->b = b;
            p->active = true;
            spawned++;
        }
    }
}
/* }}} */

/* {{{ update_particles
 * Simulate particle physics */
void update_particles(float dt) {
    for (int i = 0; i < MAX_PARTICLES; i++) {
        if (g_particles[i].active) {
            Particle* p = &g_particles[i];
            /* Gravity */
            p->vy -= 9.8f * dt;
            /* Movement */
            p->x += p->vx * dt;
            p->y += p->vy * dt;
            p->z += p->vz * dt;
            /* Decay */
            p->life -= dt * 2.0f;
            if (p->life <= 0) {
                p->active = false;
            }
        }
    }
}
/* }}} */

/* {{{ draw_particles
 * Render active particles as small cubes */
void draw_particles(void) {
    for (int i = 0; i < MAX_PARTICLES; i++) {
        if (g_particles[i].active) {
            Particle* p = &g_particles[i];
            unsigned char alpha = (unsigned char)(p->life * 255);
            Color col = { p->r, p->g, p->b, alpha };
            DrawCube((Vector3){ p->x, p->y, p->z }, 0.05f, 0.05f, 0.05f, col);
        }
    }
}
/* }}} */

/* {{{ create_cube_mesh */
MeshData* create_cube_mesh(float size, float chunk_size) {
    MeshData* mesh = (MeshData*)malloc(sizeof(MeshData));
    mesh->size = size;

    float half = size / 2.0f;
    float chunk = chunk_size;

    /* Count chunks */
    int count = 0;
    for (float x = -half; x < half; x += chunk) {
        for (float y = -half; y < half; y += chunk) {
            for (float z = -half; z < half; z += chunk) {
                count++;
            }
        }
    }

    mesh->chunks = (ChunkData*)malloc(count * sizeof(ChunkData));
    mesh->chunk_count = count;

    /* Pre-compute chunks */
    int i = 0;
    for (float x = -half; x < half; x += chunk) {
        for (float y = -half; y < half; y += chunk) {
            for (float z = -half; z < half; z += chunk) {
                ChunkData* c = &mesh->chunks[i];
                c->x = x + chunk / 2.0f;
                c->y = y + chunk / 2.0f;
                c->z = z + chunk / 2.0f;
                c->size = chunk * (0.9f + 0.1f * sinf(x + y + z));

                /* Base color (will be overridden by chunk state) */
                c->r = 40;
                c->g = 90;
                c->b = 200;

                bool surface = (x <= -half + chunk || x >= half - chunk ||
                                y <= -half + chunk || y >= half - chunk ||
                                z <= -half + chunk || z >= half - chunk);
                c->is_solid = surface;
                i++;
            }
        }
    }

    return mesh;
}
/* }}} */

/* {{{ rotate_around_axis
 * Rodrigues' rotation formula: rotate point around arbitrary axis.
 * axis must be normalized. angle in radians. */
void rotate_around_axis(float px, float py, float pz,
                        float ax, float ay, float az,
                        float angle,
                        float* ox, float* oy, float* oz) {
    float c = cosf(angle);
    float s = sinf(angle);
    float t = 1.0f - c;

    /* Rodrigues: v' = v*cos + (k×v)*sin + k*(k·v)*(1-cos) */
    /* Cross product k × v */
    float cx = ay * pz - az * py;
    float cy = az * px - ax * pz;
    float cz = ax * py - ay * px;

    /* Dot product k · v */
    float dot = ax * px + ay * py + az * pz;

    *ox = px * c + cx * s + ax * dot * t;
    *oy = py * c + cy * s + ay * dot * t;
    *oz = pz * c + cz * s + az * dot * t;
}
/* }}} */

/* {{{ transform_chunk_to_world
 * Transform chunk local position to world position given slot transforms.
 * Must match the order in render_cube_at_slot:
 *   1. Spin around Y (applied first to local coords)
 *   2. Clock rotation around (0.577, 0.577, 0.577)
 *   3. Scale
 *   4. Translate to world position */
void transform_chunk_to_world(ChunkData* c, RenderSlot* slot, float* wx, float* wy, float* wz) {
    float px = c->x;
    float py = c->y;
    float pz = c->z;

    /* 1. Spin around Y axis (counter-clockwise per OpenGL convention) */
    float rad_spin = slot->spin * 3.14159f / 180.0f;
    float cos_s = cosf(rad_spin);
    float sin_s = sinf(rad_spin);
    float rx = px * cos_s - pz * sin_s;
    float ry = py;
    float rz = px * sin_s + pz * cos_s;

    /* 2. Clock rotation around diagonal axis (0.577, 0.577, 0.577) */
    float rad_clock = slot->rotation * 3.14159f / 180.0f;
    float fx, fy, fz;
    rotate_around_axis(rx, ry, rz,
                       0.577f, 0.577f, 0.577f,
                       rad_clock,
                       &fx, &fy, &fz);

    /* 3. Scale */
    fx *= slot->scale;
    fy *= slot->scale;
    fz *= slot->scale;

    /* 4. Translate to world position */
    *wx = fx + slot->x;
    *wy = fy + slot->y;
    *wz = fz + slot->z;
}
/* }}} */

/* {{{ find_chunk_at_ray
 * Returns chunk index at ray hit, or -1 if none.
 * Uses simple distance-based picking. */
int find_chunk_at_ray(Ray ray, RenderSlot* slot, MeshData* mesh) {
    int closest = -1;
    float closest_dist = 1000.0f;

    for (int i = 0; i < mesh->chunk_count; i++) {
        if (!mesh->chunks[i].is_solid) continue;
        if (g_chunk_states[i].destroyed) continue;

        ChunkData* c = &mesh->chunks[i];
        float wx, wy, wz;
        transform_chunk_to_world(c, slot, &wx, &wy, &wz);

        /* Simple sphere test for picking */
        float radius = c->size * slot->scale * 0.5f;
        Vector3 center = { wx, wy, wz };
        RayCollision col = GetRayCollisionSphere(ray, center, radius);

        if (col.hit && col.distance < closest_dist) {
            closest_dist = col.distance;
            closest = i;
        }
    }

    return closest;
}
/* }}} */

/* {{{ process_chunk_input
 * Handle mouse clicks on chunks */
void process_chunk_input(RenderSlot* slot, MeshData* mesh, Camera3D* camera) {
    if (!slot || !slot->visible) return;

    /* Check if clicking on slider area */
    Vector2 mouse = GetMousePosition();
    if (mouse.y > WINDOW_HEIGHT - 120) return;

    bool left_click = IsMouseButtonPressed(MOUSE_LEFT_BUTTON);
    bool right_click = IsMouseButtonPressed(MOUSE_RIGHT_BUTTON);

    if (!left_click && !right_click) return;

    Ray ray = GetMouseRay(mouse, *camera);
    int chunk_idx = find_chunk_at_ray(ray, slot, mesh);

    if (chunk_idx >= 0 && chunk_idx < MAX_CHUNKS) {
        ChunkState* state = &g_chunk_states[chunk_idx];
        ChunkData* c = &mesh->chunks[chunk_idx];

        if (left_click) {
            /* Cycle color: blue -> green -> red -> blue */
            state->color_index = (state->color_index + 1) % 3;
        } else if (right_click) {
            /* Destroy with particles */
            state->destroyed = true;

            /* Get world position for particles */
            float wx, wy, wz;
            transform_chunk_to_world(c, slot, &wx, &wy, &wz);

            /* Spawn sparks using chunk color */
            int ci = state->color_index;
            spawn_particles(wx, wy, wz,
                            COLOR_PALETTE[ci][0],
                            COLOR_PALETTE[ci][1],
                            COLOR_PALETTE[ci][2]);
        }
    }
}
/* }}} */

/* {{{ render_cube_at_slot
 * Renders cube with per-chunk state (color, destroyed) */
void render_cube_at_slot(RenderSlot* slot, MeshData* mesh) {
    if (!slot->visible) return;

    rlPushMatrix();
        rlTranslatef(slot->x, slot->y, slot->z);
        rlScalef(slot->scale, slot->scale, slot->scale);
        rlRotatef(slot->rotation, 0.577f, 0.577f, 0.577f);
        rlRotatef(slot->spin, 0.0f, 1.0f, 0.0f);

        for (int i = 0; i < mesh->chunk_count && i < MAX_CHUNKS; i++) {
            ChunkData* c = &mesh->chunks[i];
            if (!c->is_solid) continue;
            if (g_chunk_states[i].destroyed) continue;

            /* Get color from palette based on chunk state */
            int ci = g_chunk_states[i].color_index;
            Color col = {
                COLOR_PALETTE[ci][0],
                COLOR_PALETTE[ci][1],
                COLOR_PALETTE[ci][2],
                255
            };

            DrawCube((Vector3){ c->x, c->y, c->z }, c->size, c->size, c->size, col);
        }
    rlPopMatrix();
}
/* }}} */

/* {{{ worker_process_fn
 * Worker computes orbital position and rotations from game time */
void worker_process_fn(WorkerContext* ctx, void* input_ptr, void* output_ptr) {
    WorkerInput* input = (WorkerInput*)input_ptr;
    WorkerOutput* output = (WorkerOutput*)output_ptr;

    /* Read current speed params (safe: main thread only writes between frames) */
    float clock_speed = g_speeds.clock_speed;
    float spin_speed = g_speeds.spin_speed;
    float orbit_radius = g_speeds.orbit_radius;

    float orbit_angle = input->game_time * clock_speed * 2.0f * 3.14159f;
    float clock_rotation = fmodf(input->game_time * clock_speed * 360.0f, 360.0f);
    float spin = fmodf(input->game_time * spin_speed * 360.0f, 360.0f);

    float orbit_x = orbit_radius * cosf(orbit_angle);
    float orbit_z = orbit_radius * sinf(orbit_angle);

    if (ctx->worker_id == 0) {
        RenderSlot* slot = (RenderSlot*)output->slot_data;
        if (!slot) {
            slot = (RenderSlot*)malloc(sizeof(RenderSlot));
            output->slot_data = slot;
        }

        slot->x = orbit_x;
        slot->y = 0.0f;
        slot->z = orbit_z;
        slot->rotation = clock_rotation;
        slot->spin = spin;
        slot->scale = 1.0f;
        slot->r = 40;
        slot->g = 90;
        slot->b = 200;
        slot->a = 255;
        slot->visible = true;
        slot->mesh_id = 0;

        output->slot_count = 1;
    } else {
        output->slot_count = 0;
    }
}
/* }}} */

/* {{{ get_game_input */
bool get_game_input(WorkerInput* out) {
    static unsigned int last_tick = 0;

    unsigned int current_tick = g_tick;
    if (current_tick == last_tick) {
        return false;
    }

    last_tick = current_tick;
    out->tick = current_tick;
    out->game_time = g_game_time;
    out->entity_count = 1;
    out->camera_x = 5.0f;
    out->camera_y = 5.0f;
    out->camera_z = 5.0f;

    return true;
}
/* }}} */

/* {{{ sync_to_primary */
void sync_to_primary(WorkerPool* pool) {
    pthread_mutex_lock(&g_primary.lock);

    for (int i = 0; i < pool->count; i++) {
        WorkerBuffers* buf = &pool->buffers[i];

        if (atomic_load(&buf->output_ready)) {
            pthread_mutex_lock(&buf->output_lock);

            if (buf->output.slot_data && buf->output.slot_count > 0) {
                RenderSlot* src = (RenderSlot*)buf->output.slot_data;

                if (i == 0 && g_demo_slot_index >= 0) {
                    ComponentSlot* slot = slot_get(g_primary.slots, g_demo_slot_index);
                    if (slot && slot->in_use) {
                        RenderSlot* new_data = (RenderSlot*)malloc(sizeof(RenderSlot));
                        if (new_data) {
                            *new_data = *src;
                            slot_set(slot, new_data);
                        }
                    }
                }
            }

            atomic_store(&buf->output_ready, false);
            pthread_mutex_unlock(&buf->output_lock);
        }
    }

    pthread_mutex_unlock(&g_primary.lock);
}
/* }}} */

/* {{{ custom_sync_loop */
void* custom_sync_loop(void* arg) {
    WorkerPool* pool = (WorkerPool*)arg;
    printf("[sync] Starting custom sync loop\n");

    while (atomic_load(&g_running)) {
        sync_to_primary(pool);
        usleep(1000);
    }

    printf("[sync] Exiting\n");
    return NULL;
}
/* }}} */

/* {{{ custom_updater_loop */
void* custom_updater_loop(void* arg) {
    WorkerPool* pool = (WorkerPool*)arg;
    printf("[updater] Starting custom updater loop\n");

    WorkerInput input;
    memset(&input, 0, sizeof(input));

    while (atomic_load(&g_running)) {
        if (get_game_input(&input)) {
            distribute_input_to_workers(pool, &input);
        } else {
            usleep(1000);
        }
    }

    printf("[updater] Exiting\n");
    return NULL;
}
/* }}} */

/* {{{ tick_loop */
void tick_loop(float dt) {
    g_game_time += dt;
    g_tick++;
}
/* }}} */

/* {{{ count_active_chunks
 * Count non-destroyed chunks */
int count_active_chunks(MeshData* mesh) {
    int count = 0;
    for (int i = 0; i < mesh->chunk_count && i < MAX_CHUNKS; i++) {
        if (mesh->chunks[i].is_solid && !g_chunk_states[i].destroyed) {
            count++;
        }
    }
    return count;
}
/* }}} */

/* {{{ init_lua_bridge
 * Initialize Lua state and register render module.
 * Runs a test script to verify the bridge works. */
bool init_lua_bridge(void) {
    /* Create Lua state */
    g_lua = luaL_newstate();
    if (!g_lua) {
        fprintf(stderr, "[lua] Failed to create Lua state\n");
        return false;
    }

    /* Open standard libraries */
    luaL_openlibs(g_lua);

    /* Initialize bridge with slot array */
    bridge_init(g_primary.slots);

    /* Register render module (LuaJIT compatible preloading) */
    lua_getglobal(g_lua, "package");
    lua_getfield(g_lua, -1, "preload");
    lua_pushcfunction(g_lua, luaopen_render);
    lua_setfield(g_lua, -2, "render");
    lua_pop(g_lua, 2);  /* Pop preload and package */

    printf("[lua] Lua state created and render module registered\n");

    /* Run inline test script */
    const char* test_script =
        "local render = require('render')\n"
        "print('[lua] render module loaded, MAX_SLOTS = ' .. render.MAX_SLOTS)\n"
        "\n"
        "-- Create test entities at different positions\n"
        "local slots = {}\n"
        "local positions = {\n"
        "    {id=100, x=-3, y=0, z=0, r=255, g=100, b=100},\n"
        "    {id=101, x=3, y=0, z=0, r=100, g=255, b=100},\n"
        "    {id=102, x=0, y=0, z=-3, r=100, g=100, b=255},\n"
        "    {id=103, x=0, y=0, z=3, r=255, g=255, b=100},\n"
        "}\n"
        "\n"
        "for _, p in ipairs(positions) do\n"
        "    local slot = render.create_entity(p.id, render.MESH_CUBE, p.x, p.y, p.z)\n"
        "    if slot >= 0 then\n"
        "        render.set_color(slot, p.r, p.g, p.b)\n"
        "        render.set_scale(slot, 0.5)\n"
        "        table.insert(slots, slot)\n"
        "        print('[lua] Created entity ' .. p.id .. ' at slot ' .. slot)\n"
        "    end\n"
        "end\n"
        "\n"
        "local active, max = render.get_slot_count()\n"
        "print('[lua] Slots: ' .. active .. '/' .. max .. ' active')\n"
        "\n"
        "-- Store slot count for C to query\n"
        "_G.lua_entity_slots = slots\n"
        "_G.lua_entity_count = #slots\n";

    int result = luaL_dostring(g_lua, test_script);
    if (result != LUA_OK) {
        fprintf(stderr, "[lua] Error: %s\n", lua_tostring(g_lua, -1));
        lua_pop(g_lua, 1);
        return false;
    }

    /* Get entity count from Lua */
    lua_getglobal(g_lua, "lua_entity_count");
    if (lua_isnumber(g_lua, -1)) {
        g_lua_entity_count = (int)lua_tointeger(g_lua, -1);
    }
    lua_pop(g_lua, 1);

    printf("[lua] Bridge test complete: %d entities created via Lua\n", g_lua_entity_count);
    return true;
}
/* }}} */

/* {{{ update_lua_entities
 * Called each frame to update Lua-created entities.
 * Applies rotation animation to demonstrate the bridge works. */
void update_lua_entities(float dt) {
    if (!g_lua) return;

    /* Run Lua update script */
    static float lua_time = 0.0f;
    lua_time += dt;

    /* Update positions via Lua bridge */
    lua_getglobal(g_lua, "lua_entity_slots");
    if (lua_istable(g_lua, -1)) {
        int n = (int)lua_rawlen(g_lua, -1);
        for (int i = 1; i <= n; i++) {
            lua_rawgeti(g_lua, -1, i);
            if (lua_isnumber(g_lua, -1)) {
                int slot_idx = (int)lua_tointeger(g_lua, -1);
                ComponentSlot* slot = slot_get(g_primary.slots, slot_idx);
                if (slot && slot->in_use && slot->data) {
                    /* Animate rotation */
                    slot->data->spin = fmodf(lua_time * 90.0f, 360.0f);
                    /* Bob up and down */
                    slot->data->y = sinf(lua_time * 2.0f + i) * 0.3f;
                }
            }
            lua_pop(g_lua, 1);
        }
    }
    lua_pop(g_lua, 1);
}
/* }}} */

/* {{{ render_lua_entities
 * Render entities created via Lua bridge as simple cubes. */
void render_lua_entities(void) {
    if (!g_lua) return;

    lua_getglobal(g_lua, "lua_entity_slots");
    if (lua_istable(g_lua, -1)) {
        int n = (int)lua_rawlen(g_lua, -1);
        for (int i = 1; i <= n; i++) {
            lua_rawgeti(g_lua, -1, i);
            if (lua_isnumber(g_lua, -1)) {
                int slot_idx = (int)lua_tointeger(g_lua, -1);
                ComponentSlot* slot = slot_get(g_primary.slots, slot_idx);
                if (slot && slot->in_use && slot->data && slot->data->visible) {
                    RenderSlot* rs = slot->data;

                    rlPushMatrix();
                        rlTranslatef(rs->x, rs->y, rs->z);
                        rlScalef(rs->scale, rs->scale, rs->scale);
                        rlRotatef(rs->spin, 0.0f, 1.0f, 0.0f);

                        Color col = { rs->r, rs->g, rs->b, rs->a };
                        DrawCube((Vector3){0, 0, 0}, 1.0f, 1.0f, 1.0f, col);
                        DrawCubeWires((Vector3){0, 0, 0}, 1.0f, 1.0f, 1.0f, WHITE);
                    rlPopMatrix();
                }
            }
            lua_pop(g_lua, 1);
        }
    }
    lua_pop(g_lua, 1);
}
/* }}} */

/* {{{ cleanup_lua
 * Clean up Lua state. */
void cleanup_lua(void) {
    if (g_lua) {
        /* Destroy Lua-created entities */
        lua_getglobal(g_lua, "lua_entity_slots");
        if (lua_istable(g_lua, -1)) {
            int n = (int)lua_rawlen(g_lua, -1);
            for (int i = 1; i <= n; i++) {
                lua_rawgeti(g_lua, -1, i);
                if (lua_isnumber(g_lua, -1)) {
                    int slot_idx = (int)lua_tointeger(g_lua, -1);
                    slot_release(g_primary.slots, slot_idx);
                }
                lua_pop(g_lua, 1);
            }
        }
        lua_pop(g_lua, 1);

        lua_close(g_lua);
        g_lua = NULL;
        printf("[lua] Lua state closed\n");
    }
}
/* }}} */

/* {{{ cleanup */
void cleanup(WorkerPool* pool) {
    for (int i = 0; i < pool->count; i++) {
        if (pool->buffers[i].output.slot_data) {
            free(pool->buffers[i].output.slot_data);
        }
    }

    if (g_cube_mesh) {
        if (g_cube_mesh->chunks) free(g_cube_mesh->chunks);
        free(g_cube_mesh);
    }

    if (g_primary.slots) {
        slot_array_destroy(g_primary.slots);
        g_primary.slots = NULL;
    }

    pthread_mutex_destroy(&g_primary.lock);
}
/* }}} */

/* {{{ main */
int main(void) {
    printf("=== WC3 Engine - Interactive Threaded Demo ===\n");
    printf("Architecture: Updater -> Workers -> Sync -> Draw\n");
    printf("Workers: %d  Slot System: 508b  Lua Bridge: 508c\n", NUM_WORKERS);
    printf("\nControls:\n");
    printf("  Left-click chunk:  Cycle color (blue/green/red)\n");
    printf("  Right-click chunk: Destroy with sparks\n");
    printf("  Sliders: Adjust speeds and orbit radius\n\n");

    /* Create cube mesh */
    g_cube_mesh = create_cube_mesh(2.0f, 0.2f);
    printf("[main] Created mesh with %d chunks\n", g_cube_mesh->chunk_count);

    /* Initialize chunk states */
    init_chunk_states(g_cube_mesh->chunk_count);

    /* Initialize particles */
    memset(g_particles, 0, sizeof(g_particles));

    /* Initialize primary buffer */
    memset(&g_primary, 0, sizeof(g_primary));
    pthread_mutex_init(&g_primary.lock, NULL);

    g_primary.slots = slot_array_create();
    if (!g_primary.slots) {
        fprintf(stderr, "[main] Failed to create slot array\n");
        return 1;
    }
    printf("[main] Created slot array with %d max slots\n", MAX_SLOTS);

    g_demo_slot_index = slot_allocate_for_entity(g_primary.slots, 0);
    if (g_demo_slot_index < 0) {
        fprintf(stderr, "[main] Failed to allocate demo slot\n");
        slot_array_destroy(g_primary.slots);
        return 1;
    }
    printf("[main] Allocated demo slot at index %d\n", g_demo_slot_index);

    /* Initialize Lua bridge (508c) */
    if (!init_lua_bridge()) {
        fprintf(stderr, "[main] Failed to initialize Lua bridge\n");
        slot_array_destroy(g_primary.slots);
        return 1;
    }

    /* Create worker pool */
    WorkerPool* pool = pool_create(NUM_WORKERS);
    pool_set_process_fn(pool, worker_process_fn);
    pool_set_primary_buffer(pool, &g_primary);

    /* Spawn threads */
    pthread_t sync_thread, updater_thread;
    pthread_create(&sync_thread, NULL, custom_sync_loop, pool);
    pthread_create(&updater_thread, NULL, custom_updater_loop, pool);

    /* Initialize raylib */
    printf("[main] Initializing window...\n");
    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "WC3 Engine - Interactive Demo");
    SetTargetFPS(TARGET_FPS);

    /* Initialize sliders */
    init_sliders();

    Camera3D camera = { 0 };
    camera.position = (Vector3){ 8.0f, 6.0f, 8.0f };
    camera.target = (Vector3){ 0.0f, 0.0f, 0.0f };
    camera.up = (Vector3){ 0.0f, 1.0f, 0.0f };
    camera.fovy = 45.0f;
    camera.projection = CAMERA_PERSPECTIVE;

    printf("[main] Entering render loop...\n\n");

    while (!WindowShouldClose()) {
        float dt = GetFrameTime();

        tick_loop(dt);
        update_particles(dt);
        update_lua_entities(dt);  /* 508c: Update Lua-created entities */

        /* Handle slider input first */
        bool slider_active = update_sliders();

        /* Read slot from primary buffer */
        RenderSlot slot_copy = {0};
        bool have_slot = false;

        pthread_mutex_lock(&g_primary.lock);
        if (g_demo_slot_index >= 0) {
            ComponentSlot* slot = slot_get(g_primary.slots, g_demo_slot_index);
            if (slot && slot->in_use && slot->data) {
                slot_copy = *(slot->data);
                have_slot = true;
            }
        }
        pthread_mutex_unlock(&g_primary.lock);

        /* Handle chunk clicks (if not using slider) */
        if (!slider_active && have_slot) {
            process_chunk_input(&slot_copy, g_cube_mesh, &camera);
        }

        /* Render */
        BeginDrawing();
            ClearBackground(BLACK);

            BeginMode3D(camera);
                /* Central pillar */
                DrawCylinder((Vector3){0, -2, 0}, 0.3f, 0.3f, 4.0f, 12, DARKGRAY);
                DrawCylinderWires((Vector3){0, -2, 0}, 0.3f, 0.3f, 4.0f, 12, GRAY);

                /* Clock hand and cube */
                if (have_slot && slot_copy.visible) {
                    DrawLine3D((Vector3){0, 0, 0},
                               (Vector3){slot_copy.x, slot_copy.y, slot_copy.z},
                               GRAY);
                    render_cube_at_slot(&slot_copy, g_cube_mesh);
                }

                /* Ground reference circle */
                DrawCircle3D((Vector3){0, -0.01f, 0}, g_speeds.orbit_radius,
                             (Vector3){1, 0, 0}, 90.0f, DARKGRAY);

                /* Particles */
                draw_particles();

                /* 508c: Render Lua-created entities */
                render_lua_entities();
            EndMode3D();

            /* HUD */
            DrawFPS(10, 10);
            DrawText("Interactive Demo (508b Slots + 508c Lua)", 10, 35, 16, DARKGRAY);

            char buf[80];
            snprintf(buf, sizeof(buf), "Chunks: %d/%d  Lua entities: %d",
                     count_active_chunks(g_cube_mesh), g_cube_mesh->chunk_count, g_lua_entity_count);
            DrawText(buf, 10, 55, 14, GRAY);

            DrawText("LMB: cycle color | RMB: destroy", 10, 75, 12, DARKGRAY);

            /* Sliders */
            draw_sliders();

        EndDrawing();
    }

    /* Shutdown */
    printf("\n[main] Shutting down...\n");
    atomic_store(&g_running, false);

    pthread_join(sync_thread, NULL);
    pthread_join(updater_thread, NULL);
    cleanup_lua();  /* 508c: Clean up Lua state */
    pool_destroy(pool);
    cleanup(pool);
    CloseWindow();

    printf("[main] Shutdown complete.\n");
    return 0;
}
/* }}} */
