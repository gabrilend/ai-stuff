/*
 * units-host.c - the renderer's main thread as the ceramic engine's host (issues 515b, 515c)
 *
 * What this is: the first real render frame on the ceramic engine. Two
 * threads of the host's own share the work, with a mailbox between them:
 *
 *   the feeder  drives the engine. For each state it points every lane's
 *               landing straight into the mailbox buffer it is writing (so
 *               the engine's landing copy is the only copy), hands the tick
 *               and the eight lanes' requests in to the task queue as one
 *               batch, waits until all eight have landed (the kept engine
 *               copy counts after the copy, so the count is trusted),
 *               stamps the frame number and the time, and publishes.
 *   the draw    thread owns the raylib window -- OpenGL takes drawing calls
 *               from that thread only, so drawing is never a station. It
 *               moves the camera, takes the newest state as late as it can,
 *               and draws every unit as a cube. It never waits for the
 *               feeder: with nothing new, it draws the state it has again.
 *
 * Pacing: once it has published, the feeder starts the next state as soon
 * as the draw thread has taken the last one, so state N+1 is worked out
 * while frame N is drawn, and no core works on states nobody will see.
 *
 * Three modes:
 *   (none)                 a window; runs until closed
 *   --check STATES         no window: this thread takes STATES states
 *                          through the mailbox while the feeder races, and
 *                          compares every unit with unit_place() at that
 *                          state's time; exits 1 on any difference
 *   --shot FRAMES PATH     a hidden window: draw FRAMES frames into an
 *                          off-screen texture and save the last as a picture
 *                          (a hidden window's screen, read back after the
 *                          frame is shown, came out black; a texture drawn
 *                          into is the dependable way)
 * Every mode prints one line: mode, frames, mean microseconds from hand-in
 * to landed, mean microseconds of the draw thread's frame (0 when nothing
 * is drawn), mean state age when drawn (ms), frames that drew a state
 * again, units.
 *
 * serac compiles it after the engine and the map's construction code;
 * run-host.sh links raylib.
 */
#include "raylib.h"
#include "mailbox.h"
#include <pthread.h>
#include <sched.h>
#include <semaphore.h>
#include <stdint.h>
#include <time.h>

/* {{{ static double now_us(void) */
static double now_us(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1e6 + ts.tv_nsec / 1e3;
}
/* }}} */

/* {{{ static void must(const char *refusal, const char *what) */
static void must(const char *refusal, const char *what)
{
    if (refusal) {
        fprintf(stderr, "refused %s: %s\n", what, refusal);
        exit(1);
    }
}
/* }}} */

/* One whole state, as the mailbox carries it: which frame, the time every
 * unit in it was true (seconds), how long the engine took to work it out,
 * and the eight lanes' units. */
typedef struct {
    int        frame;
    float      time;
    double     engine_us;    /* hand-in to landed, measured by the feeder */
    lane_units lanes[UNIT_LANES];
} unit_state;

/* The engine side, and the mailbox between the feeder and the draw thread. */
typedef struct {
    cera_map_t *m;
    int tick_at, tick_p, lane_at[UNIT_LANES], lane_p[UNIT_LANES], out_at[UNIT_LANES], out_p[UNIT_LANES];
    mailbox   *mb;
    sem_t      taken;        /* posted by the reader each time it takes a new state */
    atomic_int stop;
    int        fixed_step;   /* 1: state N is true at N/60 s (check, shot); 0: at the clock */
    double     clock_zero_us;
    pthread_t  feeder;
} host;

/* {{{ static float host_clock(const host *h) */
/* Seconds since the host started: the one clock both threads read. */
static float host_clock(const host *h)
{
    return (float)((now_us() - h->clock_zero_us) / 1e6);
}
/* }}} */

/* {{{ static void *feeder_run(void *arg) */
/* THREADING { -- the feeder: one state per take, straight into the mailbox */
static void *feeder_run(void *arg)
{
    host *h = arg;
    for (int frame = 0; !atomic_load(&h->stop); frame++) {
        unit_state *s = mailbox_writing(h->mb, 0);
        double start = now_us();
        /* re-armed per state: the landing goes into this state's buffer */
        for (int l = 0; l < UNIT_LANES; l++)
            must(cera_map_collect(h->m, h->out_at[l], h->out_p[l], &s->lanes[l], 1, (int)sizeof(lane_units)), "a lane's landing");
        float t = h->fixed_step ? (float)frame / 60.0f : host_clock(h);
        cera_pool_batch_begin(h->m->pool);
        tick tk = { frame, t };
        must(cera_map_deliver_argument(h->m, h->tick_at, h->tick_p, &tk, sizeof tk), "the tick");
        for (int l = 0; l < UNIT_LANES; l++) {
            lane_req r = { frame, l };
            must(cera_map_deliver_argument(h->m, h->lane_at[l], h->lane_p[l], &r, sizeof r), "a lane's request");
        }
        cera_pool_batch_end(h->m->pool);
        for (int l = 0; l < UNIT_LANES; l++)
            while (cera_map_collected(h->m, h->out_at[l], h->out_p[l]) < 1) sched_yield();
        s->frame = frame;
        s->time = t;
        s->engine_us = now_us() - start;
        mailbox_publish(h->mb, 0);
        sem_wait(&h->taken);   /* the draw thread took it (or the host is stopping) */
    }
    return NULL;
}
/* }}} */

/* {{{ static void host_start(host *h, int fixed_step) */
/* Start the engine, find its doors, make the mailbox, start the feeder. */
static void host_start(host *h, int fixed_step)
{
    const cera_map_build_t *program = cera_map_build_find("units.map");
    if (!program) { fprintf(stderr, "built without units.map\n"); exit(70); }
    h->m = cera_map_create_empty();
    program->build(h->m, 0, 0);
    long cores = sysconf(_SC_NPROCESSORS_ONLN);
    /* one worker per core but two: the feeder and the draw thread have theirs */
    cera_map_start(h->m, cores > 2 ? (int)cores - 2 : 1);
    cera_pool_submitter_register(h->m->pool);
    must(cera_map_bring_up(h->m), "the program");
    if (!cera_map_argument_at(h->m, 0, &h->tick_at, &h->tick_p)) { fprintf(stderr, "units.map has no argument 0\n"); exit(70); }
    for (int l = 0; l < UNIT_LANES; l++)
        if (!cera_map_argument_at(h->m, 1 + l, &h->lane_at[l], &h->lane_p[l]) || !cera_map_result_at(h->m, l, &h->out_at[l], &h->out_p[l])) {
            fprintf(stderr, "units.map has no door for lane %d\n", l);
            exit(70);
        }
    cera_pool_release(h->m->pool);

    h->mb = mailbox_create(sizeof(unit_state), 1);
    if (!h->mb) { fprintf(stderr, "no memory for the mailbox\n"); exit(71); }
    sem_init(&h->taken, 0, 0);
    atomic_init(&h->stop, 0);
    h->fixed_step = fixed_step;
    h->clock_zero_us = now_us();
    pthread_create(&h->feeder, NULL, feeder_run, h);
}
/* }}} */

/* {{{ static const unit_state *host_take(host *h, int *is_new) */
/* The newest state, for the reader. Taking a new one lets the feeder start
 * the next. */
static const unit_state *host_take(host *h, int *is_new)
{
    const unit_state *s = mailbox_take(h->mb, is_new);
    if (*is_new) sem_post(&h->taken);
    return s;
}
/* }}} */

/* {{{ static void host_stop(host *h) */
static void host_stop(host *h)
{
    atomic_store(&h->stop, 1);
    sem_post(&h->taken);   /* wake the feeder if it waits for a take */
    pthread_join(h->feeder, NULL);
    cera_pool_submitter_unregister(h->m->pool);
    cera_pool_join(h->m->pool);
    cera_map_destroy(h->m);
    mailbox_destroy(h->mb);
}
/* } THREADING */
/* }}} */

/* {{{ static void draw_units(const unit_state *s) */
/* Every unit of the state as a cube, in its team's colour. */
static void draw_units(const unit_state *s)
{
    for (int l = 0; l < UNIT_LANES; l++) {
        const unit *each = (const unit *)&s->lanes[l];
        for (int i = 0; i < UNITS_PER_LANE; i++) {
            unsigned int c = each[i].color;
            Color col = { (unsigned char)(c >> 24), (unsigned char)(c >> 16), (unsigned char)(c >> 8), (unsigned char)c };
            DrawCube((Vector3){ each[i].x, each[i].y, each[i].z }, 0.5f, 0.5f, 0.5f, col);
        }
    }
}
/* }}} */

/* {{{ static int check(host *h, int states) */
/* No window: take states as they come and compare every unit with
 * unit_place() at the state's own time. The feeder races this thread the
 * whole time, so a half-written state would show as units that differ. */
static int check(host *h, int states)
{
    double engine = 0;
    int wrong = 0, last_frame = -1, checked = 0;
    while (checked < states) {
        int is_new;
        const unit_state *s = host_take(h, &is_new);
        /* Two paths: nothing new yet -> look again; a new state -> check it */
        if (!is_new) { sched_yield(); continue; }
        if (s->frame <= last_frame || s->time != (float)s->frame / 60.0f) {
            if (wrong < 5) fprintf(stderr, "state %d came after %d, or its time is not its own\n", s->frame, last_frame);
            wrong++;
        }
        last_frame = s->frame;
        engine += s->engine_us;
        for (int l = 0; l < UNIT_LANES; l++) {
            const unit *each = (const unit *)&s->lanes[l];
            for (int i = 0; i < UNITS_PER_LANE; i++) {
                unit direct;
                unit_place(l * UNITS_PER_LANE + i, s->time, &direct);
                if (memcmp(&direct, &each[i], sizeof direct) != 0) {
                    if (wrong < 5) fprintf(stderr, "state %d, unit %d: the engine's answer differs\n", s->frame, l * UNITS_PER_LANE + i);
                    wrong++;
                }
            }
        }
        checked++;
    }
    printf("check\t%d\t%.1f\t0\t0\t0\t%d\n", states, engine / states, UNIT_COUNT);
    if (wrong) fprintf(stderr, "%d differences\n", wrong);
    return wrong ? 1 : 0;
}
/* }}} */

/* {{{ int main(int argc, char **argv) */
int main(int argc, char **argv)
{
    int check_states = 0, shot_frames = 0;
    const char *shot_path = NULL;
    if (argc == 3 && strcmp(argv[1], "--check") == 0) check_states = atoi(argv[2]);
    else if (argc == 4 && strcmp(argv[1], "--shot") == 0) { shot_frames = atoi(argv[2]); shot_path = argv[3]; }
    else if (argc != 1) {
        fprintf(stderr, "usage: %s [--check STATES | --shot FRAMES PATH]\n", argv[0]);
        return 64;
    }

    host h;
    host_start(&h, check_states > 0 || shot_path);
    if (check_states > 0) {
        int rc = check(&h, check_states);
        host_stop(&h);
        return rc;
    }

    /* A window: hidden when only a picture is wanted. */
    if (shot_path) SetConfigFlags(FLAG_WINDOW_HIDDEN);
    SetConfigFlags(FLAG_MSAA_4X_HINT);
    InitWindow(1280, 720, "ceramic host loop");
    SetTargetFPS(shot_path ? 0 : 60);
    Camera3D cam = { .position = { 30, 22, 30 }, .target = { 0, 0, 0 }, .up = { 0, 1, 0 }, .fovy = 45, .projection = CAMERA_PERSPECTIVE };

    /* the window opens on a complete state: the only wait, and only once */
    int is_new = 0;
    const unit_state *s = host_take(&h, &is_new);
    while (!is_new) { sched_yield(); s = host_take(&h, &is_new); }

    /* picture mode draws into a texture the size of the window */
    RenderTexture2D target = { 0 };
    if (shot_path) target = LoadRenderTexture(1280, 720);
    double engine_sum = 0, frame_sum = 0, age_sum = 0, shown_engine = 0, shown_frame = 0, shown_age = 0;
    int frame = 0, again = 0;
    while (!WindowShouldClose()) {
        double frame_start = now_us();
        /* the camera is this thread's, moved before the take (issue 515) */
        if (!shot_path) UpdateCamera(&cam, CAMERA_ORBITAL);
        /* the newest state, taken as late as possible */
        if (frame > 0) s = host_take(&h, &is_new);
        if (!is_new) again++;
        /* the state's age: how long ago the moment it shows was (in picture
         * mode states are on a fixed step, so their age has no meaning) */
        double age_ms = shot_path ? 0 : (host_clock(&h) - s->time) * 1e3;
        /* Two paths: the window's own screen, or (picture mode) the texture */
        if (shot_path) BeginTextureMode(target); else BeginDrawing();
        ClearBackground((Color){ 18, 24, 22, 255 });
        BeginMode3D(cam);
        DrawGrid(40, 1.0f);
        draw_units(s);
        EndMode3D();
        /* the numbers, smoothed so they can be read */
        shown_engine = frame ? shown_engine * 0.95 + s->engine_us * 0.05 : s->engine_us;
        shown_age = frame ? shown_age * 0.95 + age_ms * 0.05 : age_ms;
        DrawRectangle(10, 10, 470, 134, (Color){ 0, 0, 0, 150 });
        DrawText(TextFormat("%d units, posed by the ceramic engine", UNIT_COUNT), 20, 18, 18, RAYWHITE);
        DrawText(TextFormat("engine, beside the drawing: %.0f us", shown_engine), 20, 42, 18, (Color){ 69, 180, 170, 255 });
        DrawText(TextFormat("draw thread: %.0f us   %d fps", shown_frame, GetFPS()), 20, 66, 18, (Color){ 222, 170, 66, 255 });
        DrawText(TextFormat("state age when drawn: %.1f ms", shown_age), 20, 90, 18, (Color){ 190, 150, 210, 255 });
        DrawText(TextFormat("frames that drew a state again: %d of %d", again, frame + 1), 20, 114, 18, (Color){ 170, 170, 170, 255 });
        /* the draw thread's frame, measured before the screen's refresh:
         * ending the 3D mode already handed raylib's batch to OpenGL, and
         * ending the drawing also sleeps to hold 60 frames a second */
        double took = now_us() - frame_start;
        if (shot_path) { EndTextureMode(); BeginDrawing(); EndDrawing(); } else EndDrawing();
        shown_frame = frame ? shown_frame * 0.95 + took * 0.05 : took;
        engine_sum += s->engine_us;
        frame_sum += took;
        age_sum += age_ms;
        frame++;
        if (shot_path && frame == shot_frames) {
            Image img = LoadImageFromTexture(target.texture);
            ImageFlipVertical(&img);   /* textures are stored bottom row first */
            int saved = ExportImage(img, shot_path);
            UnloadImage(img);
            if (!saved) { fprintf(stderr, "the picture could not be saved to %s\n", shot_path); return 1; }
            break;
        }
    }
    printf("%s\t%d\t%.1f\t%.1f\t%.2f\t%d\t%d\n", shot_path ? "shot" : "window", frame,
           engine_sum / frame, frame_sum / frame, age_sum / frame, again, UNIT_COUNT);
    if (shot_path) UnloadRenderTexture(target);
    CloseWindow();
    host_stop(&h);
    return 0;
}
/* }}} */
