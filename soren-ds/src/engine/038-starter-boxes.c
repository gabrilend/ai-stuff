/*
 * 038-starter-boxes.c — the starter box library (issue 212).
 *
 * General description: nine small C functions and, beside each, the record
 * the engine needs to run it — the parameter names, types, sizes and
 * offsets, and a two-line adapter that unpacks a task's input bytes into
 * the function's arguments. From phase 3 on, the generator writes those
 * records and adapters by reading the functions themselves; these are
 * written in the same shape so that swap is a file, not a redesign.
 *
 * `pass` and `chew` exist to measure the design stance: the engine costs
 * something per *run*, so a program of a few substantial boxes pays less
 * engine than one of many tiny ones. `pass` is all engine and no work;
 * `chew` is mostly work. The endurance demo (215) runs the same total work
 * both ways and reports the ratio.
 */
#include "027-primitives.h"
#include "038-starter-boxes.h"

#define SOURCE "src/engine/038-starter-boxes.c"
#define TALLY_SLOTS 4096

/* {{{ the functions */
/* {{{ constant */
static int64_t constant(int64_t value)
{
    return value;
}
/* }}} */

/* {{{ pass */
static int64_t pass(int64_t v)
{
    return v;
}
/* }}} */

/* {{{ increment */
static int64_t increment(int64_t v)
{
    return v + 1;
}
/* }}} */

/* {{{ add */
static int64_t add(int64_t a, int64_t b)
{
    return a + b;
}
/* }}} */

/* {{{ countdown */
static int64_t countdown(int64_t v)
{
    return v - 1;
}
/* }}} */

struct tally {
    uint64_t count;
    int64_t  sum;
} LINE_ALIGNED;
static struct tally tallies[TALLY_SLOTS];

/* {{{ discard */
static void discard(int64_t v)
{
    int32_t station = engine_current_station();
    struct tally *t = &tallies[(uint32_t)station % TALLY_SLOTS];
    atomic_add(&t->count, 1);
    atomic_add(&t->sum, v);
}
/* }}} */

/* {{{ say_value */
static void say_value(int64_t v)
{
    int32_t station = engine_current_station();
    say("%s: %lld", engine_station_name(station), (long long)v);
}
/* }}} */

/* {{{ chew */
static int64_t chew(int64_t seed, int64_t rounds)
{
    uint64_t x = (uint64_t)seed ^ 0x9e3779b97f4a7c15ull;
    for (int64_t r = 0; r < rounds; r++) {
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        x *= 0x2545f4914f6cdd1dull;
    }
    return (int64_t)(x >> 1);
}
/* }}} */

static struct tally refusals[TALLY_SLOTS];

/* {{{ picky */
/* Refuses anything over its limit. Each refusal is also written to an
 * outside tally, the way discard writes its count: several runs of one
 * station may be queued when the first refusal takes it out of service,
 * and each of those refuses too, so a caller doing exact arithmetic needs
 * to know which values were turned away. */
static int64_t picky(int64_t v, int64_t limit)
{
    if (v > limit) {
        struct tally *t = &refusals[(uint32_t)engine_current_station() % TALLY_SLOTS];
        atomic_add(&t->count, 1);
        atomic_add(&t->sum, v);
        engine_refuse((uint64_t)v);
    }
    return v;
}
/* }}} */
/* }}} */

/* {{{ adapters and shapes */
/* The adapters: unpack the task's input bytes, call, store the return.
 * Offsets are 8-byte aligned; every parameter here is an int64_t. */
#define ARG(i) (*(const int64_t *)((const uint8_t *)in + 8 * (i)))
#define RET    (*(int64_t *)out)

/* {{{ constant__call */
static void constant__call(const void *in, void *out) { RET = constant(ARG(0)); }
/* }}} */
/* {{{ pass__call */
static void pass__call(const void *in, void *out) { RET = pass(ARG(0)); }
/* }}} */
/* {{{ increment__call */
static void increment__call(const void *in, void *out) { RET = increment(ARG(0)); }
/* }}} */
/* {{{ add__call */
static void add__call(const void *in, void *out) { RET = add(ARG(0), ARG(1)); }
/* }}} */
/* {{{ countdown__call */
static void countdown__call(const void *in, void *out) { RET = countdown(ARG(0)); }
/* }}} */
/* {{{ discard__call */
static void discard__call(const void *in, void *out) { (void)out; discard(ARG(0)); }
/* }}} */
/* {{{ say__call */
static void say__call(const void *in, void *out) { (void)out; say_value(ARG(0)); }
/* }}} */
/* {{{ chew__call */
static void chew__call(const void *in, void *out) { RET = chew(ARG(0), ARG(1)); }
/* }}} */
/* {{{ picky__call */
static void picky__call(const void *in, void *out) { RET = picky(ARG(0), ARG(1)); }
/* }}} */

static const struct box_param one_value[]  = { { "v", "int64_t", 8, 0 } };
static const struct box_param const_value[]= { { "value", "int64_t", 8, 0 } };
static const struct box_param two_values[] = { { "a", "int64_t", 8, 0 }, { "b", "int64_t", 8, 8 } };
static const struct box_param chew_args[]  = { { "seed", "int64_t", 8, 0 }, { "rounds", "int64_t", 8, 8 } };
static const struct box_param picky_args[] = { { "v", "int64_t", 8, 0 }, { "limit", "int64_t", 8, 8 } };

const struct box box_constant  = { "constant",  SOURCE, constant__call,  1, const_value, 8,  8, "int64_t" };
const struct box box_pass      = { "pass",      SOURCE, pass__call,      1, one_value,   8,  8, "int64_t" };
const struct box box_increment = { "increment", SOURCE, increment__call, 1, one_value,   8,  8, "int64_t" };
const struct box box_add       = { "add",       SOURCE, add__call,       2, two_values,  16, 8, "int64_t" };
const struct box box_countdown = { "countdown", SOURCE, countdown__call, 1, one_value,   8,  8, "int64_t" };
const struct box box_discard   = { "discard",   SOURCE, discard__call,   1, one_value,   8,  0, "void" };
const struct box box_say       = { "say",       SOURCE, say__call,       1, one_value,   8,  0, "void" };
const struct box box_chew      = { "chew",      SOURCE, chew__call,      2, chew_args,   16, 8, "int64_t" };
const struct box box_picky     = { "picky",     SOURCE, picky__call,     2, picky_args,  16, 8, "int64_t" };
/* }}} */

const struct box *const starter_boxes[] = {
    &box_constant, &box_pass, &box_increment, &box_add, &box_countdown,
    &box_discard, &box_say, &box_chew, &box_picky,
};
const int starter_box_count = (int)(sizeof starter_boxes / sizeof starter_boxes[0]);

/* {{{ starter_box_named */
const struct box *starter_box_named(const char *name)
{
    for (int i = 0; i < starter_box_count; i++) {
        if (text_equal(starter_boxes[i]->name, name)) {
            return starter_boxes[i];
        }
    }
    return (const struct box *)0;
}
/* }}} */

/* {{{ starter_discard_tally */
void starter_discard_tally(int32_t station, uint64_t *count, int64_t *sum)
{
    struct tally *t = &tallies[(uint32_t)station % TALLY_SLOTS];
    *count = atomic_load_acquire(&t->count);
    *sum   = atomic_load_acquire(&t->sum);
}
/* }}} */

/* {{{ starter_refused_tally */
void starter_refused_tally(int32_t station, uint64_t *count, int64_t *sum)
{
    struct tally *t = &refusals[(uint32_t)station % TALLY_SLOTS];
    *count = atomic_load_acquire(&t->count);
    *sum   = atomic_load_acquire(&t->sum);
}
/* }}} */

/* {{{ starter_discard_reset */
void starter_discard_reset(void)
{
    bytes_zero(tallies, sizeof tallies);
    bytes_zero(refusals, sizeof refusals);
}
/* }}} */
