/*
 * units-host.c - the renderer's main thread as the ceramic engine's host (issue 515b)
 *
 * What this is: the first real render frame on the ceramic engine. The main
 * thread owns the raylib window -- OpenGL takes drawing calls from that
 * thread only, so drawing is never a station. Each frame it hands the tick
 * and the eight lanes' requests in to the task queue as one batch, waits
 * until every lane's answer has landed (the kept engine copy counts after
 * the copy, so the count is trusted), and draws every unit as a cube, with
 * the camera and the numbers handled here too. One frame is in flight at a
 * time; the mailbox (issue 515c) is what will let computing and drawing
 * overlap.
 *
 * Three modes:
 *   (none)                 a window; runs until closed
 *   --check FRAMES         no window: hand in and collect FRAMES frames and
 *                          compare every unit with unit_place() called
 *                          directly; exits 1 on any difference
 *   --shot FRAMES PATH     a hidden window: draw FRAMES frames into an
 *                          off-screen texture and save the last as a picture
 *                          (a hidden window's screen, read back after the
 *                          frame is shown, came out black; a texture drawn
 *                          into is the dependable way)
 * Every mode prints one line: mode, frames, mean microseconds from hand-in
 * to landed, mean microseconds drawing (0 when nothing is drawn), units.
 *
 * serac compiles it after the engine and the map's construction code;
 * run-host.sh links raylib.
 */
#include "raylib.h"
#include <sched.h>
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

/* The engine side: the program, its doors, and where answers land. */
typedef struct {
    cera_map_t *m;
    int tick_at, tick_p, lane_at[UNIT_LANES], lane_p[UNIT_LANES], out_at[UNIT_LANES], out_p[UNIT_LANES];
    lane_units landed[UNIT_LANES];
} host;

/* {{{ static void host_start(host *h) */
/* THREADING { -- start the engine, find its doors, register the landings */
static void host_start(host *h)
{
    const cera_map_build_t *program = cera_map_build_find("units.map");
    if (!program) { fprintf(stderr, "built without units.map\n"); exit(70); }
    h->m = cera_map_create_empty();
    program->build(h->m, 0, 0);
    long cores = sysconf(_SC_NPROCESSORS_ONLN);
    /* one worker per core but one: this thread is the last core */
    cera_map_start(h->m, cores > 1 ? (int)cores - 1 : 1);
    cera_pool_submitter_register(h->m->pool);
    must(cera_map_bring_up(h->m), "the program");
    if (!cera_map_argument_at(h->m, 0, &h->tick_at, &h->tick_p)) { fprintf(stderr, "units.map has no argument 0\n"); exit(70); }
    for (int l = 0; l < UNIT_LANES; l++) {
        if (!cera_map_argument_at(h->m, 1 + l, &h->lane_at[l], &h->lane_p[l]) || !cera_map_result_at(h->m, l, &h->out_at[l], &h->out_p[l])) {
            fprintf(stderr, "units.map has no door for lane %d\n", l);
            exit(70);
        }
        must(cera_map_collect(h->m, h->out_at[l], h->out_p[l], &h->landed[l], 1, (int)sizeof(lane_units)), "a lane's landing");
    }
    cera_pool_release(h->m->pool);
}
/* }}} */

/* {{{ static double host_frame(host *h, int frame, float t) */
/* One frame through the engine: re-arm, hand the tick and every lane's
 * request in as one batch, wait until every lane has landed. Returns the
 * microseconds from hand-in to landed. */
static double host_frame(host *h, int frame, float t)
{
    double start = now_us();
    if (frame > 0)   /* re-armed only now: the previous frame has landed */
        for (int l = 0; l < UNIT_LANES; l++)
            must(cera_map_collect(h->m, h->out_at[l], h->out_p[l], &h->landed[l], 1, (int)sizeof(lane_units)), "a lane's landing");
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
    return now_us() - start;
}
/* }}} */

/* {{{ static void host_stop(host *h) */
static void host_stop(host *h)
{
    cera_pool_submitter_unregister(h->m->pool);
    cera_pool_join(h->m->pool);
    cera_map_destroy(h->m);
}
/* } THREADING */
/* }}} */

/* {{{ static void draw_units(const host *h) */
/* Every landed unit as a cube, in its team's colour. */
static void draw_units(const host *h)
{
    for (int l = 0; l < UNIT_LANES; l++) {
        const unit *each = (const unit *)&h->landed[l];
        for (int i = 0; i < UNITS_PER_LANE; i++) {
            unsigned int c = each[i].color;
            Color col = { (unsigned char)(c >> 24), (unsigned char)(c >> 16), (unsigned char)(c >> 8), (unsigned char)c };
            DrawCube((Vector3){ each[i].x, each[i].y, each[i].z }, 0.5f, 0.5f, 0.5f, col);
        }
    }
}
/* }}} */

/* {{{ static int check(host *h, int frames) */
/* No window: every unit of every frame against unit_place() called here. */
static int check(host *h, int frames)
{
    double engine = 0;
    int wrong = 0;
    for (int f = 0; f < frames; f++) {
        float t = (float)f / 60.0f;
        engine += host_frame(h, f, t);
        for (int l = 0; l < UNIT_LANES; l++) {
            const unit *each = (const unit *)&h->landed[l];
            for (int i = 0; i < UNITS_PER_LANE; i++) {
                unit direct;
                unit_place(l * UNITS_PER_LANE + i, t, &direct);
                if (memcmp(&direct, &each[i], sizeof direct) != 0) {
                    if (wrong < 5) fprintf(stderr, "frame %d, unit %d: the engine's answer differs\n", f, l * UNITS_PER_LANE + i);
                    wrong++;
                }
            }
        }
    }
    printf("check\t%d\t%.1f\t0\t%d\n", frames, engine / frames, UNIT_COUNT);
    if (wrong) fprintf(stderr, "%d units differed\n", wrong);
    return wrong ? 1 : 0;
}
/* }}} */

/* {{{ int main(int argc, char **argv) */
int main(int argc, char **argv)
{
    int check_frames = 0, shot_frames = 0;
    const char *shot_path = NULL;
    if (argc == 3 && strcmp(argv[1], "--check") == 0) check_frames = atoi(argv[2]);
    else if (argc == 4 && strcmp(argv[1], "--shot") == 0) { shot_frames = atoi(argv[2]); shot_path = argv[3]; }
    else if (argc != 1) {
        fprintf(stderr, "usage: %s [--check FRAMES | --shot FRAMES PATH]\n", argv[0]);
        return 64;
    }

    host h;
    host_start(&h);
    if (check_frames > 0) {
        int rc = check(&h, check_frames);
        host_stop(&h);
        return rc;
    }

    /* A window: hidden when only a picture is wanted. */
    if (shot_path) SetConfigFlags(FLAG_WINDOW_HIDDEN);
    SetConfigFlags(FLAG_MSAA_4X_HINT);
    InitWindow(1280, 720, "ceramic host loop");
    SetTargetFPS(shot_path ? 0 : 60);
    Camera3D cam = { .position = { 30, 22, 30 }, .target = { 0, 0, 0 }, .up = { 0, 1, 0 }, .fovy = 45, .projection = CAMERA_PERSPECTIVE };

    /* picture mode draws into a texture the size of the window */
    RenderTexture2D target = { 0 };
    if (shot_path) target = LoadRenderTexture(1280, 720);
    double engine_sum = 0, draw_sum = 0, shown_engine = 0, shown_draw = 0;
    int frame = 0;
    while (!WindowShouldClose()) {
        /* the camera is this thread's, taken at the last moment (issue 515) */
        if (!shot_path) UpdateCamera(&cam, CAMERA_ORBITAL);
        float t = shot_path ? (float)frame / 60.0f : (float)GetTime();
        double engine = host_frame(&h, frame, t);
        double draw_start = now_us();
        /* Two paths: the window's own screen, or (picture mode) the texture */
        if (shot_path) BeginTextureMode(target); else BeginDrawing();
        ClearBackground((Color){ 18, 24, 22, 255 });
        BeginMode3D(cam);
        DrawGrid(40, 1.0f);
        draw_units(&h);
        EndMode3D();
        /* the numbers, smoothed so they can be read */
        shown_engine = frame ? shown_engine * 0.95 + engine * 0.05 : engine;
        DrawRectangle(10, 10, 430, 86, (Color){ 0, 0, 0, 150 });
        DrawText(TextFormat("%d units, posed by the ceramic engine", UNIT_COUNT), 20, 18, 18, RAYWHITE);
        DrawText(TextFormat("hand-in to landed: %.0f us", shown_engine), 20, 42, 18, (Color){ 69, 180, 170, 255 });
        DrawText(TextFormat("drawing: %.0f us   %d fps", shown_draw, GetFPS()), 20, 66, 18, (Color){ 222, 170, 66, 255 });
        if (shot_path) { EndTextureMode(); BeginDrawing(); EndDrawing(); } else EndDrawing();
        double drawn = now_us() - draw_start;
        shown_draw = frame ? shown_draw * 0.95 + drawn * 0.05 : drawn;
        engine_sum += engine;
        draw_sum += drawn;
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
    printf("%s\t%d\t%.1f\t%.1f\t%d\n", shot_path ? "shot" : "window", frame, engine_sum / frame, draw_sum / frame, UNIT_COUNT);
    if (shot_path) UnloadRenderTexture(target);
    CloseWindow();
    host_stop(&h);
    return 0;
}
/* }}} */
