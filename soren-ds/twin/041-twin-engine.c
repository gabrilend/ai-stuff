/*
 * 041-twin-engine.c — the engine's cores, started in the background on
 * the laptop.
 *
 * General description: one background thread calls the platform's
 * start-the-cores, becoming core 0 while the platform starts the rest.
 * The thread that called twin_engine_start is left free, and — not being a
 * core — acts as the engine's "outside" owner when it builds programs.
 */
#define _GNU_SOURCE
#include "../src/engine/025-platform.h"
#include "../src/engine/031-engine.h"
#include "026-platform-twin.h"
#include "041-twin-engine.h"

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static pthread_t launcher;
static int       launched_cores;

/* {{{ launch */
static void *launch(void *arg)
{
    (void)arg;
    platform_start_cores(launched_cores, engine_core_main);
    return NULL;
}
/* }}} */

/* {{{ twin_engine_start */
void twin_engine_start(int cores, size_t pool_bytes)
{
    twin_platform_init(cores, pool_bytes);
    engine_init(cores);
    launched_cores = cores;
    if (pthread_create(&launcher, NULL, launch, NULL) != 0) {
        fprintf(stderr, "twin: could not start the engine's cores\n");
        exit(2);
    }
}
/* }}} */

/* {{{ sleep_ms */
static void sleep_ms(int ms)
{
    struct timespec ts = { ms / 1000, (long)(ms % 1000) * 1000000L };
    nanosleep(&ts, NULL);
}
/* }}} */

/* {{{ twin_engine_settle */
int twin_engine_settle(int timeout_ms)
{
    int waited = 0;
    int calm = 0;
    while (waited < timeout_ms) {
        /* Two looks in a row, a moment apart: a single look can land in
         * the instant between one core parking and another's push. */
        calm = engine_is_idle() ? calm + 1 : 0;
        if (calm >= 2) {
            return 1;
        }
        sleep_ms(1);
        waited++;
    }
    return 0;
}
/* }}} */

/* {{{ twin_engine_stop */
void twin_engine_stop(void)
{
    engine_shutdown();
    pthread_join(launcher, NULL);
    twin_platform_shutdown();
}
/* }}} */

/* {{{ twin_ms */
double twin_ms(void)
{
    return (double)platform_now_ns() / 1e6;
}
/* }}} */
