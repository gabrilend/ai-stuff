/*
 * 076-written-down.c — phase 3's demo: a program written down (issue 312).
 *
 * General description: eight scenes, each measured first into a record of
 * facts and only then told from that record, so the telling cannot change
 * what was measured. The round trip (a file in, a program running, the
 * program back out as a file that reads into the same program); the
 * catalogue as the joint (a misspelled box refused, saying what the file
 * does hold); both ends of a wire (four disagreements told apart); the
 * wire check (two widths refused, naming both types); all of them at
 * once; the loop that is the counter; every way of choosing an exit, with
 * its distribution; a map placed inside a map, twice; and a box taking
 * itself out of service while everything else runs, then brought back.
 * The results are drawn on both screens and written as a picture.
 *
 * Usage: 076-written-down [--png path]
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/engine/038-tallies.h"
#include "../../src/system/058-draw.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "../057-screens-twin.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* One scene's record: what it measured, whether that is what it should
 * be, and the one-line finding. */
struct scene {
    const char *title;
    int         passed;
    char        finding[160];
    char        detail[16384];
};

static struct scene scenes[9];
static int n_scenes;
static char log_path[512];

/* {{{ read_log */
static const char *read_log(void)
{
    static char buf[1 << 16];
    FILE *f = fopen(log_path, "r");
    size_t n = f ? fread(buf, 1, sizeof buf - 1, f) : 0;
    if (f) fclose(f);
    buf[n] = 0;
    return buf;
}
/* }}} */

/* {{{ load */
static int load(const char *path, const char *text, struct map_report *report)
{
    return program_load_text(path, text, strlen(text), report);
}
/* }}} */

/* {{{ tally_count */
static uint64_t tally_count(int program, const char *station)
{
    uint64_t c;
    int64_t s;
    tally_read(program_station(program, station), &c, &s);
    return c;
}
/* }}} */

/* {{{ scene_round_trip */
static void scene_round_trip(struct scene *s)
{
    struct map_report report;
    int p = program_load("src/maps/greeting.map", &report);
    twin_engine_settle(2000);
    static char first[8192], second[8192];
    program_write(p, first, sizeof first);
    int q = load("src/maps/greeting-again.map", first, &report);
    program_write(q, second, sizeof second);
    int said = strstr(read_log(), "WORLD\n") != NULL;
    int same = strcmp(strchr(first, '\n'), strchr(second, '\n')) == 0;
    s->passed = p >= 0 && said && q >= 0 && same;
    snprintf(s->finding, sizeof s->finding, "WORLD said: %s; written out and read back: %s; written twice: %s",
             said ? "yes" : "no", q >= 0 ? "loads" : "refused", same ? "identical" : "DIFFERENT");
    snprintf(s->detail, sizeof s->detail, "%s", first);
}
/* }}} */

/* {{{ scene_catalogue */
static void scene_catalogue(struct scene *s)
{
    struct map_report report;
    int p = load("src/maps/misspelled.map",
        "station greeting (../boxes/063-text.c:constant_text)\n  in 0 = \"world\"\n  out 0 - shout.0\n"
        "station shout (../boxes/063-text.c:to_uppr)\n  in 0 - greeting.0\n", &report);
    s->passed = p < 0 && report.problems == 1 && strstr(report.text, "to_upper");
    snprintf(s->finding, sizeof s->finding, "refused, naming the file it looked in and what that file holds");
    snprintf(s->detail, sizeof s->detail, "%s", report.text);
}
/* }}} */

/* {{{ scene_both_ends */
static void scene_both_ends(struct scene *s)
{
    struct map_report report;
    int p = load("src/maps/ends.map",
        "b = ../boxes/062-arithmetic.c\n"
        "station a (b:constant)\n  in 0 = 1\n  out 0 - b1.0\n"
        "station b1 (b:increment)\n  in 0 -\n"
        "station c (b:increment)\n  in 0 - a.0\n"
        "station d (b:add)\n  in 0 - e.0\n  in 1 - ghost.0\n"
        "station e (b:increment)\n  in 0 -\n  out 0 - d.1\n", &report);
    s->passed = p < 0 && report.problems == 4;
    snprintf(s->finding, sizeof s->finding, "%d disagreements, four kinds, all in one run", report.problems);
    snprintf(s->detail, sizeof s->detail, "%s", report.text);
}
/* }}} */

/* {{{ scene_widths */
static void scene_widths(struct scene *s)
{
    struct map_report report;
    int p = load("src/maps/widths.map",
        "station greeting (../boxes/063-text.c:constant_text)\n  in 0 = \"world\"\n  out 0 - count.0\n"
        "station count (../boxes/064-launch.c:say_number)\n  in 0 - greeting.0\n", &report);
    s->passed = p < 0 && strstr(report.text, "64 bytes") && strstr(report.text, "8 bytes");
    snprintf(s->finding, sizeof s->finding, "refused: a 64-byte text into an 8-byte number, both types named");
    snprintf(s->detail, sizeof s->detail, "%s", report.text);
}
/* }}} */

/* {{{ scene_all_at_once */
static void scene_all_at_once(struct scene *s)
{
    struct map_report report;
    int p = load("src/maps/everything.map",
        "boxes = ../boxes/\n"
        "station one (boxes/062-arithmetic.c:constant)\n  in 0 = 12x\n  in 3 = 1\n  out 0 - two.0\n"
        "station two (boxes/062-arithmetic.c:nothing_here)\n  in 0 - one.0\n"
        "frobnicate three\n"
        "boxes2 = somewhere\n"
        "station one (boxes/062-arithmetic.c:pass)\n", &report);
    s->passed = p < 0 && report.problems == 6;
    snprintf(s->finding, sizeof s->finding, "%d mistakes of six kinds reported in one run, in file order", report.problems);
    snprintf(s->detail, sizeof s->detail, "%s", report.text);
}
/* }}} */

/* {{{ scene_counter */
static void scene_counter(struct scene *s)
{
    struct map_report report;
    int p = program_load("src/maps/counting.map", &report);
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
    int64_t result = 0;
    int got = program_result(p, 0, &result, sizeof result);
    s->passed = p >= 0 && in_order && got == 1 && result == 10;
    snprintf(s->finding, sizeof s->finding, "said 1 to 10 in order through a backwards arrow; result door holds %lld", (long long)result);
    snprintf(s->detail, sizeof s->detail, "the old design refused any map with a loop; this map could not count without one");
}
/* }}} */

/* {{{ scene_kinds */
static void scene_kinds(struct scene *s)
{
    struct map_report report;
    const char *text =
        "p = ../boxes/062-arithmetic.c\n"
        "iterator deal (p:pass)\n  in 0 - 0$\n  out 0 - i0.0\n  out 1 - i1.0\n  out 2 - i2.0\n"
        "random pick (p:pass)\n  in 0 - 1$\n  out 0 - r0.0\n  out 1 - r1.0\n  out 2 - r2.0\n"
        "weighted lean (p:pass)\n  in 0 - 2$\n  in 1 = { 1, 2, 5 }\n  out 0 - w0.0\n  out 1 - w1.0\n  out 2 - w2.0\n"
        "comparator split (p:below)\n  in 0 - 3$\n  in 1 = 50\n  out 0 - lo.0\n  out 1 - eq.0\n  out 2 - hi.0\n"
        "station i0 (p:discard)\n  in 0 - deal.0\n" "station i1 (p:discard)\n  in 0 - deal.1\n" "station i2 (p:discard)\n  in 0 - deal.2\n"
        "station r0 (p:discard)\n  in 0 - pick.0\n" "station r1 (p:discard)\n  in 0 - pick.1\n" "station r2 (p:discard)\n  in 0 - pick.2\n"
        "station w0 (p:discard)\n  in 0 - lean.0\n" "station w1 (p:discard)\n  in 0 - lean.1\n" "station w2 (p:discard)\n  in 0 - lean.2\n"
        "station lo (p:discard)\n  in 0 - split.0\n" "station eq (p:discard)\n  in 0 - split.1\n" "station hi (p:discard)\n  in 0 - split.2\n";
    int p = load("src/maps/kinds.map", text, &report);
    const int N = 24000;
    for (int64_t v = 0; v < N; v++) {
        program_argument(p, 0, &v, sizeof v);
        program_argument(p, 1, &v, sizeof v);
        program_argument(p, 2, &v, sizeof v);
        if (v < 100) program_argument(p, 3, &v, sizeof v);
    }
    twin_engine_settle(10000);
    uint64_t it[3] = { tally_count(p, "i0"), tally_count(p, "i1"), tally_count(p, "i2") };
    uint64_t rn[3] = { tally_count(p, "r0"), tally_count(p, "r1"), tally_count(p, "r2") };
    uint64_t wt[3] = { tally_count(p, "w0"), tally_count(p, "w1"), tally_count(p, "w2") };
    uint64_t cm[3] = { tally_count(p, "lo"), tally_count(p, "eq"), tally_count(p, "hi") };
    int ok_it = it[0] == 8000 && it[1] == 8000 && it[2] == 8000;
    int ok_rn = rn[0] > 7400 && rn[0] < 8600 && rn[1] > 7400 && rn[1] < 8600 && rn[2] > 7400 && rn[2] < 8600;
    int ok_wt = wt[0] > 2700 && wt[0] < 3300 && wt[1] > 5400 && wt[1] < 6600 && wt[2] > 14000 && wt[2] < 16000;
    int ok_cm = cm[0] == 50 && cm[1] == 1 && cm[2] == 49;
    s->passed = p >= 0 && ok_it && ok_rn && ok_wt && ok_cm;
    snprintf(s->finding, sizeof s->finding, "iterator exact, random within 7%%, weighted near 1:2:5, comparator exact");
    snprintf(s->detail, sizeof s->detail,
             "iterator  %llu %llu %llu   (expected 8000 each)\n"
             "random    %llu %llu %llu   (expected about 8000 each)\n"
             "weighted  %llu %llu %llu   (expected about 3000 / 6000 / 15000)\n"
             "comparator %llu %llu %llu  (expected 50 below, 1 equal, 49 above)\n",
             (unsigned long long)it[0], (unsigned long long)it[1], (unsigned long long)it[2],
             (unsigned long long)rn[0], (unsigned long long)rn[1], (unsigned long long)rn[2],
             (unsigned long long)wt[0], (unsigned long long)wt[1], (unsigned long long)wt[2],
             (unsigned long long)cm[0], (unsigned long long)cm[1], (unsigned long long)cm[2]);
}
/* }}} */

/* {{{ scene_inside */
static void scene_inside(struct scene *s)
{
    struct map_report report;
    char path[600];
    snprintf(path, sizeof path, "%s/tmp/shared-memory/shout.map", getenv("SOREN_DIR"));
    FILE *f = fopen(path, "w");
    fputs("station up (../../src/boxes/063-text.c:to_upper)\n  in 0 - 0$\n  out 0 - 0$\n", f);
    fclose(f);
    int p = load("tmp/shared-memory/two-shouts.map",
        "t = ../../src/boxes/063-text.c\n"
        "station hello (t:constant_text)\n  in 0 = \"hello\"\n  out 0 - first.0\n"
        "station there (t:constant_text)\n  in 0 = \"there\"\n  out 0 - second.0\n"
        "station first (shout.map)\n  in 0 - hello.0\n  out 0 - say_first.0\n"
        "station second (shout.map)\n  in 0 - there.0\n  out 0 - say_second.0\n"
        "station say_first (t:say)\n  in 0 - first.0\n"
        "station say_second (t:say)\n  in 0 - second.0\n", &report);
    twin_engine_settle(2000);
    const char *log = read_log();
    s->passed = p >= 0 && strstr(log, "HELLO\n") && strstr(log, "THERE\n") && program_child_count(p) == 2;
    snprintf(s->finding, sizeof s->finding, "one map placed twice: two copies, each with its own input, neither disturbing the other");
    snprintf(s->detail, sizeof s->detail, "%s", p < 0 ? report.text : "HELLO and THERE both said");
}
/* }}} */

/* {{{ scene_out_of_service */
static void scene_out_of_service(struct scene *s)
{
    struct map_report report;
    int p = load("src/maps/fussy.map",
        "a = ../boxes/062-arithmetic.c\n"
        "station fussy (a:picky)\n  in 0 - 0$\n  in 1 = 5\n  out 0 - kept.0\n"
        "station calm (a:increment)\n  in 0 - 1$\n  out 0 - calm_sink.0\n"
        "station kept (a:discard)\n  in 0 - fussy.0\n"
        "station calm_sink (a:discard)\n  in 0 - calm.0\n", &report);
    for (int64_t v = 1; v <= 10; v++) {
        program_argument(p, 0, &v, sizeof v);
        twin_engine_settle(500);
        program_argument(p, 1, &v, sizeof v);
    }
    twin_engine_settle(2000);
    int32_t fussy = program_station(p, "fussy");
    struct engine_error_report er;
    engine_read_error(fussy, &er, 0);
    uint64_t kept = tally_count(p, "kept"), calm = tally_count(p, "calm_sink");
    int out = engine_port_tag(fussy, 0) == PORT_NONE;
    int64_t limit = 100;
    engine_configure(fussy, 1, PORT_STATIC, &limit, sizeof limit);
    engine_configure(fussy, 0, PORT_RING, NULL, 0);
    twin_engine_settle(2000);
    uint64_t kept_after = tally_count(p, "kept");
    s->passed = p >= 0 && er.kind == 1 && er.detail == 6 && out && kept == 5 && calm == 10 && kept_after == 9;
    snprintf(s->finding, sizeof s->finding, "refused 6, took itself out; its neighbour ran all 10; rewired, it ran the %llu that waited",
             (unsigned long long)(kept_after - kept));
    snprintf(s->detail, sizeof s->detail, "error slot: kind %d, detail %llu, count %llu", er.kind,
             (unsigned long long)er.detail, (unsigned long long)er.count);
}
/* }}} */

/* {{{ draw */
static void draw(void)
{
    struct canvas top = canvas_of_screen(0);
    struct canvas bottom = canvas_of_screen(1);
    draw_fill(top, COLOUR_PAPER);
    draw_fill(bottom, COLOUR_PAPER);
    draw_text(top, 20, 16, "A PROGRAM WRITTEN DOWN", 2, COLOUR_ACCENT, 0);
    int passed = 0;
    for (int i = 0; i < n_scenes; i++) passed += scenes[i].passed;
    char line[160];
    snprintf(line, sizeof line, "%d of %d scenes pass", passed, n_scenes);
    draw_text(top, 20, 56, line, 1, passed == n_scenes ? COLOUR_GOOD : COLOUR_BAD, 0);
    for (int i = 0; i < n_scenes; i++) {
        int y = 90 + i * 42;
        draw_rect(top, 20, y, 12, 12, scenes[i].passed ? COLOUR_GOOD : COLOUR_BAD);
        draw_text(top, 40, y - 2, scenes[i].title, 1, COLOUR_INK, 0);
        char cut[76];
        snprintf(cut, sizeof cut, "%.74s", scenes[i].finding);
        draw_text(top, 40, y + 16, cut, 1, COLOUR_QUIET, 0);
    }
    platform_screen_present(0);
    /* The bottom screen shows the greeting written back out: the round
     * trip's own text. */
    draw_text(bottom, 20, 16, "greeting.map, written back out", 1, COLOUR_ACCENT, 0);
    int y = 44;
    for (const char *p = scenes[0].detail; *p && y < 460; y += 17) {
        int n = 0;
        while (p[n] && p[n] != '\n' && n < 76) n++;
        char row[80];
        memcpy(row, p, (size_t)n);
        row[n] = 0;
        draw_text(bottom, 20, y, row, 1, row[0] == '#' ? COLOUR_QUIET : COLOUR_INK, 0);
        p += n;
        if (*p == '\n') p++;
    }
    platform_screen_present(1);
}
/* }}} */

int main(int argc, char **argv)
{
    const char *png = NULL;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--png") && i + 1 < argc) png = argv[++i];
    }
    snprintf(log_path, sizeof log_path, "%s/tmp/shared-memory/demos/phase-3/developer-line.log", getenv("SOREN_DIR"));
    remove(log_path);
    twin_engine_start(4, (size_t)512 << 20);
    twin_platform_set_log(log_path, 0);
    engine_open_gate();
    metrics_open("076-written-down");

    static void (*const run[])(struct scene *) = {
        scene_round_trip, scene_catalogue, scene_both_ends, scene_widths, scene_all_at_once,
        scene_counter, scene_kinds, scene_inside, scene_out_of_service,
    };
    static const char *const titles[] = {
        "the round trip", "the catalogue is the joint", "both ends of a wire", "the wire check",
        "all of them at once", "the loop is the counter", "every way of choosing an exit",
        "a map inside a map", "a box takes itself out",
    };
    n_scenes = (int)(sizeof run / sizeof run[0]);
    for (int i = 0; i < n_scenes; i++) {
        scenes[i].title = titles[i];
        run[i](&scenes[i]);
    }
    int passed = 0;
    for (int i = 0; i < n_scenes; i++) {
        passed += scenes[i].passed;
        printf("\n=== %d. %s: %s\n    %s\n", i + 1, scenes[i].title, scenes[i].passed ? "PASS" : "FAIL", scenes[i].finding);
        if (scenes[i].detail[0]) {
            printf("%s%s", scenes[i].detail, scenes[i].detail[strlen(scenes[i].detail) - 1] == '\n' ? "" : "\n");
        }
        char key[64];
        snprintf(key, sizeof key, "written_down.scene%d_passed", i + 1);
        metric_record(key, scenes[i].passed, "bool", "written-down-scenes", scenes[i].title);
    }
    metric_record("written_down.scenes_passed", passed, "scenes", "written-down-scenes", "scenes of the phase 3 demo that passed");
    metrics_close();
    draw();
    if (png) {
        twin_screens_save_png(png);
        printf("\nscreens written to %s\n", png);
    }
    printf("\n%d of %d scenes pass — %s\n", passed, n_scenes, passed == n_scenes ? "PASS" : "FAIL");
    twin_engine_stop();
    return passed == n_scenes ? 0 : 1;
}
