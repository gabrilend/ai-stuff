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
#include "raymath.h"
#include "rlgl.h"
#include "threading.h"
#include "slots.h"
#include "bridge.h"
#include "terrain.h"
#include "input.h"
#include "ui.h"
#include "profiler.h"

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

/* {{{ RenderTaskContext - context for render computation tasks
 * Pre-allocated in a pool to avoid malloc in hot path.
 * Each task computes orbital position and registers with sync. */
#define MAX_RENDER_TASKS 64
typedef struct render_task_context {
    float game_time;           /* snapshot of game time for computation */
    int slot_index;            /* which slot to update */
    atomic_bool ready;         /* set true when result is ready for sync */
    RenderSlot result;         /* computed render data */
    void** target_ptr;         /* pointer to slot data in primary buffer */
} RenderTaskContext;
/* }}} */

/* {{{ Global State */
static MeshData* g_cube_mesh = NULL;
static PrimaryBuffer g_primary;
static atomic_bool g_running = true;
static unsigned int g_tick = 0;
static unsigned int g_last_processed_tick = 0;  /* for updater to detect new ticks */
static float g_game_time = 0.0f;
static int g_demo_slot_index = -1;

/* Threading v2 state */
static WorkerPool* g_pool = NULL;
static SyncContext* g_sync = NULL;
static UpdaterContext* g_updater = NULL;
static RenderTaskContext g_task_pool[MAX_RENDER_TASKS];
static atomic_uint g_task_pool_head = 0;

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

/* {{{ transform_chunk_to_world
 * Transform chunk local position to world position given slot transforms.
 * Uses Raylib matrix functions to ensure consistency with rendering.
 *
 * Matches the transform order in render_cube_at_slot:
 *   rlTranslatef(slot->x, slot->y, slot->z);
 *   rlScalef(slot->scale, slot->scale, slot->scale);
 *   rlRotatef(slot->rotation, 0.577f, 0.577f, 0.577f);  // clock
 *   rlRotatef(slot->spin, 0.0f, 1.0f, 0.0f);            // spin
 *
 * OpenGL applies in reverse order: spin -> clock -> scale -> translate
 * So we build: M = Translate * Scale * RotateClock * RotateSpin
 */
void transform_chunk_to_world(ChunkData* c, RenderSlot* slot, float* wx, float* wy, float* wz) {
    /* Convert degrees to radians */
    float spin_rad = slot->spin * DEG2RAD;
    float clock_rad = slot->rotation * DEG2RAD;

    /* Diagonal axis (1,1,1) normalized = (1/√3, 1/√3, 1/√3) ≈ (0.57735, 0.57735, 0.57735) */
    Vector3 clock_axis = { 0.57735026919f, 0.57735026919f, 0.57735026919f };

    /* Build transform matrix in order: spin -> clock -> scale -> translate
     * For v' = T * S * C * Sp * v, we build M = T * S * C * Sp */
    Matrix spin_mat = MatrixRotateY(spin_rad);
    Matrix clock_mat = MatrixRotate(clock_axis, clock_rad);
    Matrix scale_mat = MatrixScale(slot->scale, slot->scale, slot->scale);
    Matrix trans_mat = MatrixTranslate(slot->x, slot->y, slot->z);

    /* Compose: M = T * S * C * Sp */
    Matrix m = spin_mat;
    m = MatrixMultiply(clock_mat, m);   /* C * Sp */
    m = MatrixMultiply(scale_mat, m);   /* S * (C * Sp) */
    m = MatrixMultiply(trans_mat, m);   /* T * (S * C * Sp) */

    /* Transform the chunk position */
    Vector3 local = { c->x, c->y, c->z };
    Vector3 world = Vector3Transform(local, m);

    *wx = world.x;
    *wy = world.y;
    *wz = world.z;
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

/* {{{ render_task_execute
 * Task function for computing orbital position and rotations.
 * Called by worker threads from their ring buffer.
 * Registers result with sync thread via watch list. */
void render_task_execute(void* arg) {
    RenderTaskContext* ctx = (RenderTaskContext*)arg;

    /* Read current speed params (safe: main thread only writes between frames) */
    float clock_speed = g_speeds.clock_speed;
    float spin_speed = g_speeds.spin_speed;
    float orbit_radius = g_speeds.orbit_radius;

    float orbit_angle = ctx->game_time * clock_speed * 2.0f * 3.14159f;
    float clock_rotation = fmodf(ctx->game_time * clock_speed * 360.0f, 360.0f);
    float spin = fmodf(ctx->game_time * spin_speed * 360.0f, 360.0f);

    float orbit_x = orbit_radius * cosf(orbit_angle);
    float orbit_z = orbit_radius * sinf(orbit_angle);

    /* Compute result into task context */
    ctx->result.x = orbit_x;
    ctx->result.y = 0.0f;
    ctx->result.z = orbit_z;
    ctx->result.rotation = clock_rotation;
    ctx->result.spin = spin;
    ctx->result.scale = 1.0f;
    ctx->result.r = 40;
    ctx->result.g = 90;
    ctx->result.b = 200;
    ctx->result.a = 255;
    ctx->result.visible = true;
    ctx->result.mesh_id = 0;

    /* Register with sync thread for pointer swap.
     * When ready flag is set, sync will copy result to primary buffer. */
    if (g_sync && ctx->target_ptr) {
        sync_add_watch(g_sync, &ctx->ready, ctx->target_ptr, &ctx->result);
        atomic_store(&ctx->ready, true);
    }
}
/* }}} */

/* {{{ render_task_on_complete
 * Called when a render task finishes (repeat_count reaches 0).
 * Allocates new slot data and updates primary buffer. */
void render_task_on_complete(void* arg) {
    RenderTaskContext* ctx = (RenderTaskContext*)arg;

    /* Copy result to persistent slot data */
    if (ctx->slot_index >= 0 && g_primary.slots) {
        ComponentSlot* slot = slot_get(g_primary.slots, ctx->slot_index);
        if (slot && slot->in_use) {
            RenderSlot* new_data = (RenderSlot*)malloc(sizeof(RenderSlot));
            if (new_data) {
                *new_data = ctx->result;
                slot_set(slot, new_data);
            }
        }
    }
}
/* }}} */

/* {{{ get_render_tasks
 * Callback for v2 updater - generates render tasks for pending work.
 * Uses pre-allocated task pool to avoid malloc in hot path. */
bool get_render_tasks(UpdaterContext* updater_ctx, WorkerTask** out, size_t* count) {
    (void)updater_ctx;  /* unused for now */

    /* Check if new tick available */
    unsigned int current_tick = g_tick;
    if (current_tick == g_last_processed_tick) {
        *count = 0;
        return false;
    }
    g_last_processed_tick = current_tick;

    /* Only generate task if we have a valid demo slot */
    if (g_demo_slot_index < 0) {
        *count = 0;
        return false;
    }

    /* Get next task context from pool (circular) */
    unsigned int idx = atomic_fetch_add(&g_task_pool_head, 1) % MAX_RENDER_TASKS;
    RenderTaskContext* task_ctx = &g_task_pool[idx];

    /* Populate task context with current game state */
    task_ctx->game_time = g_game_time;
    task_ctx->slot_index = g_demo_slot_index;
    atomic_store(&task_ctx->ready, false);

    /* Get pointer to slot data for sync update */
    ComponentSlot* slot = slot_get(g_primary.slots, g_demo_slot_index);
    if (slot && slot->in_use) {
        task_ctx->target_ptr = (void**)&slot->data;
    } else {
        task_ctx->target_ptr = NULL;
    }

    /* Create WorkerTask pointing to our context */
    static WorkerTask pending[1];
    pending[0] = (WorkerTask){
        .execute = render_task_execute,
        .on_complete = render_task_on_complete,
        .context = task_ctx,
        .weight = WEIGHT_MEDIUM,
        .repeat_count = 1
    };

    *out = pending;
    *count = 1;
    return true;
}
/* }}} */

/* NOTE: custom_sync_loop and custom_updater_loop removed - using v2 threading */

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

    /* Run inline test script - attempts to load real map, falls back to demo */
    const char* test_script =
        "-- 508d/508f: Map Integration and Movement Test Script\n"
        "local render = require('render')\n"
        "print('[lua] render module loaded, MAX_SLOTS = ' .. render.MAX_SLOTS)\n"
        "\n"
        "-- Set up package path for map loading\n"
        "local PROJECT_ROOT = '/mnt/mtwo/programming/ai-stuff/world-edit-to-execute'\n"
        "package.path = PROJECT_ROOT .. '/src/?.lua;' ..\n"
        "              PROJECT_ROOT .. '/src/?/init.lua;' ..\n"
        "              package.path\n"
        "package.cpath = '/usr/lib/lua/5.1/?.so;' .. package.cpath\n"
        "\n"
        "-- 508f: Create demo entities FIRST (before map loading takes up slots)\n"
        "local slots = {}\n"
        "local positions = {\n"
        "    {id=100, x=-5, y=0.5, z=0, r=255, g=50, b=50},   -- Red\n"
        "    {id=101, x=5, y=0.5, z=0, r=50, g=50, b=255},    -- Blue\n"
        "    {id=102, x=0, y=0.5, z=-5, r=50, g=200, b=50},   -- Green\n"
        "    {id=103, x=0, y=0.5, z=5, r=255, g=255, b=50},   -- Yellow\n"
        "}\n"
        "\n"
        "for _, p in ipairs(positions) do\n"
        "    local slot = render.create_entity(p.id, render.MESH_CUBE, p.x, p.y, p.z)\n"
        "    if slot >= 0 then\n"
        "        render.set_color(slot, p.r, p.g, p.b)\n"
        "        render.set_scale(slot, 0.5)\n"
        "        table.insert(slots, slot)\n"
        "    end\n"
        "end\n"
        "print('[lua] Created ' .. #slots .. ' demo entities')\n"
        "\n"
        "_G.lua_entity_slots = slots\n"
        "_G.lua_entity_count = #slots\n"
        "\n"
        "-- Slot to entity ID mapping for movement\n"
        "_G.slot_to_entity = {}\n"
        "for i, slot in ipairs(slots) do\n"
        "    _G.slot_to_entity[slot] = positions[i].id\n"
        "end\n"
        "\n"
        "-- 508f: Movement order handling\n"
        "_G.entity_targets = {}\n"
        "_G.move_speed = 3.0\n"
        "\n"
        "function on_move_order(x, z, entity_ids)\n"
        "    print('[lua] Move order: (' .. string.format('%.1f', x) .. ', ' .. string.format('%.1f', z) .. ') for ' .. #entity_ids .. ' units')\n"
        "    for _, entity_id in ipairs(entity_ids) do\n"
        "        _G.entity_targets[entity_id] = {x = x, z = z}\n"
        "    end\n"
        "end\n"
        "\n"
        "-- 508g: Entity info for UI (demo entities have simple stats)\n"
        "_G.entity_info = {\n"
        "    [100] = {name = 'Red Warrior', hp = 100, hp_max = 100},\n"
        "    [101] = {name = 'Blue Mage', hp = 80, hp_max = 80},\n"
        "    [102] = {name = 'Green Scout', hp = 60, hp_max = 60},\n"
        "    [103] = {name = 'Yellow Guard', hp = 120, hp_max = 120},\n"
        "}\n"
        "\n"
        "-- 508g: Game time tracking\n"
        "_G.game_time = 0\n"
        "\n"
        "-- 508g: Called when selection changes to update UI\n"
        "function on_selection_changed()\n"
        "    local selected = render.get_selection()\n"
        "    local count = #selected\n"
        "    \n"
        "    if count == 0 then\n"
        "        render.ui_clear_selection()\n"
        "        return\n"
        "    end\n"
        "    \n"
        "    -- Get info from first selected entity\n"
        "    local first_id = _G.slot_to_entity and _G.slot_to_entity[selected[1]]\n"
        "    local info = first_id and _G.entity_info[first_id]\n"
        "    \n"
        "    if info then\n"
        "        render.ui_set_selection(info.name, count, info.hp, info.hp_max)\n"
        "    else\n"
        "        render.ui_set_selection('Unit', count, 100, 100)\n"
        "    end\n"
        "end\n"
        "\n"
        "-- 508g: Called each frame to update game time UI\n"
        "function update_game_time(dt)\n"
        "    _G.game_time = _G.game_time + dt\n"
        "    render.ui_set_game_time(_G.game_time)\n"
        "end\n"
        "\n"
        "-- Try to load a real map (doodads will use remaining slots)\n"
        "local map_loaded = false\n"
        "local test_map = PROJECT_ROOT .. '/assets/DAoW-5.4b-PUBLIC-TEST.w3x'\n"
        "\n"
        "local f = io.open(test_map, 'rb')\n"
        "if f then\n"
        "    f:close()\n"
        "    print('[lua] Found test map: ' .. test_map)\n"
        "    \n"
        "    -- Try to load data and map_renderer modules\n"
        "    local ok1, Map = pcall(require, 'data')\n"
        "    local ok2, map_renderer = pcall(require, 'demo.map_renderer')\n"
        "    \n"
        "    if ok1 and ok2 then\n"
        "        print('[lua] Loading map...')\n"
        "        local load_ok, map = pcall(Map.load, test_map)\n"
        "        if load_ok and map then\n"
        "            print('[lua] Map: ' .. (map.name or 'unnamed'))\n"
        "            print('[lua] Size: ' .. (map.width or 0) .. 'x' .. (map.height or 0))\n"
        "            if map.terrain then\n"
        "                print('[lua] Terrain: ' .. map.terrain.width .. 'x' .. map.terrain.height)\n"
        "            end\n"
        "            \n"
        "            -- Render the map\n"
        "            local render_ok = map_renderer.load(map)\n"
        "            if render_ok then\n"
        "                map_loaded = true\n"
        "                print('[lua] Map rendered successfully!')\n"
        "            else\n"
        "                print('[lua] Failed to render map, using fallback')\n"
        "            end\n"
        "        else\n"
        "            print('[lua] Failed to load map: ' .. tostring(map))\n"
        "        end\n"
        "    else\n"
        "        if not ok1 then print('[lua] Cannot load data module: ' .. tostring(Map)) end\n"
        "        if not ok2 then print('[lua] Cannot load map_renderer: ' .. tostring(map_renderer)) end\n"
        "    end\n"
        "else\n"
        "    print('[lua] No test map found at: ' .. test_map)\n"
        "end\n"
        "\n"
        "-- Fallback: create demo terrain if map didn't load\n"
        "if not map_loaded then\n"
        "    print('[lua] Using demo terrain fallback')\n"
        "    local size = 32\n"
        "    local tile_size = 1.0\n"
        "    local ok = render.terrain_create(size, size, tile_size)\n"
        "    if ok then\n"
        "        render.terrain_set_offset(-size * tile_size / 2, -size * tile_size / 2)\n"
        "        \n"
        "        -- Create terrain pattern (island with water)\n"
        "        local tiles = {}\n"
        "        for y = 0, size - 1 do\n"
        "            for x = 0, size - 1 do\n"
        "                local cx, cy = size / 2, size / 2\n"
        "                local dx, dy = x - cx, y - cy\n"
        "                local dist = math.sqrt(dx * dx + dy * dy)\n"
        "                local r, g, b\n"
        "                if dist < 4 then\n"
        "                    r, g, b = 30, 100, 180  -- Water\n"
        "                elseif dist < 7 then\n"
        "                    r, g, b = 194, 145, 87  -- Beach\n"
        "                elseif dist < 14 then\n"
        "                    r, g, b = 34, 139, 34   -- Grass\n"
        "                else\n"
        "                    r, g, b = 100, 80, 60   -- Dirt edge\n"
        "                end\n"
        "                table.insert(tiles, {x, y, r, g, b})\n"
        "            end\n"
        "        end\n"
        "        render.terrain_set_tiles(tiles)\n"
        "        print('[lua] Demo terrain created: ' .. size .. 'x' .. size)\n"
        "    end\n"
        "end\n"
        "\n"
        "-- Demo entities and movement order handling already set up at script start\n";

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
 * 508f: Moves entities toward targets set by on_move_order. */
void update_lua_entities(float dt) {
    if (!g_lua) return;

    static float lua_time = 0.0f;
    lua_time += dt;

    /* Get movement speed from Lua */
    float move_speed = 3.0f;
    lua_getglobal(g_lua, "move_speed");
    if (lua_isnumber(g_lua, -1)) {
        move_speed = (float)lua_tonumber(g_lua, -1);
    }
    lua_pop(g_lua, 1);

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
                    RenderSlot* rs = slot->data;

                    /* Get entity ID for this slot */
                    lua_getglobal(g_lua, "slot_to_entity");
                    lua_pushinteger(g_lua, slot_idx);
                    lua_gettable(g_lua, -2);
                    int entity_id = lua_isnumber(g_lua, -1) ? (int)lua_tointeger(g_lua, -1) : -1;
                    lua_pop(g_lua, 2);  /* pop entity_id and slot_to_entity */

                    /* Check if entity has movement target */
                    bool has_target = false;
                    float target_x = 0, target_z = 0;

                    if (entity_id >= 0) {
                        lua_getglobal(g_lua, "entity_targets");
                        lua_pushinteger(g_lua, entity_id);
                        lua_gettable(g_lua, -2);
                        if (lua_istable(g_lua, -1)) {
                            lua_getfield(g_lua, -1, "x");
                            lua_getfield(g_lua, -2, "z");
                            target_x = (float)lua_tonumber(g_lua, -2);
                            target_z = (float)lua_tonumber(g_lua, -1);
                            lua_pop(g_lua, 2);
                            has_target = true;
                        }
                        lua_pop(g_lua, 2);  /* pop target table and entity_targets */
                    }

                    if (has_target) {
                        /* Calculate direction to target */
                        float dx = target_x - rs->x;
                        float dz = target_z - rs->z;
                        float dist = sqrtf(dx * dx + dz * dz);

                        if (dist > 0.1f) {
                            /* Move toward target */
                            float step = move_speed * dt;
                            if (step > dist) step = dist;

                            rs->x += (dx / dist) * step;
                            rs->z += (dz / dist) * step;

                            /* Face movement direction */
                            rs->facing = atan2f(dx, dz) * (180.0f / 3.14159f);
                        } else {
                            /* Arrived - clear target */
                            lua_getglobal(g_lua, "entity_targets");
                            lua_pushinteger(g_lua, entity_id);
                            lua_pushnil(g_lua);
                            lua_settable(g_lua, -3);
                            lua_pop(g_lua, 1);
                        }
                    }

                    /* Light spin animation */
                    rs->spin = fmodf(lua_time * 45.0f, 360.0f);

                    /* Slight bob when moving */
                    if (has_target) {
                        rs->y = 0.5f + sinf(lua_time * 8.0f) * 0.05f;
                    } else {
                        rs->y = 0.5f;
                    }
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

    /* Destroy terrain (508d) */
    TerrainGrid* terrain = terrain_get_global();
    if (terrain) {
        terrain_destroy(terrain);
        terrain_set_global(NULL);
    }
}
/* }}} */

/* {{{ cleanup
 * Clean up rendering resources (v2 threading cleanup is separate) */
void cleanup(WorkerPool* pool) {
    (void)pool;  /* v2 cleanup handled by pool_destroy */

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

    /* Create v2 worker pool - ring buffer task model */
    g_pool = pool_create(NUM_WORKERS);
    if (!g_pool) {
        fprintf(stderr, "[main] Failed to create worker pool\n");
        cleanup_lua();
        slot_array_destroy(g_primary.slots);
        return 1;
    }

    /* Create sync context - watch list based sync */
    g_sync = sync_create(WATCH_LIST_SIZE);
    if (!g_sync) {
        fprintf(stderr, "[main] Failed to create sync context\n");
        pool_destroy(g_pool);
        cleanup_lua();
        slot_array_destroy(g_primary.slots);
        return 1;
    }

    /* Spawn sync thread (v2) */
    pthread_t sync_thread = spawn_sync_thread(g_sync);

    /* Create and start updater (v2) - runs as worker task */
    g_updater = updater_create(g_pool, get_render_tasks, NULL);
    if (!g_updater) {
        fprintf(stderr, "[main] Failed to create updater\n");
        atomic_store(&g_sync->running, false);
        pthread_join(sync_thread, NULL);
        sync_destroy(g_sync);
        pool_destroy(g_pool);
        cleanup_lua();
        slot_array_destroy(g_primary.slots);
        return 1;
    }
    updater_start(g_updater);  /* Adds updater to worker ring buffer */

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

    /* Initialize input system (508e) */
    input_init(&camera);

    /* Initialize UI system (508g) */
    ui_init();

    /* Initialize profiler (511) */
    profile_init();

    printf("[main] Entering render loop...\n\n");

    while (!WindowShouldClose()) {
        /* Profiler: begin frame timing */
        profile_begin_frame();

        float dt = GetFrameTime();

        PROFILE_BEGIN(update);
        tick_loop(dt);
        update_particles(dt);
        update_lua_entities(dt);  /* 508c: Update Lua-created entities */

        /* 508g: Update game time in Lua */
        if (g_lua) {
            lua_getglobal(g_lua, "update_game_time");
            if (lua_isfunction(g_lua, -1)) {
                lua_pushnumber(g_lua, dt);
                lua_pcall(g_lua, 1, 0, 0);
            } else {
                lua_pop(g_lua, 1);
            }
        }
        PROFILE_END(update);

        PROFILE_BEGIN(input);
        /* Update input system (508e) */
        input_update();

        /* Handle slider input first */
        bool slider_active = update_sliders();

        /* Track selection for UI updates (508g) */
        static int prev_sel_count = 0;
        int cur_sel_count = selection_get_count();

        /* Process selection input if not using sliders (508e) */
        if (!slider_active) {
            process_selection_input(g_primary.slots);
        }

        /* 508g: Notify Lua when selection changes */
        cur_sel_count = selection_get_count();
        if (cur_sel_count != prev_sel_count && g_lua) {
            lua_getglobal(g_lua, "on_selection_changed");
            if (lua_isfunction(g_lua, -1)) {
                lua_pcall(g_lua, 0, 0, 0);
            } else {
                lua_pop(g_lua, 1);
            }
            prev_sel_count = cur_sel_count;
        }

        /* 508f: Process movement orders (right-click) */
        if (!slider_active) {
            process_movement_input(g_primary.slots, g_lua);
        }

        /* 508f: Update move marker animation */
        move_marker_update(dt);

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
        PROFILE_END(input);

        /* F3: Toggle profiler overlay */
        if (IsKeyPressed(KEY_F3)) {
            profile_toggle();
        }

        /* F4: Dump profiler to file */
        if (IsKeyPressed(KEY_F4)) {
            profile_dump_to_file("profile_dump.txt");
        }

        /* Render */
        PROFILE_BEGIN(draw);
        BeginDrawing();
            ClearBackground(BLACK);

            BeginMode3D(camera);
                /* Terrain grid (508d) */
                TerrainGrid* terrain = terrain_get_global();
                if (terrain && terrain->initialized) {
                    terrain_draw(terrain);
                }

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

                /* 508e: Selection circles under selected entities */
                draw_selection_circles(g_primary.slots);

                /* 508f: Move target marker */
                move_marker_draw();
            EndMode3D();

            /* 508g: Draw UI (resource bar at top, selection panel at bottom) */
            ui_draw();

            /* Debug HUD (offset below resource bar) */
            DrawFPS(10, 40);
            DrawText("Interactive Demo (508b Slots + 508c Lua)", 10, 60, 16, DARKGRAY);

            char buf[80];
            snprintf(buf, sizeof(buf), "Chunks: %d/%d  Lua entities: %d",
                     count_active_chunks(g_cube_mesh), g_cube_mesh->chunk_count, g_lua_entity_count);
            DrawText(buf, 10, 80, 14, GRAY);

            DrawText("LMB: select | RMB: move | Shift+LMB: add", 10, 100, 12, DARKGRAY);

            /* Sliders */
            draw_sliders();

            /* 508e: Selection box during drag */
            draw_selection_box();

            /* 511: Profiler overlay (F3 to toggle) */
            profile_draw_overlay();

        EndDrawing();
        PROFILE_END(draw);

        /* Profiler: end frame timing */
        profile_end_frame();
    }

    /* Shutdown */
    printf("\n[main] Shutting down...\n");
    atomic_store(&g_running, false);

    /* Stop sync thread (v2) */
    atomic_store(&g_sync->running, false);
    pthread_join(sync_thread, NULL);

    /* Clean up v2 components */
    updater_destroy(g_updater);
    pool_destroy(g_pool);
    sync_destroy(g_sync);

    /* Clean up Lua and rendering resources */
    cleanup_lua();  /* 508c: Clean up Lua state */
    cleanup(g_pool);
    profile_shutdown();  /* 511: Cleanup profiler */
    CloseWindow();

    printf("[main] Shutdown complete.\n");
    return 0;
}
/* }}} */
