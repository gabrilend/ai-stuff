/*
 * 105-test-surfaces.c — issue 601: rectangles of a screen that one box
 * owns.
 *
 * General description: a surface is granted where nobody else holds any
 * of the rectangle, and refused where somebody does; the same owner may
 * stack its own; edges may touch; a rectangle not wholly on its screen is
 * refused. A released surface's rectangle is free again, and its handle
 * reaches nothing — not even what is granted in the same slot next.
 * Resizing keeps the pixels the two rectangles share and clears the rest;
 * moving and resizing are checked like a request and change nothing when
 * refused. Surfaces list back to front in the order granted; the table
 * fills and says so. Four threads asking for and letting go of
 * overlapping rectangles never hold the same pixel at once. And a surface
 * asked for by a box belongs to its station: another station cannot let
 * it go.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/engine/070-catalogue.h"
#include "../../src/system/104-surfaces.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "047-check.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <string.h>

#define CORES 4
#define TOP 0
#define BOTTOM 1

/* {{{ a box that asks for a surface, or lets one go */
static int64_t grab_fn(int64_t v)
{
    return v == 0 ? (int64_t)surface_request(BOTTOM, 600, 400, 20, 20) : (int64_t)surface_release((int32_t)v);
}
static void grab_call(const void *in, void *out)
{
    *(int64_t *)out = grab_fn(*(const int64_t *)in);
}
static const struct box_param grab_params[] = { { "v", "int64_t", 8, 0 } };
static const struct box grab_box = { "grab", __FILE__, grab_call, 1, grab_params, 8, 8, "int64_t" };
/* }}} */

/* {{{ the claim map, for the threads */
/* One cell per pixel of a 64×64 corner of the top screen: which owner a
 * grant says holds it, or 0. A grant that finds another owner's mark
 * would be two owners on one pixel. */
#define AREA 64
static _Atomic int32_t claim[AREA][AREA];
static _Atomic int     clashes;
static _Atomic int     grants;

static void *hammer(void *arg)
{
    int32_t owner = (int32_t)(intptr_t)arg;
    uint32_t seed = (uint32_t)owner * 2654435761u;
    for (int round = 0; round < 3000; round++) {
        seed = seed * 1664525u + 1013904223u;
        int x = (int)(seed >> 8) % (AREA - 16), y = (int)(seed >> 16) % (AREA - 16);
        int w = 4 + (int)(seed >> 4) % 12, h = 4 + (int)(seed >> 12) % 12;
        int32_t handle = surface_request_for(owner, TOP, x, y, w, h);
        if (handle <= 0) {
            continue;
        }
        atomic_fetch_add(&grants, 1);
        for (int r = y; r < y + h; r++) {
            for (int c = x; c < x + w; c++) {
                int32_t none = 0;
                if (!atomic_compare_exchange_strong(&claim[r][c], &none, owner) && none != owner) {
                    atomic_fetch_add(&clashes, 1);
                }
            }
        }
        for (int r = y; r < y + h; r++) {
            for (int c = x; c < x + w; c++) {
                int32_t mine = owner;
                atomic_compare_exchange_strong(&claim[r][c], &mine, 0);
            }
        }
        surface_release(handle);
    }
    return NULL;
}
/* }}} */

int main(void)
{
    twin_engine_start(CORES, (size_t)256 << 20);
    engine_open_gate();
    metrics_open("105-surfaces");
    struct map_report report;
    struct surface_facts f;

    /* --- granting and refusing ------------------------------------------- */
    int32_t a = surface_request_for(5, BOTTOM, 0, 0, 100, 50);
    CHECK(a > 0, "a rectangle nobody holds is granted (%d)", a);
    CHECK(surface_facts(a, &f) == SURFACE_OK && f.screen == BOTTOM && f.x == 0 && f.y == 0 &&
          f.width == 100 && f.height == 50 && f.owner == 5, "and is what was asked for");
    struct canvas c = surface_canvas(a);
    int clear = c.pixels && c.width == 100 && c.height == 50;
    for (int i = 0; clear && i < 100 * 50; i++) clear = c.pixels[i] == 0;
    CHECK(clear, "its pixels start clear");
    CHECK(surface_request_for(6, BOTTOM, 99, 49, 10, 10) == SURFACE_TAKEN, "one pixel of overlap with another owner is refused");
    int32_t a2 = surface_request_for(5, BOTTOM, 50, 25, 100, 50);
    CHECK(a2 > 0, "the same owner may stack its own surfaces");
    int32_t b = surface_request_for(6, BOTTOM, 150, 0, 10, 10);
    CHECK(b > 0, "a rectangle touching another owner's edge is granted");
    CHECK(surface_request_for(6, TOP, 0, 0, 100, 50) > 0, "the same rectangle on the other screen is someone else's to have");
    CHECK(surface_request_for(7, BOTTOM, 600, 0, 41, 10) == SURFACE_OFF_SCREEN &&
          surface_request_for(7, BOTTOM, -1, 0, 10, 10) == SURFACE_OFF_SCREEN &&
          surface_request_for(7, BOTTOM, 300, 300, 0, 10) == SURFACE_OFF_SCREEN &&
          surface_request_for(7, 2, 0, 0, 10, 10) == SURFACE_OFF_SCREEN,
          "past the edge, before it, empty, or on a third screen is refused");
    CHECK(surface_request_for(7, BOTTOM, 600, 440, 40, 40) > 0, "the bottom-right corner exactly is on the screen");

    /* --- back to front --------------------------------------------------- */
    int32_t list[SURFACE_MAX];
    int n = surface_list(BOTTOM, list, SURFACE_MAX);
    CHECK(n == 4 && list[0] == a && list[1] == a2 && list[2] == b, "surfaces list back to front, in the order granted (%d)", n);

    /* --- resize and move ------------------------------------------------- */
    c = surface_canvas(a);
    for (int y = 0; y < 50; y++) for (int x = 0; x < 100; x++) c.pixels[y * c.stride + x] = (uint32_t)(y * 1000 + x);
    CHECK(surface_resize(a, 160, 60) == SURFACE_TAKEN, "growing into another owner's rectangle is refused");
    CHECK(surface_canvas(a).width == 100 && surface_canvas(a).pixels == c.pixels, "and nothing changed");
    CHECK(surface_resize(a, 140, 80) == SURFACE_OK, "growing into free space is granted");
    struct canvas g = surface_canvas(a);
    int kept = g.width == 140 && g.height == 80;
    for (int y = 0; kept && y < 80; y++)
        for (int x = 0; kept && x < 140; x++)
            kept = g.pixels[y * g.stride + x] == ((y < 50 && x < 100) ? (uint32_t)(y * 1000 + x) : 0u);
    CHECK(kept, "the pixels it had are where they were, and the new ones are clear");
    CHECK(surface_resize(a, 30, 20) == SURFACE_OK && surface_canvas(a).pixels[19 * 30 + 29] == 19 * 1000 + 29,
          "shrinking keeps the top-left corner's pixels");
    CHECK(surface_set_position(b, 20, 10) == SURFACE_TAKEN, "moving onto another owner is refused");
    CHECK(surface_set_position(b, 635, 0) == SURFACE_OFF_SCREEN, "moving off the screen is refused");
    CHECK(surface_facts(b, &f) == SURFACE_OK && f.x == 150, "and neither moved it");
    CHECK(surface_set_position(b, 300, 200) == SURFACE_OK && surface_facts(b, &f) == SURFACE_OK && f.x == 300 && f.y == 200,
          "moving into free space is granted");

    /* --- release, and handles that outlive it ---------------------------- */
    CHECK(surface_release(a) == SURFACE_OK && surface_release(a2) == SURFACE_OK, "the owner lets both go");
    CHECK(surface_release(a) == SURFACE_NO_HANDLE && surface_resize(a, 10, 10) == SURFACE_NO_HANDLE &&
          surface_set_position(a, 0, 0) == SURFACE_NO_HANDLE && surface_canvas(a).pixels == NULL &&
          surface_facts(a, &f) == SURFACE_NO_HANDLE, "a released handle names nothing");
    int32_t again = surface_request_for(6, BOTTOM, 0, 0, 100, 50);
    CHECK(again > 0 && again != a && again != a2, "its rectangle is free for another owner, under a new handle");
    CHECK(surface_release(a) == SURFACE_NO_HANDLE && surface_facts(again, &f) == SURFACE_OK,
          "and the old handle does not reach the new surface in its slot");

    /* --- the table fills ------------------------------------------------- */
    int32_t many[SURFACE_MAX];
    int got = 0;
    for (int i = 0; i < SURFACE_MAX; i++) {
        int32_t h = surface_request_for(9, TOP, (i % 32) * 20, 300 + (i / 32) * 20, 10, 10);
        if (h > 0) many[got++] = h;
        else break;
    }
    CHECK(surface_request_for(9, TOP, 639, 479, 1, 1) == SURFACE_FULL, "once every slot is used, the next is refused as full (%d granted)", got);
    for (int i = 0; i < got; i++) surface_release(many[i]);
    CHECK(surface_request_for(9, TOP, 0, 300, 10, 10) > 0, "and letting them go makes room");

    /* --- four threads, overlapping rectangles ---------------------------- */
    /* Clear the corner the threads use. */
    n = surface_list(TOP, list, SURFACE_MAX);
    for (int i = 0; i < n; i++) {
        if (surface_facts(list[i], &f) == SURFACE_OK && f.x < AREA && f.y < AREA) surface_release(list[i]);
    }
    pthread_t threads[4];
    for (int t = 0; t < 4; t++) pthread_create(&threads[t], NULL, hammer, (void *)(intptr_t)(100 + t));
    for (int t = 0; t < 4; t++) pthread_join(threads[t], NULL);
    CHECK(atomic_load(&clashes) == 0 && atomic_load(&grants) > 100,
          "four threads asking and letting go never held one pixel between two owners (%d grants, %d clashes)",
          atomic_load(&grants), atomic_load(&clashes));
    metric_record("surfaces.threaded_grants", (double)atomic_load(&grants), "grants", "surfaces",
                  "surfaces granted to four threads asking for overlapping rectangles 3000 times each");

    /* --- a box owns what it asks for ------------------------------------- */
    CHECK(catalogue_add("src/boxes/999-surface.c:grab", &grab_box) == 0, "a box that asks for surfaces joins the catalogue");
    const char *map =
        "station owner (../boxes/999-surface.c:grab)\n"
        "  in 0 - 0$\n"
        "  out 0 - 0$\n"
        "station thief (../boxes/999-surface.c:grab)\n"
        "  in 0 - 1$\n"
        "  out 0 - 1$\n";
    int p = program_load_text("src/maps/surface-owner.map", map, strlen(map), &report);
    CHECK(p >= 0 && program_bring_up(p, &report) == 0, "a map of two of them loads (%s)", report.text);
    int64_t zero = 0, handle = 0, answer = 0;
    program_argument(p, 0, &zero, sizeof zero);
    twin_engine_settle(5000);
    CHECK(program_result(p, 0, &handle, sizeof handle) == 1 && handle > 0, "the first asks for a surface (%lld)", (long long)handle);
    CHECK(surface_facts((int32_t)handle, &f) == SURFACE_OK && f.owner == program_station(p, "owner"),
          "and it belongs to that station (%d)", f.owner);
    program_argument(p, 1, &handle, sizeof handle);
    twin_engine_settle(5000);
    CHECK(program_result(p, 1, &answer, sizeof answer) == 1 && answer == SURFACE_NOT_OWNER,
          "the other station cannot let it go (%lld)", (long long)answer);
    program_argument(p, 0, &handle, sizeof handle);
    twin_engine_settle(5000);
    CHECK(program_result(p, 0, &answer, sizeof answer) == 1 && answer == SURFACE_OK,
          "its own station can (%lld)", (long long)answer);

    twin_engine_stop();
    metrics_close();
    CHECK_DONE("105 surfaces");
}
