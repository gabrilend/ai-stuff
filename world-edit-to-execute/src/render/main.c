/*
 * Rotating Blue Cube Demo
 *
 * A minimal raylib-based renderer demonstrating data-driven architecture.
 * The cube is defined only by its vertices and material pointer.
 * Rendering is separated from data definition.
 *
 * Based on template at: /home/ritz/programming/c/games/template/
 */

#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
#include "pthread.h"
#include "raylib.h"
#include "rlgl.h"

/* {{{ Constants */
#define WINDOW_WIDTH 800
#define WINDOW_HEIGHT 600
#define TARGET_FPS 60
#define ROTATION_SPEED 1.0f
/* }}} */

/* {{{ ChunkMaterial - defines visual properties */
typedef struct chunk_material {
    Color base_color;
    Color edge_color;
    float chunk_size;      /* size of fuzzy chunks (0 = smooth) */
    bool wireframe;
} ChunkMaterial;
/* }}} */

/* {{{ EdgeMod - describes a modified edge between two vertices */
typedef struct edge_mod {
    int v1, v2;            /* vertex indices (0-7 for cube corners) */
    float offset;          /* how much this edge differs from default */
} EdgeMod;
/* }}} */

/* {{{ MeshData - minimal cube definition */
typedef struct mesh_data {
    float size;            /* cube size - all geometry derived from this */
    EdgeMod* edge_mods;    /* optional edge modifications (NULL = default box) */
    int edge_mod_count;    /* number of edge modifications */
} MeshData;
/* }}} */

/* {{{ Entity - combines mesh + material + transform */
typedef struct entity {
    MeshData* mesh;
    ChunkMaterial* material;
    Vector3 position;
    Vector3 rotation;      /* euler angles in degrees */
} Entity;
/* }}} */

/* {{{ Shared State */
typedef struct game_state {
    Entity* cube;
    bool running;
    pthread_mutex_t mutex;
} GameState;
/* }}} */

/* {{{ create_cube_mesh */
/* Minimal cube: just size + optional edge mods. Vertices derived at render time. */
MeshData* create_cube_mesh(float size) {
    MeshData* mesh = (MeshData*)malloc(sizeof(MeshData));
    mesh->size = size;
    mesh->edge_mods = NULL;    /* no modifications = perfect cube */
    mesh->edge_mod_count = 0;
    return mesh;
}
/* }}} */

/* {{{ create_fuzzy_blue_material */
ChunkMaterial* create_fuzzy_blue_material(void) {
    ChunkMaterial* mat = (ChunkMaterial*)malloc(sizeof(ChunkMaterial));
    mat->base_color = (Color){ 40, 90, 200, 255 };
    mat->edge_color = (Color){ 80, 130, 240, 255 };
    mat->chunk_size = 0.2f;
    mat->wireframe = false;
    return mat;
}
/* }}} */

/* {{{ create_entity */
Entity* create_entity(MeshData* mesh, ChunkMaterial* material) {
    Entity* ent = (Entity*)malloc(sizeof(Entity));
    ent->mesh = mesh;
    ent->material = material;
    ent->position = (Vector3){ 0, 0, 0 };
    ent->rotation = (Vector3){ 0, 0, 0 };
    return ent;
}
/* }}} */

/* {{{ render_entity_chunky */
/* Renders an entity using chunky/fuzzy style based on material */
void render_entity_chunky(Entity* ent) {
    ChunkMaterial* mat = ent->material;
    float size = ent->mesh->size;
    float chunk = mat->chunk_size;

    if (chunk <= 0) chunk = size;  /* fallback to solid */

    float half = size / 2.0f;

    rlPushMatrix();
        rlTranslatef(ent->position.x, ent->position.y, ent->position.z);
        rlRotatef(ent->rotation.y, 0, 1, 0);
        rlRotatef(ent->rotation.x, 1, 0, 0);
        rlRotatef(ent->rotation.z, 0, 0, 1);

        /* Draw chunky surface */
        for (float x = -half; x < half; x += chunk) {
            for (float y = -half; y < half; y += chunk) {
                for (float z = -half; z < half; z += chunk) {
                    /* Only surface chunks */
                    bool surface = (x <= -half + chunk || x >= half - chunk ||
                                    y <= -half + chunk || y >= half - chunk ||
                                    z <= -half + chunk || z >= half - chunk);

                    if (surface) {
                        /* Color variation for fuzziness */
                        int b = mat->base_color.b + ((int)(x * y * 50) % 40) - 20;
                        int g = mat->base_color.g + ((int)(z * x * 30) % 30) - 15;
                        int r = mat->base_color.r + ((int)(y * z * 20) % 20) - 10;

                        Color c = {
                            (unsigned char)(r < 0 ? 0 : (r > 255 ? 255 : r)),
                            (unsigned char)(g < 0 ? 0 : (g > 255 ? 255 : g)),
                            (unsigned char)(b < 0 ? 0 : (b > 255 ? 255 : b)),
                            255
                        };

                        /* Slight size variation */
                        float sz = chunk * (0.9f + 0.1f * sinf(x + y + z));

                        DrawCube(
                            (Vector3){ x + chunk/2, y + chunk/2, z + chunk/2 },
                            sz, sz, sz, c
                        );
                    }
                }
            }
        }

    rlPopMatrix();
}
/* }}} */

/* {{{ draw - Render thread */
void* draw(void* args) {
    GameState* state = (GameState*)args;

    printf("[render] Initializing window...\n");

    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "WC3 Engine - Rotating Cube Demo");
    SetTargetFPS(TARGET_FPS);

    Camera3D camera = { 0 };
    camera.position = (Vector3){ 5.0f, 5.0f, 5.0f };
    camera.target = (Vector3){ 0.0f, 0.0f, 0.0f };
    camera.up = (Vector3){ 0.0f, 1.0f, 0.0f };
    camera.fovy = 45.0f;
    camera.projection = CAMERA_PERSPECTIVE;

    printf("[render] Entering render loop...\n");

    while (!WindowShouldClose()) {
        /* Copy entity state */
        pthread_mutex_lock(&state->mutex);
        Entity cube_copy = *(state->cube);
        pthread_mutex_unlock(&state->mutex);

        BeginDrawing();
            ClearBackground(BLACK);

            BeginMode3D(camera);
                render_entity_chunky(&cube_copy);
            EndMode3D();

            /* Minimal HUD */
            DrawFPS(10, 10);
            DrawText("fuzzy cube", 10, 35, 16, (Color){ 60, 60, 80, 255 });

        EndDrawing();
    }

    pthread_mutex_lock(&state->mutex);
    state->running = false;
    pthread_mutex_unlock(&state->mutex);

    printf("[render] Closing window...\n");
    CloseWindow();

    return NULL;
}
/* }}} */

/* {{{ game - Game logic thread */
void* game(void* args) {
    GameState* state = (GameState*)args;

    printf("[game] Starting game logic thread...\n");

    while (true) {
        pthread_mutex_lock(&state->mutex);
        bool running = state->running;
        pthread_mutex_unlock(&state->mutex);

        if (!running) break;

        /* Update rotation */
        pthread_mutex_lock(&state->mutex);
        state->cube->rotation.y += ROTATION_SPEED;
        if (state->cube->rotation.y >= 360.0f) {
            state->cube->rotation.y -= 360.0f;
        }
        state->cube->rotation.x = sinf(state->cube->rotation.y * 0.02f) * 8.0f;
        pthread_mutex_unlock(&state->mutex);

        /* Sleep 16ms (~60 updates/sec) */
        usleep(16000);
    }

    printf("[game] Exiting game logic thread...\n");
    return NULL;
}
/* }}} */

/* {{{ cleanup */
void cleanup(GameState* state) {
    if (state->cube) {
        if (state->cube->mesh) {
            if (state->cube->mesh->edge_mods) {
                free(state->cube->mesh->edge_mods);
            }
            free(state->cube->mesh);
        }
        if (state->cube->material) {
            free(state->cube->material);
        }
        free(state->cube);
    }
    pthread_mutex_destroy(&state->mutex);
}
/* }}} */

/* {{{ main */
int main(void) {
    printf("=== WC3 Engine - Rotating Cube Demo ===\n");
    printf("Data-driven: mesh vertices + material pointer\n\n");

    /* Create cube data */
    MeshData* mesh = create_cube_mesh(2.0f);
    ChunkMaterial* material = create_fuzzy_blue_material();
    Entity* cube = create_entity(mesh, material);

    /* Initialize state */
    GameState state;
    state.cube = cube;
    state.running = true;
    pthread_mutex_init(&state.mutex, NULL);

    /* Create threads */
    pthread_t threads[2];

    printf("[main] Spawning threads...\n");
    pthread_create(&threads[0], NULL, draw, &state);
    pthread_create(&threads[1], NULL, game, &state);

    pthread_join(threads[0], NULL);
    pthread_join(threads[1], NULL);

    cleanup(&state);

    printf("[main] Shutdown complete.\n");
    return 0;
}
/* }}} */
