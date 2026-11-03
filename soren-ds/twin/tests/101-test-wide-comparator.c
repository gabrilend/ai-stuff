/*
 * 101-test-wide-comparator.c — issue 313: a comparator on a value wider
 * than its threshold can hold is refused, not placed.
 *
 * General description: a comparator copies its threshold into
 * ENGINE_THRESHOLD_BYTES of stack before comparing, and on a wider value
 * it used to let nothing out of any exit, with no error anywhere. A box
 * returning 72 bytes, with an ordering, is added to the catalogue by hand
 * (nothing under src/boxes/ is that wide and ordered); a map placing it as
 * a comparator is refused, placing nothing, with a line naming the
 * station, the box, the type, its width and the limit. The same box as a
 * plain station is still fine. And a comparator on exactly the limit —
 * text, 64 bytes — still loads and still splits its values.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/engine/070-catalogue.h"
#include "../../src/engine/027-primitives.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "047-check.h"

#include <stdio.h>
#include <string.h>

#define CORES 2

static char log_path[512];

/* {{{ a box wider than a threshold */
struct wide {
    int64_t v[9];                          /* 72 bytes */
};

static void wide_call(const void *in, void *out)
{
    int64_t x;
    bytes_copy(&x, in, sizeof x);
    struct wide w;
    for (int i = 0; i < 9; i++) w.v[i] = x;
    bytes_copy(out, &w, sizeof w);
}

static int wide_order(const void *a, const void *b)
{
    struct wide x, y;
    bytes_copy(&x, a, sizeof x);
    bytes_copy(&y, b, sizeof y);
    return x.v[0] < y.v[0] ? -1 : (x.v[0] > y.v[0] ? 1 : 0);
}

static const struct box_param wide_params[] = { { "x", "int64_t", 8, 0 } };
static const struct box wide_box = {
    "widen", __FILE__, wide_call, 1, wide_params, 8, sizeof(struct wide), "struct wide", wide_order
};
/* }}} */

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

/* {{{ load */
static int load(const char *path, const char *text, struct map_report *report)
{
    return program_load_text(path, text, strlen(text), report);
}
/* }}} */

int main(void)
{
    snprintf(log_path, sizeof log_path, "%s/tmp/shared-memory/test-logs/101-developer-line.log", getenv("SOREN_DIR"));
    remove(log_path);
    twin_engine_start(CORES, (size_t)128 << 20);
    twin_platform_set_log(log_path, 0);
    engine_open_gate();
    metrics_open("101-wide-comparator");
    struct map_report report;

    CHECK(sizeof(struct wide) > ENGINE_THRESHOLD_BYTES, "the hand-made box is wider than a threshold");
    CHECK(catalogue_add("src/boxes/999-wide.c:widen", &wide_box) == 0, "it joins the catalogue");
    int before = (int)engine_station_count();

    /* --- refused as a comparator ----------------------------------------- */
    int bad = load("src/maps/wide-comparator.map",
        "comparator split (../boxes/999-wide.c:widen)\n"
        "  in 0 = 5\n", &report);
    char want[256];
    snprintf(want, sizeof want, "split is a comparator, but widen returns struct wide, which is 72 bytes; "
             "a comparator can compare values of at most %d bytes (issue 313)", ENGINE_THRESHOLD_BYTES);
    CHECK(bad < 0 && report.problems == 1 && strstr(report.text, want) != NULL,
          "a comparator on 72 bytes is refused, naming the station, the box, the type and the limit:\n%s", report.text);
    CHECK(strstr(report.text, "wide-comparator.map line   1") != NULL || strstr(report.text, "line  1") != NULL ||
          strstr(report.text, "line 1") != NULL, "on the line that places it:\n%s", report.text);
    CHECK((int)engine_station_count() == before, "and nothing is placed");

    /* --- fine as a plain station ----------------------------------------- */
    int plain = load("src/maps/wide-plain.map",
        "station widen (../boxes/999-wide.c:widen)\n"
        "  in 0 = 5\n", &report);
    CHECK(plain >= 0, "the same box placed as a plain station loads (%s)", report.text);
    twin_engine_settle(5000);
    CHECK(engine_station_runs(program_station(plain, "widen")) == 1, "and runs");

    /* --- exactly the limit still works ----------------------------------- */
    CHECK(catalogue_box("src/boxes/063-text.c:constant_text")->return_size == ENGINE_THRESHOLD_BYTES,
          "text is exactly as wide as a threshold");
    int text = load("src/maps/text-comparator.map",
        "comparator before_m (../boxes/063-text.c:constant_text)\n"
        "  in 0 = \"apple\"\n"
        "  in 1 = \"m\"\n"
        "  out 0 - early.0\n"
        "  out 2 - late.0\n"
        "station early (../boxes/063-text.c:say)\n"
        "  in 0 - before_m.0\n"
        "station late (../boxes/063-text.c:say)\n"
        "  in 0 - before_m.2\n", &report);
    CHECK(text >= 0, "a comparator on 64 bytes of text loads (%s)", report.text);
    twin_engine_settle(5000);
    CHECK(engine_station_runs(program_station(text, "early")) == 1 &&
          engine_station_runs(program_station(text, "late")) == 0 && strcmp(read_log(), "apple\n") == 0,
          "and still splits: apple comes before m, out of the below exit:\n%s", read_log());

    twin_engine_stop();
    metrics_close();
    CHECK_DONE("101 wide comparator");
}
