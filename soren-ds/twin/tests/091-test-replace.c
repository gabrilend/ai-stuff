/*
 * 091-test-replace.c — issue 411.
 *
 * General description: a box in a running program is replaced by a new
 * station, the arrows moved onto it, the old station left placed and
 * unwired. Values streaming through a program while one of its boxes is
 * replaced come out whole, each made by the old box or the new, never a
 * mixture, and every value delivered after the replacement returns is the
 * new box's. Values waiting in the old station stay exactly where they
 * were, and a rollback puts the arrows back so they can still be used.
 * The two stations are swapped back and forth, the program's own name,
 * doors and written-out text following the arrows each time. A new box of
 * a different width is refused, naming both types and both widths, and
 * nothing changes. Finishing removes the unwired station; removing a
 * program takes an unfinished replacement's spare with it. And the whole
 * authoring loop: a file compiled twice, the newer swapped in, the older's
 * code freed once nothing places it (409, 410).
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/engine/070-catalogue.h"
#include "../../src/engine/087-compile.h"
#include "../../src/engine/090-replace.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "047-check.h"

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

struct text {
    char chars[64];
};

#define STREAM 3000

static struct map_report report;
static struct compile_report words;
static char log_path[600];

/* {{{ compile */
static int compile(const char *path, const char *source)
{
    int r = compile_box_source(path, source, strlen(source), &words);
    if (r < 0) fprintf(stderr, "%s did not compile:\n%s\n", path, words.text);
    return r;
}
/* }}} */

/* {{{ load */
static int load(const char *path, const char *text)
{
    int p = program_load_text(path, text, strlen(text), &report);
    if (p < 0 || program_bring_up(p, &report) != 0) {
        fprintf(stderr, "%s did not load:\n%s\n", path, report.text);
        return -1;
    }
    return p;
}
/* }}} */

/* {{{ say */
static struct text say(const char *s)
{
    struct text t;
    memset(&t, 0, sizeof t);
    snprintf(t.chars, sizeof t.chars, "%s", s);
    return t;
}
/* }}} */

/* {{{ through */
/* One text in by door 0, the result out of door 0, or "" if none came. */
static struct text through(int program, const char *in)
{
    struct text t = say(in), out;
    program_argument(program, 0, &t, sizeof t);
    twin_engine_settle(2000);
    if (program_result(program, 0, &out, sizeof out) != 1) return say("");
    return out;
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

/* {{{ the stream */
static int stream_program;
static volatile int delivered;

static void *deliverer(void *arg)
{
    (void)arg;
    for (int i = 0; i < STREAM; i++) {
        char s[32];
        snprintf(s, sizeof s, "v%d", i);
        struct text t = say(s);
        program_argument(stream_program, 0, &t, sizeof t);
        __atomic_store_n(&delivered, i + 1, __ATOMIC_RELEASE);
        if (i % 64 == 0) {
            struct timespec pause = { 0, 200000 };
            nanosleep(&pause, NULL);
        }
    }
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
    snprintf(log_path, sizeof log_path, "%s/tmp/shared-memory/test-logs/091-developer-line.log", dir);
    remove(log_path);
    twin_engine_start(4, (size_t)256 << 20);
    twin_platform_set_log(log_path, 0);
    engine_open_gate();

    const char *text_type = "#include <stdint.h>\nstruct text { char chars[64]; };\n";
    char source[1024];
    snprintf(source, sizeof source,
             "%sstruct text shout(struct text t)\n{\n    int n = 0;\n"
             "    while (n < 62 && t.chars[n]) {\n        if (t.chars[n] >= 'a' && t.chars[n] <= 'z') t.chars[n] -= 32;\n        n++;\n    }\n"
             "    t.chars[n] = '!';\n    t.chars[n + 1] = 0;\n    return t;\n}\n", text_type);
    CHECK(compile("/boxes/loud.c", source) >= 0, "a louder to_upper compiles");
    snprintf(source, sizeof source,
             "%sstruct text glue(struct text a, struct text b)\n{\n    int n = 0;\n    while (n < 62 && a.chars[n]) n++;\n"
             "    a.chars[n++] = '+';\n    for (int i = 0; n < 63 && b.chars[i]; i++) a.chars[n++] = b.chars[i];\n"
             "    a.chars[n] = 0;\n    return a;\n}\n", text_type);
    CHECK(compile("/boxes/glue.c", source) >= 0, "and a join that glues with a plus");
    CHECK(compile("/boxes/count.c", "#include <stdint.h>\nint64_t count(int64_t v)\n{\n    return v + 1;\n}\n") >= 0,
          "and a box of another width");

    /* {{{ the output changes at the first run after, and never mid-value */
    const char *chain =
        "t = ../boxes/063-text.c\n"
        "station up (t:to_upper)\n  in 0 - 0$\n  out 0 - j.0\n"
        "station j (t:join)\n  in 0 - up.0\n  in 1 = \" end\"\n  out 0 - 0$\n";
    int p = load("src/maps/chain.map", chain);
    CHECK(p >= 0 && strcmp(through(p, "abc").chars, "ABC end") == 0, "a running program shouts and ends: abc gives ABC end");
    int32_t old_up = program_station(p, "up");
    int32_t stations_before = engine_station_count();

    stream_program = p;
    pthread_t feeder;
    pthread_create(&feeder, NULL, deliverer, NULL);
    while (__atomic_load_n(&delivered, __ATOMIC_ACQUIRE) < STREAM / 3) {
        struct timespec pause = { 0, 100000 };
        nanosleep(&pause, NULL);
    }
    int r = replace_station(p, "up", "/boxes/loud.c:shout", &report);
    int after = __atomic_load_n(&delivered, __ATOMIC_ACQUIRE) + 1;
    pthread_join(feeder, NULL);
    twin_engine_settle(5000);
    CHECK(r >= 0, "while values stream through it, up is replaced by /boxes/loud.c:shout (%s)", report.text);

    static char seen[STREAM];
    int torn = 0, late_old = 0, twice = 0, old_form = 0, new_form = 0;
    struct text out;
    while (program_result(p, 0, &out, sizeof out) == 1) {
        int n = -1, end = 0;
        char bang = 0;
        if (sscanf(out.chars, "V%d%n", &n, &end) == 1 && n >= 0 && n < STREAM) {
            char want_old[40], want_new[40];
            snprintf(want_old, sizeof want_old, "V%d end", n);
            snprintf(want_new, sizeof want_new, "V%d! end", n);
            if (strcmp(out.chars, want_old) == 0) {
                old_form++;
                late_old += n >= after;
            } else if (strcmp(out.chars, want_new) == 0) {
                new_form++;
                bang = 1;
            } else {
                torn++;
            }
            twice += seen[n]++ > 0;
        } else {
            torn++;
        }
        (void)bang;
    }
    CHECK(torn == 0 && twice == 0, "every value that came out was whole: one box's or the other's, each once (%d torn, %d twice)", torn, twice);
    CHECK(late_old == 0 && new_form > 0 && old_form > 0,
          "and none delivered after the replacement returned was the old box's (%d old, %d new, %d lost in the move)",
          old_form, new_form, STREAM - old_form - new_form);
    CHECK(program_station(p, "up") == replacement_live(r) && replacement_spare(r) == old_up && engine_station_box(old_up),
          "the program's name follows the arrows; the old station is still placed, unwired");
    CHECK(engine_station_count() == stations_before + 1, "one station was added, none removed");
    CHECK(strcmp(through(p, "xyz").chars, "XYZ! end") == 0, "xyz now gives XYZ! end");
    /* }}} */

    /* {{{ swapped back and forth */
    int alternated = 1;
    for (int i = 0; i < 10; i++) {
        alternated &= replacement_swap(r) == 0;
        const char *want = i % 2 == 0 ? "HI end" : "HI! end";
        alternated &= strcmp(through(p, "hi").chars, want) == 0;
    }
    CHECK(alternated, "rolled back and forward ten times, each swap changes what comes out");
    CHECK(program_station(p, "up") == replacement_live(r), "and the name follows each time");
    CHECK(log_says("replaced: up in src/maps/chain.map now places /boxes/loud.c:shout") &&
          log_says("replaced: up in src/maps/chain.map back on"), "the developer's line says what happened each way");
#ifdef SOREN_DEBUG
    struct transcript_event events[64];
    uint64_t from = 1, next = 0;
    int found = 0;
    for (;;) {
        int got = transcript_read(from, events, 64, &next);
        for (int k = 0; k < got; k++) found += events[k].kind == TRANSCRIPT_REPLACED && events[k].station == replacement_live(r);
        if (got <= 0) break;
        from = next;
    }
    CHECK(found > 0, "and the transcript recorded the swaps, naming the station the arrows went to (%d)", found);
#endif
    /* }}} */

    /* {{{ a different width is refused and changes nothing */
    int32_t live_before = program_station(p, "up");
    int32_t count_before = engine_station_count();
    CHECK(replace_station(p, "up", "/boxes/count.c:count", &report) == REPLACE_DIFFERENT_SHAPE &&
          strstr(report.text, "up.0: shout takes struct text (64 bytes), count takes int64_t (8 bytes)") &&
          strstr(report.text, "shout returns struct text (64 bytes), count returns int64_t (8 bytes)"),
          "a box of another width is refused, naming both types and both widths:\n%s", report.text);
    CHECK(program_station(p, "up") == live_before && engine_station_count() == count_before &&
          strcmp(through(p, "ok").chars, "OK! end") == 0, "and nothing changed");
    /* }}} */

    /* {{{ values waiting in the old station stay where they were */
    int q = load("src/maps/pair.map",
                 "t = ../boxes/063-text.c\n"
                 "station j (t:join)\n  in 0 - 0$\n  in 1 - 1$\n  out 0 - tail.0\n"
                 "station tail (t:to_upper)\n  in 0 - j.0\n  out 0 - 0$\n");
    for (int i = 0; i < 5; i++) {
        struct text t = say("left");
        program_argument(q, 0, &t, sizeof t);
    }
    twin_engine_settle(2000);
    int32_t old_j = program_station(q, "j");
    CHECK(engine_port_waiting(old_j, 0) == 5, "five values wait in a join for a partner");
    int rq = replace_station(q, "j", "/boxes/glue.c:glue", &report);
    twin_engine_settle(2000);
    CHECK(rq >= 0 && engine_port_waiting(old_j, 0) == 5 && engine_port_waiting(replacement_live(rq), 0) == 0 &&
          program_result(q, 0, &out, sizeof out) == 0,
          "replaced, they stay in the old station, are not moved and not delivered (%s)", report.text);
    struct text a = say("a"), b = say("b");
    program_argument(q, 0, &a, sizeof a);
    program_argument(q, 1, &b, sizeof b);
    twin_engine_settle(2000);
    CHECK(program_result(q, 0, &out, sizeof out) == 1 && strcmp(out.chars, "A+B") == 0, "new values reach the new box: A+B");
    CHECK(engine_port_waiting(old_j, 0) == 5, "and the old station's five are still there");
    uint64_t old_runs = engine_station_runs(old_j);
    struct text stray = say("stray");
    engine_deliver(old_j, 1, &stray, sizeof stray);
    twin_engine_settle(2000);
    CHECK(engine_station_runs(old_j) == old_runs + 1 && program_result(q, 0, &out, sizeof out) == 0,
          "a value that still lands in the old station runs it, and what it makes goes nowhere");
    CHECK(replacement_swap(rq) == 0, "the replacement is rolled back");
    int joined = 0;
    for (int i = 0; i < 5; i++) {         /* one more than are waiting: it stays */
        struct text right = say("right");
        program_argument(q, 1, &right, sizeof right);
    }
    twin_engine_settle(2000);
    while (program_result(q, 0, &out, sizeof out) == 1) joined += strcmp(out.chars, "LEFTRIGHT") == 0;
    CHECK(joined == 4 && engine_port_waiting(old_j, 0) == 0 && engine_port_waiting(old_j, 1) == 1,
          "and the four still waiting meet their partners in the old box (%d)", joined);
    int32_t spare_q = replacement_spare(rq);
    CHECK(program_remove(q) == 0 && engine_station_box(spare_q) == NULL,
          "removing the program takes the unfinished replacement's spare with it");
    /* }}} */

    /* {{{ finishing */
    int32_t spare = replacement_spare(r);
    CHECK(replacement_finish(r) == 0 && engine_station_box(spare) == NULL, "finishing removes the unwired station");
    CHECK(replacement_swap(r) == REPLACE_NO_REPLACEMENT, "after which there is nothing to roll back to");
    char written[4096];
    int len = program_write(p, written, sizeof written);
    CHECK(len > 0 && strstr(written, "station up (/boxes/loud.c:shout)") && strstr(written, "out 0 - j.0"),
          "written back out, the program places the new box under the old name:\n%s", written);
    int again = program_load_text("src/maps/chain-again.map", written, (size_t)len, &report);
    CHECK(again >= 0 && program_bring_up(again, &report) == 0 && strcmp(through(again, "re").chars, "RE! end") == 0,
          "and reads back in as the same program (%s)", report.text);
    /* }}} */

    /* {{{ the authoring loop: compile, swap in, retire the old code */
    int v1 = compile("/boxes/step.c", "#include <stdint.h>\nint64_t step(int64_t v)\n{\n    return v + 1;\n}\n");
    int s = load("src/maps/step.map", "station s (/boxes/step.c:step)\n  in 0 - 0$\n  out 0 - 0$\n");
    int v2 = compile("/boxes/step.c", "#include <stdint.h>\nint64_t step(int64_t v)\n{\n    return v + 2;\n}\n");
    int rs = replace_station(s, "s", "/boxes/step.c:step", &report);
    int64_t ten = 10, got = 0;
    program_argument(s, 0, &ten, sizeof ten);
    twin_engine_settle(2000);
    CHECK(v1 >= 0 && v2 > v1 && rs >= 0 && program_result(s, 0, &got, sizeof got) == 1 && got == 12,
          "a file saved again is swapped into the program placing the first save: 10 gives %lld", (long long)got);
    CHECK(replacement_finish(rs) == 0 && compile_retire(v1) == 0, "the swap is finished and the first save retired");
    int freed = 0;
    for (int i = 0; i < 3000 && !freed; i++) {
        engine_sweep();
        struct compile_unit_facts f;
        compile_unit_facts(v1, &f);
        freed = f.state == UNIT_FREED;
        struct timespec pause = { 0, 1000000 };
        nanosleep(&pause, NULL);
    }
    CHECK(freed, "and its code is freed, since nothing places it any more");
    /* }}} */

    twin_engine_stop();
    CHECK_DONE("091 replace");
}
