/*
 * crowd-common.h - what every crowd runner shares: the scene, the crossing, the clock, the report (issue 515k)
 *
 * What this is: the parts of a benchmark run that aren't the threading:
 * reading a scene (crowd-scene.lua's format) into a C crowd, sending the
 * armies across and back as the Lua runner does, the clock, the one-line
 * report with its checksum of every unit's position, and the timeline
 * (who ran which chunk of units when, for a few ticks, for the page's
 * GIFs). Header only: each runner is one program.
 */
#ifndef CROWD_COMMON_H
#define CROWD_COMMON_H

#include "crowd.h"
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* {{{ static double now_us(void) */
static inline double now_us(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1e6 + ts.tv_nsec / 1e3;
}
/* }}} */

/* {{{ static void pause_a_moment(void) */
static inline void pause_a_moment(void)
{
#if defined(__x86_64__) || defined(__i386__)
    __builtin_ia32_pause();
#endif
}
/* }}} */

/* A scene's homes and armies (unit ids, team 1 and team 2). */
typedef struct { double homes[2][2]; int *armies[2]; int counts[2]; } scene;

/* {{{ static cr_crowd *scene_load(const char *path, scene *sc) */
static inline cr_crowd *scene_load(const char *path, scene *sc)
{
    FILE *f = fopen(path, "r");
    if (!f) { fprintf(stderr, "can't read %s\n", path); exit(66); }
    int w, h;
    double cell;
    if (fscanf(f, "%d %d %lf\n", &w, &h, &cell) != 3) { fprintf(stderr, "a scene starts with W H CELL\n"); exit(65); }
    unsigned char *walk = malloc((size_t)w * h);
    char *row = malloc((size_t)w + 8);
    for (int y = 0; y < h; y++) {
        if (fscanf(f, "%s\n", row) != 1 || (int)strlen(row) != w) { fprintf(stderr, "row %d of the ground is wrong\n", y + 1); exit(65); }
        for (int x = 0; x < w; x++) walk[y * w + x] = row[x] != '#';
    }
    int n;
    if (fscanf(f, "HOMES %lf %lf %lf %lf\nUNITS %d\n", &sc->homes[0][0], &sc->homes[0][1], &sc->homes[1][0], &sc->homes[1][1], &n) != 5) {
        fprintf(stderr, "HOMES and UNITS lines expected\n"); exit(65);
    }
    cr_crowd *c = cr_new(w, h, walk, cell);
    sc->armies[0] = malloc((size_t)n * sizeof(int));
    sc->armies[1] = malloc((size_t)n * sizeof(int));
    sc->counts[0] = sc->counts[1] = 0;
    for (int i = 0; i < n; i++) {
        double x, y, r, speed;
        int team;
        if (fscanf(f, "%lf %lf %lf %lf %d\n", &x, &y, &r, &speed, &team) != 5) { fprintf(stderr, "unit %d is wrong\n", i + 1); exit(65); }
        cr_add(c, x, y, r, speed, team);
        sc->armies[team - 1][sc->counts[team - 1]++] = i + 1;
    }
    fclose(f);
    free(walk); free(row);
    return c;
}
/* }}} */

/* The crossing: which way the armies go next. */
typedef struct { int across; long crossings; } crossing;

/* {{{ static void crossing_start(crossing *x, cr_crowd *c, const scene *sc) */
static inline void crossing_start(crossing *x, cr_crowd *c, const scene *sc)
{
    x->across = 1;
    x->crossings = 0;
    for (int a = 0; a < 2; a++) cr_move_group(c, sc->armies[a], sc->counts[a], sc->homes[1 - a][0], sc->homes[1 - a][1]);
}
/* }}} */

/* {{{ static void crossing_step(crossing *x, cr_crowd *c, const scene *sc) */
/* After a tick: nobody moving -> the crossing is over, each army to the
 * other side (or back); otherwise nothing. */
static inline void crossing_step(crossing *x, cr_crowd *c, const scene *sc)
{
    cr_unit *u = cr_units(c);
    int n = cr_count(c);
    for (int i = 0; i < n; i++) if (u[i].moving) return;
    x->across = !x->across;
    x->crossings++;
    for (int a = 0; a < 2; a++) {
        int home = !x->across ? a : 1 - a;
        cr_move_group(c, sc->armies[a], sc->counts[a], sc->homes[home][0], sc->homes[home][1]);
    }
}
/* }}} */

/* {{{ static int by_value(const void *a, const void *b) */
static inline int by_value(const void *a, const void *b)
{
    double x = *(const double *)a, y = *(const double *)b;
    return x < y ? -1 : x > y;
}
/* }}} */

/* {{{ static uint64_t checksum(cr_crowd *c) */
/* FNV-1a over the bits of every unit's position: equal only if every
 * position is equal to the last bit. */
static inline uint64_t checksum(cr_crowd *c)
{
    uint64_t h = 1469598103934665603ull;
    cr_unit *u = cr_units(c);
    for (int i = 0; i < cr_count(c); i++) {
        double v[2] = { u[i].x, u[i].y };
        const unsigned char *b = (const unsigned char *)v;
        for (size_t k = 0; k < sizeof v; k++) { h ^= b[k]; h *= 1099511628211ull; }
    }
    return h;
}
/* }}} */

/* {{{ static void report(...) */
/* The one line: way, threads, units, ticks, mean, median, 99th
 * percentile and worst tick (ms), checksum. */
static inline void report(const char *way, int threads, int units, long ticks, double *times, cr_crowd *c)
{
    double sum = 0;
    for (long i = 0; i < ticks; i++) sum += times[i];
    qsort(times, (size_t)ticks, sizeof(double), by_value);
    printf("%s\t%d\t%d\t%ld\t%.4f\t%.4f\t%.4f\t%.4f\t%016llx\n", way, threads, units, ticks, sum / ticks,
           times[ticks / 2], times[(long)(ticks * 0.99)], times[ticks - 1], (unsigned long long)checksum(c));
}
/* }}} */

/* {{{ The timeline: who ran which chunk when, for TIMELINE_TICKS ticks from
 * CROWD_TIMELINE_AT (default 600): best set to when the armies meet, when
 * the work is at its most uneven */
#define TIMELINE_TICKS 4
#define TIMELINE_MOST 200000
static long TIMELINE_FIRST = 600;
typedef struct { int worker, chunk; long tick; double start, end; } timeline_span;
static FILE *timeline_file;
static timeline_span *timeline_spans;
static _Atomic int timeline_n;
static long timeline_current;
static double timeline_zero;

/* {{{ static void timeline_open(const char *path, int threads) */
static inline void timeline_open(const char *path, int threads)
{
    (void)threads;
    if (!path) return;
    if (getenv("CROWD_TIMELINE_AT")) TIMELINE_FIRST = atol(getenv("CROWD_TIMELINE_AT"));
    timeline_file = fopen(path, "w");
    if (!timeline_file) { fprintf(stderr, "can't write %s\n", path); exit(73); }
    timeline_spans = malloc(TIMELINE_MOST * sizeof(timeline_span));
}
/* }}} */

/* {{{ static int timeline_on(void) */
static inline int timeline_on(void)
{
    return timeline_file && timeline_current >= TIMELINE_FIRST && timeline_current < TIMELINE_FIRST + TIMELINE_TICKS;
}
/* }}} */

/* {{{ static void timeline_tick(long t) */
static inline void timeline_tick(long t)
{
    timeline_current = t;
    if (t == TIMELINE_FIRST) timeline_zero = now_us();
}
/* }}} */

/* {{{ static void timeline_add(int worker, int chunk, double start, double end) */
static inline void timeline_add(int worker, int chunk, double start, double end)
{
    int i = atomic_fetch_add(&timeline_n, 1);
    if (i < TIMELINE_MOST) timeline_spans[i] = (timeline_span){ worker, chunk, timeline_current, start - timeline_zero, end - timeline_zero };
}
/* }}} */

/* {{{ static void timeline_close(void) */
/* One line a span: tick, worker, chunk, start and end (microseconds from
 * the first recorded tick's start). */
static inline void timeline_close(void)
{
    if (!timeline_file) return;
    int n = atomic_load(&timeline_n);
    if (n > TIMELINE_MOST) n = TIMELINE_MOST;
    for (int i = 0; i < n; i++)
        fprintf(timeline_file, "%ld\t%d\t%d\t%.1f\t%.1f\n", timeline_spans[i].tick, timeline_spans[i].worker,
                timeline_spans[i].chunk, timeline_spans[i].start, timeline_spans[i].end);
    fclose(timeline_file);
}
/* }}} */
/* }}} */

#endif
