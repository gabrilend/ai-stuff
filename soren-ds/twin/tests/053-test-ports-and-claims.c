/*
 * 053-test-ports-and-claims.c — issues 208, 209 and 210.
 *
 * General description: a three-input station is fed in all six possible
 * arrival orders and must run exactly once per complete set, never before
 * the last value lands. Four cores at once spray values into both sides
 * of an adder and the number of runs must equal the number of complete
 * pairs, with the sums exact — the property the lock-free claim is
 * trusted for, and the one the "every delivery is looked at by somebody"
 * checker in 034-ports.c exists to keep. A port's source is switched
 * between ring, static and none while wide, self-checking values stream
 * into it, and no run ever sees a torn value. A port nobody configured
 * holds its station back until it is given a source. And a task, once
 * built, keeps its own copies however the station changes afterwards.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
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

/* {{{ spray */
/* (count, target station, target port): deliver 1..count into a port. */
static int64_t spray_fn(int64_t count, int64_t target, int64_t port)
{
    for (int64_t i = 1; i <= count; i++) {
        engine_deliver((int32_t)target, (int)port, &i, sizeof i);
    }
    return count;
}
static void spray_call(const void *in, void *out)
{
    const int64_t *x = in;
    (void)out;
    spray_fn(x[0], x[1], x[2]);
}
static const struct box_param spray_params[] = {
    { "count", "int64_t", 8, 0 }, { "target", "int64_t", 8, 8 }, { "port", "int64_t", 8, 16 } };
static const struct box spray = { "spray", __FILE__, spray_call, 3, spray_params, 24, 0, "void" };
/* }}} */

/* {{{ the self-checking wide value */
struct checked {
    int64_t serial;
    int64_t payload[6];
    int64_t check;                     /* serial xor every payload word */
};

static struct checked make_checked(int64_t serial)
{
    struct checked c;
    c.serial = serial;
    c.check = serial;
    for (int i = 0; i < 6; i++) {
        c.payload[i] = serial * 1000003 + i;
        c.check ^= c.payload[i];
    }
    return c;
}

static _Atomic int torn;
static _Atomic int64_t checked_runs;
static void inspect_call(const void *in, void *out)
{
    (void)out;
    const struct checked *c = in;
    int64_t x = c->serial;
    for (int i = 0; i < 6; i++) x ^= c->payload[i];
    if (x != c->check) atomic_fetch_add(&torn, 1);
    atomic_fetch_add(&checked_runs, 1);
}
static const struct box_param checked_param[] = { { "c", "struct checked", sizeof(struct checked), 0 } };
static const struct box inspect = { "inspect", __FILE__, inspect_call, 1, checked_param, sizeof(struct checked), 0, "void" };

static void checked_spray_call(const void *in, void *out)
{
    (void)out;
    const int64_t *x = in;
    for (int64_t i = 1; i <= x[0]; i++) {
        struct checked c = make_checked(i);
        engine_deliver((int32_t)x[1], 0, &c, sizeof c);
    }
}
static const struct box_param checked_spray_params[] = { { "count", "int64_t", 8, 0 }, { "target", "int64_t", 8, 8 } };
static const struct box checked_spray = { "checked_spray", __FILE__, checked_spray_call, 2, checked_spray_params, 16, 0, "void" };
/* }}} */

BOX_3_1(sum3, a * 100 + b * 10 + c);

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

int main(void)
{
    twin_engine_start(CORES, (size_t)512 << 20);
    engine_open_gate();
    metrics_open("053-ports-and-claims");

    /* --- three inputs, six arrival orders ------------------------------ */
    static const int orders[6][3] = { {0,1,2}, {0,2,1}, {1,0,2}, {1,2,0}, {2,0,1}, {2,1,0} };
    int early = 0, wrong = 0;
    for (int o = 0; o < 6; o++) {
        int32_t sink = PLACE(box__arithmetic__discard, "order-sink", KIND_PLAIN, 0);
        int32_t st = PLACE(sum3, "three-inputs", KIND_PLAIN, 1);
        MUST(engine_wire(st, 0, ONE_WIRE(sink, 0)));
        MUST(configure_ring(sink, 0));
        for (int p = 0; p < 3; p++) MUST(configure_ring(st, p));
        for (int k = 0; k < 3; k++) {
            int port = orders[o][k];
            int64_t v = port + 1;
            MUST(engine_deliver(st, port, &v, sizeof v));
            twin_engine_settle(1000);
            if (k < 2 && engine_station_runs(st) != 0) early++;
        }
        if (tally_count(sink) != 1 || tally_sum(sink) != 123) wrong++;
    }
    CHECK(early == 0, "no station ran before its last input arrived (%d did)", early);
    CHECK(wrong == 0, "every arrival order made exactly one run with the right values (%d did not)", wrong);

    /* --- four cores spraying both sides of an adder -------------------- */
    const int64_t PER = 50000;
    int32_t sink = PLACE(box__arithmetic__discard, "hammer-sink", KIND_PLAIN, 0);
    int32_t adder = PLACE(box__arithmetic__add, "hammered", KIND_PLAIN, 1);
    MUST(engine_wire(adder, 0, ONE_WIRE(sink, 0)));
    MUST(configure_ring(sink, 0));
    MUST(configure_ring(adder, 0));
    MUST(configure_ring(adder, 1));
    int32_t sprayers[4];
    for (int s = 0; s < 4; s++) {
        sprayers[s] = PLACE(spray, "sprayer", KIND_PLAIN, 0);
        MUST(configure_static(sprayers[s], 1, adder));
        MUST(configure_static(sprayers[s], 2, s % 2));
    }
    uint64_t t0 = platform_now_ns();
    for (int s = 0; s < 4; s++) MUST(configure_static(sprayers[s], 0, PER));
    CHECK(twin_engine_settle(20000), "the hammering settled");
    uint64_t t1 = platform_now_ns();
    int64_t expect = 4 * (PER * (PER + 1) / 2);
    CHECK(tally_count(sink) == (uint64_t)(2 * PER), "runs equal complete pairs: %llu of %lld",
          (unsigned long long)tally_count(sink), (long long)(2 * PER));
    CHECK(tally_sum(sink) == expect, "nothing lost, doubled or torn: sum %lld, expected %lld",
          (long long)tally_sum(sink), (long long)expect);
    CHECK(engine_port_waiting(adder, 0) == 0 && engine_port_waiting(adder, 1) == 0,
          "no complete pair was left sitting unrun");
    struct engine_core_stats cs;
    uint64_t checks = 0, merged = 0;
    for (int c = 0; c < CORES; c++) {
        engine_core_stats(c, &cs);
        checks += cs.checks;
        merged += cs.checks_merged;
    }
    metric_record("claim.pairs_per_s", (double)(2 * PER) * 1e9 / (double)(t1 - t0), "pairs/s", "claim-throughput",
                  "complete pairs claimed and run per second, four cores spraying one adder");
    metric_record("claim.merged_fraction", checks ? (double)merged / (double)checks : 0, "fraction", "claim-merging",
                  "readiness checks handed to a core already checking that station, of all checks");

    /* --- switching a port's source while wide values stream in ---------- */
    int32_t seer = PLACE(inspect, "inspector", KIND_PLAIN, 0);
    MUST(configure_ring(seer, 0));
    int32_t source = PLACE(checked_spray, "checked-source", KIND_PLAIN, 0);
    MUST(configure_static(source, 1, seer));
    MUST(configure_static(source, 0, 200000));
    struct checked dial = make_checked(-7);
    for (int i = 0; i < 300; i++) {
        switch (i % 3) {
        case 0: MUST(engine_configure(seer, 0, PORT_STATIC, &dial, sizeof dial)); break;
        case 1: MUST(engine_configure(seer, 0, PORT_NONE, NULL, 0)); break;
        case 2: MUST(configure_ring(seer, 0)); break;
        }
    }
    MUST(configure_ring(seer, 0));
    CHECK(twin_engine_settle(20000), "the tag-cycling stream settled");
    CHECK(atomic_load(&torn) == 0, "no run saw a torn value across %lld runs (%d torn)",
          (long long)atomic_load(&checked_runs), atomic_load(&torn));

    /* --- an unconfigured port holds its station back -------------------- */
    int32_t wait_sink = PLACE(box__arithmetic__discard, "wait-sink", KIND_PLAIN, 0);
    int32_t waiter = PLACE(box__arithmetic__add, "waiter", KIND_PLAIN, 1);
    MUST(engine_wire(waiter, 0, ONE_WIRE(wait_sink, 0)));
    MUST(configure_ring(wait_sink, 0));
    MUST(configure_ring(waiter, 0));
    int64_t five = 5;
    MUST(engine_deliver(waiter, 0, &five, sizeof five));
    MUST(engine_deliver(waiter, 1, &five, sizeof five));   /* lands in a none port: waits */
    twin_engine_settle(1000);
    CHECK(engine_station_runs(waiter) == 0, "a station with a port nobody configured never ran");
    MUST(configure_ring(waiter, 1));
    twin_engine_settle(1000);
    CHECK(engine_station_runs(waiter) == 1 && tally_sum(wait_sink) == 10,
          "giving the port a source ran it at once, with the value that had been waiting");

    /* --- a built task keeps its own copies ------------------------------ */
    int32_t held = PLACE(box__arithmetic__add, "copy-source", KIND_PLAIN, 1);
    MUST(configure_static(held, 0, 11));
    MUST(configure_static(held, 1, 22));
    twin_engine_settle(1000);
    struct station *hs = station_at(held);
    uint8_t *no_cells[2] = { NULL, NULL };
    struct task *t = task_build(engine_here(), hs, held, (void **)no_cells);
    MUST(configure_static(held, 0, 99));
    int64_t a, b;
    memcpy(&a, t->in + 0, 8);
    memcpy(&b, t->in + 8, 8);
    CHECK(a == 11 && b == 22, "a task built before the station changed kept its copies (%lld, %lld)",
          (long long)a, (long long)b);
    __atomic_sub_fetch(&hs->in_flight, 1, __ATOMIC_ACQ_REL);
    task_free(engine_here(), t);

    twin_engine_stop();
    metrics_close();
    CHECK_DONE("053 ports and claims");
}
