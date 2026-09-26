/*
 * frame-plan.h - the fabricated frame's work and its plan (issue 515h)
 *
 * What this is: everything the three ways of running the frame share, so
 * they do identical work and must reach identical answers.
 *   - churn(): the stand-in for real work. A hash chain of a set number of
 *     rounds: its cost is real (it can't be skipped or folded away, each
 *     round needs the last) and its answer is checkable.
 *   - the frame's plan, all derived from the frame number by a hash, so it
 *     varies from frame to frame the same way for everybody:
 *       simulation     one step, SIM_US
 *       fog of war     one per player (4), 400-1000 us, uneven
 *       poses          8 lanes of 256 units (the real pose math, elsewhere)
 *       culling        one per lane, CULL_US
 *       pathfinding    20-60 requests, 10 us to 2 ms each (a long tail:
 *                      most are short, a few are very long, as real
 *                      searches are)
 *       decoding       2 per frame in the background, DECODE_US each
 *
 * Costs are written in microseconds and turned into rounds with
 * ROUNDS_PER_US, which the build measures on this machine once
 * (calibrate.c) and passes to every program as the same number. So "400 us"
 * is the same amount of work everywhere, whatever the wall clock says.
 */
#ifndef FRAME_PLAN_H
#define FRAME_PLAN_H

#ifndef ROUNDS_PER_US
#error "ROUNDS_PER_US must be given by the build (run-frame.sh measures it)"
#endif

#define FRAME_PLAYERS 4
#define FRAME_LANES 8
#define FRAME_UNITS_PER_LANE 256
#define FRAME_PATHS_MIN 20
#define FRAME_PATHS_MAX 60
#define FRAME_DECODES 2
#define SIM_US 300
#define CULL_US 60
#define DECODE_US 1500

/* {{{ static inline unsigned int mix32(unsigned int x) */
/* A 32-bit hash (the "lowbias32" finaliser): every bit of the input
 * affects every bit of the output. */
static inline unsigned int mix32(unsigned int x)
{
    x ^= x >> 16; x *= 0x7feb352dU;
    x ^= x >> 15; x *= 0x846ca68bU;
    x ^= x >> 16;
    return x;
}
/* }}} */

/* {{{ static inline unsigned int churn(unsigned int x, unsigned int rounds) */
/* The work: `rounds` hash steps, each needing the one before. */
static inline unsigned int churn(unsigned int x, unsigned int rounds)
{
    for (unsigned int i = 0; i < rounds; i++) x = mix32(x + i);
    return x;
}
/* }}} */

/* {{{ static inline unsigned int us_rounds(unsigned int us) */
static inline unsigned int us_rounds(unsigned int us)
{
    return us * (unsigned int)ROUNDS_PER_US;
}
/* }}} */

/* {{{ the plan */
/* Fog for one player this frame: 400 to 1000 us. */
static inline unsigned int fog_us(int frame, int player)
{
    return 400 + mix32((unsigned int)(frame * 16 + player) ^ 0xf06u) % 601;
}

/* How many pathfinding requests this frame: 20 to 60. */
static inline int path_count(int frame)
{
    return FRAME_PATHS_MIN + (int)(mix32((unsigned int)frame ^ 0x9a7u) % (FRAME_PATHS_MAX - FRAME_PATHS_MIN + 1));
}

/* One request's cost: 10 us times 200 to the power of a uniform draw, so
 * 10 us to 2 ms with most requests short and a few long. Done in integer
 * steps so every program computes the same number: the draw is split into
 * 8 even bands, each band 200^(1/8) (about 1.94x) longer than the last. */
static inline unsigned int path_us(int frame, int id)
{
    unsigned int h = mix32((unsigned int)(frame * 4096 + id) ^ 0x5a7u);
    unsigned int band = h % 8;              /* 0..7 */
    unsigned int us = 10;
    for (unsigned int b = 0; b < band; b++) us = us * 194 / 100;
    /* spread within the band */
    return us + (h >> 8) % (us * 94 / 100 + 1);
}
/* }}} */

#endif
