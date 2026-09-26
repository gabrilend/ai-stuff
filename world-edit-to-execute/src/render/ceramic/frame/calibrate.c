/*
 * calibrate.c - how many rounds of churn make a microsecond here (issue 515h)
 *
 * The fabricated frame's costs are written in microseconds and turned into
 * rounds of work once, by this, so every program does the same number of
 * rounds. Prints one integer. Best of five timings, so a moment of
 * interruption doesn't make the frame lighter than intended.
 */
#define ROUNDS_PER_US 1
#include "frame-plan.h"
#include <stdio.h>
#include <time.h>

/* {{{ int main(void) */
int main(void)
{
    const unsigned int rounds = 50000000u;
    double best = 1e18;
    unsigned int sink = 0;
    for (int trial = 0; trial < 5; trial++) {
        struct timespec a, b;
        clock_gettime(CLOCK_MONOTONIC, &a);
        sink ^= churn((unsigned int)trial, rounds);
        clock_gettime(CLOCK_MONOTONIC, &b);
        double us = (b.tv_sec - a.tv_sec) * 1e6 + (b.tv_nsec - a.tv_nsec) / 1e3;
        if (us < best) best = us;
    }
    printf("%d\n", (int)(rounds / best + 0.5));
    return sink == 0xffffffffu ? 1 : 0;   /* keeps the work from being optimised away */
}
/* }}} */
