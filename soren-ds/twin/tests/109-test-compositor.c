/*
 * 109-test-compositor.c — issue 603: surfaces copied onto the screens,
 * once a frame.
 *
 * General description: first one frame at a time, called by hand. A new
 * surface is copied where it stands and nothing else on the screen
 * changes; a frame with nothing marked copies nothing and presents
 * nothing; a marked surface is copied again. Of two overlapping surfaces,
 * marking the one behind copies both, so the one in front still shows in
 * front. Moving, shrinking and releasing paint the background where the
 * surface was, and copy again what was under it. A surface in the bottom
 * right corner lands exactly there. Then the compositor map on its own
 * timer: frames come at 60 Hz with only ever one in progress, a thread
 * drawing and marking meanwhile has its last drawing on the screen once
 * the frames stop, and stopping leaves the next frame waiting on the loop.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/system/104-surfaces.h"
#include "../../src/system/107-compositor.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "047-check.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#define CORES  4
#define TOP    0
#define BOTTOM 1

/* {{{ helpers */
static void sleep_ms(int ms)
{
    struct timespec t = { ms / 1000, (long)(ms % 1000) * 1000000L };
    nanosleep(&t, NULL);
}

static uint32_t at(int screen, int x, int y)
{
    struct platform_screen s = platform_screen(screen);
    return s.pixels[(size_t)y * (size_t)s.stride + (size_t)x];
}

static void fill(int32_t handle, uint32_t colour)
{
    struct canvas c = surface_canvas(handle);
    for (int i = 0; i < c.width * c.height; i++) c.pixels[i] = colour;
    surface_mark_dirty(handle);
}

/* Is every pixel of the rectangle `colour`? */
static int all(int screen, int x, int y, int w, int h, uint32_t colour)
{
    for (int r = y; r < y + h; r++)
        for (int c = x; c < x + w; c++)
            if (at(screen, c, r) != colour) return 0;
    return 1;
}

/* Clear a screen by hand, so a check sees only what the compositor wrote. */
static void clear(int screen)
{
    struct platform_screen s = platform_screen(screen);
    for (int r = 0; r < s.height; r++) memset(s.pixels + (size_t)r * (size_t)s.stride, 0, (size_t)s.width * 4);
}
/* }}} */

/* {{{ the drawing thread */
#define STROKES 3000
static int32_t     drawn_on;
static atomic_int  drawing = 1;

static void *draw(void *arg)
{
    (void)arg;
    struct canvas c = surface_canvas(drawn_on);
    for (uint32_t k = 1; k <= STROKES; k++) {
        __atomic_store_n(&c.pixels[0], 0xFF000000u | k, __ATOMIC_RELAXED);
        surface_mark_dirty(drawn_on);
        if (k % 100 == 0) sleep_ms(1);
    }
    atomic_store(&drawing, 0);
    return NULL;
}
/* }}} */

int main(void)
{
    twin_engine_start(CORES, (size_t)256 << 20);
    engine_open_gate();
    metrics_open("109-compositor");
    struct map_report report;
    struct compositor_frame f;
    const uint32_t RED = 0xFFE06060u, BLUE = 0xFF5A9AE6u, GREEN = 0xFF60C080u, BG = COMPOSITOR_BACKGROUND;
    clear(TOP);
    clear(BOTTOM);

    /* --- a new surface ---------------------------------------------------- */
    int32_t a = surface_request_for(5, BOTTOM, 10, 20, 100, 50);
    fill(a, RED);
    f = compositor_frame();
    CHECK(f.copied == 1 && f.painted == 0, "a new surface is copied (%d copied, %d painted)", f.copied, f.painted);
    CHECK(all(BOTTOM, 10, 20, 100, 50, RED), "to exactly where it stands");
    CHECK(at(BOTTOM, 9, 20) == 0 && at(BOTTOM, 110, 20) == 0 && at(BOTTOM, 10, 19) == 0 && at(BOTTOM, 10, 70) == 0 &&
          all(TOP, 0, 0, 640, 480, 0), "and nothing around it, or on the other screen, changes");
    uint64_t presents = twin_screen_presents(BOTTOM);
    f = compositor_frame();
    CHECK(f.copied == 0 && f.painted == 0 && twin_screen_presents(BOTTOM) == presents,
          "a frame with nothing marked copies nothing and presents nothing");
    surface_canvas(a).pixels[0] = BLUE;
    CHECK(compositor_frame().copied == 0 && at(BOTTOM, 10, 20) == RED, "writing without marking shows nothing yet");
    surface_mark_dirty(a);
    CHECK(compositor_frame().copied == 1 && at(BOTTOM, 10, 20) == BLUE && twin_screen_presents(BOTTOM) == presents + 1,
          "marking it copies it again, and presents the screen");

    /* --- one in front of another ---------------------------------------- */
    int32_t b = surface_request_for(5, BOTTOM, 60, 40, 100, 50);      /* the same owner, overlapping, in front */
    fill(b, GREEN);
    compositor_frame();
    CHECK(at(BOTTOM, 70, 50) == GREEN && at(BOTTOM, 20, 30) == RED, "a surface granted later shows in front");
    fill(a, RED);
    f = compositor_frame();
    CHECK(f.copied == 2 && at(BOTTOM, 70, 50) == GREEN && at(BOTTOM, 105, 65) == GREEN,
          "marking the one behind copies the one in front again, which still shows in front (%d copied)", f.copied);

    /* --- moving, shrinking, releasing ------------------------------------ */
    CHECK(surface_set_position(b, 300, 300) == SURFACE_OK, "the one in front moves away");
    f = compositor_frame();
    CHECK(f.painted == 1 && all(BOTTOM, 300, 300, 100, 50, GREEN), "it is copied where it went");
    CHECK(all(BOTTOM, 110, 40, 50, 50, BG) && all(BOTTOM, 60, 70, 100, 20, BG),
          "where it was and nothing else is, the background shows");
    CHECK(all(BOTTOM, 60, 40, 50, 30, RED), "and where the one behind was under it, that one shows again");
    CHECK(surface_resize(a, 40, 20) == SURFACE_OK && compositor_frame().painted == 1 &&
          all(BOTTOM, 10, 20, 40, 20, RED) && all(BOTTOM, 50, 20, 60, 50, BG) && all(BOTTOM, 10, 40, 40, 30, BG),
          "shrinking keeps its corner and gives the rest back to the background");
    CHECK(surface_release(a) == SURFACE_OK && compositor_frame().painted == 1 && all(BOTTOM, 10, 20, 40, 20, BG),
          "releasing it gives all of it back");
    CHECK(all(BOTTOM, 300, 300, 100, 50, GREEN), "and leaves the other surface alone");
    surface_release(b);
    compositor_frame();

    /* --- the corner ------------------------------------------------------- */
    int32_t corner = surface_request_for(6, TOP, 600, 440, 40, 40);
    fill(corner, BLUE);
    compositor_frame();
    CHECK(all(TOP, 600, 440, 40, 40, BLUE) && at(TOP, 599, 479) == 0 && at(TOP, 639, 439) == 0,
          "a surface in the bottom-right corner lands exactly there");
    surface_release(corner);
    compositor_frame();

    /* --- a full-screen surface: the cost of one copy --------------------- */
    int32_t whole = surface_request_for(7, TOP, 0, 0, 640, 480);
    fill(whole, RED);
    uint64_t t0 = platform_now_ns();
    for (int i = 0; i < 100; i++) {
        surface_mark_dirty(whole);
        compositor_frame();
    }
    uint64_t per = (platform_now_ns() - t0) / 100;
    CHECK(all(TOP, 0, 0, 640, 480, RED), "a whole screen's surface covers the whole screen");
    metric_record("compositor.full_screen_copy_us", (double)per / 1000.0, "us", "compositor",
                  "one frame copying a 640x480 surface onto the top screen (laptop time)");
    surface_release(whole);
    compositor_frame();

    /* --- the map, on its own timer --------------------------------------- */
    struct compositor comp;
    drawn_on = surface_request_for(8, BOTTOM, 200, 200, 20, 20);
    int p = compositor_start(&comp, &report);
    CHECK(p >= 0 && comp.timer >= 0, "the compositor map loads, brings up and is armed (%s)", report.text);
    CHECK(program_argument_count(p) == 1 && program_result_count(p) == 0 && program_station_count(p) == 2,
          "one argument door, the tick; no results; two stations");
    int32_t station = program_station(p, "composite");
    uint64_t first_ns = engine.timers[comp.timer].due_ns;
    pthread_t thread;
    pthread_create(&thread, NULL, draw, NULL);
    pthread_join(thread, NULL);
    sleep_ms(500);
    uint64_t stopped_ns = platform_now_ns();
    int timer = comp.timer;
    compositor_stop(&comp);
    CHECK(comp.timer == -1 && twin_engine_settle(10000), "stopping disarms it and every core goes to sleep");
    uint64_t frames = engine_station_runs(station);
    uint64_t missed = engine_timer_missed(timer);
    uint64_t came_due = (stopped_ns - first_ns) / COMPOSITOR_FRAME_NS + 1;
    CHECK(frames >= 20 && frames + missed + 1 >= came_due && frames + missed <= came_due + 1,
          "frames came at 60 Hz: %llu made and %llu skipped for the %llu that came due",
          (unsigned long long)frames, (unsigned long long)missed, (unsigned long long)came_due);
    CHECK(at(BOTTOM, 200, 200) == (0xFF000000u | STROKES),
          "the last thing drawn while the frames ran is on the screen (%08x)", at(BOTTOM, 200, 200));
    CHECK(engine_port_waiting(station, 1) == 1 && engine_port_waiting(station, 0) == 0,
          "only one frame number was ever on the loop, and it waits there for a restart");
    metric_record("compositor.frames_per_second", (double)frames * 1e9 / (double)(stopped_ns - first_ns),
                  "frames/s", "compositor", "frames the compositor map made per second, with a thread drawing");
    surface_release(drawn_on);
    CHECK(program_remove(p) == 0, "the program comes out");

    twin_engine_stop();
    metrics_close();
    CHECK_DONE("109 compositor");
}
