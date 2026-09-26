/*
 * 052-test-station-table.c — issue 207, and the growth half of 208.
 *
 * General description: stations are placed until the table has grown
 * several shelves, and every station's record is checked to still be at
 * the address it was first given. One input of a two-input station is
 * flooded until its port has grown many pages, and again no station has
 * moved; then the other input catches up and every pair is summed. Four
 * cores place stations at once from inside boxes and no two get the same
 * number. A removed place is refused while it is waiting to be reclaimed,
 * reused after, and removing a station while values are flowing into it
 * leaves the rest of the program running.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/038-starter-boxes.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "047-check.h"
#include "050-test-boxes.h"

#include <stdatomic.h>

#define CORES 4
#define PLACERS 4
#define PER_PLACER 300

static _Atomic int32_t placed_by_boxes[PLACERS * PER_PLACER];
static _Atomic int placed_count;
static _Atomic int place_failures;

/* {{{ placer */
/* A box that places stations — legal: a program may build a program. */
static int64_t placer_fn(int64_t n)
{
    for (int64_t i = 0; i < n; i++) {
        int32_t s = engine_place(&box_pass, "placed-by-a-box", KIND_PLAIN, 1);
        if (s < 0) {
            atomic_fetch_add(&place_failures, 1);
            continue;
        }
        placed_by_boxes[atomic_fetch_add(&placed_count, 1)] = s;
    }
    return n;
}
static void placer_call(const void *in, void *out) { *(int64_t *)out = placer_fn(*(const int64_t *)in); }
static const struct box_param placer_params[] = { { "n", "int64_t", 8, 0 } };
static const struct box placer = { "placer", __FILE__, placer_call, 1, placer_params, 8, 8, "int64_t" };
/* }}} */

/* {{{ compare_ints */
static int compare_ints(const void *a, const void *b)
{
    int32_t x = *(const int32_t *)a, y = *(const int32_t *)b;
    return (x > y) - (x < y);
}
/* }}} */

int main(void)
{
    twin_engine_start(CORES, (size_t)512 << 20);
    engine_open_gate();
    metrics_open("052-station-table");

    /* --- growth moves nothing ----------------------------------------- */
    enum { FIRST = 200 };
    int32_t first[FIRST];
    struct station *where[FIRST];
    for (int i = 0; i < FIRST; i++) {
        first[i] = PLACE(box_pass, "early", KIND_PLAIN, 1);
        where[i] = station_at(first[i]);
    }
    for (int i = 0; i < 1000; i++) {
        PLACE(box_pass, "later", KIND_PLAIN, 1);
    }
    int moved = 0;
    for (int i = 0; i < FIRST; i++) {
        moved += station_at(first[i]) != where[i];
    }
    CHECK(moved == 0, "adding %d shelves moved no station (%d moved)", 1000 / STATIONS_PER_SHELF, moved);

    /* --- flooding one port grows it, and still moves nothing ----------- */
    int32_t sink = PLACE(box_discard, "pair-sink", KIND_PLAIN, 0);
    int32_t pair = PLACE(box_add, "pair", KIND_PLAIN, 1);
    MUST(engine_wire(pair, 0, ONE_WIRE(sink, 0)));
    MUST(configure_ring(sink, 0));
    MUST(configure_ring(pair, 0));
    MUST(configure_ring(pair, 1));
    const int FLOOD = 5000;
    int64_t expect_sum = 0;
    for (int i = 0; i < FLOOD; i++) {
        int64_t v = i;
        MUST(engine_deliver(pair, 0, &v, sizeof v));
        expect_sum += i;
    }
    CHECK(twin_engine_settle(2000), "settled after the flood");
    struct station *ps = station_at(pair);
    uint64_t growths = ps->ports[0].growths;
    int cells_per_page = ps->ports[0].cells_per_page;
    int expected_growths = (FLOOD + cells_per_page - 1) / cells_per_page - 1;
    CHECK((int)growths == expected_growths, "port 0 grew %llu pages for %d waiting values at %d per page (expected %d)",
          (unsigned long long)growths, FLOOD, cells_per_page, expected_growths);
    CHECK(engine_station_runs(pair) == 0, "no run while only one side had values");
    moved = 0;
    for (int i = 0; i < FIRST; i++) {
        moved += station_at(first[i]) != where[i];
    }
    CHECK(moved == 0 && station_at(pair) == ps, "port growth moved no station");
    for (int i = 0; i < FLOOD; i++) {
        int64_t v = 1000000;
        MUST(engine_deliver(pair, 1, &v, sizeof v));
        expect_sum += 1000000;
    }
    CHECK(twin_engine_settle(4000), "settled after the other side caught up");
    uint64_t count; int64_t sum;
    starter_discard_tally(sink, &count, &sum);
    CHECK(count == (uint64_t)FLOOD && sum == expect_sum, "every pair ran once and summed right (%llu runs)",
          (unsigned long long)count);
    metric_record("ports.cells_per_page.int64", cells_per_page, "cells", "ports-depth",
                  "how many 8-byte values one port page holds (its starting depth)");
    metric_record("ports.growths_for_5000_unmatched", (double)growths, "pages", "ports-growth",
                  "pages a port added while 5000 values waited for their partners");

    /* --- four cores placing at once ------------------------------------ */
    int32_t placers[PLACERS];
    for (int p = 0; p < PLACERS; p++) {
        placers[p] = PLACE(placer, "placer", KIND_PLAIN, 1);
    }
    for (int p = 0; p < PLACERS; p++) {
        MUST(configure_static(placers[p], 0, PER_PLACER));
    }
    CHECK(twin_engine_settle(4000), "placement from four cores settled");
    int total = atomic_load(&placed_count);
    CHECK(total == PLACERS * PER_PLACER && atomic_load(&place_failures) == 0,
          "all %d placements succeeded (%d, %d failures)", PLACERS * PER_PLACER, total, atomic_load(&place_failures));
    int32_t sorted[PLACERS * PER_PLACER];
    for (int i = 0; i < total; i++) sorted[i] = placed_by_boxes[i];
    qsort(sorted, (size_t)total, sizeof sorted[0], compare_ints);
    int dupes = 0;
    for (int i = 1; i < total; i++) dupes += sorted[i] == sorted[i - 1];
    CHECK(dupes == 0, "no two stations placed at once shared an index (%d did)", dupes);

    /* --- a removed place: refused until reclaimed, then reused ---------- */
    int32_t doomed = PLACE(box_pass, "doomed", KIND_PLAIN, 1);
    MUST(engine_remove(doomed));
    /* The outside caller was inside its own engine call when it filed the
     * station, so its own sweep could not free it: still waiting. */
    CHECK(engine_place_at(doomed, &box_pass, "too-soon", KIND_PLAIN, 1) == ENGINE_PLACE_BUSY,
          "placing into a removed place before the sweep reclaimed it is refused");
    engine_sweep();
    CHECK(station_at(doomed)->state == STATION_FREE, "the sweep reclaimed the place");
    int32_t reborn = engine_place(&box_pass, "reborn", KIND_PLAIN, 1);
    CHECK(reborn == doomed, "the next placement reused the reclaimed place (%d, was %d)", reborn, doomed);

    /* --- removing a station while values flow into it ------------------- */
    int32_t tail = PLACE(box_discard, "tail", KIND_PLAIN, 0);
    int32_t pipe = PLACE(box_chew, "pipe", KIND_PLAIN, 1);
    MUST(engine_wire(pipe, 0, ONE_WIRE(tail, 0)));
    MUST(configure_ring(tail, 0));
    MUST(configure_static(pipe, 1, 2000));
    MUST(configure_ring(pipe, 0));
    const int STREAM = 20000;
    for (int i = 0; i < STREAM; i++) {
        int64_t v = i;
        MUST(engine_deliver(pipe, 0, &v, sizeof v));
        if (i == STREAM / 2) {
            MUST(engine_remove(tail));
        }
    }
    CHECK(twin_engine_settle(8000), "the stream settled after its tail was removed");
    CHECK(engine_station_runs(pipe) == (uint64_t)STREAM, "the rest of the program kept running (%llu of %d runs)",
          (unsigned long long)engine_station_runs(pipe), STREAM);
    engine_sweep();
    struct destination left[4];
    CHECK(engine_exit_destinations(pipe, 0, left, 4) == 0, "the wire into the removed station was cut");

    struct engine_totals totals;
    engine_totals(&totals);
    metric_record("stations.placed_total", totals.stations, "places", "stations-table",
                  "places in the table at the end of the test, free ones included");
    metric_record("scrap.freed", (double)totals.scrap_freed, "items", "scrapyard",
                  "retired lists and stations the sweep has freed");
    metric_record("scrap.waiting", (double)totals.scrap_waiting, "items", "scrapyard",
                  "retired things still waiting for every core to move on");
    twin_engine_stop();
    metrics_close();
    CHECK_DONE("052 station table");
}
