/*
 * 054-test-parking-and-errors.c — issues 213 and 214.
 *
 * General description: a program fed by a timer is parked, and while it
 * is parked no core runs any of it and no station's count moves, however
 * long it waits. A program holding a hundred unmatched values is parked
 * and restarted at once, and resumes with all hundred intact. Another is
 * parked, its pages are then deliberately handed to somebody else, and on
 * restart it says so and starts empty. A box that refuses a value takes
 * itself out of service while the program beside it keeps running, and
 * giving its input back brings it back. A million badly-sized deliveries
 * produce one error slot, one line on the developer's channel, and a
 * count of a million. A box that dereferences nothing is caught (debug
 * build), named, and taken out of service, and nothing else notices.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/038-starter-boxes.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "047-check.h"
#include "050-test-boxes.h"

#include <stdio.h>
#include <string.h>
#include <time.h>

#define CORES 4

#ifdef SOREN_DEBUG
/* {{{ crasher */
/* A box that faults on the value 13 and passes everything else through.
 * The address is read from a variable so the compiler cannot see it is bad. */
static volatile uintptr_t bad_address = 8;
static int64_t crasher_fn(int64_t v)
{
    if (v == 13) {
        volatile int64_t *nothing = (volatile int64_t *)bad_address;
        return *nothing;
    }
    return v;
}
static void crasher_call(const void *in, void *out) { *(int64_t *)out = crasher_fn(*(const int64_t *)in); }
static const struct box_param crasher_params[] = { { "v", "int64_t", 8, 0 } };
static const struct box crasher = { "crasher", __FILE__, crasher_call, 1, crasher_params, 8, 8, "int64_t" };
/* }}} */
#endif

/* {{{ sleep_ms */
static void sleep_ms(int ms)
{
    struct timespec ts = { ms / 1000, (long)(ms % 1000) * 1000000L };
    nanosleep(&ts, NULL);
}
/* }}} */

/* {{{ tally */
static uint64_t tally_count(int32_t station)
{
    uint64_t count; int64_t sum;
    starter_discard_tally(station, &count, &sum);
    return count;
}

static int64_t tally_sum(int32_t station)
{
    uint64_t count; int64_t sum;
    starter_discard_tally(station, &count, &sum);
    return sum;
}
/* }}} */

/* {{{ park_fully */
static int park_fully(const int32_t *stations, int n)
{
    int handle = engine_park_begin(stations, n);
    if (handle < 0) {
        return handle;
    }
    for (int tries = 0; tries < 2000; tries++) {
        if (engine_park_step(handle) == PARK_PARKED) {
            return handle;
        }
        sleep_ms(1);
    }
    return ENGINE_STOPPED;
}
/* }}} */

/* {{{ count_lines_containing */
static int count_lines_containing(const char *path, const char *needle)
{
    FILE *f = fopen(path, "r");
    if (!f) {
        return -1;
    }
    char line[1024];
    int n = 0;
    while (fgets(line, sizeof line, f)) {
        n += strstr(line, needle) != NULL;
    }
    fclose(f);
    return n;
}
/* }}} */

int main(void)
{
    char log_path[512];
    snprintf(log_path, sizeof log_path, "%s/tmp/shared-memory/test-logs/054-developer-line.log",
             getenv("SOREN_DIR"));
    remove(log_path);
    twin_engine_start(CORES, (size_t)512 << 20);
    twin_platform_set_log(log_path, 0);
    engine_open_gate();
    metrics_open("054-parking-and-errors");

    /* --- a parked program costs no core and no cycle -------------------- */
    int32_t ticks_sink = PLACE(box_discard, "tick-sink", KIND_PLAIN, 0);
    int32_t ticker = PLACE(box_increment, "ticker", KIND_PLAIN, 1);
    MUST(engine_wire(ticker, 0, ONE_WIRE(ticks_sink, 0)));
    MUST(configure_ring(ticks_sink, 0));
    MUST(configure_ring(ticker, 0));
    int64_t one = 1;
    int timer = engine_timer(ticker, 0, &one, sizeof one, platform_now_ns() + 1000000, 1000000);
    CHECK(timer >= 0, "a 1 kHz timer was armed");
    sleep_ms(50);
    CHECK(tally_count(ticks_sink) > 10, "the timer fed the program (%llu ticks)", (unsigned long long)tally_count(ticks_sink));
    int32_t program[2] = { ticker, ticks_sink };
    int handle = park_fully(program, 2);
    CHECK(handle >= 0, "the program parked (%s)", handle < 0 ? engine_error_text(handle) : "ok");
    uint64_t runs_parked = engine_station_runs(ticker);
    struct engine_core_stats before[CORES], after[CORES];
    for (int c = 0; c < CORES; c++) engine_core_stats(c, &before[c]);
    sleep_ms(60);
    uint64_t ran = 0, fires = 0;
    for (int c = 0; c < CORES; c++) {
        engine_core_stats(c, &after[c]);
        ran += after[c].ran - before[c].ran;
        fires += after[c].timer_fires - before[c].timer_fires;
    }
    CHECK(engine_station_runs(ticker) == runs_parked && ran == 0,
          "while parked, no station ran and no core ran a task (%llu tasks)", (unsigned long long)ran);
    CHECK(fires > 20 && engine_station_discarded(ticker) > 20,
          "the timer kept firing and its values were discarded and counted (%llu fired, %llu discarded)",
          (unsigned long long)fires, (unsigned long long)engine_station_discarded(ticker));
    int lost = -1;
    CHECK(engine_restart(handle, &lost) == RESTART_RESUMED, "restarting resumed it");
    sleep_ms(20);
    CHECK(engine_station_runs(ticker) > runs_parked, "and it ran again once restarted");
    engine_timer_cancel(timer);
    twin_engine_settle(2000);

    /* --- parked and restarted at once: every buffered value survives ---- */
    int32_t pair_sink = PLACE(box_discard, "pair-sink", KIND_PLAIN, 0);
    int32_t pair = PLACE(box_add, "pair", KIND_PLAIN, 1);
    MUST(engine_wire(pair, 0, ONE_WIRE(pair_sink, 0)));
    MUST(configure_ring(pair_sink, 0));
    MUST(configure_ring(pair, 0));
    MUST(configure_ring(pair, 1));
    for (int64_t i = 1; i <= 100; i++) MUST(engine_deliver(pair, 0, &i, sizeof i));
    twin_engine_settle(2000);
    int32_t pair_program[2] = { pair, pair_sink };
    handle = park_fully(pair_program, 2);
    CHECK(handle >= 0, "the half-fed pair parked");
    CHECK(engine_restart(handle, &lost) == RESTART_RESUMED && lost == 0,
          "restarted at once, it resumed in place with nothing lost (%d lost)", lost);
    for (int64_t i = 1; i <= 100; i++) {
        int64_t k = 1000;
        MUST(engine_deliver(pair, 1, &k, sizeof k));
    }
    twin_engine_settle(2000);
    CHECK(tally_count(pair_sink) == 100 && tally_sum(pair_sink) == 5050 + 100000,
          "all hundred buffered values were still there (%llu runs, sum %lld)",
          (unsigned long long)tally_count(pair_sink), (long long)tally_sum(pair_sink));

    /* --- parked, its memory handed away, restarted: rebuilt, out loud --- */
    for (int64_t i = 1; i <= 100; i++) MUST(engine_deliver(pair, 0, &i, sizeof i));
    twin_engine_settle(2000);
    handle = park_fully(pair_program, 2);
    CHECK(handle >= 0, "parked again with a hundred values waiting");
    struct station *ps = station_at(pair);
    void *wanted = (void *)((uintptr_t)ps->ports[0].pages[0] & ~(uintptr_t)4095);
    int owner = page_owner(wanted);
    int found = 0;
    void *taken[4096];
    int n_taken = 0;
    /* Allocate as the page's owner until that very page is handed out,
     * then scribble on it: somebody else needed the memory. Only the
     * outside owner can be borrowed safely from this thread. */
    if (owner == OWNER_OUTSIDE) {
        for (; n_taken < 4096 && !found; n_taken++) {
            taken[n_taken] = page_alloc(OWNER_OUTSIDE);
            if (taken[n_taken] == wanted) {
                memset(wanted, 0xAB, 4096);
                found = 1;
            }
        }
    }
    CHECK(found, "the parked page was handed to somebody else (owner %d)", owner);
    CHECK(engine_restart(handle, &lost) == RESTART_REBUILT && lost == 100,
          "restart noticed, rebuilt empty, and counted the %d lost values", lost);
    CHECK(count_lines_containing(log_path, "had to be rebuilt empty") == 1, "and said so on the developer's line");
    for (int i = 0; i < n_taken; i++) {
        page_free(OWNER_OUTSIDE, taken[i]);
    }

    /* --- a refusing box takes itself out; its neighbours carry on ------- */
    int32_t fussy_sink = PLACE(box_discard, "fussy-sink", KIND_PLAIN, 0);
    int32_t fussy = PLACE(box_picky, "fussy", KIND_PLAIN, 1);
    int32_t calm_sink = PLACE(box_discard, "calm-sink", KIND_PLAIN, 0);
    int32_t calm = PLACE(box_increment, "calm", KIND_PLAIN, 1);
    MUST(engine_wire(fussy, 0, ONE_WIRE(fussy_sink, 0)));
    MUST(engine_wire(calm, 0, ONE_WIRE(calm_sink, 0)));
    MUST(configure_ring(fussy_sink, 0));
    MUST(configure_ring(calm_sink, 0));
    MUST(configure_static(fussy, 1, 10));
    MUST(configure_ring(fussy, 0));
    MUST(configure_ring(calm, 0));
    for (int64_t i = 1; i <= 20; i++) {
        MUST(engine_deliver(fussy, 0, &i, sizeof i));
        twin_engine_settle(1000);
        MUST(engine_deliver(calm, 0, &i, sizeof i));
    }
    twin_engine_settle(2000);
    struct engine_error_report report;
    MUST(engine_read_error(fussy, &report, 0));
    CHECK(report.kind == ERROR_REFUSED && report.detail == 11, "the box refused 11 and the slot says so (kind %d, detail %llu)",
          report.kind, (unsigned long long)report.detail);
    CHECK(tally_count(fussy_sink) == 10, "it passed the ten it accepted and then stopped (%llu)",
          (unsigned long long)tally_count(fussy_sink));
    CHECK(engine_port_tag(fussy, 0) == PORT_NONE, "its input now has no source");
    CHECK(tally_count(calm_sink) == 20, "the station beside it kept running (%llu of 20)",
          (unsigned long long)tally_count(calm_sink));
    MUST(configure_static(fussy, 1, 100));
    MUST(configure_ring(fussy, 0));
    twin_engine_settle(2000);
    CHECK(tally_count(fussy_sink) == 19, "fixed and given its input back, it ran the nine values that had waited (%llu)",
          (unsigned long long)tally_count(fussy_sink));
    MUST(engine_read_error(fussy, &report, 0));
    CHECK(report.kind == ERROR_NONE, "giving its input back reset the error slot");

    /* --- a million of the same error: one slot, one line --------------- */
    int32_t target = PLACE(box_increment, "target-of-a-million", KIND_PLAIN, 1);
    MUST(configure_ring(target, 0));
    int32_t small = 7;
    for (int i = 0; i < 1000000; i++) {
        engine_deliver(target, 0, &small, sizeof small);
    }
    MUST(engine_read_error(target, &report, 1));
    CHECK(report.kind == ERROR_WRONG_SIZE && report.count == 1000000,
          "a million wrong-size deliveries: one slot, count %llu", (unsigned long long)report.count);
    CHECK(count_lines_containing(log_path, "target-of-a-million") == 1,
          "and exactly one line on the developer's channel");
    MUST(engine_read_error(target, &report, 0));
    CHECK(report.count == 0, "reading with clear handed the number to the reader");

#ifdef SOREN_DEBUG
    /* --- a box that faults is caught, named, and taken out -------------- */
    int32_t crash_sink = PLACE(box_discard, "crash-sink", KIND_PLAIN, 0);
    int32_t crash = PLACE(crasher, "crasher", KIND_PLAIN, 1);
    MUST(engine_wire(crash, 0, ONE_WIRE(crash_sink, 0)));
    MUST(configure_ring(crash_sink, 0));
    MUST(configure_ring(crash, 0));
    for (int64_t i = 1; i <= 20; i++) {
        MUST(engine_deliver(crash, 0, &i, sizeof i));
        twin_engine_settle(1000);
    }
    MUST(engine_read_error(crash, &report, 0));
    CHECK(report.kind == ERROR_TRAPPED && report.detail == 8, "the fault was caught and its address recorded (kind %d, %llu)",
          report.kind, (unsigned long long)report.detail);
    CHECK(tally_count(crash_sink) == 12 && engine_port_tag(crash, 0) == PORT_NONE,
          "twelve values passed before 13 faulted, and the station took itself out (%llu)",
          (unsigned long long)tally_count(crash_sink));
    CHECK(count_lines_containing(log_path, "trapped") == 1, "the trap was named once on the developer's line");
#endif

    twin_engine_stop();
    metrics_close();
    CHECK_DONE("054 parking and errors");
}
