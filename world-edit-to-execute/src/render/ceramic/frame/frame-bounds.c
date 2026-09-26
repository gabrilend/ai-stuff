/*
 * frame-bounds.c - how fast the fabricated frame could possibly be (issue 515h)
 *
 * What this is: the floor under every way of running the frame, worked out
 * from the frame's own plan (frame-plan.h) rather than measured. For each
 * frame:
 *   the longest chain  the simulation step, then the slowest of: any
 *                      player's fog, a pose lane and its culling, any single
 *                      pathfinding request. No arrangement of any number of
 *                      cores can finish the frame sooner.
 *   the total work     every task's cost added up: what one core must do.
 *   the core floor     the total work spread perfectly over CORES cores.
 * The best possible frame is the larger of the longest chain and the core
 * floor. A pose lane's cost is the real pose math, so it is timed here
 * (best of many runs, on a warm core); every other cost comes from the plan.
 *
 * Output: one tab-separated line: mean longest chain, mean total work, mean
 * best possible frame for CORES cores, the pose lane's cost -- microseconds.
 *
 * Usage: ./frame-bounds FRAMES CORES
 */
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "frame-boxes.c"

/* {{{ static double now_us(void) */
static double now_us(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1e6 + ts.tv_nsec / 1e3;
}
/* }}} */

/* {{{ int main(int argc, char **argv) */
int main(int argc, char **argv)
{
    if (argc != 3) { fprintf(stderr, "usage: %s FRAMES CORES\n", argv[0]); return 64; }
    int frames = atoi(argv[1]), cores = atoi(argv[2]);

    /* The pose lane, timed: best of 50, after a warm-up. */
    double pose_us = 1e18;
    unsigned int sink = 0;
    sim_state s = { 0, 1 };
    for (int i = 0; i < 60; i++) {
        double t0 = now_us();
        sink ^= pose_lane((lane_req){ i, i % FRAME_LANES }, s).hash;
        double took = now_us() - t0;
        if (i >= 10 && took < pose_us) pose_us = took;
    }

    double chain_sum = 0, work_sum = 0, best_sum = 0;
    for (int f = 0; f < frames; f++) {
        double slowest = pose_us + CULL_US, work = SIM_US + FRAME_LANES * (pose_us + CULL_US);
        for (int p = 0; p < FRAME_PLAYERS; p++) {
            double fu = fog_us(f, p);
            work += fu;
            if (fu > slowest) slowest = fu;
        }
        int np = path_count(f);
        for (int i = 0; i < np; i++) {
            double pu = path_us(f, i);
            work += pu;
            if (pu > slowest) slowest = pu;
        }
        double chain = SIM_US + slowest;
        double floor = work / cores;
        chain_sum += chain;
        work_sum += work;
        best_sum += chain > floor ? chain : floor;
    }
    printf("%.1f\t%.1f\t%.1f\t%.1f\n", chain_sum / frames, work_sum / frames, best_sum / frames, pose_us);
    return sink == 0xdeadbeefu ? 1 : 0;   /* keeps the pose work from being optimised away */
}
/* }}} */
