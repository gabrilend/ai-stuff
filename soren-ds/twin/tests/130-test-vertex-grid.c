/*
 * 130-test-vertex-grid.c — issue 1001: the modeller's vertex grid, over
 * the STAND-IN for 902's per-app memory.
 *
 * General description: first the stand-in itself — an app's budget is
 * kept, a request past it is refused, and what is given back is
 * counted. Then the grid: a vertex is placed, found, placed again
 * (nothing changes) and removed; every cell outside the cube is refused;
 * the whole cube fills and empties; a long run of random placements and
 * removals agrees, cell for cell, with a plain array of 32768 flags; a
 * walk sees every vertex once. A grid whose app has run out of memory
 * refuses the placement and is left as it was, and goes on once the
 * budget is raised. Freeing a grid gives every byte back; sixteen grids
 * is the most. Four threads placing into one grid at once lose nothing.
 * Last, the boxes and the map: vertex-grid.map answers through its doors,
 * on its own and placed inside another map as one station, and the
 * boxes' value types are the system's, size for size.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/engine/070-catalogue.h"
#include "../../src/engine/127-app-memory.h"
#include "../../src/system/128-vertex-grid.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "047-check.h"

#include <pthread.h>
#include <stdio.h>
#include <string.h>

#define CORES 4
#define SIDE VERTEX_GRID_SIDE

/* The boxes' layouts, written out again here: if 129 changes them, the
 * size checks below say so. */
struct cell        { int32_t grid, x, y, z; };
struct cell_answer { int32_t grid, x, y, z, answer, faces; };

/* {{{ a random stream of our own */
static uint64_t seed = 0x1001;
static uint32_t next_random(void)
{
    seed ^= seed << 13;
    seed ^= seed >> 7;
    seed ^= seed << 17;
    return (uint32_t)seed;
}
/* }}} */

/* {{{ agrees */
/* Does the grid hold exactly the cells `flags` marks? */
static int agrees(int grid, const uint8_t *flags)
{
    int expected = 0;
    for (int z = 0; z < SIDE; z++) {
        for (int y = 0; y < SIDE; y++) {
            for (int x = 0; x < SIDE; x++) {
                int want = flags[vertex_cell_key(x, y, z)];
                expected += want;
                if (vertex_grid_at(grid, x, y, z, NULL) != want) {
                    fprintf(stderr, "  cell %d,%d,%d: grid says %d, flags say %d\n", x, y, z, !want, want);
                    return 0;
                }
            }
        }
    }
    return vertex_grid_count(grid) == expected;
}
/* }}} */

/* {{{ walk_agrees */
/* Does a walk of the grid see every marked cell once and nothing else? */
static int walk_agrees(int grid, const uint8_t *flags)
{
    static uint8_t seen[VERTEX_GRID_CELLS];
    static struct vertex page[100];
    memset(seen, 0, sizeof seen);
    int total = 0, start = 0, n;
    while ((n = vertex_grid_list(grid, start, page, 100)) > 0) {
        for (int i = 0; i < n; i++) {
            uint32_t k = vertex_cell_key(page[i].x, page[i].y, page[i].z);
            if (seen[k] || !flags[k] || page[i].first_face != VERTEX_NO_FACE || page[i].face_count != 0) {
                return 0;
            }
            seen[k] = 1;
        }
        total += n;
        start += n;
    }
    return total == vertex_grid_count(grid);
}
/* }}} */

/* {{{ four placers */
struct placer { int grid; int z0; int placed; };

static void *place_slab(void *arg)
{
    struct placer *p = arg;
    for (int z = p->z0; z < p->z0 + SIDE / 4; z++) {
        for (int y = 0; y < SIDE; y++) {
            for (int x = 0; x < SIDE; x++) {
                p->placed += vertex_grid_place(p->grid, x, y, z) == VERTEX_PLACED;
            }
        }
    }
    return NULL;
}
/* }}} */

/* {{{ ask */
/* Put `c` in at door `door` of `program` and take its answer. */
static int ask(int program, int door, struct cell c, struct cell_answer *out)
{
    program_argument(program, door, &c, sizeof c);
    twin_engine_settle(2000);
    return program_result(program, door, out, sizeof *out);
}
/* }}} */

int main(void)
{
    twin_engine_start(CORES, (size_t)512 << 20);
    engine_open_gate();
    metrics_open("130-vertex-grid");

    /* --- the stand-in: an app's memory and its budget ------------------- */
    enum { A = 3, B = 4, C = 5 };
    CHECK(app_memory_limit(A) == APP_MEMORY_DEFAULT_LIMIT && app_memory_held(A) == 0,
          "an app starts with nothing held and the default budget");
    app_memory_set_limit(A, 10000);
    uint8_t *m1 = app_memory_alloc(A, 6000);
    CHECK(m1 && m1[0] == 0 && m1[5999] == 0 && app_memory_held(A) == 6000, "6000 bytes come zeroed, and are counted");
    CHECK(app_memory_alloc(A, 5000) == NULL && app_memory_counts(A).refused == 1,
          "5000 more would pass the 10000-byte budget, and are refused");
    uint8_t *m2 = app_memory_alloc(A, 4000);
    CHECK(m2 && app_memory_held(A) == 10000, "4000 more fill it exactly");
    app_memory_free(A, m1, 6000);
    app_memory_free(A, m2, 4000);
    CHECK(app_memory_held(A) == 0 && app_memory_counts(A).given_back == 2, "both are given back");
    CHECK(app_memory_alloc(-1, 16) == NULL && app_memory_alloc(APP_MEMORY_APPS, 16) == NULL,
          "there is no app below 0 or past the last");

    /* --- one vertex ------------------------------------------------------ */
    int g = vertex_grid_alloc(B);
    CHECK(g >= 0 && vertex_grid_app(g) == B && vertex_grid_count(g) == 0, "a new grid is empty and its memory is app B's");
    CHECK(app_memory_held(B) == vertex_grid_bytes(g) && app_memory_held(B) > 0,
          "app B holds exactly the grid's bytes (%zu, %zu)", app_memory_held(B), vertex_grid_bytes(g));
    CHECK(vertex_grid_place(g, 3, 4, 5) == VERTEX_PLACED, "a vertex is placed at 3,4,5");
    struct vertex v;
    memset(&v, 0x55, sizeof v);
    CHECK(vertex_grid_at(g, 3, 4, 5, &v) == 1 && v.x == 3 && v.y == 4 && v.z == 5 &&
          v.first_face == VERTEX_NO_FACE && v.face_count == 0,
          "and is found there, with no faces yet");
    CHECK(vertex_grid_at(g, 5, 4, 3, NULL) == 0, "5,4,3 is still empty: the coordinates are not mixed up");
    CHECK(vertex_grid_place(g, 3, 4, 5) == VERTEX_UNCHANGED && vertex_grid_count(g) == 1,
          "placing it again changes nothing");
    CHECK(vertex_grid_remove(g, 3, 4, 5) == VERTEX_PLACED && vertex_grid_at(g, 3, 4, 5, NULL) == 0 && vertex_grid_count(g) == 0,
          "removing it empties the cell");
    CHECK(vertex_grid_remove(g, 3, 4, 5) == VERTEX_UNCHANGED, "removing it again changes nothing");

    int refused = 0;
    const int bad[] = { -1, SIDE, SIDE + 100, -1000 };
    for (int i = 0; i < 4; i++) {
        refused += vertex_grid_place(g, bad[i], 0, 0) == VERTEX_OUTSIDE;
        refused += vertex_grid_place(g, 0, bad[i], 0) == VERTEX_OUTSIDE;
        refused += vertex_grid_place(g, 0, 0, bad[i]) == VERTEX_OUTSIDE;
        refused += vertex_grid_remove(g, 0, 0, bad[i]) == VERTEX_OUTSIDE;
        refused += vertex_grid_at(g, bad[i], bad[i], 0, NULL) == VERTEX_OUTSIDE;
    }
    CHECK(refused == 20 && vertex_grid_count(g) == 0, "every cell outside the 32-cube is refused, on every axis (%d of 20)", refused);
    CHECK(vertex_grid_place(g, 31, 31, 31) == VERTEX_PLACED && vertex_grid_place(g, 0, 0, 0) == VERTEX_PLACED,
          "both far corners are inside");
    CHECK(vertex_grid_place(-1, 0, 0, 0) == VERTEX_NO_GRID && vertex_grid_place(VERTEX_GRID_MAX, 0, 0, 0) == VERTEX_NO_GRID &&
          vertex_grid_at(g + 1, 0, 0, 0, NULL) == VERTEX_NO_GRID,
          "a grid that does not exist answers so");

    /* --- the whole cube, in and out ------------------------------------- */
    static uint8_t flags[VERTEX_GRID_CELLS];
    memset(flags, 0, sizeof flags);
    vertex_grid_remove(g, 31, 31, 31);
    vertex_grid_remove(g, 0, 0, 0);
    int placed = 0;
    for (int z = 0; z < SIDE; z++) {
        for (int y = 0; y < SIDE; y++) {
            for (int x = 0; x < SIDE; x++) {
                placed += vertex_grid_place(g, x, y, z) == VERTEX_PLACED;
                flags[vertex_cell_key(x, y, z)] = 1;
            }
        }
    }
    CHECK(placed == VERTEX_GRID_CELLS && vertex_grid_count(g) == VERTEX_GRID_CELLS, "every one of the 32768 cells takes a vertex");
    CHECK(agrees(g, flags), "and every one is found");
    CHECK(vertex_grid_bytes(g) == (size_t)VERTEX_GRID_CELLS * sizeof(struct vertex) + (size_t)2 * VERTEX_GRID_CELLS * 2,
          "a full cube takes 384 KB of vertices and 128 KB of slots (%zu)", vertex_grid_bytes(g));
    CHECK(app_memory_held(B) == vertex_grid_bytes(g), "and app B holds exactly that, nothing left over from growing");
    CHECK(walk_agrees(g, flags), "a walk of the full cube sees each vertex once");
    int removed = 0;
    for (int k = VERTEX_GRID_CELLS - 1; k >= 0; k -= 2) {
        removed += vertex_grid_remove(g, k & 31, (k >> 5) & 31, k >> 10) == VERTEX_PLACED;
        flags[k] = 0;
    }
    CHECK(removed == VERTEX_GRID_CELLS / 2 && agrees(g, flags), "removing every other cell leaves exactly the rest");

    /* --- a long random run against a plain array ------------------------ */
    int mismatches = 0;
    for (int i = 0; i < 400000; i++) {
        uint32_t r = next_random();
        int x = r & 31, y = (r >> 5) & 31, z = (r >> 10) & 31;
        uint32_t k = vertex_cell_key(x, y, z);
        /* Mostly removals for a while, then mostly placements, so the
         * grid runs from nearly empty to nearly full and back. */
        int phase = (i / 50000) & 1;
        int placing = ((r >> 16) % 10) < (phase ? 8 : 2);
        int got = placing ? vertex_grid_place(g, x, y, z) : vertex_grid_remove(g, x, y, z);
        int want = placing ? !flags[k] : flags[k];
        flags[k] = (uint8_t)placing;
        mismatches += got != want;
        if (i % 100000 == 99999) {
            mismatches += !agrees(g, flags);
        }
    }
    CHECK(mismatches == 0, "400000 random placements and removals agree with a plain array of flags (%d mismatches)", mismatches);
    CHECK(walk_agrees(g, flags), "and a walk still sees each vertex once");

    CHECK(vertex_grid_free(g) == 0 && app_memory_held(B) == 0, "freeing the grid gives every byte back to app B");
    CHECK(vertex_grid_place(g, 1, 1, 1) == VERTEX_NO_GRID && vertex_grid_free(g) == VERTEX_NO_GRID,
          "and a freed grid answers that it is not there");

    /* --- a grid that cannot grow ---------------------------------------- */
    app_memory_set_limit(C, 2048);
    int small = vertex_grid_alloc(C);
    CHECK(small >= 0, "a grid fits in a 2048-byte budget to begin with");
    int i = 0;
    int answer = VERTEX_PLACED;
    for (; i < 200 && answer == VERTEX_PLACED; i++) {
        answer = vertex_grid_place(small, i % SIDE, i / SIDE, 7);
    }
    int stopped_at = i - 1;
    CHECK(answer == VERTEX_NO_MEMORY && stopped_at > 0, "it refuses a placement it has no memory to grow for (after %d)", stopped_at);
    CHECK(vertex_grid_count(small) == stopped_at && vertex_grid_at(small, 0, 0, 7, NULL) == 1 &&
          vertex_grid_at(small, (stopped_at - 1) % SIDE, (stopped_at - 1) / SIDE, 7, NULL) == 1 &&
          vertex_grid_at(small, stopped_at % SIDE, stopped_at / SIDE, 7, NULL) == 0,
          "and is left exactly as it was");
    CHECK(app_memory_held(C) == vertex_grid_bytes(small), "the failed growth left nothing held");
    app_memory_set_limit(C, APP_MEMORY_DEFAULT_LIMIT);
    CHECK(vertex_grid_place(small, stopped_at % SIDE, stopped_at / SIDE, 7) == VERTEX_PLACED &&
          vertex_grid_count(small) == stopped_at + 1,
          "with its budget raised, the same placement goes in");
    vertex_grid_free(small);

    int many[VERTEX_GRID_MAX + 1];
    int made = 0;
    for (int n = 0; n < VERTEX_GRID_MAX; n++) {
        many[n] = vertex_grid_alloc(C);
        made += many[n] >= 0;
    }
    many[VERTEX_GRID_MAX] = vertex_grid_alloc(C);
    CHECK(made == VERTEX_GRID_MAX && many[VERTEX_GRID_MAX] == VERTEX_NO_GRID, "sixteen grids at once, and a seventeenth is refused");
    vertex_grid_free(many[5]);
    CHECK(vertex_grid_alloc(C) == many[5], "a freed grid's number is used again");
    for (int n = 0; n < VERTEX_GRID_MAX; n++) {
        vertex_grid_free(many[n]);
    }
    CHECK(app_memory_held(C) == 0, "and when all sixteen are freed, app C holds nothing");

    /* --- four at once ---------------------------------------------------- */
    int shared = vertex_grid_alloc(A);
    app_memory_set_limit(A, APP_MEMORY_DEFAULT_LIMIT);
    pthread_t threads[4];
    struct placer placers[4];
    for (int t = 0; t < 4; t++) {
        placers[t] = (struct placer){ shared, t * (SIDE / 4), 0 };
        pthread_create(&threads[t], NULL, place_slab, &placers[t]);
    }
    for (int t = 0; t < 4; t++) {
        pthread_join(threads[t], NULL);
    }
    memset(flags, 1, sizeof flags);
    CHECK(placers[0].placed + placers[1].placed + placers[2].placed + placers[3].placed == VERTEX_GRID_CELLS &&
          agrees(shared, flags),
          "four threads filling one grid at once, growing it as they go, lose nothing");
    vertex_grid_free(shared);

    /* --- the boxes and the map ------------------------------------------ */
    const struct box *place = catalogue_box("src/boxes/129-vertex-grid.c:place_vertex");
    CHECK(place && place->n_params == 1 && place->params[0].size == sizeof(struct cell) &&
          place->return_size == sizeof(struct cell_answer),
          "place_vertex takes a 16-byte cell and answers a 24-byte answer");

    struct map_report report;
    int prog = program_load("src/maps/vertex-grid.map", &report);
    CHECK(prog >= 0 && program_bring_up(prog, &report) == 0, "vertex-grid.map loads and brings up (%s)", report.text);
    CHECK(program_argument_count(prog) == 3 && program_result_count(prog) == 3, "with three doors in and three out");
    int mg = vertex_grid_alloc(prog < APP_MEMORY_APPS ? prog : 0);
    struct cell_answer a;
    memset(&a, 0, sizeof a);
    CHECK(ask(prog, 0, (struct cell){ mg, 1, 2, 3 }, &a) == 1 && a.answer == VERTEX_PLACED &&
          a.grid == mg && a.x == 1 && a.y == 2 && a.z == 3,
          "door 0 places a vertex and answers with the cell (%d)", a.answer);
    CHECK(vertex_grid_at(mg, 1, 2, 3, NULL) == 1, "and the vertex is in the grid");
    CHECK(ask(prog, 2, (struct cell){ mg, 1, 2, 3 }, &a) == 1 && a.answer == 1 && a.faces == 0, "door 2 finds it");
    CHECK(ask(prog, 1, (struct cell){ mg, 1, 2, 3 }, &a) == 1 && a.answer == VERTEX_PLACED, "door 1 removes it");
    CHECK(ask(prog, 2, (struct cell){ mg, 1, 2, 3 }, &a) == 1 && a.answer == 0, "door 2 finds the cell empty");
    CHECK(ask(prog, 0, (struct cell){ mg, 40, 2, 3 }, &a) == 1 && a.answer == VERTEX_OUTSIDE, "door 0 refuses a cell outside the cube");

    /* A modeller's map places the grid as one station. This map lives in
     * tmp/shared-memory/, so its address climbs two levels. */
    const char *modeller =
        "station grid (../../src/maps/vertex-grid.map)\n"
        "  in 0 - 0$\n"
        "  in 1 - 1$\n"
        "  in 2 - 2$\n"
        "  out 0 - 0$\n"
        "  out 1 - 1$\n"
        "  out 2 - 2$\n";
    int outer = program_load_text("tmp/shared-memory/modeller.map", modeller, strlen(modeller), &report);
    CHECK(outer >= 0 && program_bring_up(outer, &report) == 0 && program_child_count(outer) == 1,
          "a map that places vertex-grid.map as one station loads (%s)", report.text);
    CHECK(ask(outer, 0, (struct cell){ mg, 9, 9, 9 }, &a) == 1 && a.answer == VERTEX_PLACED &&
          vertex_grid_at(mg, 9, 9, 9, NULL) == 1,
          "and places a vertex through the inner program's doors (%d: %d %d,%d,%d)", a.answer, a.grid, a.x, a.y, a.z);
    CHECK(ask(outer, 2, (struct cell){ mg, 9, 9, 9 }, &a) == 1 && a.answer == 1, "and finds it");
    vertex_grid_free(mg);

    metrics_close();
    twin_engine_stop();
    CHECK_DONE("130-vertex-grid");
}
