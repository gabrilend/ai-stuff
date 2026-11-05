/*
 * 132-test-radial-menu.c — issue 506: one character from a direction and
 * a face button.
 *
 * General description: first the boxes are called directly — the D-pad's
 * eight ways and its impossible pairs, the sources in their order, every
 * one of the default table's 128 places against the chord that reaches
 * it, the triggers choosing the mode, and the chords that type nothing.
 * Then src/maps/radial-menu-chord.map runs on the twin, driven a frame at
 * a time with the twin's buttons and sticks set before each frame: a word
 * typed, upper case and digits through the triggers, a held direction
 * typing repeatedly, the left stick standing in for the D-pad, a table of
 * the user's own replacing the default through its second door, and a
 * table that names no mode refused saying which combination. Last, the
 * program placed inside another map, as the editor will place it, its
 * characters said on the developer line.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/system/096-input.h"
#include "../../src/system/133-radial-menu.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "../099-input-twin.h"
#include "047-check.h"

/* The boxes themselves, called as plain functions (the catalogue holds
 * renamed copies). 131 uses 095's types and its stick helpers. */
#include "../../src/boxes/095-input.c"
#include "../../src/boxes/131-radial-menu.c"

#include <stdio.h>
#include <string.h>

#define CORES 4

/* A comparator compares at most 64 bytes (issue 313). */
_Static_assert(sizeof(struct radial_event) <= 64, "radial_event outgrew a comparator's threshold");

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

/* {{{ has_line */
static int has_line(const char *log, const char *line)
{
    char want[256];
    snprintf(want, sizeof want, "%s\n", line);
    return strstr(log, want) != NULL;
}
/* }}} */

#define UP    BUTTON_BIT(BUTTON_DPAD_UP)
#define DOWN  BUTTON_BIT(BUTTON_DPAD_DOWN)
#define LEFT  BUTTON_BIT(BUTTON_DPAD_LEFT)
#define RIGHT BUTTON_BIT(BUTTON_DPAD_RIGHT)
#define A     BUTTON_BIT(BUTTON_A)
#define B     BUTTON_BIT(BUTTON_B)
#define X     BUTTON_BIT(BUTTON_X)
#define Y     BUTTON_BIT(BUTTON_Y)
#define L1    BUTTON_BIT(BUTTON_L1)
#define R1    BUTTON_BIT(BUTTON_R1)
#define L2    BUTTON_BIT(BUTTON_L2)
#define R2    BUTTON_BIT(BUTTON_R2)

static const struct radial_source BOTH = { RADIAL_FROM_DPAD | RADIAL_FROM_LEFT_STICK, 0, { 200, 200, 414214, 414214 } };

/* The default table, as the map writes it. */
static const struct radial_table DEFAULT = {
    "abcdefghijklmnopqrstuvwxyz .,?!'", "ABCDEFGHIJKLMNOPQRSTUVWXYZ\n-:;\"/",
    "0123456789+-*/=%()[]{}<>&|^~@#$_", "`\\\t",
    { 0, 1, 2, -1, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
};

/* The D-pad bits that point each way, n to nw. */
static const uint32_t POINT[8] = { UP, UP | RIGHT, RIGHT, DOWN | RIGHT, DOWN, DOWN | LEFT, LEFT, UP | LEFT };

/* {{{ direction_read */
/* The direction radial_read finds with these buttons and the left stick here. */
static int32_t direction_read(uint32_t pressed, int32_t lx, int32_t ly, struct radial_source src)
{
    twin_input_set_buttons(pressed);
    twin_input_set_sticks(lx, ly, 0, 0);
    return radial_read(1, src).direction;
}
/* }}} */

/* {{{ typed */
/* The character the chord box types for these held buttons, of which
 * `struck` went down this frame, with the direction `direction`. */
static uint32_t typed(int32_t direction, uint32_t held, uint32_t struck, const struct radial_table *t)
{
    struct radial_history h = { 5, held | struck, struck, direction, 1 };
    return radial_chord(h, *t).character;
}
/* }}} */

/* {{{ frame */
/* One frame of the program: the buttons and the left stick set, then the
 * frame number in by door 0, and whatever it typed out by door 0. Answers
 * the character, or 0 when it typed nothing. */
static int64_t frame_number;
static uint32_t frame(int program, uint32_t pressed, int32_t lx, int32_t ly)
{
    twin_input_set_buttons(pressed);
    twin_input_set_sticks(lx, ly, 0, 0);
    frame_number++;
    program_argument(program, 0, &frame_number, sizeof frame_number);
    twin_engine_settle(5000);
    struct radial_event e;
    if (program_result(program, 0, &e, sizeof e) != 1) {
        return 0;
    }
    return e.character;
}
/* }}} */

/* {{{ type_text */
/* Type `text` through the program the way a person would: for each
 * character, find its chord in `t`, hold the direction (and the mode's
 * trigger) a frame, strike the face button, and let go of everything.
 * Answers what came out, in order. */
static void type_text(int program, const char *text, const struct radial_table *t, char *out, size_t size)
{
    static const uint32_t MODE_TRIGGER[4] = { 0, L1, R1, L2 };
    size_t n = 0;
    for (const char *c = text; *c && n + 1 < size; c++) {
        for (int mode = 0; mode < 4; mode++) {
            const char *line = mode == 0 ? t->mode0 : mode == 1 ? t->mode1 : mode == 2 ? t->mode2 : t->mode3;
            const char *at = strchr(line, *c);
            if (!at) continue;
            int place = (int)(at - line);
            uint32_t hold = POINT[place / 4] | MODE_TRIGGER[mode];
            uint32_t got = 0;
            got |= frame(program, hold, 0, 0);
            got |= frame(program, hold | (A << (place % 4)), 0, 0);
            got |= frame(program, 0, 0, 0);
            if (got) out[n++] = (char)got;
            break;
        }
    }
    out[n] = 0;
}
/* }}} */

int main(void)
{
    snprintf(log_path, sizeof log_path, "%s/tmp/shared-memory/test-logs/132-developer-line.log", getenv("SOREN_DIR"));
    remove(log_path);
    twin_engine_start(CORES, (size_t)256 << 20);
    twin_platform_set_log(log_path, 0);
    engine_open_gate();
    metrics_open("132-radial-menu");
    struct map_report report;

    /* --- where the direction comes from ---------------------------------- */
    int right = 1;
    for (int d = 0; d < 8; d++) {
        if (direction_read(POINT[d], 0, 0, BOTH) != DIRECTION_N + d) right = 0;
    }
    CHECK(right, "the D-pad points eight ways: one bit straight, two neighbours the diagonal between");
    CHECK(direction_read(UP | DOWN, 0, 0, BOTH) == DIRECTION_NONE &&
          direction_read(LEFT | RIGHT, 0, 0, BOTH) == DIRECTION_NONE &&
          direction_read(UP | LEFT | RIGHT, 0, 0, BOTH) == DIRECTION_NONE &&
          direction_read(UP | DOWN | LEFT | RIGHT, 0, 0, BOTH) == DIRECTION_NONE,
          "two opposites, three or four at once point nowhere");
    CHECK(direction_read(0, 0, 1000, BOTH) == DIRECTION_N && direction_read(0, -1000, -1000, BOTH) == DIRECTION_SW,
          "with the D-pad at rest the left stick points");
    CHECK(direction_read(0, 150, 0, BOTH) == DIRECTION_NONE && direction_read(0, 150, 150, BOTH) == DIRECTION_NE,
          "inside its resting circle the stick points nowhere, and outside it by 503's eight sectors (%d)",
          (int)direction_read(0, 150, 150, BOTH));
    CHECK(direction_read(LEFT, 0, 1000, BOTH) == DIRECTION_W, "the D-pad wins when both point");
    struct radial_source dpad_only = BOTH;
    dpad_only.sources = RADIAL_FROM_DPAD;
    int32_t unread_left = direction_read(0, 0, 1000, dpad_only);
    twin_input_set_sticks(0, 0, -1000, 0);
    CHECK(unread_left == DIRECTION_NONE && radial_read(1, dpad_only).direction == DIRECTION_NONE,
          "a source not chosen is not read, neither stick");
    struct radial_source right_stick = BOTH;
    right_stick.sources = RADIAL_FROM_RIGHT_STICK;
    twin_input_set_buttons(0);
    twin_input_set_sticks(0, 1000, -1000, 0);
    CHECK(radial_read(1, right_stick).direction == DIRECTION_W, "the right stick, when it is chosen");
    twin_input_set_sticks(0, 0, 0, 0);

    /* --- the history ----------------------------------------------------- */
    struct radial_history h = radial_at_rest(0);
    struct radial_snapshot s1 = { 1, UP, DIRECTION_N }, s2 = { 2, UP | A, DIRECTION_N };
    h = radial_track(s1, h);
    h = radial_track(s2, h);
    CHECK(h.frame == 2 && h.went_down == A && h.pressed == (UP | A) && h.fresh == 1,
          "the history says what went down this frame");
    struct radial_history stale = radial_track(s1, h);
    CHECK(stale.fresh == 0 && stale.went_down == 0 && stale.frame == 2 && stale.pressed == (UP | A),
          "a reading no newer than the history changes nothing");
    struct radial_history same = radial_track(s2, h);
    CHECK(same.fresh == 0 && same.went_down == 0, "nor does a second reading of the same frame");
    struct radial_history marked = { 3, UP | A, A, DIRECTION_N, 0 };
    CHECK(radial_chord(stale, DEFAULT).character == 0 && radial_chord(marked, DEFAULT).character == 0,
          "and a history marked stale types nothing, whatever it says went down");

    /* --- every place of the default table -------------------------------- */
    static const uint32_t FACE[4] = { A, B, X, Y };
    static const uint32_t MODE_TRIGGER[4] = { 0, L1, R1, L2 };
    int all = 1, count = 0;
    for (int mode = 0; mode < 4; mode++) {
        const char *line = mode == 0 ? DEFAULT.mode0 : mode == 1 ? DEFAULT.mode1 : mode == 2 ? DEFAULT.mode2 : DEFAULT.mode3;
        size_t length = strlen(line);
        for (int d = 0; d < 8; d++) {
            for (int f = 0; f < 4; f++) {
                int place = d * 4 + f;
                uint32_t want = (size_t)place < length ? (uint8_t)line[place] : 0;
                uint32_t got = typed(DIRECTION_N + d, POINT[d] | MODE_TRIGGER[mode], FACE[f], &DEFAULT);
                if (got != want) {
                    all = 0;
                    fprintf(stderr, "mode %d, %s + %s: wanted %u, got %u\n", mode, direction_name(DIRECTION_N + d),
                            button_name(BUTTON_A + f), want, got);
                }
                if (got) count++;
            }
        }
    }
    CHECK(all && count == 32 + 32 + 32 + 3,
          "each of the 128 places types its own character, n to nw and A B X Y within, and the empty ones nothing (%d typed)", count);
    struct radial_history struck = { 7, UP | L1 | B, B, DIRECTION_N, 1 };
    struct radial_event e = radial_chord(struck, DEFAULT);
    CHECK(e.character == 'B' && e.frame == 7 && e.direction == DIRECTION_N && e.button == BUTTON_B && e.mode == 1,
          "the event carries the frame and the chord that typed it");
    struct radial_event none;
    bytes_zero(&none, sizeof none);
    CHECK(radial_event__compare(e, none) > 0 && radial_event__compare(none, none) == 0,
          "a character is above the all-zero threshold, nothing equal to it");

    /* --- what types nothing ---------------------------------------------- */
    CHECK(typed(DIRECTION_NONE, 0, A, &DEFAULT) == 0, "a face button with no direction types nothing");
    CHECK(typed(DIRECTION_N, UP | A, 0, &DEFAULT) == 0, "a direction pushed while a face button is already down types nothing");
    CHECK(typed(DIRECTION_N, UP, A | B, &DEFAULT) == 0, "two face buttons in one frame type nothing");
    CHECK(typed(DIRECTION_N, UP | L1 | R1, A, &DEFAULT) == 0 && typed(DIRECTION_N, UP | R2, A, &DEFAULT) == 0,
          "a combination of triggers with no mode types nothing");
    CHECK(typed(DIRECTION_N, UP | L2, Y, &DEFAULT) == 0 && typed(DIRECTION_N, UP | L2, B, &DEFAULT) == '\\',
          "past the end of a short line types nothing; before it, its character");
    CHECK(typed(DIRECTION_N, UP | B, A, &DEFAULT) == 'a', "another face button already held does not stop a new one");
    struct radial_table junk = DEFAULT;
    memset(junk.mode3 + 4, 'q', sizeof junk.mode3 - 4);   /* bytes after the line's end, as a careless caller might leave */
    CHECK(typed(DIRECTION_N, UP | L2, Y, &junk) == 0 && typed(DIRECTION_S, DOWN | L2, A, &junk) == 0,
          "a place after the line's end types nothing, whatever lies after it");

    /* --- the program ----------------------------------------------------- */
    int p = program_load("src/maps/radial-menu-chord.map", &report);
    CHECK(p >= 0 && program_bring_up(p, &report) == 0, "radial-menu-chord.map loads and brings up (%s)", report.text);
    CHECK(program_argument_count(p) == 1 && program_result_count(p) == 1,
          "one door in (the frame) and one out (%d, %d)", program_argument_count(p), program_result_count(p));
    twin_engine_settle(5000);
    char out[128];
    type_text(p, "hello, world", &DEFAULT, out, sizeof out);
    CHECK(strcmp(out, "hello, world") == 0, "a sentence typed through the program (\"%s\")", out);
    type_text(p, "Room 101: OK", &DEFAULT, out, sizeof out);
    CHECK(strcmp(out, "Room 101: OK") == 0, "upper case under L1 and digits under R1 (\"%s\")", out);

    /* Hold north and strike A three times: three a's. */
    uint32_t got[8];
    int n = 0;
    got[n++] = frame(p, UP, 0, 0);
    for (int i = 0; i < 3; i++) {
        got[n++] = frame(p, UP | A, 0, 0);
        got[n++] = frame(p, UP, 0, 0);
    }
    got[n++] = frame(p, 0, 0, 0);
    CHECK(got[0] == 0 && got[1] == 'a' && got[2] == 0 && got[3] == 'a' && got[4] == 0 && got[5] == 'a' && got[6] == 0,
          "a direction held types once for each press of a face button");
    CHECK(frame(p, UP | L1 | R1, 0, 0) == 0 && frame(p, UP | L1 | R1 | A, 0, 0) == 0 && frame(p, 0, 0, 0) == 0 &&
          frame(p, UP | R2, 0, 0) == 0 && frame(p, UP | R2 | A, 0, 0) == 0 && frame(p, 0, 0, 0) == 0,
          "in the program, L1 with R1, or R2, types nothing");
    CHECK(frame(p, A, 0, 0) == 0 && frame(p, A | UP, 0, 0) == 0 && frame(p, 0, 0, 0) == 0,
          "a face button first, then the direction, types nothing");
    CHECK(frame(p, 0, -1000, 0) == 0 && frame(p, B, -1000, 0) == 'z' && frame(p, 0, 0, 0) == 0,
          "the left stick west and B is 'z', as the D-pad west would be");

    /* A table of the user's own, through the hook. */
    struct radial_table mine = DEFAULT;
    snprintf(mine.mode0, sizeof mine.mode0, "%s", "zyxwvutsrqponmlkjihgfedcba!?,. ");
    CHECK(radial_menu_set_table(p, &mine, sizeof mine) == 0, "a table of the user's own is taken");
    twin_engine_settle(5000);
    type_text(p, "hello", &mine, out, sizeof out);
    CHECK(strcmp(out, "hello") == 0, "and the very next frames type from it (\"%s\")", out);
    CHECK(frame(p, UP, 0, 0) == 0 && frame(p, UP | A, 0, 0) == 'z' && frame(p, 0, 0, 0) == 0,
          "north and A is now 'z'");

    /* A table naming a mode that does not exist. */
    struct radial_table broken = DEFAULT;
    broken.select[6] = 4;                 /* R1 with L2 */
    CHECK(radial_menu_set_table(p, &broken, sizeof mine - 1) == ENGINE_WRONG_SIZE &&
          radial_menu_set_table(-5, &broken, sizeof broken) == ENGINE_NO_STATION,
          "a table of the wrong size, or for no program, is refused by the call");
    radial_menu_set_table(p, &broken, sizeof broken);
    twin_engine_settle(5000);
    frame(p, UP, 0, 0);
    frame(p, UP | A, 0, 0);
    struct engine_error_report er;
    int has = engine_read_error(program_station(p, "chord"), &er, 0);
    CHECK(has == ENGINE_OK && er.kind == 1 && er.detail == 2 + 6,
          "a table naming a mode outside 0 to 3 refuses the chord, saying which combination (%d, kind %d, detail %llu)",
          has, er.kind, (unsigned long long)er.detail);
    CHECK(program_remove(p) == 0, "the program comes out");

    /* A source that is none of the three. */
    static char text[4096];
    snprintf(text, sizeof text,
        "boxes = ../boxes/\n"
        "station read (boxes/131-radial-menu.c:radial_read)\n"
        "  in 0 - 0$\n"
        "  in 1 = { 8, 0, { 200, 200, 414214, 414214 } }\n");
    int bad = program_load_text("src/maps/test-bad-source.map", text, strlen(text), &report);
    CHECK(bad >= 0 && program_bring_up(bad, &report) == 0, "a map with a source that is none of the three loads (%s)", report.text);
    int64_t one = 1;
    program_argument(bad, 0, &one, sizeof one);
    twin_engine_settle(5000);
    has = engine_read_error(program_station(bad, "read"), &er, 0);
    CHECK(has == ENGINE_OK && er.kind == 1 && er.detail == 1,
          "and refuses on its first frame (%d, kind %d, detail %llu)", has, er.kind, (unsigned long long)er.detail);
    CHECK(program_remove(bad) == 0, "and comes out");

    /* --- placed inside another map, as the editor will place it ---------- */
    snprintf(text, sizeof text,
        "boxes = ../boxes/\n"
        "station first_frame (boxes/062-arithmetic.c:constant)\n"
        "  in 0 = 0\n"
        "  out 0 - frame.1\n"
        "station frame (boxes/095-input.c:frame_next)\n"
        "  in 0 - 0$\n"
        "  in 1 - first_frame.0\n"
        "  in 1 - frame.0\n"
        "  out 0 - frame.1\n"
        "  out 0 - typing.0\n"
        "station typing (radial-menu-chord.map)\n"
        "  in 0 - frame.0\n"
        "  out 0 - say_typed.0\n"
        "station say_typed (boxes/131-radial-menu.c:say_radial)\n"
        "  in 0 - typing.0\n");
    int editor = program_load_text("src/maps/test-editor.map", text, strlen(text), &report);
    CHECK(editor >= 0 && program_bring_up(editor, &report) == 0, "a map placing the radial menu loads and brings up (%s)", report.text);
    twin_engine_settle(5000);
    uint32_t steps[] = { 0, RIGHT, RIGHT | X, 0, UP | RIGHT | L1, UP | RIGHT | L1 | Y, 0, DOWN | R1, DOWN | R1 | B, 0 };
    for (size_t i = 0; i < sizeof steps / sizeof steps[0]; i++) {
        twin_input_set_buttons(steps[i]);
        program_argument(editor, 0, &one, sizeof one);
        twin_engine_settle(5000);
    }
    /* The user's table, given to the program placed inside: east and X is
     * now its own eleventh character. */
    CHECK(program_child_count(editor) == 1 && radial_menu_set_table(program_child(editor, 0), &mine, sizeof mine) == 0,
          "the placed program takes a table of the user's own");
    twin_engine_settle(5000);
    uint32_t again[] = { RIGHT, RIGHT | X, 0 };
    for (size_t i = 0; i < sizeof again / sizeof again[0]; i++) {
        twin_input_set_buttons(again[i]);
        program_argument(editor, 0, &one, sizeof one);
        twin_engine_settle(5000);
    }
    const char *log = read_log();
    CHECK(has_line(log, "say_typed: frame 12: 'p' (e + abxy-x, mode 0)"), "and types from it (frame 12)");
    CHECK(has_line(log, "say_typed: frame 3: 'k' (e + abxy-x, mode 0)") &&
          has_line(log, "say_typed: frame 6: 'H' (ne + abxy-y, mode 1)") &&
          has_line(log, "say_typed: frame 9: ')' (s + abxy-b, mode 2)"),
          "its characters reach the map around it, frame by frame:\n%s", log);
    CHECK(program_remove(editor) == 0, "and it comes out");

    twin_engine_stop();
    metrics_close();
    CHECK_DONE("132 radial menu");
}
