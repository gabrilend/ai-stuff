/*
 * 136-test-input-roles.c — issue 507: handedness and the drawer swap
 * applied to the event stream.
 *
 * General description: first the appliers, called directly. Right-handed,
 * the D-pad side navigates and its L triggers modify that, the face side
 * acts and its R triggers modify that; left-handed, every role changes
 * sides. The four center buttons open their drawers, the swap moving each
 * pair to the other screen while it keeps its side. The raw event is
 * carried whole. A stick change says which stick is navigating, its
 * changed bits following the roles.
 *
 * Then the input-poll map, driven one frame at a time with the twin's
 * buttons and sticks set before each tick and the developer line read
 * after: the roles under the map's own settings, the settings turned while
 * it runs and the very next event under them, a wrong setting turned away
 * by the call, and the raw events said as before. While one thread turns
 * the settings back and forth as fast as it can, every event still answers
 * to one whole pair of settings. Last, a garbled setting given to an
 * applier directly refuses it, saying which.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/system/096-input.h"
#include "../../src/system/135-input-settings.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "../099-input-twin.h"
#include "047-check.h"

/* The boxes themselves, called as plain functions (the catalogue holds
 * renamed copies). 134 uses 095's event types. */
#include "../../src/boxes/095-input.c"
#include "../../src/boxes/134-input-roles.c"

#include <pthread.h>
#include <stdio.h>
#include <string.h>

#define CORES 4

/* input_settings_set sends two int32s; the appliers' dial must be that. */
_Static_assert(sizeof(struct input_settings) == 8, "input_settings is not the two int32s 135 sends");

#define UP     BUTTON_BIT(BUTTON_DPAD_UP)
#define A      BUTTON_BIT(BUTTON_A)
#define L1     BUTTON_BIT(BUTTON_L1)
#define L2     BUTTON_BIT(BUTTON_L2)
#define R1     BUTTON_BIT(BUTTON_R1)
#define R2     BUTTON_BIT(BUTTON_R2)
#define SL     BUTTON_BIT(BUTTON_STICK_LEFT)
#define SR     BUTTON_BIT(BUTTON_STICK_RIGHT)
#define START1  BUTTON_BIT(BUTTON_START1)
#define SELECT1 BUTTON_BIT(BUTTON_SELECT1)
#define SELECT2 BUTTON_BIT(BUTTON_SELECT2)
#define START2  BUTTON_BIT(BUTTON_START2)

static char log_path[512];

/* {{{ read_log */
static char *read_log(void)
{
    static char buf[1 << 20];
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

/* {{{ tick */
static void tick(int program, uint32_t pressed, int32_t lx)
{
    int64_t one = 1;
    twin_input_set_buttons(pressed);
    twin_input_set_sticks(lx, 0, 0, 0);
    program_argument(program, 0, &one, sizeof one);
    twin_engine_settle(5000);
}
/* }}} */

/* {{{ roles */
static struct role_event roles(uint32_t buttons, int32_t left_handed, int32_t drawer_swap)
{
    struct button_event e;
    memset(&e, 0, sizeof e);
    e.frame = 7;
    e.buttons = buttons;
    struct input_settings s = { left_handed, drawer_swap };
    return button_roles(e, s);
}
/* }}} */

/* {{{ drawers_of */
/* The drawers each center button opens alone, as four bits a button. */
static uint32_t drawers_of(int32_t drawer_swap)
{
    return roles(START1, 0, drawer_swap).drawers | roles(SELECT1, 0, drawer_swap).drawers << 4 |
           roles(SELECT2, 0, drawer_swap).drawers << 8 | roles(START2, 0, drawer_swap).drawers << 12;
}
/* }}} */

/* {{{ turner */
/* Turns the settings between right-handed standard and left-handed
 * swapped until told to stop, counting the turns. */
static volatile int turning;
static volatile long turns;
static int turn_program;
static void *turner(void *unused)
{
    (void)unused;
    while (turning) {
        input_settings_set(turn_program, 1, 1);
        input_settings_set(turn_program, 0, 0);
        turns++;
    }
    return NULL;
}
/* }}} */

int main(void)
{
    snprintf(log_path, sizeof log_path, "%s/tmp/shared-memory/test-logs/136-developer-line.log", getenv("SOREN_DIR"));
    remove(log_path);
    twin_engine_start(CORES, (size_t)256 << 20);
    twin_platform_set_log(log_path, 0);
    engine_open_gate();
    metrics_open("136-input-roles");
    struct map_report report;

    /* --- the appliers, called directly ----------------------------------- */
    uint32_t all = UP | A | L1 | R2 | SL | SR;
    struct role_event r = roles(all, 0, 0);
    CHECK(r.navigate == (UP | SL) && r.act == (A | SR) && r.modify_navigate == L1 && r.modify_act == R2,
          "right-handed: the D-pad and left stick navigate, L modifies that, the face buttons and right stick act, R modifies that");
    r = roles(all, 1, 0);
    CHECK(r.navigate == (A | SR) && r.act == (UP | SL) && r.modify_navigate == R2 && r.modify_act == L1,
          "left-handed: every role changes sides");
    r = roles(L2 | R1, 0, 0);
    CHECK(r.modify_navigate == L2 && r.modify_act == R1 && r.navigate == 0 && r.act == 0,
          "the second triggers modify as the first do");
    r = roles(L2 | R1, 1, 0);
    CHECK(r.modify_navigate == R1 && r.modify_act == L2, "and change sides with them");

    struct button_event raw;
    memset(&raw, 0, sizeof raw);
    raw.frame = 41;
    raw.buttons = A | START2;
    raw.held_ms[BUTTON_A] = 300;
    raw.held_ms[BUTTON_START2] = 65535;
    struct input_settings lefty = { 1, 1 };
    r = button_roles(raw, lefty);
    CHECK(r.frame == 41 && r.buttons == (A | START2) && r.held_ms[BUTTON_A] == 300 &&
          r.held_ms[BUTTON_START2] == 65535 && r.held_ms[BUTTON_B] == 0,
          "the raw event is carried whole: its frame, its buttons and how long each was held");

    r = roles(START1 | SELECT1 | SELECT2 | START2, 0, 0);
    CHECK(r.navigate == 0 && r.act == 0 && r.modify_navigate == 0 && r.modify_act == 0,
          "a center button has no side, so no role");
    CHECK(drawers_of(0) == (DRAWER_BOTTOM_LEFT | DRAWER_BOTTOM_RIGHT << 4 | DRAWER_TOP_LEFT << 8 |
                            (uint32_t)DRAWER_TOP_RIGHT << 12),
          "standard: start1 bottom-left, select1 bottom-right, select2 top-left, start2 top-right (%x)",
          drawers_of(0));
    CHECK(drawers_of(1) == (DRAWER_TOP_LEFT | DRAWER_TOP_RIGHT << 4 | DRAWER_BOTTOM_LEFT << 8 |
                            (uint32_t)DRAWER_BOTTOM_RIGHT << 12),
          "swapped: start1 top-left, select1 top-right, select2 bottom-left, start2 bottom-right (%x)",
          drawers_of(1));
    CHECK(roles(START1 | SELECT1 | SELECT2 | START2, 0, 1).drawers == 15u &&
          roles(START1 | START2, 0, 0).drawers == (DRAWER_BOTTOM_LEFT | DRAWER_TOP_RIGHT),
          "several center buttons at once open each its drawer");
    CHECK(roles(START1, 1, 0).drawers == DRAWER_BOTTOM_LEFT && roles(UP, 0, 1).navigate == UP,
          "handedness moves no drawer, and the swap moves no role");

    struct stick_change c = { 9, 1u, 0, DIRECTION_N, DIRECTION_S };
    struct input_settings right_std = { 0, 0 }, left_std = { 1, 0 };
    struct stick_role_event sr = stick_roles(c, right_std);
    CHECK(sr.frame == 9 && sr.navigate == DIRECTION_N && sr.act == DIRECTION_S && sr.changed == 1u,
          "right-handed, the left stick navigates and its change is the navigating stick's");
    sr = stick_roles(c, left_std);
    CHECK(sr.navigate == DIRECTION_S && sr.act == DIRECTION_N && sr.changed == 2u,
          "left-handed, the right stick navigates, and the left stick's change is the acting stick's");
    c.changed = 2u;
    CHECK(stick_roles(c, left_std).changed == 1u && stick_roles(c, right_std).changed == 2u,
          "and the right stick's change is the navigating stick's");
    c.changed = 3u;
    CHECK(stick_roles(c, left_std).changed == 3u && stick_roles(c, right_std).changed == 3u,
          "both changing is both, either way");

    /* --- through the input-poll map ---------------------------------------- */
    int p = program_load(INPUT_POLL_MAP, &report);
    CHECK(p >= 0 && program_bring_up(p, &report) == 0, "input-poll loads and brings up (%s)", report.text);
    twin_engine_settle(5000);
    tick(p, 0, 0);                                            /* 1 */
    tick(p, UP | START1, 0);                                  /* 2 */
    tick(p, 0, 0);                                            /* 3 */
    tick(p, 0, 2000);                                         /* 4: left stick e */
    char *log = read_log();
    CHECK(has_line(log, "say_roles_down: frame 2: navigate dpad-up; drawer bottom-left") &&
          has_line(log, "say_roles_up: frame 3: navigate dpad-up; drawer bottom-left"),
          "as the map is written, right-handed and standard, for downs and ups");
    CHECK(has_line(log, "say_roles_sticks: frame 4: navigate e"), "and the left stick navigates");
    CHECK(has_line(log, "say_down: frame 2: dpad-up start1") && has_line(log, "say_sticks: frame 4: left e"),
          "the raw events are said as before");

    CHECK(input_settings_set(p, 1, 1) == 0, "the settings are turned while it runs");
    tick(p, 0, 0);                                            /* 5: left stick none */
    tick(p, UP | START1, 0);                                  /* 6 */
    tick(p, UP | START1 | A | R1, 0);                         /* 7 */
    tick(p, 0, 0);                                            /* 8 */
    log = read_log();
    CHECK(has_line(log, "say_roles_sticks: frame 5: act none"), "the very next stick change is the acting stick's");
    CHECK(has_line(log, "say_roles_down: frame 6: act dpad-up; drawer top-left") &&
          has_line(log, "say_roles_down: frame 7: navigate abxy-a; modify-navigate r1") &&
          has_line(log, "say_roles_up: frame 8: navigate abxy-a; act dpad-up; modify-navigate r1; drawer top-left"),
          "and the very next button events are left-handed and swapped");

    CHECK(input_settings_set(p, 2, 0) == INPUT_SETTINGS_BAD_VALUE &&
          input_settings_set(p, 0, -1) == INPUT_SETTINGS_BAD_VALUE,
          "a setting that is neither 0 nor 1 is turned away by the call");
    CHECK(input_settings_set(-5, 0, 0) == ENGINE_NO_STATION, "and so is a program that is not one");
    tick(p, UP, 0);                                           /* 9 */
    tick(p, 0, 0);                                            /* 10 */
    log = read_log();
    CHECK(has_line(log, "say_roles_down: frame 9: act dpad-up"), "leaving the settings as they were");

    /* Each setting on its own. */
    CHECK(input_settings_set(p, 0, 1) == 0, "right-handed with the drawers swapped");
    tick(p, UP | START1 | R2, 0);                             /* 11 */
    tick(p, 0, 0);                                            /* 12 */
    CHECK(input_settings_set(p, 1, 0) == 0, "left-handed with the drawers standard");
    tick(p, UP | START1 | L2, 0);                             /* 13 */
    tick(p, 0, 0);                                            /* 14 */
    log = read_log();
    CHECK(has_line(log, "say_roles_down: frame 11: navigate dpad-up; modify-act r2; drawer top-left") &&
          has_line(log, "say_roles_down: frame 13: act dpad-up; modify-act l2; drawer bottom-left"),
          "each setting takes effect alone, the other left as given");
    int64_t pair[2] = { 0, 0 };
    CHECK(engine_deliver(program_station(p, "roles_down"), 1, pair, sizeof pair) == ENGINE_WRONG_SIZE,
          "the appliers' dial takes the two settings and nothing wider");

    /* A program without the appliers: none is turned. */
    static char text[1024];
    snprintf(text, sizeof text,
        "boxes = ../boxes/\n"
        "station roles_down (boxes/134-input-roles.c:button_roles)\n"
        "  in 0 - 0$\n"
        "  in 1 = { 0, 0 }\n"
        "  out 0 - 0$\n");
    int partial = program_load_text("src/maps/test-one-applier.map", text, strlen(text), &report);
    CHECK(partial >= 0 && program_bring_up(partial, &report) == 0, "a map with one applier of three loads (%s)", report.text);
    CHECK(input_settings_set(partial, 1, 1) == ENGINE_NO_STATION, "and is not given the settings");
    struct button_event one_up;
    memset(&one_up, 0, sizeof one_up);
    one_up.frame = 1;
    one_up.buttons = UP;
    program_argument(partial, 0, &one_up, sizeof one_up);
    twin_engine_settle(5000);
    struct role_event got;
    CHECK(program_result(partial, 0, &got, sizeof got) == 1 && got.navigate == UP,
          "not even the one it has: it is still right-handed");
    CHECK(program_remove(partial) == 0, "and comes out");

    /* A program whose `roles_up` is some other box: the dial will not take
     * the settings, and the call says so. */
    snprintf(text, sizeof text,
        "boxes = ../boxes/\n"
        "station roles_down (boxes/134-input-roles.c:button_roles)\n"
        "  in 0 - 0$\n"
        "  in 1 = { 0, 0 }\n"
        "station roles_up (boxes/095-input.c:button_down)\n"
        "  in 0 - 1$\n"
        "  in 1 = 262143\n"
        "station roles_sticks (boxes/134-input-roles.c:stick_roles)\n"
        "  in 0 - 2$\n"
        "  in 1 = { 0, 0 }\n");
    int odd = program_load_text("src/maps/test-odd-applier.map", text, strlen(text), &report);
    CHECK(odd >= 0 && program_bring_up(odd, &report) == 0, "a map with an applier that is not one loads (%s)", report.text);
    CHECK(input_settings_set(odd, 1, 1) == ENGINE_WRONG_SIZE, "and the call answers that it could not turn it");
    CHECK(program_remove(odd) == 0, "and comes out");

    /* Turned as fast as a thread can, every event is one whole pair. */
    input_settings_set(p, 0, 0);
    size_t from = strlen(read_log());
    turn_program = p;
    turning = 1;
    turns = 0;
    pthread_t thread;
    pthread_create(&thread, NULL, turner, NULL);
    for (int i = 0; i < 200; i++) {
        tick(p, UP | START1, 0);
        tick(p, 0, 0);
    }
    turning = 0;
    pthread_join(thread, NULL);
    log = read_log() + from;
    int whole = 0, torn = 0, right = 0, left = 0;
    for (const char *at = log; (at = strstr(at, "say_roles_down: frame ")) != NULL; at++) {
        const char *colon = strchr(at + 22, ':');
        const char *nl = strchr(at, '\n');
        if (!colon || !nl) break;
        size_t n = (size_t)(nl - colon);
        if (n == strlen(": navigate dpad-up; drawer bottom-left") &&
            strncmp(colon, ": navigate dpad-up; drawer bottom-left", n) == 0) {
            whole++;
            right++;
        } else if (n == strlen(": act dpad-up; drawer top-left") &&
                   strncmp(colon, ": act dpad-up; drawer top-left", n) == 0) {
            whole++;
            left++;
        } else {
            torn++;
        }
    }
    CHECK(whole == 200 && torn == 0 && right > 0 && left > 0,
          "while the settings turned %ld times, all 200 downs answered to one whole pair (%d whole, %d torn, %d right, %d left)",
          turns, whole, torn, right, left);
    input_settings_set(p, 0, 0);

    /* --- garbled settings given directly ------------------------------------ */
    int32_t garbled[2] = { 2, 0 };
    CHECK(engine_deliver(program_station(p, "roles_down"), 1, garbled, sizeof garbled) == 0,
          "a garbled handedness reaches an applier directly");
    garbled[0] = 0;
    garbled[1] = 5;
    engine_deliver(program_station(p, "roles_sticks"), 1, garbled, sizeof garbled);
    twin_engine_settle(5000);
    tick(p, UP, 2000);
    tick(p, 0, 0);
    struct engine_error_report er;
    int has = engine_read_error(program_station(p, "roles_down"), &er, 0);
    CHECK(has == ENGINE_OK && er.kind == 1 && er.detail == 1,
          "and refuses it, saying handedness (%d, kind %d, detail %llu)", has, er.kind, (unsigned long long)er.detail);
    has = engine_read_error(program_station(p, "roles_sticks"), &er, 0);
    CHECK(has == ENGINE_OK && er.kind == 1 && er.detail == 2,
          "a garbled swap refuses the stick applier, saying the swap (%d, kind %d, detail %llu)",
          has, er.kind, (unsigned long long)er.detail);
    has = engine_read_error(program_station(p, "roles_up"), &er, 0);
    CHECK(has != ENGINE_OK || er.kind != 1, "and the applier given good settings goes on");

    CHECK(program_remove(p) == 0, "input-poll comes out");
    twin_engine_stop();
    metrics_close();
    CHECK_DONE("136 input roles");
}
