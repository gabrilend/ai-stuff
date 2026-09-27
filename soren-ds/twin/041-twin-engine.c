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
#include "../src/engine/068-programs.h"
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

/* {{{ disk_reader */
/* Map files on the laptop come from the project directory itself, so a
 * map can be edited and reloaded without rebuilding anything. Paths are
 * project-relative, exactly as on the device. The text is kept until the
 * process ends; loading is rare. */
static const char *disk_reader(const char *path, size_t *length, void *ctx)
{
    (void)ctx;
    const char *dir = getenv("SOREN_DIR");
    if (!dir) {
        return NULL;
    }
    char full[4096];
    snprintf(full, sizeof full, "%s/%s", dir, path);
    FILE *f = fopen(full, "rb");
    if (!f) {
        return NULL;
    }
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *text = malloc((size_t)n + 1);
    size_t got = fread(text, 1, (size_t)n, f);
    fclose(f);
    text[got] = 0;
    *length = got;
    return text;
}
/* }}} */

/* {{{ twin_engine_start */
void twin_engine_start(int cores, size_t pool_bytes)
{
    twin_platform_init(cores, pool_bytes);
    engine_init(cores);
    program_set_reader(disk_reader, NULL);
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
