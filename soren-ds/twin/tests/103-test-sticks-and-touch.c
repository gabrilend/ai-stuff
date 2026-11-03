/*
 * 103-test-sticks-and-touch.c — issues 503 and 504: the sticks as
 * changes of direction, the touch panels as down, move and up.
 *
 * General description: first the boxes, called directly. The sticks'
 * resting zone is a circle, not a square; the eight directions are angle
 * sectors, split exactly at 22.5 degrees with no floating point, and the
 * edge can be widened; a stale frame changes nothing. A panel's move is
 * any change of a whole pixel while it stays touched, never on the frame
 * it is first touched; let go, it keeps where it was last touched.
 *
 * Then the input-poll map, driven one frame at a time with the twin's
 * sticks and panels set before each tick and the developer line read
 * after: a stick is said only when its direction changes, both sticks in
 * one line when both change; a touch is said going down and coming up,
 * with the place it was last touched, both screens in one event when
 * they move together.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/system/096-input.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "../099-input-twin.h"
#include "047-check.h"

/* The boxes themselves, called as plain functions (the catalogue holds
 * renamed copies). */
#include "../../src/boxes/095-input.c"

#include <stdio.h>
#include <string.h>

#define CORES 4

/* A comparator compares at most 64 bytes (issue 313). */
_Static_assert(sizeof(struct stick_change) <= 64, "stick_change outgrew a comparator's threshold");
_Static_assert(sizeof(struct touch_event) <= 64, "touch_event outgrew a comparator's threshold");

static char log_path[512];

/* {{{ read_log */
static char *read_log(void)
{
    static char buf[1 << 16];
    FILE *f = fopen(log_path, "r");
    size_t n = f ? fread(buf, 1, sizeof buf - 1, f) : 0;
    if (f) fclose(f);
    buf[n] = 0;
    return buf;
}
/* }}} */

/* {{{ count_lines */
static int count_lines(const char *log, const char *prefix)
{
    int n = 0;
    size_t len = strlen(prefix);
    const char *at = log;
    while (*at) {
        if (strncmp(at, prefix, len) == 0) n++;
        const char *nl = strchr(at, '\n');
        if (!nl) break;
        at = nl + 1;
    }
    return n;
}
/* }}} */

/* {{{ has_line */
static int has_line(const char *log, const char *line)
{
    char want[256];
    snprintf(want, sizeof want, "%s\n", line);
    return strstr(log, want) != NULL;
}
/* }}} */

/* {{{ tick */
static void tick(int program)
{
    int64_t one = 1;
    program_argument(program, 0, &one, sizeof one);
    twin_engine_settle(5000);
}
/* }}} */

/* {{{ dir */
static int32_t dir(int32_t x, int32_t y)
{
    struct stick_tuning t = { 200, 200, 414214, 414214 };
    struct stick_snapshot s = { 1, x, y, 0, 0 };
    return stick_direction(stick_deadband(s, t), t).left;
}
/* }}} */

/* {{{ snap */
static struct touch_snapshot snap(int64_t frame, int bottom_down, int32_t bx, int32_t by,
                                  int top_down, int32_t tx, int32_t ty)
{
    struct touch_snapshot s = { frame, { bottom_down, bx, by, 10 }, { top_down, tx, ty, 10 } };
    return s;
}
/* }}} */

int main(void)
{
    snprintf(log_path, sizeof log_path, "%s/tmp/shared-memory/test-logs/103-developer-line.log", getenv("SOREN_DIR"));
    remove(log_path);
    twin_engine_start(CORES, (size_t)256 << 20);
    twin_platform_set_log(log_path, 0);
    engine_open_gate();
    metrics_open("103-sticks-and-touch");
    struct map_report report;

    /* --- the sticks, called directly ------------------------------------- */
    CHECK(dir(2000, 0) == DIRECTION_E && dir(0, 2000) == DIRECTION_N && dir(-2000, 0) == DIRECTION_W &&
          dir(0, -2000) == DIRECTION_S, "straight pushes are the four straight directions");
    CHECK(dir(1500, 1500) == DIRECTION_NE && dir(1500, -1500) == DIRECTION_SE &&
          dir(-1500, -1500) == DIRECTION_SW && dir(-1500, 1500) == DIRECTION_NW,
          "diagonal pushes are the four diagonals");
    CHECK(dir(1000000, 414214) == DIRECTION_E && dir(1000000, 414215) == DIRECTION_NE,
          "the edge between east and north-east is at 22.5 degrees");
    CHECK(dir(199, 0) == DIRECTION_NONE && dir(141, 141) == DIRECTION_NONE && dir(150, 150) == DIRECTION_NE,
          "the resting zone is a circle: 150,150 is outside it, though a square of 200 would hold it");
    struct stick_tuning wide = { 200, 200, 1000000, 1000000 };
    struct stick_snapshot almost = { 1, 1500, 1400, 0, 0 };
    CHECK(stick_direction(almost, wide).left == DIRECTION_E,
          "a wider edge (45 degrees) makes every push but an exact diagonal straight");
    struct stick_history h = sticks_at_rest(0);
    struct stick_directions d5 = { 5, DIRECTION_N, DIRECTION_NONE }, d4 = { 4, DIRECTION_S, DIRECTION_S };
    h = stick_track(d5, h);
    CHECK(h.fresh && h.changed == 1u && h.left == DIRECTION_N, "a change of the left stick is bit 0");
    struct stick_history stale = stick_track(d4, h);
    CHECK(!stale.fresh && stale.left == DIRECTION_N && stick_direction_changed(stale).changed == 0,
          "an older frame arriving late changes nothing");

    /* --- the panels, called directly ------------------------------------- */
    struct touch_history t = touch_at_rest(0);
    t = touch_track(snap(1, 1, 10, 20, 0, 0, 0), t);
    CHECK(touch_down(t).screens == 1u && touch_move(t).screens == 0,
          "the frame a panel is first touched is a down and not a move");
    t = touch_track(snap(2, 1, 10, 20, 0, 0, 0), t);
    CHECK(touch_move(t).screens == 0, "held still is no move");
    t = touch_track(snap(3, 1, 11, 20, 0, 0, 0), t);
    struct touch_event mv = touch_move(t);
    CHECK(mv.screens == 1u && mv.bottom_x == 11 && mv.bottom_y == 20, "a pixel's slide is a move, to where it slid");
    t = touch_track(snap(4, 0, 0, 0, 0, 0, 0), t);
    struct touch_event up = touch_up(t);
    CHECK(up.screens == 1u && up.bottom_x == 11 && up.bottom_y == 20 && !t.bottom.down,
          "let go, it is an up at the place it was last touched, not where the controller says now");
    struct touch_history tstale = touch_track(snap(3, 1, 50, 50, 1, 50, 50), t);
    CHECK(!tstale.fresh && touch_down(tstale).screens == 0 && tstale.bottom.x == 11,
          "an older frame arriving late changes nothing");

    /* --- both, through the input-poll map -------------------------------- */
    int p = program_load(INPUT_POLL_MAP, &report);
    CHECK(p >= 0 && program_bring_up(p, &report) == 0, "input-poll loads and brings up (%s)", report.text);
    twin_engine_settle(5000);

    twin_input_set_sticks(0, 0, 0, 0);
    tick(p);                                                  /* 1 */
    twin_input_set_sticks(2000, 0, 0, 0);       tick(p);      /* 2: left e */
    twin_input_set_sticks(2000, 100, 0, 0);     tick(p);      /* 3: still e */
    twin_input_set_sticks(1500, 1500, 0, 0);    tick(p);      /* 4: left ne */
    twin_input_set_sticks(100, 50, 0, 0);       tick(p);      /* 5: resting: left none */
    twin_input_set_sticks(0, 2000, 0, -2000);   tick(p);      /* 6: left n, right s */
    twin_input_set_sticks(0, 0, 0, 0);          tick(p);      /* 7: both none */
    const char *log = read_log();
    CHECK(has_line(log, "say_sticks: frame 2: left e") && has_line(log, "say_sticks: frame 4: left ne") &&
          has_line(log, "say_sticks: frame 5: left none") && has_line(log, "say_sticks: frame 6: left n right s") &&
          has_line(log, "say_sticks: frame 7: left none right none"),
          "each change of direction is said, both sticks in one line when both change:\n%s", log);
    CHECK(count_lines(log, "say_sticks:") == 5, "and nothing else: a push that stays east is no change (%d lines)",
          count_lines(log, "say_sticks:"));

    twin_input_set_touch(0, 1, 10, 20, 30);     tick(p);      /* 8: bottom down */
    twin_input_set_touch(0, 1, 11, 20, 30);     tick(p);      /* 9: bottom moves */
    twin_input_set_touch(1, 1, 300, 40, 30);    tick(p);      /* 10: top down */
    twin_input_set_touch(0, 0, 0, 0, 0);        tick(p);      /* 11: bottom up */
    twin_input_set_touch(1, 0, 0, 0, 0);        tick(p);      /* 12: top up */
    twin_input_set_touch(0, 1, 5, 6, 30);
    twin_input_set_touch(1, 1, 7, 8, 30);       tick(p);      /* 13: both down */
    twin_input_set_touch(0, 0, 0, 0, 0);
    twin_input_set_touch(1, 0, 0, 0, 0);        tick(p);      /* 14: both up */
    log = read_log();
    CHECK(has_line(log, "say_touch_down: frame 8: bottom 10,20") && has_line(log, "say_touch_down: frame 10: top 300,40"),
          "each panel's first touch is said, with where:\n%s", log);
    CHECK(has_line(log, "say_touch_up: frame 11: bottom 11,20") && has_line(log, "say_touch_up: frame 12: top 300,40"),
          "and its letting go, with where it was last touched");
    CHECK(has_line(log, "say_touch_down: frame 13: bottom 5,6 top 7,8") &&
          has_line(log, "say_touch_up: frame 14: bottom 5,6 top 7,8"),
          "both screens in one frame are one event each way");
    CHECK(count_lines(log, "say_touch_down:") == 3 && count_lines(log, "say_touch_up:") == 3,
          "and nothing else (%d downs, %d ups)", count_lines(log, "say_touch_down:"), count_lines(log, "say_touch_up:"));
    CHECK(engine_station_runs(program_station(p, "touch_move")) == 14,
          "touch_move looked at every frame (and the move at frame 9 left by its unwired exit)");

    CHECK(program_remove(p) == 0, "the program comes out");
    twin_engine_stop();
    metrics_close();
    CHECK_DONE("103 sticks and touch");
}
