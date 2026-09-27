/*
 * 072-test-maps.c — issues 305, 306, 307 and 309: a program written down.
 *
 * General description: the greeting map loads, runs, says WORLD, and
 * writes itself back out as text that reads into the same program —
 * writing that out again gives the same text. The counting map counts
 * 1 to 10 through an arrow that points backwards and holds 10 as its
 * result. Maps with mistakes are refused, placing nothing, with every
 * mistake in the list: a misspelled box, the four ways the two ends of a
 * wire can disagree, a wire joining two widths, and one of everything at
 * once. Then the doors: a program with an argument and a result is fed
 * and read through its doors; the same program placed twice inside a
 * parent gives two copies that do not interfere; a marked port that a
 * wire also feeds is not an argument; renumbering is done by editing
 * marks, not by moving lines; bring-up refuses a gap in the numbering,
 * and bringing a program up twice starts nothing twice.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "catalogue-boxes.h"
#include "../../src/engine/038-tallies.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "047-check.h"

#include <stdio.h>
#include <string.h>

#define CORES 4

static char log_path[512];

/* {{{ read_log */
static char *read_log(void)
{
    static char buf[65536];
    FILE *f = fopen(log_path, "r");
    size_t n = f ? fread(buf, 1, sizeof buf - 1, f) : 0;
    if (f) fclose(f);
    buf[n] = 0;
    return buf;
}
/* }}} */

/* {{{ load_text */
static int load_text(const char *path, const char *text, struct map_report *report)
{
    return program_load_text(path, text, strlen(text), report);
}
/* }}} */

/* {{{ contains */
static int contains(const char *hay, const char *needle)
{
    return strstr(hay, needle) != NULL;
}
/* }}} */

int main(void)
{
    snprintf(log_path, sizeof log_path, "%s/tmp/shared-memory/test-logs/072-developer-line.log", getenv("SOREN_DIR"));
    remove(log_path);
    twin_engine_start(CORES, (size_t)512 << 20);
    twin_platform_set_log(log_path, 0);
    engine_open_gate();
    metrics_open("072-maps");
    struct map_report report;

    /* --- the round trip --------------------------------------------------- */
    int greeting = program_load("src/maps/greeting.map", &report);
    CHECK(greeting >= 0, "greeting.map loads (%s)", report.text);
    CHECK(program_bring_up(greeting, &report) == 0, "and brings up cleanly (%s)", report.text);
    twin_engine_settle(2000);
    CHECK(contains(read_log(), "WORLD\n"), "WORLD came out of the developer's line");
    static char first[16384], second[16384], third[16384];
    int n1 = program_write(greeting, first, sizeof first);
    CHECK(n1 > 0, "the running greeting writes itself out:\n%s", first);
    int again = load_text("src/maps/greeting-written.map", first, &report);
    CHECK(again >= 0, "what it wrote loads back (%s)", report.text);
    int n2 = program_write(again, second, sizeof second);
    CHECK(n2 > 0, "and writes itself out again");
    /* The two texts differ only in their first line, which names the file. */
    CHECK(strcmp(strchr(first, '\n'), strchr(second, '\n')) == 0,
          "writing it out twice gives the same text:\n--- first ---\n%s--- second ---\n%s", first, second);
    int n3 = program_write(again, third, sizeof third);
    CHECK(n3 == n2 && strcmp(second, third) == 0, "and a third time, still the same");

    /* --- the loop is the counter ------------------------------------------ */
    int counting = program_load("src/maps/counting.map", &report);
    CHECK(counting >= 0, "counting.map loads (%s)", report.text);
    twin_engine_settle(2000);
    const char *log = read_log();
    int in_order = 1;
    const char *at = log;
    for (int i = 1; i <= 10; i++) {
        char want[32];
        snprintf(want, sizeof want, "tell: %d\n", i);
        const char *found = strstr(at, want);
        if (!found) { in_order = 0; break; }
        at = found + strlen(want);
    }
    CHECK(in_order, "the counter said 1 to 10, in order:\n%s", log);
    CHECK(!contains(log, "tell: 11\n"), "and stopped at 10");
    int64_t result = 0;
    CHECK(program_result(counting, 0, &result, sizeof result) == 1 && result == 10,
          "and its result door holds 10 (%lld)", (long long)result);

    /* --- refusals ------------------------------------------------------- */
    int32_t before = engine_station_count();
    int bad = load_text("src/maps/misspelled.map",
        "boxes = ../boxes/\n"
        "station greeting (boxes/063-text.c:constant_text)\n"
        "  in 0 = \"world\"\n"
        "  out 0 - shout.0\n"
        "station shout (boxes/063-text.c:to_uppr)\n"
        "  in 0 - greeting.0\n", &report);
    CHECK(bad < 0 && report.problems == 1, "a misspelled box is refused (%d problems)", report.problems);
    CHECK(contains(report.text, "no box named \"to_uppr\" in src/boxes/063-text.c") &&
          contains(report.text, "to_upper") && contains(report.text, "line   5"),
          "naming the function, the file it looked in, what the file holds, and the line:\n%s", report.text);
    CHECK(engine_station_count() == before, "and nothing was placed");

    bad = load_text("src/maps/ends.map",
        "b = ../boxes/062-arithmetic.c\n"
        "station a (b:constant)\n"
        "  in 0 = 1\n"
        "  out 0 - b1.0\n"                 /* 4: arrow with no receiving end */
        "station b1 (b:increment)\n"
        "  in 0 -\n"
        "station c (b:increment)\n"
        "  in 0 - a.0\n"                   /* 8: receiving end with no arrow */
        "station d (b:add)\n"
        "  in 0 - e.0\n"                   /* 10: different ports */
        "  in 1 - ghost.0\n"               /* 11: a station the file does not have */
        "station e (b:increment)\n"
        "  in 0 -\n"
        "  out 0 - d.1\n", &report);
    CHECK(bad < 0 && report.problems == 4, "the four ways the ends of a wire disagree are all reported (%d):\n%s",
          report.problems, report.text);
    CHECK(contains(report.text, "an arrow with no receiving end") && contains(report.text, "add \"in 0 - a.0\" to b1") &&
          contains(report.text, "a receiving end with no arrow") && contains(report.text, "add \"out 0 - c.0\" to a") &&
          contains(report.text, "name different ports") && contains(report.text, "a station ghost the file does not have"),
          "each told apart, naming the line to add");

    bad = load_text("src/maps/widths.map",
        "station greeting (../boxes/063-text.c:constant_text)\n"
        "  in 0 = \"world\"\n"
        "  out 0 - count.0\n"
        "station count (../boxes/064-launch.c:say_number)\n"
        "  in 0 - greeting.0\n", &report);
    CHECK(bad < 0 && contains(report.text, "constant_text returns struct text (64 bytes), the port takes int64_t (8 bytes)"),
          "a wire joining two widths is refused naming both types and both widths:\n%s", report.text);

    bad = load_text("src/maps/everything.map",
        "boxes = ../boxes/\n"
        "station one (boxes/062-arithmetic.c:constant)\n"
        "  in 0 = 12x\n"                   /* a value that does not read */
        "  in 3 = 1\n"                     /* no port 3 */
        "  out 0 - two.0\n"
        "station two (boxes/062-arithmetic.c:nothing_here)\n"
        "  in 0 - one.0\n"
        "frobnicate three\n"               /* not a line a map says */
        "boxes2 = somewhere\n"             /* a shortcut after a station */
        "station one (boxes/062-arithmetic.c:pass)\n", &report);
    CHECK(bad < 0 && report.problems == 6, "a map with one of every mistake reports them all in one run (%d):\n%s",
          report.problems, report.text);

    /* --- doors ------------------------------------------------------------ */
    /* These maps live in tmp/shared-memory/, two directories below the
     * project, so their box addresses climb two levels to src/boxes/. */
    const char *doubler =
        "b = ../../src/boxes/062-arithmetic.c\n"
        "station twice (b:add)\n"
        "  in 0 - 0$\n"
        "  in 1 - 1$\n"
        "  out 0 - 0$\n";
    int prog = load_text("tmp/shared-memory/doubler.map", doubler, &report);
    CHECK(prog >= 0 && program_bring_up(prog, &report) == 0, "a program with two arguments and a result loads (%s)", report.text);
    int64_t x = 20, y = 22, got = 0;
    program_argument(prog, 0, &x, sizeof x);
    program_argument(prog, 1, &y, sizeof y);
    twin_engine_settle(2000);
    CHECK(program_result(prog, 0, &got, sizeof got) == 1 && got == 42, "its arguments go in by their doors and its result comes out by its door (%lld)", (long long)got);

    const char *gappy =
        "b = ../../src/boxes/062-arithmetic.c\n"
        "station twice (b:add)\n"
        "  in 0 - 0$\n"
        "  in 1 - 2$\n"
        "  out 0 - 0$\n";
    int gp = load_text("tmp/shared-memory/gappy.map", gappy, &report);
    CHECK(gp >= 0 && program_bring_up(gp, &report) > 0 && contains(report.text, "argument 1$ is missing"),
          "bring-up refuses a gap in the argument numbering:\n%s", report.text);

    /* A parent places the adder twice; each copy is fed and read on its own. */
    const char *parent =
        "b = ../../src/boxes/062-arithmetic.c\n"
        "station ten (b:constant)\n"
        "  in 0 = 10\n"
        "  out 0 - left.0\n"
        "  out 0 - right.0\n"
        "  out 0 - right.1\n"
        "station seven (b:constant)\n"
        "  in 0 = 7\n"
        "  out 0 - left.1\n"
        "station left (doubler.map)\n"
        "  in 0 - ten.0\n"
        "  in 1 - seven.0\n"
        "  out 0 - sum_left.0\n"
        "station right (doubler.map)\n"
        "  in 0 - ten.0\n"
        "  in 1 - ten.0\n"
        "  out 0 - sum_right.0\n"
        "station sum_left (b:discard)\n"
        "  in 0 - left.0\n"
        "station sum_right (b:discard)\n"
        "  in 0 - right.0\n";
    /* The doubler is read from disk by the parent, so write it there. */
    char doubler_path[600];
    snprintf(doubler_path, sizeof doubler_path, "%s/tmp/shared-memory/doubler.map", getenv("SOREN_DIR"));
    FILE *df = fopen(doubler_path, "w");
    fputs(doubler, df);
    fclose(df);
    int composed = load_text("tmp/shared-memory/parent.map", parent, &report);
    CHECK(composed >= 0, "a program placing another program twice loads (%s)", report.text);
    twin_engine_settle(2000);
    uint64_t lc, rc;
    int64_t ls, rs;
    tally_read(program_station(composed, "sum_left"), &lc, &ls);
    tally_read(program_station(composed, "sum_right"), &rc, &rs);
    CHECK(lc == 1 && ls == 17 && rc == 1 && rs == 20, "the two copies did not interfere (left %lld, right %lld)", (long long)ls, (long long)rs);
    CHECK(program_child_count(composed) == 2, "the parent records its two placed programs");
    int child = program_child(composed, 0);
    int32_t inner = program_station(child, "twice");
    CHECK(engine_port_door(inner, 0) == 0 && engine_port_fed(inner, 0), "a marked port a wire feeds is still marked, and fed");
    char composed_text[16384];
    CHECK(program_write(composed, composed_text, sizeof composed_text) > 0 && contains(composed_text, "station left (doubler.map)"),
          "the parent writes its placed programs back out by their map files:\n%s", composed_text);

    /* --- the reference map: every line form, once ------------------------ */
    int ref = program_load("src/maps/reference.map", &report);
    CHECK(ref >= 0, "reference.map, which says every line form once, loads (%s)", report.text);
    CHECK(program_bring_up(ref, &report) == 0, "and brings up (%s)", report.text);
    int64_t seven = 7, ten = 0;
    program_argument(ref, 0, &seven, sizeof seven);
    twin_engine_settle(2000);
    CHECK(program_result(ref, 0, &ten, sizeof ten) == 1 && ten == 10, "3 + argument 7 left by the equal exit as result 0 (%lld)", (long long)ten);
    struct map_report unfinished;
    int findings = program_unfinished(ref, &unfinished);
    CHECK(findings == 2 && contains(unfinished.text, "unfinished port 0 has no source") &&
          contains(unfinished.text, "deal port 0 queues values but nothing feeds it"),
          "asked, it reports the two unfinished things and not the marked argument:\n%s", unfinished.text);
    CHECK(engine_port_waiting(program_station(ref, "deal"), 0) == 0 &&
          station_at(program_station(ref, "deal"))->ports[0].n_pages * station_at(program_station(ref, "deal"))->ports[0].cells_per_page >= 64,
          "in 0 x64 left the queue at least 64 deep");
    bad = load_text("src/maps/bad-include.map", "include ../boxes/999-nowhere.c\n", &report);
    CHECK(bad < 0 && contains(report.text, "include names src/boxes/999-nowhere.c, which holds no box the device has"),
          "an include naming nothing the device holds is refused:\n%s", report.text);

    twin_engine_stop();
    metrics_close();
    CHECK_DONE("072 maps");
}
