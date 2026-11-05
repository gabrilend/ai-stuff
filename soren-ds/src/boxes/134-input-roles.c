/*
 * 134-input-roles.c — handedness and the drawer swap, applied to the event
 * stream (issue 507).
 *
 * General description: a button event names physical buttons. An app
 * mostly wants to know what a button is for: which side is navigating and
 * which is acting, and which drawer a center button opens. Those depend
 * on two settings (docs/011's /settings/handedness and
 * /settings/drawer-swap), and this is the one place they are applied, so
 * no app does it on its own:
 *
 *   button_down / button_up ──→ button_roles ──→ (the apps, phase 6)
 *   stick_direction_changed ──→ stick_roles  ──→
 *                                   ▲
 *                     struct input_settings, a dial on each
 *
 * The physical identity is never changed: a role event carries the raw
 * event whole and adds the roles beside it. An app wanting the raw stream
 * hangs off the events before this; one wanting meaning, after.
 *
 *   right-handed (the default)          left-handed
 *   D-pad, left stick   navigate        A B X Y, right stick  navigate
 *   L1, L2              modify that     R1, R2                modify that
 *   A B X Y, right stick act            D-pad, left stick     act
 *   R1, R2              modify that     L1, L2                modify that
 *
 * The four center buttons open the drawers at the four corners. Standard:
 * start1 bottom-left, select1 bottom-right, select2 top-left, start2
 * top-right. Swapped, the pairs change screens and keep their side:
 * start1 top-left, select1 top-right, select2 bottom-left, start2
 * bottom-right.
 *
 * The settings are a fixed value on each applier station, turned like a
 * dial by input_settings_set (src/system/135-input-settings.h) when they
 * change. A dial is written under a sequence count (034-ports.c), so a
 * box reading it on any core sees the settings wholly before or wholly
 * after a change, never half of each.
 */
#include <stdint.h>
#include "../engine/031-engine.h"
#include "../engine/027-primitives.h"
#include "../system/096-input.h"

/* {{{ value types */
/* The two settings, as the appliers hold them: each 0 or 1. */
struct input_settings {
    int32_t left_handed;         /* 0 right-handed (the default), 1 left-handed */
    int32_t drawer_swap;         /* 0 standard, 1 swapped */
};

/* The drawers, a bit each. */
#define DRAWER_BOTTOM_LEFT  1u
#define DRAWER_BOTTOM_RIGHT 2u
#define DRAWER_TOP_LEFT     4u
#define DRAWER_TOP_RIGHT    8u

/* A button event with its meaning beside it. `buttons` and `held_ms` are
 * the raw event's own; each role mask is the part of `buttons` that has
 * that role now, and `drawers` the drawers its center buttons open. */
struct role_event {
    int64_t  frame;
    uint32_t buttons;
    uint32_t navigate;           /* the direction side's buttons */
    uint32_t act;                /* the action side's buttons */
    uint32_t modify_navigate;    /* the direction side's triggers */
    uint32_t modify_act;         /* the action side's triggers */
    uint32_t drawers;            /* DRAWER_* */
    uint16_t held_ms[BUTTON_COUNT];
};

/* A stick change with its meaning: which stick is navigating now, and
 * what each role's stick points. `changed` is in roles: bit 0 the
 * navigating stick changed, bit 1 the acting stick. */
struct stick_role_event {
    int64_t  frame;
    uint32_t changed;
    uint32_t reserved;
    int32_t  navigate;           /* enum direction */
    int32_t  act;
};
/* }}} */

#define ROLES_DPAD    (BUTTON_BIT(BUTTON_DPAD_UP) | BUTTON_BIT(BUTTON_DPAD_DOWN) | \
                       BUTTON_BIT(BUTTON_DPAD_LEFT) | BUTTON_BIT(BUTTON_DPAD_RIGHT) | \
                       BUTTON_BIT(BUTTON_STICK_LEFT))
#define ROLES_FACE    (BUTTON_BIT(BUTTON_A) | BUTTON_BIT(BUTTON_B) | \
                       BUTTON_BIT(BUTTON_X) | BUTTON_BIT(BUTTON_Y) | \
                       BUTTON_BIT(BUTTON_STICK_RIGHT))
#define ROLES_L       (BUTTON_BIT(BUTTON_L1) | BUTTON_BIT(BUTTON_L2))
#define ROLES_R       (BUTTON_BIT(BUTTON_R1) | BUTTON_BIT(BUTTON_R2))

/* {{{ settings_refused */
/* A setting that is neither 0 nor 1 refuses the station (detail 1 for
 * handedness, 2 for the swap): a torn or garbled value is said, not
 * guessed at. Answers 1 when refused. */
static int settings_refused(struct input_settings s)
{
    if (s.left_handed != 0 && s.left_handed != 1) {
        engine_refuse(1);
        return 1;
    }
    if (s.drawer_swap != 0 && s.drawer_swap != 1) {
        engine_refuse(2);
        return 1;
    }
    return 0;
}
/* }}} */

/* {{{ button_roles */
/* One button event (down, up or held, 502) with its roles and drawers as
 * the settings now stand. Nothing about the raw event changes. */
struct role_event button_roles(struct button_event e, struct input_settings s)
{
    struct role_event r;
    bytes_zero(&r, sizeof r);
    r.frame = e.frame;
    r.buttons = e.buttons;
    for (int b = 0; b < BUTTON_COUNT; b++) {
        r.held_ms[b] = e.held_ms[b];
    }
    if (settings_refused(s)) {
        return r;
    }
    uint32_t nav_side = s.left_handed ? ROLES_FACE : ROLES_DPAD;
    uint32_t act_side = s.left_handed ? ROLES_DPAD : ROLES_FACE;
    uint32_t nav_triggers = s.left_handed ? ROLES_R : ROLES_L;
    uint32_t act_triggers = s.left_handed ? ROLES_L : ROLES_R;
    r.navigate = e.buttons & nav_side;
    r.act = e.buttons & act_side;
    r.modify_navigate = e.buttons & nav_triggers;
    r.modify_act = e.buttons & act_triggers;
    static const uint32_t standard[4] = {
        DRAWER_BOTTOM_LEFT, DRAWER_BOTTOM_RIGHT, DRAWER_TOP_LEFT, DRAWER_TOP_RIGHT,
    };
    static const uint32_t swapped[4] = {
        DRAWER_TOP_LEFT, DRAWER_TOP_RIGHT, DRAWER_BOTTOM_LEFT, DRAWER_BOTTOM_RIGHT,
    };
    for (int i = 0; i < 4; i++) {
        if (e.buttons & BUTTON_BIT(BUTTON_START1 + i)) {
            r.drawers |= s.drawer_swap ? swapped[i] : standard[i];
        }
    }
    return r;
}
/* }}} */

/* {{{ stick_roles */
/* One stick change (503) by role: the left stick navigates right-handed,
 * the right stick left-handed. */
struct stick_role_event stick_roles(struct stick_change c, struct input_settings s)
{
    struct stick_role_event r;
    bytes_zero(&r, sizeof r);
    r.frame = c.frame;
    if (settings_refused(s)) {
        return r;
    }
    if (s.left_handed) {
        r.navigate = c.right;
        r.act = c.left;
        r.changed = ((c.changed & 2u) ? 1u : 0u) | ((c.changed & 1u) ? 2u : 0u);
    } else {
        r.navigate = c.left;
        r.act = c.right;
        r.changed = c.changed & 3u;
    }
    return r;
}
/* }}} */

/* {{{ say_roles */
/* A role event on the developer line: the station's name, the frame, and
 * each role that has buttons, by name, then each drawer, the groups
 * parted by semicolons: "navigate dpad-up; act abxy-a; drawer top-left". */
void say_roles(struct role_event r)
{
    static const char *const role_names[4] = { "navigate", "act", "modify-navigate", "modify-act" };
    static const char *const drawer_names[4] = { "bottom-left", "bottom-right", "top-left", "top-right" };
    uint32_t masks[4] = { r.navigate, r.act, r.modify_navigate, r.modify_act };
    char line[512];
    size_t used = 0;
    line[0] = 0;
    for (int k = 0; k < 4; k++) {
        if (!masks[k]) continue;
        text_format(line + used, sizeof line - used, "%s %s", used ? ";" : "", role_names[k]);
        used = text_length(line);
        for (int b = 0; b < BUTTON_COUNT; b++) {
            if (masks[k] & BUTTON_BIT(b)) {
                text_format(line + used, sizeof line - used, " %s", button_name(b));
                used = text_length(line);
            }
        }
    }
    for (int d = 0; d < 4; d++) {
        if (r.drawers & (1u << d)) {
            text_format(line + used, sizeof line - used, "%s drawer %s", used ? ";" : "", drawer_names[d]);
            used = text_length(line);
        }
    }
    say_line("%s: frame %lld:%s", engine_station_name(engine_current_station()), (long long)r.frame, line);
}
/* }}} */

/* {{{ say_stick_roles */
/* A stick change by role on the developer line. */
void say_stick_roles(struct stick_role_event r)
{
    char line[128];
    size_t used = 0;
    line[0] = 0;
    if (r.changed & 1u) {
        text_format(line, sizeof line, " navigate %s", direction_name(r.navigate));
        used = text_length(line);
    }
    if (r.changed & 2u) {
        text_format(line + used, sizeof line - used, " act %s", direction_name(r.act));
    }
    say_line("%s: frame %lld:%s", engine_station_name(engine_current_station()), (long long)r.frame, line);
}
/* }}} */
