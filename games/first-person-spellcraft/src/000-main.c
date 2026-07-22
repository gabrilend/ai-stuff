/* 000-main.c — First Person Spellcraft: the story the whole engine reads
 * top-to-bottom.
 *
 * The shape (note-to-claude-ai's narrative main): say hello, read input/ to
 * learn how to start, boot the machine, spin up the threads, let the graph turn
 * until a quit signal, break the machine down, and — the last thing, always —
 * write output/goodbye.
 *
 * What runs here, concretely, is the Phase-1 skeleton of the dataflow engine:
 *   - a worker pool (the threads) and a slot store (the wires) — libs/;
 *   - one "mover" box that plays the frame-clock heartbeat's role for now,
 *     nudging a rectangle across the room each tick and publishing its position
 *     into a renderables slot;
 *   - one dedicated, always-unblocked render thread that owns the raylib window,
 *     drains that slot to the latest position, and draws — lagging the pool by a
 *     frame or two is fine (docs/soramech-notes.md pattern 7).
 * No spells, mice, or world yet — just proof the substrate turns into a window.
 */
#include "../libs/engine-core/slot.h"
#include "../libs/engine-core/graph.h"
#include "../libs/task-pool/pool.h"
#include "../libs/platform/platform.h"
#include "001-world.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>
#include <pthread.h>
#include <time.h>

/* {{{ shared shapes + the one global quit flag */
/* A renderable is, for now, the player's position in WORLD tile coordinates.
 * Later this grows into the culled renderables list the render thread sweeps. */
typedef struct { float x, y; } renderable_t;

/* The single quit signal. The render thread raises it when the window closes (or
 * the frame budget runs out); main and the mover box both watch it to wind down.
 * Atomic because it crosses threads. */
static _Atomic int g_quit;

#define CELL_PX   32                /* pixels per world tile in the top-down view */
#define WIN_W     (20 * CELL_PX)    /* matches the test world's 20-wide grid */
#define WIN_H     (12 * CELL_PX)    /* ... and 12 tall */
#define PLAYER_PX 18.0f

typedef struct { const char *dir; long frames; } run_config_t;
/* }}} */

/* {{{ say_hello() */
static void say_hello(void)
{
    printf("First Person Spellcraft — waking up.\n");
}
/* }}} */

/* {{{ read_startup() — the FIRST act: learn how to start from input/ */
/* Opens <dir>/input/startup and reads key = value lines (ignoring # comments
 * and blanks). Missing file is a loud error, never a silent default — that is
 * the house "read input/ first" contract, and errors-over-fallbacks. The only
 * key honored so far is `frames` (a headless run budget); an env FPS_FRAMES
 * overrides it so the loop can be auto-quit for tests without editing the seed. */
static run_config_t read_startup(const char *dir)
{
    run_config_t cfg = { dir, 0 };

    char path[1024];
    snprintf(path, sizeof path, "%s/input/startup", dir);
    FILE *f = fopen(path, "r");
    if (!f) {
        fprintf(stderr, "FATAL: cannot read %s — the first act is to read "
                        "input/, and it is not there.\n", path);
        exit(1);
    }
    char line[512];
    while (fgets(line, sizeof line, f)) {
        char *p = line;
        while (*p == ' ' || *p == '\t') p++;
        if (*p == '#' || *p == '\n' || *p == '\0') continue;   /* comment/blank */
        char *eq = strchr(p, '=');
        if (!eq) continue;
        *eq = '\0';                       /* p is now the null-terminated key */
        long val = strtol(eq + 1, NULL, 10);
        /* One key today; add more here as the config grows. */
        if (strncmp(p, "frames", 6) == 0) cfg.frames = val;
    }
    fclose(f);

    const char *env = getenv("FPS_FRAMES");
    if (env) cfg.frames = strtol(env, NULL, 10);   /* test override */
    return cfg;
}
/* }}} */

/* {{{ say_goodbye() — the LAST act: write output/goodbye */
/* Every run, success or clean quit, ends by writing the goodbye file. */
static void say_goodbye(const char *dir)
{
    char path[1024];
    snprintf(path, sizeof path, "%s/output/goodbye", dir);
    FILE *f = fopen(path, "w");
    if (!f) { fprintf(stderr, "warning: could not write %s\n", path); return; }
    fprintf(f, "goodbye — the room went quiet, the threads joined, the window "
               "closed. Until next run.\n");
    fclose(f);
    printf("First Person Spellcraft — goodbye written, sleeping.\n");
}
/* }}} */

/* {{{ mover_box — a stand-in "player" that wanders the world */
/* Stands in for both the frame-clock heartbeat and (eventually) real input: each
 * tick it tries to drift the player by its velocity and bounces off any solid
 * tile — the first taste of collision (issue 105). It publishes the player's
 * world position into the renderables slot. The nanosleep is a placeholder for
 * the real timer box (SoraMech issue 251); when that lands, a clock tick on a
 * wire drives this instead of a sleep. */
typedef struct {
    slot_id_t out; slot_store_t *slots; const world_t *world;
    float x, y, vx, vy;
} mover_state_t;

static int mover_box(box_t *b)
{
    mover_state_t *m = b->user;
    if (atomic_load(&g_quit)) return 0;   /* stop re-arming on quit */

    struct timespec ts = { 0, 16 * 1000 * 1000 };   /* ~16 ms ≈ 60 Hz placeholder */
    nanosleep(&ts, NULL);

    /* Per-axis collision: try X, then Y, reversing whichever axis would step
     * into a solid tile. Separating the axes lets the player slide along a wall
     * instead of sticking in a corner — the seed of issue 105's movement. */
    float nx = m->x + m->vx, ny = m->y + m->vy;
    if (world_is_solid(m->world, (int)nx, (int)m->y)) m->vx = -m->vx; else m->x = nx;
    if (world_is_solid(m->world, (int)m->x, (int)ny)) m->vy = -m->vy; else m->y = ny;

    renderable_t r = { m->x, m->y };
    /* Latest-position semantics: if the tiny renderables ring is momentarily
     * full (render stalled), just drop this update — the next tick carries a
     * fresher position anyway. */
    (void)slot_push(m->slots, m->out, &r);
    return 1;   /* re-arm */
}
/* }}} */

/* {{{ render_thread — the dedicated, always-unblocked drawer */
/* Owns the raylib window/GL context. Loops as fast as vsync allows: drain the
 * renderables slot to the latest player position, draw the world top-down plus
 * the player, present. Never blocks on the pool — if no new position arrived, it
 * redraws the current one. Raises g_quit on window close or frame budget.
 *
 * This top-down view is a DEBUG visualisation of the world (issue 103), not the
 * real first-person renderer (issue 104) — it just lets us see the rooms, the
 * walls, the step-up, and the player moving among them. */
typedef struct {
    slot_store_t *slots; slot_id_t rend; const world_t *world; long frames;
} render_ctx_t;

/* {{{ draw_world_topdown() */
static void draw_world_topdown(const world_t *w)
{
    for (int y = 0; y < w->height; y++)
        for (int x = 0; x < w->width; x++) {
            const cell_t *c = world_cell(w, x, y);
            float px = (float)x * CELL_PX, py = (float)y * CELL_PX;
            if (c->solid) {
                platform_draw_rect(px, py, CELL_PX, CELL_PX, 70, 70, 84); /* wall */
            } else {
                /* Floor tinted by room so the two rooms and the step-up read at a
                 * glance — the higher room (id 1) draws a touch brighter. */
                uint8_t g = (c->room_id == 1) ? 66 : 42;
                platform_draw_rect(px, py, CELL_PX, CELL_PX, 26, g, 34);
            }
        }
}
/* }}} */

static void *render_thread(void *arg)
{
    render_ctx_t *rc = arg;
    if (!platform_open(WIN_W, WIN_H, "First Person Spellcraft")) {
        fprintf(stderr, "FATAL: could not open a window/GL surface.\n");
        atomic_store(&g_quit, 1);
        return NULL;
    }

    renderable_t cur = { rc->world->width / 2.0f, rc->world->height / 2.0f };
    long n = 0;
    while (!atomic_load(&g_quit)) {
        renderable_t r;
        while (slot_pop(rc->slots, rc->rend, &r)) cur = r;   /* drain to latest */

        platform_begin_frame();
        draw_world_topdown(rc->world);
        platform_draw_rect(cur.x * CELL_PX - PLAYER_PX / 2,
                           cur.y * CELL_PX - PLAYER_PX / 2,
                           PLAYER_PX, PLAYER_PX, 230, 200, 90);   /* the player */
        platform_end_frame();

        n++;
        /* Optional one-shot screenshot (FPS_SHOT=<abs path>) once the player has
         * moved a little, so demos can capture the view without a human present. */
        if (n == 40) { const char *shot = getenv("FPS_SHOT"); if (shot) platform_screenshot(shot); }
        if (platform_should_close() || (rc->frames > 0 && n >= rc->frames))
            atomic_store(&g_quit, 1);
    }
    platform_close();
    return NULL;
}
/* }}} */

/* {{{ main() — the whole life of the program */
int main(int argc, char **argv)
{
    say_hello();

    /* First act: read input/ to learn how to start. Project dir is argv[1], or
     * "." so the binary works launched from anywhere a run script points it. */
    const char *dir = (argc > 1) ? argv[1] : ".";
    run_config_t cfg = read_startup(dir);

    /* Boot the machine: the threads (pool), the wires (slots), the world. */
    pool_t *pool = pool_create(0);
    slot_store_t *slots = slot_store_create();
    slot_id_t rend_slot = slot_alloc(slots, SLOT_QUEUE, sizeof(renderable_t), 8);
    world_t *world = world_build_test();
    if (!world) { fprintf(stderr, "FATAL: could not build the world.\n"); return 1; }

    /* Spin up the one thread that is NOT a box: the render thread (GL affinity).
     * It reads the world (built once, read-only) and the latest player position. */
    render_ctx_t rctx = { slots, rend_slot, world, cfg.frames };
    pthread_t rthread;
    pthread_create(&rthread, NULL, render_thread, &rctx);

    /* Wire and start the graph: one source box, the mover "player", spawning at
     * the spawn room's centre and wandering, bouncing off walls, forever. */
    room_t *spawn = &world->rooms[world->spawn_room];
    mover_state_t mstate = {
        .out = rend_slot, .slots = slots, .world = world,
        .x = (spawn->x0 + spawn->x1) / 2.0f, .y = (spawn->y0 + spawn->y1) / 2.0f,
        .vx = 0.07f, .vy = 0.045f,
    };
    box_t mover = {
        .name = "mover", .fn = mover_box, .slots = slots, .pool = pool,
        .n_in = 0, .n_down = 0, .user = &mstate,
    };
    box_kick(&mover);

    /* Run until the quit signal (the render thread raises it on window close /
     * frame budget). Watch it without spinning. */
    while (!atomic_load(&g_quit)) {
        struct timespec ts = { 0, 10 * 1000 * 1000 };
        nanosleep(&ts, NULL);
    }

    /* Break down: join the render thread, tear down the pool (the mover, seeing
     * g_quit, stops re-arming, so the pool drains and joins), free world + wires. */
    pthread_join(rthread, NULL);
    pool_destroy(pool);
    world_destroy(world);
    slot_store_destroy(slots);

    /* Last act, always. */
    say_goodbye(dir);
    return 0;
}
/* }}} */
