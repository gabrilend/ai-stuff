/*
 * 112-test-foreground.c — issue 604: one foreground app per screen.
 *
 * General description: two apps (two loaded programs) each hold the same
 * rectangle of the bottom screen, which they may, as each app has the
 * screen to itself; two stations of one app may not, nor two owners no
 * program placed, as before. Until a foreground is set, the screen shows
 * the surfaces of owners no program placed, and neither app. Making an app
 * the foreground shows its surfaces and paints out the rest; the app in
 * the background keeps drawing, and when it comes back it shows what it
 * drew meanwhile. Setting the same foreground again does nothing. The
 * system's surfaces show whichever app is in front. And the event boxes:
 * a tracker placed in a map hears of each change once, with the app
 * before and after, and of nothing when nothing changed.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/system/104-surfaces.h"
#include "../../src/system/107-compositor.h"
#include "../../src/system/110-foreground.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "047-check.h"

#include <stdio.h>
#include <string.h>

#define CORES  4
#define TOP    0
#define BOTTOM 1

/* {{{ helpers */
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

/* An app: a program of two stations that do nothing but exist. */
static int load_app(const char *path, struct map_report *report)
{
    const char *map =
        "station one (../boxes/062-arithmetic.c:pass)\n"
        "  in 0 - 0$\n"
        "  out 0 - 0$\n"
        "station two (../boxes/062-arithmetic.c:pass)\n"
        "  in 0 - 1$\n"
        "  out 0 - 1$\n";
    int p = program_load_text(path, map, strlen(map), report);
    return p >= 0 && program_bring_up(p, report) == 0 ? p : -1;
}

struct change {
    int64_t changed, screen, from, to;
};
/* }}} */

int main(void)
{
    twin_engine_start(CORES, (size_t)256 << 20);
    engine_open_gate();
    metrics_open("112-foreground");
    struct map_report report;
    struct compositor_frame f;
    const uint32_t RED = 0xFFE06060u, BLUE = 0xFF5A9AE6u, GREEN = 0xFF60C080u, AMBER = 0xFFE0A040u;
    const uint32_t BG = COMPOSITOR_BACKGROUND;

    /* --- apps ------------------------------------------------------------- */
    int pa = load_app("src/maps/app-a.map", &report);
    int pb = load_app("src/maps/app-b.map", &report);
    CHECK(pa >= 0 && pb >= 0, "two apps load (%s)", report.text);
    int32_t a1 = program_station(pa, "one"), a2 = program_station(pa, "two"), b1 = program_station(pb, "one");
    CHECK(program_app_of(a1) == pa && program_app_of(a2) == pa && program_app_of(b1) == pb,
          "a station's app is the program that placed it");
    CHECK(program_app_of(-1) == -1 && program_app_of(1 << 30) == -1, "and no station has none");
    CHECK(surface_app_of(SURFACE_SYSTEM) == SURFACE_APP_SYSTEM && surface_app_of(5) == SURFACE_APP_NONE &&
          surface_app_of(a1) == pa, "an owner's app: the system's, none, or its program");

    /* --- who may hold what ----------------------------------------------- */
    int32_t sa = surface_request_for(a1, BOTTOM, 100, 100, 200, 100);
    int32_t sb = surface_request_for(b1, BOTTOM, 100, 100, 200, 100);
    CHECK(sa > 0 && sb > 0, "two apps may hold the same rectangle of one screen");
    CHECK(surface_request_for(a2, BOTTOM, 150, 150, 10, 10) == SURFACE_TAKEN,
          "two stations of one app may not");
    int32_t loose = surface_request_for(5, BOTTOM, 0, 0, 50, 50);
    CHECK(loose > 0 && surface_request_for(6, BOTTOM, 40, 40, 20, 20) == SURFACE_TAKEN,
          "nor two owners that no program placed");
    int32_t sys = surface_request_for(SURFACE_SYSTEM, BOTTOM, 280, 180, 40, 40);
    CHECK(sys > 0, "the system may hold a rectangle over an app's");
    struct surface_facts facts;
    CHECK(surface_facts(sa, &facts) == SURFACE_OK && facts.app == pa, "and a surface knows its app");
    fill(sa, RED);
    fill(sb, BLUE);
    fill(loose, GREEN);
    fill(sys, AMBER);

    /* --- no foreground yet ----------------------------------------------- */
    CHECK(screen_get_foreground(BOTTOM) == SURFACE_APP_NONE && screen_get_foreground(TOP) == SURFACE_APP_NONE,
          "until one is set, a screen's foreground is the owners no program placed");
    compositor_frame();
    CHECK(all(BOTTOM, 0, 0, 50, 50, GREEN) && all(BOTTOM, 280, 180, 40, 40, AMBER) && at(BOTTOM, 150, 150) != RED &&
          at(BOTTOM, 150, 150) != BLUE, "so those show, and the system's, and neither app");

    /* --- one app, then the other ----------------------------------------- */
    CHECK(screen_set_foreground(BOTTOM, pa) == SURFACE_OK && screen_get_foreground(BOTTOM) == pa,
          "app a becomes the bottom screen's foreground");
    compositor_frame();
    CHECK(all(BOTTOM, 100, 100, 180, 100, RED) && all(BOTTOM, 0, 0, 50, 50, BG) && at(BOTTOM, 290, 190) == AMBER,
          "its surface shows, the loose one is painted out, the system's stays on top");
    CHECK(screen_get_foreground(TOP) == SURFACE_APP_NONE, "the top screen's foreground is its own");
    fill(sb, 0xFF000000u | 7);
    CHECK(compositor_frame().copied == 0 && at(BOTTOM, 150, 150) == RED,
          "app b draws in the background and nothing of it shows");
    CHECK(screen_set_foreground(BOTTOM, pb) == SURFACE_OK, "app b comes to the front");
    f = compositor_frame();
    CHECK(all(BOTTOM, 100, 100, 180, 100, 0xFF000000u | 7) && at(BOTTOM, 290, 190) == AMBER && f.painted == 1,
          "showing what it drew while it was behind, with the system's still on top");
    CHECK(screen_set_foreground(BOTTOM, pb) == SURFACE_OK && compositor_frame().painted == 0,
          "setting the same foreground again paints nothing");
    CHECK(screen_set_foreground(2, pa) == SURFACE_OFF_SCREEN && screen_get_foreground(2) == SURFACE_APP_NONE,
          "there is no third screen");
    CHECK(surface_release(sa) == SURFACE_OK && compositor_frame().painted == 1 &&
          all(BOTTOM, 100, 100, 180, 100, 0xFF000000u | 7),
          "a background app letting its surface go leaves the foreground's alone");

    /* --- the event boxes -------------------------------------------------- */
    const char *watch =
        "boxes = ../boxes/\n"
        "station start (boxes/111-foreground.c:foreground_start)\n"
        "  in 0 = { 1, -2, -2 }\n"
        "  out 0 - track.1\n"
        "station track (boxes/111-foreground.c:foreground_track)\n"
        "  in 0 - 0$\n"
        "  in 1 - start.0\n"
        "  in 1 - track.0\n"
        "  out 0 - track.1\n"
        "  out 0 - changed.0\n"
        "comparator changed (boxes/111-foreground.c:foreground_changed)\n"
        "  in 0 - track.0\n"
        "  in 1 = { 0, 0, 0, 0 }\n"
        "  out 2 - 0$\n";
    int pw = program_load_text("src/maps/foreground-watch.map", watch, strlen(watch), &report);
    CHECK(pw >= 0 && program_bring_up(pw, &report) == 0, "a map watching the bottom screen loads (%s)", report.text);
    int64_t tick = 1;
    struct change c;
    program_argument(pw, 0, &tick, sizeof tick);
    twin_engine_settle(5000);
    CHECK(program_result(pw, 0, &c, sizeof c) == 1 && c.changed == 1 && c.screen == 1 && c.from == SURFACE_APP_NONE &&
          c.to == pb, "the first tick tells it the foreground it starts with (%lld to %lld)", (long long)c.from,
          (long long)c.to);
    program_argument(pw, 0, &tick, sizeof tick);
    twin_engine_settle(5000);
    CHECK(program_result(pw, 0, &c, sizeof c) == 0, "a tick with no change says nothing");
    screen_set_foreground(TOP, pa);
    program_argument(pw, 0, &tick, sizeof tick);
    twin_engine_settle(5000);
    CHECK(program_result(pw, 0, &c, sizeof c) == 0, "nor does a change on the other screen");
    screen_set_foreground(BOTTOM, pa);
    program_argument(pw, 0, &tick, sizeof tick);
    twin_engine_settle(5000);
    CHECK(program_result(pw, 0, &c, sizeof c) == 1 && c.changed == 1 && c.from == pb && c.to == pa,
          "a change is told once, with the app before and after (%lld to %lld)", (long long)c.from, (long long)c.to);
    program_argument(pw, 0, &tick, sizeof tick);
    twin_engine_settle(5000);
    CHECK(program_result(pw, 0, &c, sizeof c) == 0, "and not again");

    twin_engine_stop();
    metrics_close();
    CHECK_DONE("112 foreground");
}
