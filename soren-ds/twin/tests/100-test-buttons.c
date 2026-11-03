/*
 * 100-test-buttons.c — issue 502: the buttons, as down, up and held
 * events.
 *
 * General description: the input-poll map is driven one frame at a time
 * by delivering its tick by hand, with the twin's buttons set before each
 * one, and the developer line read after. A button pressed says so once,
 * on the frame it went down; released, it says so once with how long it
 * was held, counted from frames; buttons pressed in the same frame are
 * one event; a button held for sixty frames was held for a second; bits
 * that are not buttons are ignored. Then a map listening to held events
 * for only two buttons hears those two, once a frame, and nothing else.
 * Then the real timer runs the map while a button is held for half a
 * second. Before any of that, the boxes are called directly: a stale
 * snapshot changes nothing, and events order by their buttons so a
 * comparator lets only real ones out.
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

/* The boxes themselves, called as plain functions. The catalogue holds its
 * own renamed copies, so these do not collide with it. */
#include "../../src/boxes/095-input.c"

#include <stdio.h>
#include <string.h>
#include <time.h>

/* A comparator's threshold must fit its 64 bytes (issue 313). */
_Static_assert(sizeof(struct button_event) <= 64, "button_event outgrew a comparator's threshold");

#define CORES 4

static char log_path[512];

/* {{{ read_log */
static char *read_log(void)
{
    static char buf[1 << 18];
    FILE *f = fopen(log_path, "r");
    size_t n = f ? fread(buf, 1, sizeof buf - 1, f) : 0;
    if (f) fclose(f);
    buf[n] = 0;
    return buf;
}
/* }}} */

/* {{{ count_lines */
/* How many lines of the log, from `from` on, start with `prefix`. */
static int count_lines(const char *log, size_t from, const char *prefix)
{
    int n = 0;
    size_t len = strlen(prefix);
    const char *at = log + from;
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
static int has_line(const char *log, size_t from, const char *line)
{
    char want[600];
    snprintf(want, sizeof want, "%s\n", line);
    return strstr(log + from, want) != NULL;
}
/* }}} */

/* {{{ tick */
/* One frame by hand: these buttons down, then the tick, then wait for
 * everything it started to finish. */
static void tick(int program, uint32_t pressed)
{
    int64_t one = 1;
    twin_input_set_buttons(pressed);
    program_argument(program, 0, &one, sizeof one);
    twin_engine_settle(5000);
}
/* }}} */

/* {{{ sleep_ms */
static void sleep_ms(int ms)
{
    struct timespec t = { ms / 1000, (long)(ms % 1000) * 1000000L };
    nanosleep(&t, NULL);
}
/* }}} */

/* A map that listens to held events for two buttons only. */
static const char *held_map =
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
    "  out 0 - buttons.1\n"
    "  out 0 - held_triggers.0\n"
    "comparator held_triggers (boxes/095-input.c:button_held)\n"
    "  in 0 - buttons.0\n"
    "  in 1 = 768\n"                      /* l1 (bit 8) and r1 (bit 9) */
    "  in 2 = { 0, 0, 0, { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } }\n"
    "  out 2 - say_held.0\n"
    "station say_held (boxes/095-input.c:say_buttons)\n"
    "  in 0 - held_triggers.2\n";

int main(void)
{
    snprintf(log_path, sizeof log_path, "%s/tmp/shared-memory/test-logs/100-developer-line.log", getenv("SOREN_DIR"));
    remove(log_path);
    twin_engine_start(CORES, (size_t)256 << 20);
    twin_platform_set_log(log_path, 0);
    engine_open_gate();
    metrics_open("100-buttons");
    struct map_report report;

    /* --- the boxes, called directly ------------------------------------- */
    struct button_state rest = buttons_at_rest(0);
    struct button_snapshot a5 = { 5, BUTTON_BIT(BUTTON_A), 0 };
    struct button_state after5 = button_track(a5, rest);
    CHECK(after5.fresh && after5.went_down == BUTTON_BIT(BUTTON_A) && after5.down_since[BUTTON_A] == 5,
          "a press is seen going down, at its frame");
    struct button_snapshot none4 = { 4, 0, 0 };
    struct button_state stale = button_track(none4, after5);
    CHECK(!stale.fresh && stale.frame == 5 && stale.pressed == BUTTON_BIT(BUTTON_A) &&
          stale.went_down == 0 && stale.went_up == 0,
          "an older frame's snapshot arriving late changes nothing");
    CHECK(button_up(stale, BUTTON_ALL).buttons == 0 && button_held(stale, BUTTON_ALL).buttons == 0,
          "and gives no event, not even a held one");
    struct button_event empty = button_down(rest, BUTTON_ALL), some = button_held(after5, BUTTON_ALL);
    CHECK(button_event__compare(empty, empty) == 0 && button_event__compare(some, empty) > 0,
          "an event about no buttons is equal to the threshold { 0 }, a real one above it");
    struct button_state long_press = after5;
    long_press.fresh = 1;
    long_press.went_up = BUTTON_BIT(BUTTON_A);
    long_press.held_frames[BUTTON_A] = 60 * 60 * 5;
    CHECK(button_up(long_press, BUTTON_ALL).held_ms[BUTTON_A] == 65535,
          "a press of five minutes reads 65535 ms, the most a duration holds");
    CHECK(strcmp(button_name(BUTTON_A), "abxy-a") == 0 && strcmp(button_name(BUTTON_STICK_RIGHT), "stick-right") == 0 &&
          strcmp(button_name(BUTTON_COUNT), "?") == 0, "buttons have their names");

    /* --- down and up, one frame at a time -------------------------------- */
    int program = program_load(INPUT_POLL_MAP, &report);
    CHECK(program >= 0, "input-poll loads (%s)", report.text);
    CHECK(program_bring_up(program, &report) == 0, "and brings up cleanly (%s)", report.text);
    twin_engine_settle(5000);
    size_t from = strlen(read_log());

    uint32_t A = BUTTON_BIT(BUTTON_A), UP = BUTTON_BIT(BUTTON_DPAD_UP);
    tick(program, 0);                                         /* frame 1 */
    CHECK(count_lines(read_log(), from, "say_") == 0, "a frame with nothing pressed says nothing");
    tick(program, A);                                         /* frame 2 */
    CHECK(has_line(read_log(), from, "say_down: frame 2: abxy-a"), "A going down is said on its frame:\n%s", read_log() + from);
    tick(program, A | UP);                                    /* frame 3 */
    CHECK(has_line(read_log(), from, "say_down: frame 3: dpad-up"), "up going down while A is held names only up");
    tick(program, A | UP);                                    /* frame 4 */
    tick(program, UP);                                        /* frame 5 */
    CHECK(has_line(read_log(), from, "say_up: frame 5: abxy-a (50 ms)"), "A going up after three frames was held 50 ms:\n%s", read_log() + from);
    tick(program, 0);                                         /* frame 6 */
    CHECK(has_line(read_log(), from, "say_up: frame 6: dpad-up (50 ms)"), "and up after its three, 50 ms");

    uint32_t five = A | BUTTON_BIT(BUTTON_B) | BUTTON_BIT(BUTTON_X) | BUTTON_BIT(BUTTON_Y) | BUTTON_BIT(BUTTON_START1);
    tick(program, five);                                      /* frame 7 */
    CHECK(has_line(read_log(), from, "say_down: frame 7: abxy-a abxy-b abxy-x abxy-y start1"),
          "five buttons down in one frame are one event:\n%s", read_log() + from);
    tick(program, 0);                                         /* frame 8 */
    CHECK(has_line(read_log(), from, "say_up: frame 8: abxy-a (17 ms) abxy-b (17 ms) abxy-x (17 ms) abxy-y (17 ms) start1 (17 ms)"),
          "and up in one frame, each held one frame (17 ms):\n%s", read_log() + from);

    uint32_t L1 = BUTTON_BIT(BUTTON_L1);
    for (int f = 9; f <= 68; f++) {
        tick(program, L1);                                    /* frames 9 to 68 */
    }
    tick(program, 0);                                         /* frame 69 */
    CHECK(has_line(read_log(), from, "say_up: frame 69: l1 (1000 ms)"), "held for sixty frames is a second:\n%s", read_log() + from);
    tick(program, 1u << 31);                                  /* frame 70 */
    tick(program, 0);                                         /* frame 71 */
    CHECK(count_lines(read_log(), from, "say_down:") == 4 && count_lines(read_log(), from, "say_up:") == 4,
          "four downs and four ups in all: a bit that is not a button is no event (%d, %d)",
          count_lines(read_log(), from, "say_down:"), count_lines(read_log(), from, "say_up:"));
    CHECK(engine_station_runs(program_station(program, "buttons")) == 71,
          "the history was compared once a frame (%llu)",
          (unsigned long long)engine_station_runs(program_station(program, "buttons")));

    /* --- held, listening to two buttons ---------------------------------- */
    int held = program_load_text("src/maps/test-held.map", held_map, strlen(held_map), &report);
    CHECK(held >= 0 && program_bring_up(held, &report) == 0, "a map listening to held l1 and r1 loads (%s)", report.text);
    twin_engine_settle(5000);
    from = strlen(read_log());
    uint32_t R1 = BUTTON_BIT(BUTTON_R1);
    tick(held, A);                                            /* frame 1 */
    CHECK(count_lines(read_log(), from, "say_held:") == 0, "A held is not listened for");
    tick(held, A | L1);                                       /* frame 2 */
    tick(held, L1 | R1);                                      /* frame 3 */
    tick(held, L1 | R1);                                      /* frame 4 */
    tick(held, 0);                                            /* frame 5 */
    const char *log = read_log();
    CHECK(has_line(log, from, "say_held: frame 2: l1") && has_line(log, from, "say_held: frame 3: l1 r1") &&
          has_line(log, from, "say_held: frame 4: l1 r1"),
          "l1 and r1 are heard every frame they are down, the frame they went down included:\n%s", log + from);
    CHECK(count_lines(log, from, "say_held:") == 3, "and not on the frame they came up (%d lines)",
          count_lines(log, from, "say_held:"));

    /* --- on the timer ---------------------------------------------------- */
    twin_input_set_buttons(0);
    struct input_poll poll;
    CHECK(input_poll_start(&poll, &report) >= 0, "input-poll starts on its timer (%s)", report.text);
    sleep_ms(200);
    from = strlen(read_log());
    twin_input_set_buttons(BUTTON_BIT(BUTTON_SELECT2));
    sleep_ms(500);
    twin_input_set_buttons(0);
    sleep_ms(200);
    input_poll_stop(&poll);
    twin_engine_settle(10000);
    log = read_log();
    long long ms = -1;
    const char *up = strstr(log + from, "say_up: frame ");
    if (up) {
        const char *open = strstr(up, "select2 (");
        if (open) ms = atoll(open + 9);
    }
    CHECK(count_lines(log, from, "say_down: ") == 1 && count_lines(log, from, "say_up: ") == 1,
          "held for half a second on the timer: one down, one up:\n%s", log + from);
    CHECK(ms >= 300 && ms <= 2000, "and the up says about half a second (%lld ms)", ms);
    metric_record("input.held_half_second_ms", (double)ms, "ms", "buttons",
                  "a button held for 500 ms of the laptop's clock, as button_up counted it in frames");

    CHECK(program_remove(program) == 0 && program_remove(held) == 0 && program_remove(poll.program) == 0,
          "every program comes out");
    twin_engine_stop();
    metrics_close();
    CHECK_DONE("100 buttons");
}
