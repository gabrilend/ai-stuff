/*
 * 106-test-damage.c — issue 602: the damage bit on a surface.
 *
 * General description: a surface starts marked, so its first frame shows
 * it; taking the mark answers it and clears it, and a second take finds
 * nothing. Marking twice is one mark. A resize or a move marks it again,
 * and a refused one does not. A handle that names nothing marks and takes
 * nothing — not even the next grant in its slot. And the order the bit
 * promises: three cores of one box write their own pixel of one surface
 * and mark after every write, while a compositor thread takes the mark
 * and copies; when the writers stop, one more take and copy shows every
 * core's last write. No mark made during a copy is lost.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/system/104-surfaces.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "047-check.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <string.h>

#define CORES   4
#define TOP     0
#define BOTTOM  1
#define WRITERS 3
#define WRITES  20000

/* {{{ the writers and the compositor */
static int32_t      shared;            /* the surface the threads use */
static uint32_t    *pixels;            /* its canvas */
static atomic_int   writers_left = WRITERS;
static atomic_int   marks;
static uint32_t     shown[WRITERS];    /* what the compositor last copied */
static int          copies, backwards;

static void *writer(void *arg)
{
    int me = (int)(intptr_t)arg;
    for (uint32_t k = 1; k <= WRITES; k++) {
        __atomic_store_n(&pixels[me], k, __ATOMIC_RELAXED);
        surface_mark_dirty(shared);
        atomic_fetch_add(&marks, 1);
    }
    atomic_fetch_sub(&writers_left, 1);
    return NULL;
}

static void copy_forward(void)
{
    for (int i = 0; i < WRITERS; i++) {
        uint32_t now = __atomic_load_n(&pixels[i], __ATOMIC_RELAXED);
        if (now < shown[i]) {
            backwards++;
        }
        shown[i] = now;
    }
    copies++;
}

static void *compositor(void *arg)
{
    (void)arg;
    while (atomic_load(&writers_left) > 0) {
        if (surface_take_dirty(shared) == 1) {
            copy_forward();
        }
    }
    /* The frame after the last write. */
    if (surface_take_dirty(shared) == 1) {
        copy_forward();
    }
    return NULL;
}
/* }}} */

int main(void)
{
    twin_engine_start(CORES, (size_t)256 << 20);
    engine_open_gate();
    metrics_open("106-damage");

    /* --- marked, taken, cleared ------------------------------------------ */
    int32_t a = surface_request_for(5, BOTTOM, 0, 0, 40, 30);
    CHECK(a > 0, "a surface is granted (%d)", a);
    CHECK(surface_is_dirty(a) == 1, "it starts marked, so its first frame shows it");
    CHECK(surface_is_dirty(a) == 1, "and looking does not clear it");
    CHECK(surface_take_dirty(a) == 1 && surface_take_dirty(a) == 0 && surface_is_dirty(a) == 0,
          "taking answers the mark and clears it; a second take finds nothing");
    CHECK(surface_mark_dirty(a) == SURFACE_OK && surface_mark_dirty(a) == SURFACE_OK &&
          surface_take_dirty(a) == 1 && surface_take_dirty(a) == 0, "marking twice is one mark");
    surface_mark_dirty(a);
    surface_take_dirty(a);
    surface_mark_dirty(a);
    CHECK(surface_take_dirty(a) == 1, "a mark made after a take is there for the next take");

    /* --- resize and move mark it ----------------------------------------- */
    int32_t b = surface_request_for(6, BOTTOM, 100, 0, 10, 10);
    surface_take_dirty(b);
    CHECK(surface_resize(a, 200, 30) == SURFACE_TAKEN && surface_set_position(a, 95, 0) == SURFACE_TAKEN &&
          surface_is_dirty(a) == 0, "a refused resize or move marks nothing");
    CHECK(surface_resize(a, 50, 30) == SURFACE_OK && surface_take_dirty(a) == 1, "a resize marks it");
    CHECK(surface_set_position(a, 0, 100) == SURFACE_OK && surface_take_dirty(a) == 1, "a move marks it");
    CHECK(surface_is_dirty(b) == 0, "and leaves the other owner's surface alone");

    /* --- handles that name nothing --------------------------------------- */
    CHECK(surface_release(a) == SURFACE_OK, "the owner lets it go");
    CHECK(surface_mark_dirty(a) == SURFACE_NO_HANDLE && surface_is_dirty(a) == SURFACE_NO_HANDLE &&
          surface_take_dirty(a) == SURFACE_NO_HANDLE, "its handle marks, reads and takes nothing");
    int32_t again = surface_request_for(7, BOTTOM, 0, 100, 50, 30);
    surface_take_dirty(again);
    surface_mark_dirty(a);
    CHECK(again > 0 && surface_is_dirty(again) == 0, "the old handle does not mark the next grant in its slot");
    CHECK(surface_mark_dirty(0) == SURFACE_NO_HANDLE && surface_take_dirty(-4) == SURFACE_NO_HANDLE,
          "nor does a handle that was never granted");
    surface_release(again);
    surface_release(b);

    /* --- three writers, one compositor ----------------------------------- */
    shared = surface_request_for(8, TOP, 0, 0, 64, 64);
    pixels = surface_canvas(shared).pixels;
    CHECK(shared > 0 && pixels, "one surface for the threads");
    pthread_t threads[WRITERS + 1];
    pthread_create(&threads[WRITERS], NULL, compositor, NULL);
    for (int t = 0; t < WRITERS; t++) pthread_create(&threads[t], NULL, writer, (void *)(intptr_t)t);
    for (int t = 0; t <= WRITERS; t++) pthread_join(threads[t], NULL);
    CHECK(shown[0] == WRITES && shown[1] == WRITES && shown[2] == WRITES,
          "after the writers stop, the last copy shows every core's last write (%u %u %u)",
          shown[0], shown[1], shown[2]);
    CHECK(backwards == 0, "and no copy ever showed a pixel older than one before it");
    CHECK(copies > 0 && copies <= atomic_load(&marks),
          "the compositor copied %d times for %d marks", copies, atomic_load(&marks));
    metric_record("damage.copies_per_mark", (double)copies / (double)atomic_load(&marks), "ratio", "surfaces",
                  "copies a compositor made per mark, three cores marking one surface after every write");
    surface_release(shared);

    twin_engine_stop();
    metrics_close();
    CHECK_DONE("106 damage");
}
