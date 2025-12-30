/*
 * WC3 Engine - Threaded Renderer Demo
 *
 * Demonstrates the staged threading architecture from docs/render-architecture.md:
 * - Updater thread: populates worker inputs from game state
 * - Worker threads: compute GPU-ready render data (always busy)
 * - Sync thread: swaps worker outputs to primary buffer (minimal work)
 * - Draw thread: renders from primary buffer (minimal work)
 *
 * The rotating cube demo validates this architecture before adding real entities.
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

/* {{{ Constants */
#define WINDOW_WIDTH 800
#define WINDOW_HEIGHT 600
#define TARGET_FPS 60
#define ROTATION_SPEED 1.0f
#define NUM_WORKERS 2
/* }}} */

/* {{{ RenderSlot - GPU-ready data for one entity (508b preview)
 * This is the output workers produce. Draw thread reads this directly. */
typedef struct render_slot {
    float x, y, z;           /* world position */
    float rotation;          /* Y-axis rotation in degrees */
    float scale;             /* uniform scale */
    unsigned char r, g, b, a; /* color */
    bool visible;            /* culling result */
    int mesh_id;             /* which mesh to draw (0 = cube) */
} RenderSlot;
/* }}} */

/* {{{ PrimaryBuffer - what the draw thread reads from
 * Sync thread writes here; draw thread reads here. */
#define MAX_RENDER_SLOTS 64

typedef struct primary_buffer {
    RenderSlot slots[MAX_RENDER_SLOTS];
    int slot_count;
    pthread_mutex_t lock;  /* Protect during swap */
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

                int r = 40 + ((int)(y * z * 20) % 20) - 10;
                int g = 90 + ((int)(z * x * 30) % 30) - 15;
                int b = 200 + ((int)(x * y * 50) % 40) - 20;
                c->r = (unsigned char)(r < 0 ? 0 : (r > 255 ? 255 : r));
                c->g = (unsigned char)(g < 0 ? 0 : (g > 255 ? 255 : g));
                c->b = (unsigned char)(b < 0 ? 0 : (b > 255 ? 255 : b));

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

/* {{{ render_cube_at_slot
 * Renders a cube using the render slot data. */
void render_cube_at_slot(RenderSlot* slot, MeshData* mesh) {
    if (!slot->visible) return;

    rlPushMatrix();
        rlTranslatef(slot->x, slot->y, slot->z);
        rlScalef(slot->scale, slot->scale, slot->scale);
        rlRotatef(slot->rotation, 0.577f, 0.577f, 0.577f);

        for (int i = 0; i < mesh->chunk_count; i++) {
            ChunkData* c = &mesh->chunks[i];
            if (c->is_solid) {
                Color col = { c->r, c->g, c->b, 255 };
                DrawCube((Vector3){ c->x, c->y, c->z }, c->size, c->size, c->size, col);
            }
        }
    rlPopMatrix();
}
/* }}} */

/* {{{ worker_process_fn
 * Called by worker threads to compute render-ready data.
 * Heavy work happens here: transforms, culling, etc.
 *
 * For demo: just updates rotation based on game time. */
void worker_process_fn(WorkerContext* ctx, void* input_ptr, void* output_ptr) {
    WorkerInput* input = (WorkerInput*)input_ptr;
    WorkerOutput* output = (WorkerOutput*)output_ptr;

    /* Compute rotation from game time
     * In full implementation: would transform entity positions,
     * apply culling, compute final screen coords, etc. */
    float rotation = fmodf(input->game_time * ROTATION_SPEED * 60.0f, 360.0f);

    /* For demo: we only have one entity (the cube)
     * Worker 0 handles slot 0, others idle */
    if (ctx->worker_id == 0) {
        /* Allocate output slot data (or reuse) */
        RenderSlot* slot = (RenderSlot*)output->slot_data;
        if (!slot) {
            slot = (RenderSlot*)malloc(sizeof(RenderSlot));
            output->slot_data = slot;
        }

        slot->x = 0.0f;
        slot->y = 0.0f;
        slot->z = 0.0f;
        slot->rotation = rotation;
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

/* {{{ get_game_input
 * Callback for updater thread. Returns true if there's new input.
 * Increments tick and game time. */
bool get_game_input(WorkerInput* out) {
    static unsigned int last_tick = 0;

    /* Generate new input every frame (16ms) */
    unsigned int current_tick = g_tick;
    if (current_tick == last_tick) {
        return false;  /* No new tick yet */
    }

    last_tick = current_tick;
    out->tick = current_tick;
    out->game_time = g_game_time;
    out->entity_count = 1;  /* Just the cube */
    out->camera_x = 5.0f;
    out->camera_y = 5.0f;
    out->camera_z = 5.0f;

    return true;
}
/* }}} */

/* {{{ sync_to_primary
 * Called by sync loop to copy worker output to primary buffer.
 * This is the "mise en place" moment - old data freed, new data in place. */
void sync_to_primary(WorkerPool* pool) {
    pthread_mutex_lock(&g_primary.lock);

    for (int i = 0; i < pool->count; i++) {
        WorkerBuffers* buf = &pool->buffers[i];

        if (atomic_load(&buf->output_ready)) {
            pthread_mutex_lock(&buf->output_lock);

            if (buf->output.slot_data && buf->output.slot_count > 0) {
                /* Copy slot data to primary buffer */
                RenderSlot* src = (RenderSlot*)buf->output.slot_data;
                /* For demo: only one slot from worker 0 */
                if (i == 0) {
                    g_primary.slots[0] = *src;
                    g_primary.slot_count = 1;
                }
            }

            atomic_store(&buf->output_ready, false);
            pthread_mutex_unlock(&buf->output_lock);
        }
    }

    pthread_mutex_unlock(&g_primary.lock);
}
/* }}} */

/* {{{ custom_sync_loop
 * Sync thread that handles our specific primary buffer. */
void* custom_sync_loop(void* arg) {
    WorkerPool* pool = (WorkerPool*)arg;

    printf("[sync] Starting custom sync loop\n");

    while (atomic_load(&g_running)) {
        sync_to_primary(pool);
        usleep(1000);  /* 1ms */
    }

    printf("[sync] Exiting\n");
    return NULL;
}
/* }}} */

/* {{{ custom_updater_loop
 * Updater thread that feeds game state to workers. */
void* custom_updater_loop(void* arg) {
    WorkerPool* pool = (WorkerPool*)arg;

    printf("[updater] Starting custom updater loop\n");

    WorkerInput input;
    memset(&input, 0, sizeof(input));

    while (atomic_load(&g_running)) {
        if (get_game_input(&input)) {
            distribute_input_to_workers(pool, &input);
        } else {
            usleep(1000);  /* 1ms */
        }
    }

    printf("[updater] Exiting\n");
    return NULL;
}
/* }}} */

/* {{{ tick_loop
 * Runs on main thread between frames. Updates game time and tick counter. */
void tick_loop(float dt) {
    g_game_time += dt;
    g_tick++;
}
/* }}} */

/* {{{ cleanup */
void cleanup(WorkerPool* pool) {
    /* Free worker output slot data */
    for (int i = 0; i < pool->count; i++) {
        if (pool->buffers[i].output.slot_data) {
            free(pool->buffers[i].output.slot_data);
        }
    }

    /* Free mesh */
    if (g_cube_mesh) {
        if (g_cube_mesh->chunks) free(g_cube_mesh->chunks);
        free(g_cube_mesh);
    }

    pthread_mutex_destroy(&g_primary.lock);
}
/* }}} */

/* {{{ main */
int main(void) {
    printf("=== WC3 Engine - Threaded Renderer Demo ===\n");
    printf("Architecture: Updater -> Workers -> Sync -> Draw\n");
    printf("Workers: %d\n\n", NUM_WORKERS);

    /* Create cube mesh */
    g_cube_mesh = create_cube_mesh(2.0f, 0.2f);
    printf("[main] Created mesh with %d chunks\n", g_cube_mesh->chunk_count);

    /* Initialize primary buffer */
    memset(&g_primary, 0, sizeof(g_primary));
    pthread_mutex_init(&g_primary.lock, NULL);
    g_primary.slots[0].visible = false;  /* Will be set by worker */

    /* Create worker pool */
    WorkerPool* pool = pool_create(NUM_WORKERS);
    pool_set_process_fn(pool, worker_process_fn);
    pool_set_primary_buffer(pool, &g_primary);

    /* Spawn sync and updater threads */
    pthread_t sync_thread, updater_thread;
    pthread_create(&sync_thread, NULL, custom_sync_loop, pool);
    pthread_create(&updater_thread, NULL, custom_updater_loop, pool);

    /* Initialize raylib (must be on main thread for some platforms) */
    printf("[main] Initializing window...\n");
    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "WC3 Engine - Threaded Demo");
    SetTargetFPS(TARGET_FPS);

    Camera3D camera = { 0 };
    camera.position = (Vector3){ 5.0f, 5.0f, 5.0f };
    camera.target = (Vector3){ 0.0f, 0.0f, 0.0f };
    camera.up = (Vector3){ 0.0f, 1.0f, 0.0f };
    camera.fovy = 45.0f;
    camera.projection = CAMERA_PERSPECTIVE;

    printf("[main] Entering render loop...\n\n");

    /* Main loop - draw thread runs here */
    while (!WindowShouldClose()) {
        float dt = GetFrameTime();

        /* Update game tick */
        tick_loop(dt);

        /* Read from primary buffer (with lock) */
        pthread_mutex_lock(&g_primary.lock);
        RenderSlot slot_copy = g_primary.slots[0];
        int slot_count = g_primary.slot_count;
        pthread_mutex_unlock(&g_primary.lock);

        /* Render */
        BeginDrawing();
            ClearBackground(BLACK);

            BeginMode3D(camera);
                if (slot_count > 0 && slot_copy.visible) {
                    render_cube_at_slot(&slot_copy, g_cube_mesh);
                }
            EndMode3D();

            /* HUD */
            DrawFPS(10, 10);
            DrawText("Threaded Architecture Demo", 10, 35, 16, DARKGRAY);

            char buf[64];
            snprintf(buf, sizeof(buf), "Tick: %u  Workers: %d", g_tick, NUM_WORKERS);
            DrawText(buf, 10, 55, 14, GRAY);

            snprintf(buf, sizeof(buf), "Rotation: %.1f", slot_copy.rotation);
            DrawText(buf, 10, 75, 14, GRAY);

        EndDrawing();
    }

    /* Shutdown */
    printf("\n[main] Shutting down...\n");
    atomic_store(&g_running, false);

    /* Join threads */
    pthread_join(sync_thread, NULL);
    pthread_join(updater_thread, NULL);

    /* Destroy pool (joins worker threads) */
    pool_destroy(pool);

    /* Cleanup */
    cleanup(pool);
    CloseWindow();

    printf("[main] Shutdown complete.\n");
    return 0;
}
/* }}} */
