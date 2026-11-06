/*
 * 089-test-reclaim.c — issue 410.
 *
 * General description: code compiled on the running engine is given back
 * by the same three steps that give back an old set of arrows — retired,
 * swept, freed — and only when nothing can still be inside it. All of it
 * runs while four looping programs keep every core busy.
 *
 * A unit compiled and never placed, once retired, stops answering its
 * addresses at once and has its code freed by a sweep while the busy
 * programs keep running; its source stays, as the session's record. A
 * unit some station places is not freed however often the sweep looks,
 * and the developer's line says which station keeps it, once; the
 * program placing it goes on giving right answers. Removing that program
 * is what lets the next sweep free the code. Retiring an older unit of a
 * file leaves the newer answering. And a teardown racing a sweep over
 * many retired units frees each exactly once.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/engine/070-catalogue.h"
#include "../../src/engine/087-compile.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "047-check.h"

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define RACERS 24

static struct map_report report;
static struct compile_report words;
static char log_path[600];

/* {{{ compile */
static int compile(const char *path, const char *source)
{
    return compile_box_source(path, source, strlen(source), &words);
}
/* }}} */

/* {{{ state_of */
static int state_of(int unit)
{
    struct compile_unit_facts f;
    return compile_unit_facts(unit, &f) == 0 ? f.state : -1;
}
/* }}} */

/* {{{ sweep_until_freed */
/* Sweep, a moment apart, until the unit's code is freed or a few seconds
 * have passed. Answers how many sweeps it took, or -1. */
static int sweep_until_freed(int unit)
{
    for (int i = 1; i <= 3000; i++) {
        engine_sweep();
        if (state_of(unit) == UNIT_FREED) return i;
        struct timespec pause = { 0, 1000000 };
        nanosleep(&pause, NULL);
    }
    return -1;
}
/* }}} */

/* {{{ busy_runs */
static uint64_t busy_runs(int program)
{
    uint64_t runs = 0;
    for (int i = 0; i < program_station_count(program); i++) runs += engine_station_runs(program_station_at(program, i));
    return runs;
}
/* }}} */

/* {{{ log_says */
static int log_says(const char *text)
{
    FILE *f = fopen(log_path, "r");
    if (!f) return 0;
    static char buffer[1 << 16];
    size_t n = fread(buffer, 1, sizeof buffer - 1, f);
    fclose(f);
    buffer[n] = 0;
    return strstr(buffer, text) != NULL;
}
/* }}} */

/* {{{ sweeper */
static volatile int racing;

static void *sweeper(void *arg)
{
    (void)arg;
    while (racing) engine_sweep();
    return NULL;
}
/* }}} */

int main(void)
{
    const char *dir = getenv("SOREN_DIR");
    if (!dir) {
        fprintf(stderr, "SOREN_DIR is not set; run this through scripts/test-twin\n");
        return 2;
    }
    snprintf(log_path, sizeof log_path, "%s/tmp/shared-memory/test-logs/089-developer-line.log", dir);
    remove(log_path);
    twin_engine_start(4, (size_t)256 << 20);
    twin_platform_set_log(log_path, 0);
    engine_open_gate();

    /* {{{ every core kept busy: four values circling four loops */
    const char *loops =
        "c = ../boxes/062-arithmetic.c\n"
        "station l0 (c:chew)\n  in 0 - l0.0\n  in 1 = 3000\n  out 0 - l0.0\n"
        "station l1 (c:chew)\n  in 0 - l1.0\n  in 1 = 3000\n  out 0 - l1.0\n"
        "station l2 (c:chew)\n  in 0 - l2.0\n  in 1 = 3000\n  out 0 - l2.0\n"
        "station l3 (c:chew)\n  in 0 - l3.0\n  in 1 = 3000\n  out 0 - l3.0\n";
    int busy = program_load_text("src/maps/busy.map", loops, strlen(loops), &report);
    CHECK(busy >= 0, "four looping programs load (%s)", report.text);
    for (int i = 0; i < 4; i++) {
        char name[8];
        snprintf(name, sizeof name, "l%d", i);
        int64_t seed = i + 1;
        engine_deliver(program_station(busy, name), 0, &seed, sizeof seed);
    }
    struct timespec warm = { 0, 50000000 };
    nanosleep(&warm, NULL);
    uint64_t runs_before = busy_runs(busy);
    CHECK(runs_before > 0 && !engine_is_idle(), "and keep the device saturated (%llu runs so far)", (unsigned long long)runs_before);
    /* }}} */

    /* {{{ compiled, never placed, retired: freed while the device runs */
    const char *never = "#include <stdint.h>\nint64_t unused(int64_t v)\n{\n    return v * 3;\n}\n";
    int lonely = compile("/boxes/lonely.c", never);
    CHECK(lonely >= 0 && catalogue_box("/boxes/lonely.c:unused"), "a box is compiled and never placed (%s)", words.text);
    CHECK(compile_retire(lonely) == 0, "it is retired");
    CHECK(catalogue_box("/boxes/lonely.c:unused") == NULL, "and its address stops answering at once");
    int refused = program_load_text("src/maps/late.map", "station u (/boxes/lonely.c:unused)\n", strlen("station u (/boxes/lonely.c:unused)\n"), &report);
    CHECK(refused < 0 && strstr(report.text, "no box"), "so no map can place it any more (%s)", report.text);
    CHECK(compile_retire(lonely) == COMPILE_RETIRED, "retiring it twice is refused");
    uint64_t freed_before = compile_units_freed();
    int sweeps = sweep_until_freed(lonely);
    CHECK(sweeps > 0 && compile_units_freed() == freed_before + 1, "a sweep frees its code while every core is busy (%d sweeps)", sweeps);
    uint64_t runs_after = busy_runs(busy);
    CHECK(runs_after > runs_before, "and the busy programs ran on throughout (%llu more runs)", (unsigned long long)(runs_after - runs_before));
    size_t length = 0;
    const char *kept = compile_source("/boxes/lonely.c:unused", &length);
    CHECK(kept && length == strlen(never) && memcmp(kept, never, length) == 0,
          "its source outlives its code, as the session's record of it");
    /* }}} */

    /* {{{ placed: never freed, and the sweep says why */
    CHECK(compile("/boxes/placed.c", "#include <stdint.h>\nint64_t triple(int64_t v)\n{\n    return v * 3;\n}\n") >= 0,
          "a second box is compiled (%s)", words.text);
    int placed_unit = compile_unit_count() - 1;
    const char *uses = "station t (/boxes/placed.c:triple)\n  in 0 - 0$\n  out 0 - 0$\n";
    int user = program_load_text("src/maps/user.map", uses, strlen(uses), &report);
    CHECK(user >= 0, "and placed by a program (%s)", report.text);
    CHECK(compile_retire(placed_unit) == 0 && catalogue_box("/boxes/placed.c:triple") == NULL,
          "retiring it stops its address answering, though a station places it");
    for (int i = 0; i < 200; i++) {
        engine_sweep();
        struct timespec pause = { 0, 1000000 };
        nanosleep(&pause, NULL);
    }
    struct compile_unit_facts facts;
    compile_unit_facts(placed_unit, &facts);
    CHECK(facts.state == UNIT_RETIRED, "two hundred sweeps, over a fifth of a second, later its code is still loaded");
    CHECK(facts.kept_by == program_station(user, "t"), "and the sweep recorded which station keeps it (%d)", (int)facts.kept_by);
    CHECK(log_says("/boxes/placed.c is retired but stays loaded: station") && log_says("places /boxes/placed.c:triple"),
          "the developer's line says why, naming the station and the box");
    int64_t seven = 7, got = 0;
    program_argument(user, 0, &seven, sizeof seven);
    for (int i = 0; i < 2000 && program_result(user, 0, &got, sizeof got) != 1; i++) {
        struct timespec pause = { 0, 1000000 };
        nanosleep(&pause, NULL);
    }
    CHECK(got == 21, "the program placing it still runs it (%lld)", (long long)got);
    CHECK(program_remove(user) == 0, "the program is removed");
    sweeps = sweep_until_freed(placed_unit);
    CHECK(sweeps > 0, "and then a sweep frees the code (%d sweeps)", sweeps);
    /* }}} */

    /* {{{ an older unit of a file retired, the newer answering */
    int older = compile("/boxes/version.c", "#include <stdint.h>\nint64_t which(int64_t v)\n{\n    return v + 1;\n}\n");
    int newer = compile("/boxes/version.c", "#include <stdint.h>\nint64_t which(int64_t v)\n{\n    return v + 2;\n}\n");
    const struct box *newest = catalogue_box("/boxes/version.c:which");
    CHECK(older >= 0 && newer > older && compile_retire(older) == 0 && catalogue_box("/boxes/version.c:which") == newest && newest,
          "retiring the older unit of a file leaves the newer answering its address");
    CHECK(sweep_until_freed(older) > 0 && state_of(newer) == UNIT_LOADED, "and only the older is freed");
    /* }}} */

    /* {{{ a teardown racing a sweep frees each unit exactly once */
    int first = compile_unit_count();
    int compiled = 0;
    for (int i = 0; i < RACERS; i++) {
        char path[64], source[160];
        snprintf(path, sizeof path, "/boxes/racer-%d.c", i);
        snprintf(source, sizeof source, "#include <stdint.h>\nint64_t racer_%d(int64_t v)\n{\n    return v - %d;\n}\n", i, i);
        compiled += compile(path, source) >= 0;
    }
    /* Retiring sweeps too, so some may be freed before the race starts;
     * the count is taken first so those are counted, once, as well. */
    uint64_t freed_start = compile_units_freed();
    for (int i = 0; i < RACERS; i++) compile_retire(first + i);
    racing = 1;
    pthread_t a, b;
    pthread_create(&a, NULL, sweeper, NULL);
    pthread_create(&b, NULL, sweeper, NULL);
    int by_teardown = 0;
    for (int round = 0; round < 50; round++) by_teardown += compile_teardown();
    racing = 0;
    pthread_join(a, NULL);
    pthread_join(b, NULL);
    by_teardown += compile_teardown();
    int all_freed = 1;
    for (int i = 0; i < RACERS; i++) all_freed &= state_of(first + i) == UNIT_FREED;
    CHECK(compiled == RACERS && all_freed && compile_units_freed() == freed_start + RACERS,
          "%d retired units, a teardown racing two sweepers: each freed exactly once (%llu freed, %d by the teardown)",
          RACERS, (unsigned long long)(compile_units_freed() - freed_start), by_teardown);
    CHECK(busy_runs(busy) > runs_after, "and the busy programs are still running");
    /* }}} */

    twin_engine_stop();
    CHECK_DONE("089 reclaim");
}
