/*
 * 102-test-chords.c — issue 505: two buttons struck together are one
 * event.
 *
 * General description: a map hangs two chord_of stations off the button
 * history — dpad-up with abxy-a within three frames, and l1 with r1 in
 * the same frame only — and is driven one frame at a time with the twin's
 * buttons set before each tick. A chord is said once, on the frame its
 * second button goes down, in either order, with how far apart the two
 * went down; not again while both stay held; not when they are further
 * apart than the window; not when the first was let go before the second
 * came down. A chord naming a button that does not exist takes its
 * station out of service on the first frame, saying which name was wrong.
 * Before any of that, the box is called directly.
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
static void tick(int program, uint32_t pressed)
{
    int64_t one = 1;
    twin_input_set_buttons(pressed);
    program_argument(program, 0, &one, sizeof one);
    twin_engine_settle(5000);
}
/* }}} */

#define CHORD_ZERO "{ 0, 0, 0 }"

/* The frame and the button history, with whatever chords `chords` adds. */
static const char *map_head =
    "boxes = ../boxes/\n"
    "station first_frame (boxes/062-arithmetic.c:constant)\n"
    "  in 0 = 0\n"
    "  out 0 - frame.1\n"
    "station frame (boxes/095-input.c:frame_next)\n"
    "  in 0 - 0$\n"
    "  in 1 - first_frame.0\n"
    "  in 1 - frame.0\n"
    "  out 0 - frame.1\n"
    "  out 0 - read_buttons.0\n"
    "station read_buttons (boxes/095-input.c:read_buttons)\n"
    "  in 0 - frame.0\n"
    "  out 0 - buttons.0\n"
    "station buttons_at_rest (boxes/095-input.c:buttons_at_rest)\n"
    "  in 0 = 0\n"
    "  out 0 - buttons.1\n"
    "station buttons (boxes/095-input.c:button_track)\n"
    "  in 0 - read_buttons.0\n"
    "  in 1 - buttons_at_rest.0\n"
    "  in 1 - buttons.0\n"
    "  out 0 - buttons.1\n";

int main(void)
{
    snprintf(log_path, sizeof log_path, "%s/tmp/shared-memory/test-logs/102-developer-line.log", getenv("SOREN_DIR"));
    remove(log_path);
    twin_engine_start(CORES, (size_t)256 << 20);
    twin_platform_set_log(log_path, 0);
    engine_open_gate();
    metrics_open("102-chords");
    struct map_report report;

    /* --- the box, called directly ---------------------------------------- */
    struct chord up_a = { "dpad-up", "abxy-a", 3 };
    struct button_state s = buttons_at_rest(0);
    struct button_snapshot f1 = { 1, BUTTON_BIT(BUTTON_DPAD_UP), 0 };
    struct button_snapshot f2 = { 2, BUTTON_BIT(BUTTON_DPAD_UP) | BUTTON_BIT(BUTTON_A), 0 };
    s = button_track(f1, s);
    CHECK(chord_of(s, up_a).buttons == 0, "one of the two down is no chord");
    s = button_track(f2, s);
    struct chord_event e = chord_of(s, up_a);
    CHECK(e.buttons == (BUTTON_BIT(BUTTON_DPAD_UP) | BUTTON_BIT(BUTTON_A)) && e.frame == 2 && e.apart == 1,
          "the second one down a frame later is the chord (%u, %lld, %u)", e.buttons, (long long)e.frame, e.apart);
    struct chord_event none = { 0, 0, 0 };
    CHECK(chord_event__compare(e, none) > 0 && chord_event__compare(none, none) == 0,
          "a chord is above the all-zero threshold, no chord equal to it");
    /* A comparator compares at most 64 bytes (issue 313). */
    _Static_assert(sizeof(struct chord_event) <= 64, "chord_event outgrew a comparator's threshold");

    /* --- a map with two chords ------------------------------------------- */
    static char text[8192];
    snprintf(text, sizeof text, "%s"
        "  out 0 - up_a.0\n"
        "  out 0 - triggers.0\n"
        "comparator up_a (boxes/095-input.c:chord_of)\n"
        "  in 0 - buttons.0\n"
        "  in 1 = { \"dpad-up\", \"abxy-a\", 3 }\n"
        "  in 2 = " CHORD_ZERO "\n"
        "  out 2 - say_up_a.0\n"
        "comparator triggers (boxes/095-input.c:chord_of)\n"
        "  in 0 - buttons.0\n"
        "  in 1 = { \"l1\", \"r1\", 0 }\n"
        "  in 2 = " CHORD_ZERO "\n"
        "  out 2 - say_triggers.0\n"
        "station say_up_a (boxes/095-input.c:say_chord)\n"
        "  in 0 - up_a.2\n"
        "station say_triggers (boxes/095-input.c:say_chord)\n"
        "  in 0 - triggers.2\n", map_head);
    int p = program_load_text("src/maps/test-chords.map", text, strlen(text), &report);
    CHECK(p >= 0 && program_bring_up(p, &report) == 0, "a map with two chords loads and brings up (%s)", report.text);
    twin_engine_settle(5000);

    uint32_t UP = BUTTON_BIT(BUTTON_DPAD_UP), A = BUTTON_BIT(BUTTON_A);
    uint32_t L1 = BUTTON_BIT(BUTTON_L1), R1 = BUTTON_BIT(BUTTON_R1);
    tick(p, 0);            /* 1 */
    tick(p, UP);           /* 2 */
    tick(p, UP | A);       /* 3: chord, 1 apart */
    tick(p, UP | A);       /* 4: still held, nothing */
    tick(p, 0);            /* 5 */
    tick(p, A);            /* 6 */
    tick(p, A);            /* 7 */
    tick(p, A);            /* 8 */
    tick(p, A | UP);       /* 9: chord, the other order, 3 apart */
    tick(p, 0);            /* 10 */
    for (int f = 11; f <= 14; f++) tick(p, UP);   /* 11-14 */
    tick(p, UP | A);       /* 15: 4 apart, too far */
    tick(p, 0);            /* 16 */
    tick(p, UP | A);       /* 17: chord, the same frame */
    tick(p, 0);            /* 18 */
    tick(p, UP);           /* 19 */
    tick(p, 0);            /* 20 */
    tick(p, A);            /* 21: up was let go: nothing */
    tick(p, 0);            /* 22 */
    tick(p, L1);           /* 23 */
    tick(p, L1 | R1);      /* 24: a frame apart, the window is 0 */
    tick(p, 0);            /* 25 */
    tick(p, L1 | R1);      /* 26: the same frame: chord */
    tick(p, 0);            /* 27 */

    const char *log = read_log();
    CHECK(has_line(log, "say_up_a: frame 3: dpad-up + abxy-a (1 apart)"), "up then A a frame later is a chord:\n%s", log);
    CHECK(has_line(log, "say_up_a: frame 9: dpad-up + abxy-a (3 apart)"), "A then up three frames later is too");
    CHECK(has_line(log, "say_up_a: frame 17: dpad-up + abxy-a (0 apart)"), "and both in one frame");
    CHECK(count_lines(log, "say_up_a:") == 3,
          "and nothing else: not while held, not four apart, not after up was let go (%d lines)",
          count_lines(log, "say_up_a:"));
    CHECK(has_line(log, "say_triggers: frame 26: l1 + r1 (0 apart)") && count_lines(log, "say_triggers:") == 1,
          "a window of 0 takes the same frame only:\n%s", log);

    /* --- a name that is not a button ------------------------------------- */
    snprintf(text, sizeof text, "%s"
        "  out 0 - sideways.0\n"
        "comparator sideways (boxes/095-input.c:chord_of)\n"
        "  in 0 - buttons.0\n"
        "  in 1 = { \"abxy-a\", \"dpad-sideways\", 3 }\n"
        "  in 2 = " CHORD_ZERO "\n", map_head);
    int bad = program_load_text("src/maps/test-bad-chord.map", text, strlen(text), &report);
    CHECK(bad >= 0 && program_bring_up(bad, &report) == 0, "a chord naming no button still loads (%s)", report.text);
    tick(bad, 0);
    struct engine_error_report er;
    int has = engine_read_error(program_station(bad, "sideways"), &er, 0);
    CHECK(has == ENGINE_OK && er.kind == 1 && er.detail == 2,
          "and on its first frame refuses, saying the second name is the wrong one (%d, kind %d, detail %llu)",
          has, er.kind, (unsigned long long)er.detail);

    CHECK(program_remove(p) == 0 && program_remove(bad) == 0, "both programs come out");
    twin_engine_stop();
    metrics_close();
    CHECK_DONE("102 chords");
}
