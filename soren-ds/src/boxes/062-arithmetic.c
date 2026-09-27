/*
 * 062-arithmetic.c — the starter boxes, as box sources (issues 212, 301).
 *
 * General description: small integer boxes that let the engine be
 * exercised and measured — a constant to start a chain, a pass-through
 * that costs nothing but the engine, increments and adds with known
 * answers, a sink that tallies what it receives, a deliberately heavy
 * box for measuring how coarse a box should be, and one that refuses
 * values over a limit. Phase 2 wrote these with hand-made records beside
 * them; now the generator reads the functions and writes the records.
 */
#include <stdint.h>
#include "../engine/031-engine.h"
#include "../engine/038-tallies.h"

/* {{{ constant */
/* The thing that starts a chain: give its only port a fixed value and it
 * runs once, sending that value on. */
int64_t constant(int64_t value)
{
    return value;
}
/* }}} */

/* {{{ pass */
/* All engine, no work: what one run costs when the box does nothing. */
int64_t pass(int64_t v)
{
    return v;
}
/* }}} */

/* {{{ increment */
int64_t increment(int64_t v)
{
    return v + 1;
}
/* }}} */

/* {{{ add */
/* The two-input case, which is where claiming gets interesting. */
int64_t add(int64_t a, int64_t b)
{
    return a + b;
}
/* }}} */

/* {{{ countdown */
/* v - 1. Placed as a comparator against 0 with its "below" exit left
 * unwired, a chain of these ends by itself. */
int64_t countdown(int64_t v)
{
    return v - 1;
}
/* }}} */

/* {{{ discard */
/* A sink that tallies how many values it consumed and their sum — the
 * tally is the outside world this box writes to, like a screen or a
 * serial line, not memory the box keeps. */
void discard(int64_t v)
{
    tally_add(engine_current_station(), v);
}
/* }}} */

/* {{{ chew */
/* Deliberately substantial: `rounds` rounds of xorshift mixing. */
int64_t chew(int64_t seed, int64_t rounds)
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

/* {{{ picky */
/* Passes a value through, or refuses one over its limit. Each refusal is
 * also tallied, because runs already queued when the first refusal takes
 * the station out of service refuse too, and exact arithmetic needs to
 * know which values were turned away. */
int64_t picky(int64_t v, int64_t limit)
{
    if (v > limit) {
        tally_refusal(engine_current_station(), v);
        engine_refuse((uint64_t)v);
    }
    return v;
}
/* }}} */

/* {{{ below */
/* v, unchanged — meant to be placed as a comparator, where the question
 * "is it below the threshold?" is asked by the exit, not the box. */
int64_t below(int64_t v)
{
    return v;
}
/* }}} */
