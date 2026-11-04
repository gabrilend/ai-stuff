/*
 * 114-test-drawers.c — issue 606: drawers sliding over a screen.
 *
 * General description: a drawer starts shut. Opened, it slides in from its
 * edge one step a frame and is open after six, each step showing the part
 * of it that is on the screen, from the right place in its own pixels; it
 * sits in its margins over the app's surface. While it is open, the
 * surface under it can be drawn and copied and the drawer stays on top,
 * and marking its own contents redraws it. Closed, it slides back out in
 * six frames, and afterwards the screen is exactly what it would be with
 * no drawer: the app's surface where it is, and the background where
 * nothing is. Turned round part way, it goes back from where it was. Two
 * drawers on one screen open side by side. And on the compositor's own
 * timer, a drawer opened and closed from another thread does the same.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/system/104-surfaces.h"
#include "../../src/system/107-compositor.h"
#include "../../src/system/113-drawers.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "047-check.h"

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

static int all(int screen, int x, int y, int w, int h, uint32_t colour)
{
    for (int r = y; r < y + h; r++)
        for (int c = x; c < x + w; c++)
            if (at(screen, c, r) != colour) return 0;
    return 1;
}

/* Frames until the drawer's state is `state`, up to 20. */
static int frames_until(int screen, int edge, int state)
{
    int n = 0;
    while (drawer_state(screen, edge) != state && n < 20) {
        compositor_frame();
        n++;
    }
    return n;
}
/* }}} */

int main(void)
{
    twin_engine_start(CORES, (size_t)256 << 20);
    engine_open_gate();
    metrics_open("114-drawers");
    struct map_report report;
    struct compositor_frame f;
    const uint32_t BLUE = 0xFF5A9AE6u, GREEN = 0xFF60C080u, AMBER = COLOUR_ACCENT;
    const uint32_t BG = COMPOSITOR_BACKGROUND, PANEL = COLOUR_PANEL, RULE = COLOUR_RULE;

    /* The app: a surface over the right of the bottom screen; the left is
     * background. */
    int32_t app = surface_request_for(5, BOTTOM, 150, 0, 490, 480);
    fill(app, BLUE);
    surface_expose(BOTTOM, 0, 0, 640, 480);
    surface_expose(TOP, 0, 0, 640, 480);
    compositor_frame();
    CHECK(all(BOTTOM, 0, 0, 150, 480, BG) && all(BOTTOM, 150, 0, 490, 480, BLUE), "the app's screen, with no drawer");

    /* --- shut ------------------------------------------------------------- */
    CHECK(drawer_state(BOTTOM, DRAWER_LEFT) == DRAWER_CLOSED && drawer_progress(BOTTOM, DRAWER_LEFT) == 0 &&
          drawer_rect(BOTTOM, DRAWER_LEFT).width == 0 && drawer_canvas(BOTTOM, DRAWER_LEFT).pixels == NULL,
          "a drawer starts shut, covering nothing, with no pixels yet");
    CHECK(drawer_open(2, DRAWER_LEFT) == DRAWER_NO_SUCH && drawer_open(BOTTOM, 2) == DRAWER_NO_SUCH &&
          drawer_state(-1, DRAWER_LEFT) == DRAWER_NO_SUCH, "there are four drawers and no more");

    /* --- opening ---------------------------------------------------------- */
    CHECK(drawer_open(BOTTOM, DRAWER_LEFT) == DRAWER_OK && drawer_state(BOTTOM, DRAWER_LEFT) == DRAWER_OPENING,
          "opening starts it sliding");
    struct canvas inside = drawer_canvas(BOTTOM, DRAWER_LEFT);
    CHECK(inside.pixels && inside.width == 256 && inside.height == 432,
          "its contents are 40%% of the screen wide and its height less 5%% top and bottom (%dx%d)",
          inside.width, inside.height);
    f = compositor_frame();
    struct surface_rect r = drawer_rect(BOTTOM, DRAWER_LEFT);
    CHECK(f.drawers == 1 && drawer_progress(BOTTOM, DRAWER_LEFT) == 1 && r.x == 0 && r.y == 24 && r.width == 48 &&
          r.height == 432, "one frame in, a sixth of the way: its last 48 columns show at the edge");
    CHECK(at(BOTTOM, 20, 240) == PANEL && at(BOTTOM, 47, 240) == RULE && at(BOTTOM, 48, 240) == BG &&
          at(BOTTOM, 20, 23) == BG && at(BOTTOM, 20, 456) == BG,
          "showing its right-hand edge, and nothing above, below or beside it");
    int opening = 1 + frames_until(BOTTOM, DRAWER_LEFT, DRAWER_OPEN);
    r = drawer_rect(BOTTOM, DRAWER_LEFT);
    CHECK(opening == DRAWER_SLIDE_FRAMES && r.x == 32 && r.width == 256,
          "it is open after six frames (%d), 5%% in from its edge", opening);
    CHECK(at(BOTTOM, 31, 240) == BG && at(BOTTOM, 32, 240) == RULE && at(BOTTOM, 100, 240) == PANEL &&
          at(BOTTOM, 200, 240) == PANEL && at(BOTTOM, 287, 240) == RULE && at(BOTTOM, 288, 240) == BLUE &&
          at(BOTTOM, 200, 23) == BLUE && at(BOTTOM, 200, 24) == RULE,
          "it sits in its margins, over the app where they overlap");
    f = compositor_frame();
    CHECK(f.copied == 0 && f.drawers == 0 && drawer_open(BOTTOM, DRAWER_LEFT) == DRAWER_OK &&
          drawer_state(BOTTOM, DRAWER_LEFT) == DRAWER_OPEN, "open and still, it is not drawn again; opening it again changes nothing");

    /* --- while open ------------------------------------------------------- */
    fill(app, GREEN);
    f = compositor_frame();
    CHECK(f.copied == 1 && f.drawers == 1 && at(BOTTOM, 200, 240) == PANEL && at(BOTTOM, 300, 240) == GREEN,
          "the app draws under it, and it stays on top");
    draw_rect(inside, 10, 10, 20, 20, AMBER);
    CHECK(drawer_mark_dirty(BOTTOM, DRAWER_LEFT) == DRAWER_OK && compositor_frame().drawers == 1 &&
          at(BOTTOM, 32 + 15, 24 + 15) == AMBER, "marking its contents redraws it");

    /* --- closing ---------------------------------------------------------- */
    CHECK(drawer_close(BOTTOM, DRAWER_LEFT) == DRAWER_OK && drawer_state(BOTTOM, DRAWER_LEFT) == DRAWER_CLOSING,
          "closing starts it sliding back");
    compositor_frame();
    CHECK(drawer_progress(BOTTOM, DRAWER_LEFT) == 5 && at(BOTTOM, 280, 240) == GREEN && at(BOTTOM, 200, 240) == PANEL,
          "a frame in, the app shows again where it has gone from");
    int closing = 1 + frames_until(BOTTOM, DRAWER_LEFT, DRAWER_CLOSED);
    CHECK(closing == DRAWER_SLIDE_FRAMES, "it is shut after six frames (%d)", closing);
    CHECK(all(BOTTOM, 0, 0, 150, 480, BG) && all(BOTTOM, 150, 0, 490, 480, GREEN),
          "and the screen is the app's again: its surface where it is, the background where nothing is");
    f = compositor_frame();
    CHECK(f.copied == 0 && f.painted == 0 && f.drawers == 0, "shut, it costs a frame nothing");

    /* --- turned round part way ------------------------------------------- */
    drawer_open(TOP, DRAWER_RIGHT);
    compositor_frame();
    compositor_frame();
    compositor_frame();
    r = drawer_rect(TOP, DRAWER_RIGHT);
    CHECK(drawer_progress(TOP, DRAWER_RIGHT) == 3 && r.x == 496 && r.width == 144 && at(TOP, 496, 240) == RULE && at(TOP, 500, 240) == PANEL,
          "the right-hand drawer comes in from the right: half way, its left half shows");
    drawer_close(TOP, DRAWER_RIGHT);
    compositor_frame();
    CHECK(drawer_progress(TOP, DRAWER_RIGHT) == 2, "closed part way, it goes back from where it was");
    CHECK(frames_until(TOP, DRAWER_RIGHT, DRAWER_CLOSED) == 2 && all(TOP, 0, 0, 640, 480, BG),
          "and is shut two frames later, leaving nothing behind");

    /* --- two at once ------------------------------------------------------ */
    drawer_open(TOP, DRAWER_LEFT);
    drawer_open(TOP, DRAWER_RIGHT);
    CHECK(frames_until(TOP, DRAWER_LEFT, DRAWER_OPEN) == DRAWER_SLIDE_FRAMES &&
          drawer_state(TOP, DRAWER_RIGHT) == DRAWER_OPEN, "two drawers on one screen open together");
    CHECK(at(TOP, 100, 240) == PANEL && at(TOP, 500, 240) == PANEL && at(TOP, 320, 240) == BG &&
          at(TOP, 352, 240) == RULE, "side by side, the middle between them clear");
    drawer_close(TOP, DRAWER_LEFT);
    drawer_close(TOP, DRAWER_RIGHT);
    frames_until(TOP, DRAWER_LEFT, DRAWER_CLOSED);
    CHECK(all(TOP, 0, 0, 640, 480, BG), "and both go");

    /* --- on the compositor's own timer ----------------------------------- */
    struct compositor comp;
    int p = compositor_start(&comp, &report);
    CHECK(p >= 0, "the compositor map starts (%s)", report.text);
    drawer_open(BOTTOM, DRAWER_RIGHT);
    sleep_ms(300);
    CHECK(drawer_state(BOTTOM, DRAWER_RIGHT) == DRAWER_OPEN && at(BOTTOM, 400, 240) == PANEL,
          "a drawer opened from another thread opens on the frames");
    drawer_close(BOTTOM, DRAWER_RIGHT);
    sleep_ms(300);
    compositor_stop(&comp);
    CHECK(twin_engine_settle(10000) && drawer_state(BOTTOM, DRAWER_RIGHT) == DRAWER_CLOSED &&
          all(BOTTOM, 0, 0, 150, 480, BG) && all(BOTTOM, 150, 0, 490, 480, GREEN),
          "and closes on them, leaving the app's screen as it was");
    program_remove(p);
    surface_release(app);

    twin_engine_stop();
    metrics_close();
    CHECK_DONE("114 drawers");
}
