/*
 * 051-test-workers-and-delivery.c — issues 205, 206, 211 and 212.
 *
 * General description: small programs built by hand with place,
 * configure and wire, each checking one promise. Nothing runs before the
 * gate opens. A value walks down a three-station chain and the middle one
 * runs exactly once. One station fans out to twenty and every one gets a
 * copy. A 64-byte struct crosses two hops byte-identical. A box that
 * returns nothing is freed and delivers nothing. N static writes to an
 * always-ready station make exactly N runs, spread over the cores. A slow
 * trickle of values lets the cores park between them and still delivers
 * every one. The same program built in two different orders gives the
 * same answer, and a station placed but never wired never runs.
 */
#define _GNU_SOURCE
#include "../../src/engine/025-platform.h"
#include "../../src/engine/031-engine.h"
#include "catalogue-boxes.h"
#include "../../src/engine/038-tallies.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "047-check.h"
#include "050-test-boxes.h"

#include <stdatomic.h>
#include <string.h>
#include <time.h>

#define CORES 4

/* A value bigger than a machine word, to check nothing is torn on the way. */
struct wide {
    uint8_t bytes[64];
};

static struct wide last_wide;

/* {{{ stamp_wide */
static struct wide stamp_wide(int64_t seed)
{
    struct wide w;
    for (int i = 0; i < 64; i++) {
        w.bytes[i] = (uint8_t)(seed * 31 + i * 7);
    }
    return w;
}
/* }}} */

/* {{{ the wide boxes */
static void make_wide_call(const void *in, void *out) { *(struct wide *)out = stamp_wide(*(const int64_t *)in); }
static void pass_wide_call(const void *in, void *out) { *(struct wide *)out = *(const struct wide *)in; }
static void keep_wide_call(const void *in, void *out) { (void)out; last_wide = *(const struct wide *)in; }
static const struct box_param seed_param[] = { { "seed", "int64_t", 8, 0 } };
static const struct box_param wide_param[] = { { "w", "struct wide", 64, 0 } };
static const struct box make_wide = { "make_wide", __FILE__, make_wide_call, 1, seed_param, 8, 64, "struct wide" };
static const struct box pass_wide = { "pass_wide", __FILE__, pass_wide_call, 1, wide_param, 64, 64, "struct wide" };
static const struct box keep_wide = { "keep_wide", __FILE__, keep_wide_call, 1, wide_param, 64, 0, "void" };
/* }}} */

static _Atomic int64_t sink_runs;
BOX_1_0(counting_sink, atomic_fetch_add(&sink_runs, 1));

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
    tally_read(station, &count, &sum);
    return count;
}

static int64_t tally_sum(int32_t station)
{
    uint64_t count; int64_t sum;
    tally_read(station, &count, &sum);
    return sum;
}
/* }}} */

/* {{{ build_adder */
/* constant(a) ─┐
 *              ├─ add ─ discard
 * constant(b) ─┘
 * in either order: placement first, or each station wired as soon as its
 * destination exists. Answers the sink. */
static int32_t build_adder(int wiring_first, int64_t a, int64_t b)
{
    int32_t sink = PLACE(box__arithmetic__discard, "sum-sink", KIND_PLAIN, 0);
    int32_t adder = PLACE(box__arithmetic__add, "adder", KIND_PLAIN, 1);
    if (wiring_first) {
        MUST(engine_wire(adder, 0, ONE_WIRE(sink, 0)));
        MUST(configure_ring(sink, 0));
        MUST(configure_ring(adder, 0));
        MUST(configure_ring(adder, 1));
    }
    int32_t left = PLACE(box__arithmetic__constant, "left", KIND_PLAIN, 1);
    int32_t right = PLACE(box__arithmetic__constant, "right", KIND_PLAIN, 1);
    MUST(engine_wire(left, 0, ONE_WIRE(adder, 0)));
    MUST(engine_wire(right, 0, ONE_WIRE(adder, 1)));
    if (!wiring_first) {
        MUST(engine_wire(adder, 0, ONE_WIRE(sink, 0)));
        MUST(configure_ring(sink, 0));
        MUST(configure_ring(adder, 0));
        MUST(configure_ring(adder, 1));
    }
    /* Writing the statics is the start: there is no other. */
    MUST(configure_static(left, 0, a));
    MUST(configure_static(right, 0, b));
    return sink;
}
/* }}} */

int main(void)
{
    twin_engine_start(CORES, (size_t)512 << 20);
    metrics_open("051-workers-and-delivery");

    /* --- nothing runs before the gate --------------------------------- */
    int32_t sink = PLACE(box__arithmetic__discard, "chain-end", KIND_PLAIN, 0);
    int32_t mid2 = PLACE(box__arithmetic__increment, "second", KIND_PLAIN, 1);
    int32_t mid1 = PLACE(box__arithmetic__increment, "first", KIND_PLAIN, 1);
    int32_t head = PLACE(box__arithmetic__constant, "head", KIND_PLAIN, 1);
    MUST(engine_wire(head, 0, ONE_WIRE(mid1, 0)));
    MUST(engine_wire(mid1, 0, ONE_WIRE(mid2, 0)));
    MUST(engine_wire(mid2, 0, ONE_WIRE(sink, 0)));
    MUST(configure_ring(mid1, 0));
    MUST(configure_ring(mid2, 0));
    MUST(configure_ring(sink, 0));
    MUST(configure_static(head, 0, 40));
    sleep_ms(30);
    CHECK(engine_station_runs(head) == 0 && tally_count(sink) == 0,
          "nothing ran before the gate opened (head ran %llu times)",
          (unsigned long long)engine_station_runs(head));
    engine_open_gate();
    CHECK(twin_engine_settle(2000), "the chain settled");
    CHECK(tally_count(sink) == 1 && tally_sum(sink) == 42,
          "the value walked the chain: 40 + 1 + 1 = %lld, arrived %llu times",
          (long long)tally_sum(sink), (unsigned long long)tally_count(sink));
    CHECK(engine_station_runs(mid1) == 1, "the middle station ran exactly once (%llu)",
          (unsigned long long)engine_station_runs(mid1));

    /* --- fan-out to twenty -------------------------------------------- */
    struct destination fan[20];
    int32_t fan_sinks[20];
    for (int i = 0; i < 20; i++) {
        fan_sinks[i] = PLACE(box__arithmetic__discard, "fan-sink", KIND_PLAIN, 0);
        MUST(configure_ring(fan_sinks[i], 0));
        fan[i].station = fan_sinks[i];
        fan[i].port = 0;
    }
    int32_t spout = PLACE(box__arithmetic__constant, "spout", KIND_PLAIN, 1);
    MUST(engine_wire(spout, 0, fan, 20));
    MUST(configure_static(spout, 0, 7));
    CHECK(twin_engine_settle(2000), "the fan-out settled");
    int got = 0;
    for (int i = 0; i < 20; i++) {
        got += tally_count(fan_sinks[i]) == 1 && tally_sum(fan_sinks[i]) == 7;
    }
    CHECK(got == 20, "every one of twenty destinations received one copy (%d did)", got);

    /* --- a wide value crosses two hops byte-identical ------------------ */
    int32_t keeper = PLACE(keep_wide, "keeper", KIND_PLAIN, 0);
    int32_t relay = PLACE(pass_wide, "relay", KIND_PLAIN, 1);
    int32_t maker = PLACE(make_wide, "maker", KIND_PLAIN, 1);
    MUST(engine_wire(maker, 0, ONE_WIRE(relay, 0)));
    MUST(engine_wire(relay, 0, ONE_WIRE(keeper, 0)));
    MUST(configure_ring(relay, 0));
    MUST(configure_ring(keeper, 0));
    MUST(configure_static(maker, 0, 99));
    CHECK(twin_engine_settle(2000), "the wide chain settled");
    struct wide expect = stamp_wide(99);
    CHECK(memcmp(&expect, &last_wide, sizeof expect) == 0, "a 64-byte value crossed two hops byte-identical");

    /* --- a sink is freed and delivers nothing -------------------------- */
    int32_t quiet = PLACE(counting_sink, "quiet", KIND_PLAIN, 0);
    MUST(configure_static(quiet, 0, 5));
    CHECK(twin_engine_settle(2000), "the sink settled");
    CHECK(atomic_load(&sink_runs) == 1, "the sink ran once and nothing came of it");
    CHECK(engine_wire(quiet, 0, ONE_WIRE(sink, 0)) == ENGINE_NO_EXIT, "a sink has no exit to wire");

    /* --- N static writes, N runs, spread across cores ------------------ */
    struct engine_core_stats before[CORES], after[CORES];
    for (int c = 0; c < CORES; c++) engine_core_stats(c, &before[c]);
    int32_t counter_sink = PLACE(box__arithmetic__discard, "counter-sink", KIND_PLAIN, 0);
    MUST(configure_ring(counter_sink, 0));
    int32_t chewer = PLACE(box__arithmetic__chew, "chewer", KIND_PLAIN, 1);
    MUST(engine_wire(chewer, 0, ONE_WIRE(counter_sink, 0)));
    MUST(configure_static(chewer, 1, 20000));
    const int N = 2000;
    uint64_t t0 = platform_now_ns();
    for (int i = 0; i < N; i++) {
        MUST(configure_static(chewer, 0, i));
    }
    CHECK(twin_engine_settle(5000), "the counting runs settled");
    uint64_t t1 = platform_now_ns();
    CHECK(engine_station_runs(chewer) == (uint64_t)N, "%d static writes made exactly %d runs (%llu)", N, N,
          (unsigned long long)engine_station_runs(chewer));
    CHECK(tally_count(counter_sink) == (uint64_t)N, "and %d values reached the sink (%llu)", N,
          (unsigned long long)tally_count(counter_sink));
    int busy_cores = 0;
    uint64_t least = ~0ull, most = 0;
    for (int c = 0; c < CORES; c++) {
        engine_core_stats(c, &after[c]);
        uint64_t ran = after[c].ran - before[c].ran;
        busy_cores += ran > 0;
        if (ran < least) least = ran;
        if (ran > most) most = ran;
    }
    CHECK(busy_cores == CORES, "every core took some of the work (%d of %d did)", busy_cores, CORES);
    metric_record("workers.spread_least_over_most", most ? (double)least / (double)most : 0, "ratio",
                  "workers-spread", "the least-busy core's runs over the busiest core's, 2000 chew runs");
    metric_record("workers.chew20k_runs_per_s", (double)N * 1e9 / (double)(t1 - t0), "runs/s", "workers-throughput",
                  "2000 runs of a 20,000-round chew box, four cores");

    /* --- a trickle lets the cores park, and loses nothing --------------- */
    for (int c = 0; c < CORES; c++) engine_core_stats(c, &before[c]);
    int32_t drip_sink = PLACE(box__arithmetic__discard, "drip-sink", KIND_PLAIN, 0);
    MUST(configure_ring(drip_sink, 0));
    int32_t drip = PLACE(box__arithmetic__pass, "drip", KIND_PLAIN, 1);
    MUST(engine_wire(drip, 0, ONE_WIRE(drip_sink, 0)));
    MUST(configure_ring(drip, 0));
    for (int i = 0; i < 40; i++) {
        int64_t v = i;
        MUST(engine_deliver(drip, 0, &v, sizeof v));
        sleep_ms(5);
    }
    CHECK(twin_engine_settle(2000), "the trickle settled");
    uint64_t sleeps = 0;
    for (int c = 0; c < CORES; c++) {
        engine_core_stats(c, &after[c]);
        sleeps += after[c].sleeps - before[c].sleeps;
    }
    CHECK(tally_count(drip_sink) == 40 && tally_sum(drip_sink) == 780, "all 40 drips arrived (%llu, sum %lld)",
          (unsigned long long)tally_count(drip_sink), (long long)tally_sum(drip_sink));
    CHECK(sleeps >= 40, "cores parked between drips instead of spinning (%llu parks for 40 drips)",
          (unsigned long long)sleeps);
    metric_record("workers.parks_per_drip", (double)sleeps / 40.0, "parks", "workers-parking",
                  "times a core parked per value, when values arrive 5 ms apart");

    /* --- building order does not matter -------------------------------- */
    int32_t s1 = build_adder(0, 20, 22);
    int32_t s2 = build_adder(1, 20, 22);
    CHECK(twin_engine_settle(2000), "both adders settled");
    CHECK(tally_sum(s1) == 42 && tally_sum(s2) == 42 && tally_count(s1) == 1 && tally_count(s2) == 1,
          "placement-first and wiring-first gave the same answer (%lld, %lld)",
          (long long)tally_sum(s1), (long long)tally_sum(s2));

    /* --- placed but never wired never runs ------------------------------ */
    int32_t lonely = PLACE(box__arithmetic__increment, "lonely", KIND_PLAIN, 1);
    CHECK(twin_engine_settle(2000), "settled with a lonely station");
    CHECK(engine_station_runs(lonely) == 0 && engine_port_tag(lonely, 0) == PORT_NONE,
          "a station placed and never given a source never ran");

    /* --- refusals name what was wrong ---------------------------------- */
    CHECK(engine_place((const struct box *)0, "nothing", KIND_PLAIN, 1) == ENGINE_NO_BOX, "placing no box is refused");
    CHECK(engine_wire(head, 0, ONE_WIRE(999999, 0)) == ENGINE_NO_STATION, "a wire to no station is refused");
    CHECK(engine_wire(head, 0, ONE_WIRE(mid1, 5)) == ENGINE_NO_PORT, "a wire to no port is refused");
    CHECK(engine_wire(maker, 0, ONE_WIRE(sink, 0)) == ENGINE_WRONG_SIZE,
          "a 64-byte value wired into an 8-byte port is refused");
    int32_t v32 = 1;
    CHECK(engine_configure(head, 0, PORT_STATIC, &v32, sizeof v32) == ENGINE_WRONG_SIZE,
          "a static of the wrong size is refused");

    twin_engine_stop();
    metrics_close();
    CHECK_DONE("051 workers and delivery");
}
