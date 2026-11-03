/*
 * 095-input.c — the input surfaces, as box sources (issues 501 onward).
 *
 * General description: the frame every input surface hangs off, and the
 * boxes that read each surface once per frame. The 60 Hz tick is not a
 * box: it is an engine timer writing a fixed value into the input-poll
 * map's argument door (see src/maps/input-poll.map and
 * src/system/096-input.c). What a box cannot do is count, because a box
 * cannot remember — so the frame number rides a wire that points back to
 * the station that makes it, exactly as counting.map's count does:
 *
 *   tick ──→ frame_next ──┬──→ read_buttons ──→ button_track ──┬──→ button_down
 *              ▲          │                       ▲           ├──→ button_up
 *              │          │                       └───────────┤──→ button_held
 *              │          │      (the buttons' history, going round)
 *              │          ├──→ read_sticks ──→ stick_deadband ──→ stick_direction ──→ stick_track ──→ changed
 *              │          ├──→ read_touch  ──→ touch_track ──┬──→ touch_down / touch_move / touch_up
 *              └──────────┘  (the previous frame, going round; each *_track has its own history loop too)
 *
 * The buttons (issue 502), the sticks (503) and the touch panels (504)
 * each keep their history on a loop of their own and hang their events
 * off it as comparators, so only a frame where something happened goes
 * on; chord_of (505) hangs off the buttons' history where a map wants a
 * chord. What reads each surface is src/system/096-input.h's seam: the
 * twin answers what a test set, and the device answers "nothing" until
 * issue 101 names the pins, channels and controllers.
 *
 * The value types are declared here, once, because later box files are
 * included after this one in the catalogue and may use them by name.
 */
#include <stdint.h>
#include "../engine/031-engine.h"
#include "../engine/027-primitives.h"
#include "../system/096-input.h"

/* {{{ value types */
/* Every button-shaped input as one bitmap, sampled at one instant. The
 * bit order is enum button in 096-input.h. */
struct button_snapshot {
    int64_t  frame;
    uint32_t pressed;            /* bit set: held down at this frame */
    uint32_t reserved;           /* zero; keeps the value a whole number of words */
};

/* The buttons as they stand after a frame, and what changed in it. This
 * is the history that goes round the loop to button_track's own input:
 * the box keeps nothing, so the press frames ride the wire. */
struct button_state {
    int64_t  frame;                       /* the frame this describes */
    uint32_t pressed;                     /* held down now */
    uint32_t went_down;                   /* released last frame, down now */
    uint32_t went_up;                     /* down last frame, released now */
    uint32_t fresh;                       /* 0: a stale snapshot changed nothing */
    int64_t  down_since[BUTTON_COUNT];    /* the frame each held button went down */
    int64_t  held_frames[BUTTON_COUNT];   /* for each that went up: frames it was held */
};

/* One frame's events of one kind: every button the event is about, at
 * once. One value per frame rather than one per button, because buttons
 * pressed together are the chord detector's whole interest (505). Ordered
 * by `buttons`, so a comparator against an all-zero event lets only real
 * events out of its "above" exit.
 *
 * Small on purpose: a comparator copies its threshold into 64 bytes of
 * stack and discards everything when the type is wider (issue 313), so
 * the durations are 16-bit milliseconds, a press of 65.5 s or longer
 * reading 65535. */
struct button_event {
    int64_t  frame;
    uint32_t buttons;                     /* the buttons this is about */
    uint32_t reserved;
    uint16_t held_ms[BUTTON_COUNT];       /* button_up only: how long each was held */
};

/* {{{ button_event__compare */
int button_event__compare(struct button_event a, struct button_event b)
{
    return a.buttons < b.buttons ? -1 : (a.buttons > b.buttons ? 1 : 0);
}
/* }}} */

/* Which two buttons make a chord, by name, and how many frames apart
 * they may go down and still count as struck together (505). */
struct chord {
    char    first[16];                    /* a button's name: "dpad-up" */
    char    second[16];                   /* "abxy-a" */
    int64_t window;                       /* frames; 0 is the same frame only */
};

/* A chord struck: once, on the frame its second button went down.
 * Ordered by `buttons`, like a button event, so a comparator against an
 * all-zero one lets only chords out. */
struct chord_event {
    int64_t  frame;
    uint32_t buttons;                     /* the two buttons */
    uint32_t apart;                       /* frames between their downs */
};

/* {{{ chord_event__compare */
int chord_event__compare(struct chord_event a, struct chord_event b)
{
    return a.buttons < b.buttons ? -1 : (a.buttons > b.buttons ? 1 : 0);
}
/* }}} */

/* Both sticks, raw. Their clicks are buttons and live in the bitmap. */
struct stick_snapshot {
    int64_t frame;
    int32_t left_x;
    int32_t left_y;
    int32_t right_x;
    int32_t right_y;
};

/* One panel's single cursor (no multi-touch, docs/004). */
struct touch_point {
    int32_t down;                /* 1 while something touches the panel */
    int32_t x;
    int32_t y;
    int32_t pressure;
};

struct touch_snapshot {
    int64_t            frame;
    struct touch_point bottom;   /* screen 0 */
    struct touch_point top;      /* screen 1 */
};

/* How a stick is read: the radius of its resting circle, and how wide
 * its four straight-on sectors are, given as the tangent of half their
 * angle in millionths — 414214 is 22.5 degrees, which makes all eight
 * sectors equal. The device's own numbers belong in
 * notes/diagnostics/002-stick-calibration.md (measured on the device). */
struct stick_tuning {
    int32_t left_deadband;
    int32_t right_deadband;
    int32_t left_edge;
    int32_t right_edge;
};

/* Both sticks as one of enum direction (096-input.h) each. */
struct stick_directions {
    int64_t frame;
    int32_t left;
    int32_t right;
};

/* The sticks' directions after a frame, and which changed in it: the
 * history that goes round stick_track's loop. */
struct stick_history {
    int64_t  frame;
    int32_t  left;
    int32_t  right;
    uint32_t changed;            /* bit 0 the left stick, bit 1 the right */
    uint32_t fresh;              /* 0: a stale frame changed nothing */
};

/* A frame in which a stick's direction changed: which, and to what.
 * Ordered by `changed`, so a comparator against all zeros lets only
 * changes out. */
struct stick_change {
    int64_t  frame;
    uint32_t changed;
    uint32_t reserved;
    int32_t  left;
    int32_t  right;
};

/* Both panels after a frame, and what happened on each: the history that
 * goes round touch_track's loop. A panel's point is where it is touched,
 * or, once let go, where it was last touched (with `down` 0). Bit 0 of
 * each mask is the bottom screen, bit 1 the top. */
struct touch_history {
    int64_t            frame;
    uint32_t           fresh;
    uint32_t           went_down;
    uint32_t           moved;
    uint32_t           went_up;
    struct touch_point bottom;
    struct touch_point top;
};

/* One frame's touch events of one kind, both screens at once: which
 * screens, and where on each. For touch-up, where it was last touched.
 * Ordered by `screens`, like a button event. */
struct touch_event {
    int64_t  frame;
    uint32_t screens;
    uint32_t reserved;
    int32_t  bottom_x;
    int32_t  bottom_y;
    int32_t  top_x;
    int32_t  top_y;
};

/* {{{ stick_change__compare */
int stick_change__compare(struct stick_change a, struct stick_change b)
{
    return a.changed < b.changed ? -1 : (a.changed > b.changed ? 1 : 0);
}
/* }}} */

/* {{{ touch_event__compare */
int touch_event__compare(struct touch_event a, struct touch_event b)
{
    return a.screens < b.screens ? -1 : (a.screens > b.screens ? 1 : 0);
}
/* }}} */
/* }}} */

/* {{{ frame_next */
/* The frame counter: the timer's tick on port 0, the previous frame on
 * port 1 (going round), the next frame out. The tick's value means
 * nothing; its arrival is the frame. Frame 1 is the first tick. */
int64_t frame_next(int64_t tick, int64_t previous)
{
    (void)tick;
    return previous + 1;
}
/* }}} */

/* {{{ read_buttons */
/* Every button, in one read, at the moment this frame is handled. */
struct button_snapshot read_buttons(int64_t frame)
{
    struct button_snapshot s = { frame, input_buttons_now(), 0 };
    return s;
}
/* }}} */

/* {{{ buttons_at_rest */
/* The history before the first frame: nothing pressed, nothing seen. Put
 * on the loop once, by a fixed value. */
struct button_state buttons_at_rest(int64_t start)
{
    struct button_state s;
    bytes_zero(&s, sizeof s);
    s.frame = start;
    return s;
}
/* }}} */

/* {{{ button_track */
/* This frame's snapshot against the history: what went down, what went
 * up and for how long it had been held. Two cores may read neighbouring
 * frames' buttons at once and finish in either order; a snapshot no newer
 * than the history is stale, and changes nothing (fresh = 0) rather than
 * undoing a newer frame. */
struct button_state button_track(struct button_snapshot now, struct button_state before)
{
    struct button_state s = before;
    s.went_down = 0;
    s.went_up = 0;
    if (now.frame <= before.frame) {
        s.fresh = 0;
        return s;
    }
    uint32_t pressed = now.pressed & BUTTON_ALL;
    s.frame = now.frame;
    s.fresh = 1;
    s.pressed = pressed;
    s.went_down = pressed & ~before.pressed;
    s.went_up = before.pressed & ~pressed;
    for (int b = 0; b < BUTTON_COUNT; b++) {
        uint32_t bit = BUTTON_BIT(b);
        s.held_frames[b] = 0;
        if (s.went_down & bit) {
            s.down_since[b] = now.frame;
        } else if (s.went_up & bit) {
            s.held_frames[b] = now.frame - before.down_since[b];
            s.down_since[b] = 0;
        }
    }
    return s;
}
/* }}} */

/* {{{ frames_to_ms */
/* A frame is 1000/60 ms; rounded to the nearest, and held at 65535. */
static uint16_t frames_to_ms(int64_t frames)
{
    int64_t ms = (frames * 1000 + 30) / 60;
    return (uint16_t)(ms > 65535 ? 65535 : ms);
}
/* }}} */

/* {{{ button_down */
/* The buttons among `listen` that went down this frame. */
struct button_event button_down(struct button_state s, uint32_t listen)
{
    struct button_event e;
    bytes_zero(&e, sizeof e);
    e.frame = s.frame;
    e.buttons = s.fresh ? (s.went_down & listen) : 0;
    return e;
}
/* }}} */

/* {{{ button_up */
/* The buttons among `listen` that went up this frame, each with how long
 * it was held, in milliseconds counted from frames. */
struct button_event button_up(struct button_state s, uint32_t listen)
{
    struct button_event e;
    bytes_zero(&e, sizeof e);
    e.frame = s.frame;
    e.buttons = s.fresh ? (s.went_up & listen) : 0;
    for (int b = 0; b < BUTTON_COUNT; b++) {
        if (e.buttons & BUTTON_BIT(b)) {
            e.held_ms[b] = frames_to_ms(s.held_frames[b]);
        }
    }
    return e;
}
/* }}} */

/* {{{ button_held */
/* The buttons among `listen` held down this frame, once per frame — the
 * frame a button goes down included, the frame it goes up not. */
struct button_event button_held(struct button_state s, uint32_t listen)
{
    struct button_event e;
    bytes_zero(&e, sizeof e);
    e.frame = s.frame;
    e.buttons = s.fresh ? (s.pressed & listen) : 0;
    return e;
}
/* }}} */

/* {{{ chord_of */
/* Two buttons struck together (issue 505), named in a fixed value:
 * `{ "dpad-up", "abxy-a", 3 }`. "Together" is within `window` frames of
 * each other, in either order, with both still held when the second goes
 * down — 0 is the same frame and nothing else. The event comes once, on
 * the frame the second button goes down, and carries the frame, the two
 * buttons, and how many frames apart they went down.
 *
 * It reads the button history, not the down events: the history already
 * holds the frame each button went down, so no window of past frames has
 * to be carried round a loop of its own, and two cores running it for
 * neighbouring frames share nothing. A name that is not a button refuses
 * the station on its first run (the refusal's detail is 1 for the first
 * name, 2 for the second, 3 for the same button twice, 4 for a negative
 * window), which takes it out of service where the person can see why. */
struct chord_event chord_of(struct button_state s, struct chord c)
{
    struct chord_event e;
    bytes_zero(&e, sizeof e);
    e.frame = s.frame;
    c.first[sizeof c.first - 1] = 0;
    c.second[sizeof c.second - 1] = 0;
    int first = -1, second = -1;
    for (int b = 0; b < BUTTON_COUNT; b++) {
        if (text_equal(c.first, button_name(b)))  first = b;
        if (text_equal(c.second, button_name(b))) second = b;
    }
    if (first < 0)        engine_refuse(1);
    else if (second < 0)  engine_refuse(2);
    else if (first == second) engine_refuse(3);
    else if (c.window < 0) engine_refuse(4);
    if (first < 0 || second < 0 || first == second || c.window < 0 || !s.fresh) {
        return e;
    }
    uint32_t both = BUTTON_BIT(first) | BUTTON_BIT(second);
    if ((s.pressed & both) != both || !(s.went_down & both)) {
        return e;
    }
    int64_t apart = s.down_since[first] - s.down_since[second];
    if (apart < 0) apart = -apart;
    if (apart > c.window) {
        return e;
    }
    e.buttons = both;
    e.apart = (uint32_t)apart;
    return e;
}
/* }}} */

/* {{{ say_chord */
/* A chord on the developer line: the station's name, the frame, the two
 * buttons by name and how many frames apart they went down. */
void say_chord(struct chord_event e)
{
    const char *names[2] = { "?", "?" };
    int n = 0;
    for (int b = 0; b < BUTTON_COUNT && n < 2; b++) {
        if (e.buttons & BUTTON_BIT(b)) names[n++] = button_name(b);
    }
    say_line("%s: frame %lld: %s + %s (%u apart)", engine_station_name(engine_current_station()),
             (long long)e.frame, names[0], names[1], (unsigned)e.apart);
}
/* }}} */

/* {{{ say_buttons */
/* One event on the developer line: the station's name, the frame, and
 * each button by name, with how long it was held when that is known.
 * Where events go until phase 6 gives them somewhere to go. */
void say_buttons(struct button_event e)
{
    char line[512];
    size_t used = 0;
    line[0] = 0;
    for (int b = 0; b < BUTTON_COUNT; b++) {
        if (!(e.buttons & BUTTON_BIT(b))) {
            continue;
        }
        if (e.held_ms[b] > 0) {
            text_format(line + used, sizeof line - used, " %s (%u ms)",
                        button_name(b), (unsigned)e.held_ms[b]);
        } else {
            text_format(line + used, sizeof line - used, " %s", button_name(b));
        }
        used = text_length(line);
    }
    say_line("%s: frame %lld:%s", engine_station_name(engine_current_station()),
             (long long)e.frame, line);
}
/* }}} */

/* {{{ read_sticks */
/* Both sticks, in one read, at the moment this frame is handled. */
struct stick_snapshot read_sticks(int64_t frame)
{
    int32_t axes[STICK_AXES];
    input_sticks_now(axes);
    struct stick_snapshot s = { frame, axes[0], axes[1], axes[2], axes[3] };
    return s;
}
/* }}} */

/* {{{ inside_circle */
/* Is (x, y) closer to the middle than `radius`? A circle, not a square,
 * so a small push on a diagonal rests exactly as a small push straight. */
static int inside_circle(int32_t x, int32_t y, int32_t radius)
{
    int64_t r = radius < 0 ? 0 : radius;
    return (int64_t)x * x + (int64_t)y * y < r * r;
}
/* }}} */

/* {{{ stick_deadband */
/* Each stick that rests inside its circle reads as centred; one outside
 * it reads as it is. */
struct stick_snapshot stick_deadband(struct stick_snapshot s, struct stick_tuning t)
{
    if (inside_circle(s.left_x, s.left_y, t.left_deadband)) {
        s.left_x = 0;
        s.left_y = 0;
    }
    if (inside_circle(s.right_x, s.right_y, t.right_deadband)) {
        s.right_x = 0;
        s.right_y = 0;
    }
    return s;
}
/* }}} */

/* {{{ quantize */
/* One of the eight directions by angle, with no floating point: a point
 * is straight on when its smaller axis is within `edge` millionths of its
 * larger (the tangent of its angle from the axis), and diagonal
 * otherwise. Centred is none. */
static int32_t quantize(int32_t x, int32_t y, int32_t edge)
{
    if (x == 0 && y == 0) {
        return DIRECTION_NONE;
    }
    if (edge < 0) edge = 0;
    if (edge > 1000000) edge = 1000000;
    int64_t ax = x < 0 ? -(int64_t)x : x;
    int64_t ay = y < 0 ? -(int64_t)y : y;
    if (ay * 1000000 <= ax * edge) {
        return x > 0 ? DIRECTION_E : DIRECTION_W;
    }
    if (ax * 1000000 <= ay * edge) {
        return y > 0 ? DIRECTION_N : DIRECTION_S;
    }
    if (x > 0) {
        return y > 0 ? DIRECTION_NE : DIRECTION_SE;
    }
    return y > 0 ? DIRECTION_NW : DIRECTION_SW;
}
/* }}} */

/* {{{ stick_direction */
/* Both sticks as directions, every frame. */
struct stick_directions stick_direction(struct stick_snapshot s, struct stick_tuning t)
{
    struct stick_directions d = {
        s.frame,
        quantize(s.left_x, s.left_y, t.left_edge),
        quantize(s.right_x, s.right_y, t.right_edge),
    };
    return d;
}
/* }}} */

/* {{{ sticks_at_rest */
/* The sticks' history before the first frame: both centred. */
struct stick_history sticks_at_rest(int64_t start)
{
    struct stick_history h;
    bytes_zero(&h, sizeof h);
    h.frame = start;
    return h;
}
/* }}} */

/* {{{ stick_track */
/* This frame's directions against the last: which stick changed. A frame
 * no newer than the history is stale and changes nothing, as for the
 * buttons. */
struct stick_history stick_track(struct stick_directions now, struct stick_history before)
{
    struct stick_history h = before;
    h.changed = 0;
    if (now.frame <= before.frame) {
        h.fresh = 0;
        return h;
    }
    h.frame = now.frame;
    h.fresh = 1;
    h.changed = (now.left != before.left ? 1u : 0u) | (now.right != before.right ? 2u : 0u);
    h.left = now.left;
    h.right = now.right;
    return h;
}
/* }}} */

/* {{{ stick_direction_changed */
/* A frame where a stick's direction changed, and both directions as they
 * now stand. */
struct stick_change stick_direction_changed(struct stick_history h)
{
    struct stick_change c;
    bytes_zero(&c, sizeof c);
    c.frame = h.frame;
    c.changed = h.fresh ? h.changed : 0;
    c.left = h.left;
    c.right = h.right;
    return c;
}
/* }}} */

/* {{{ say_sticks */
/* A change on the developer line: each stick that changed, and its new
 * direction. */
void say_sticks(struct stick_change c)
{
    char line[128];
    size_t used = 0;
    line[0] = 0;
    if (c.changed & 1u) {
        text_format(line, sizeof line, " left %s", direction_name(c.left));
        used = text_length(line);
    }
    if (c.changed & 2u) {
        text_format(line + used, sizeof line - used, " right %s", direction_name(c.right));
    }
    say_line("%s: frame %lld:%s", engine_station_name(engine_current_station()), (long long)c.frame, line);
}
/* }}} */

/* {{{ read_touch */
/* Both panels, read one after the other in the same frame. */
struct touch_snapshot read_touch(int64_t frame)
{
    int32_t b[TOUCH_FIELDS], t[TOUCH_FIELDS];
    input_touch_now(0, b);
    input_touch_now(1, t);
    struct touch_snapshot s = { frame, { b[0] != 0, b[1], b[2], b[3] }, { t[0] != 0, t[1], t[2], t[3] } };
    return s;
}
/* }}} */

/* {{{ touch_at_rest */
/* The panels' history before the first frame: neither touched. */
struct touch_history touch_at_rest(int64_t start)
{
    struct touch_history h;
    bytes_zero(&h, sizeof h);
    h.frame = start;
    return h;
}
/* }}} */

/* {{{ track_panel */
/* One panel: what happened between `before` and `now`, as a bit in the
 * history's masks, and what the panel's point becomes. */
static struct touch_point track_panel(struct touch_point now, struct touch_point before,
                                      uint32_t bit, struct touch_history *h)
{
    if (now.down && !before.down) {
        h->went_down |= bit;
        return now;
    }
    if (now.down && before.down) {
        if (now.x != before.x || now.y != before.y) {
            h->moved |= bit;
        }
        return now;
    }
    if (!now.down && before.down) {
        h->went_up |= bit;
    }
    before.down = 0;                     /* let go: keep where it last was */
    before.pressure = 0;
    return before;
}
/* }}} */

/* {{{ touch_track */
/* This frame's panels against the last. Stale frames change nothing. */
struct touch_history touch_track(struct touch_snapshot now, struct touch_history before)
{
    struct touch_history h = before;
    h.went_down = 0;
    h.moved = 0;
    h.went_up = 0;
    if (now.frame <= before.frame) {
        h.fresh = 0;
        return h;
    }
    h.frame = now.frame;
    h.fresh = 1;
    h.bottom = track_panel(now.bottom, before.bottom, 1u, &h);
    h.top = track_panel(now.top, before.top, 2u, &h);
    return h;
}
/* }}} */

/* {{{ touch_event_of */
/* An event about the screens in `screens`, where each one's point is. */
static struct touch_event touch_event_of(const struct touch_history *h, uint32_t screens)
{
    struct touch_event e;
    bytes_zero(&e, sizeof e);
    e.frame = h->frame;
    e.screens = h->fresh ? screens : 0;
    if (e.screens & 1u) {
        e.bottom_x = h->bottom.x;
        e.bottom_y = h->bottom.y;
    }
    if (e.screens & 2u) {
        e.top_x = h->top.x;
        e.top_y = h->top.y;
    }
    return e;
}
/* }}} */

/* {{{ touch_down */
/* The screens first touched this frame, and where. */
struct touch_event touch_down(struct touch_history h)
{
    return touch_event_of(&h, h.went_down);
}
/* }}} */

/* {{{ touch_move */
/* The screens still touched this frame whose point moved by at least a
 * pixel, and where to. Positions are whole pixels, so this is also the
 * issue's touch-move-changed: there is no smaller move to leave out. */
struct touch_event touch_move(struct touch_history h)
{
    return touch_event_of(&h, h.moved);
}
/* }}} */

/* {{{ touch_up */
/* The screens let go this frame, and where each was last touched. */
struct touch_event touch_up(struct touch_history h)
{
    return touch_event_of(&h, h.went_up);
}
/* }}} */

/* {{{ say_touch */
/* A touch event on the developer line: each screen it is about, and
 * where. */
void say_touch(struct touch_event e)
{
    char line[128];
    size_t used = 0;
    line[0] = 0;
    if (e.screens & 1u) {
        text_format(line, sizeof line, " bottom %d,%d", (int)e.bottom_x, (int)e.bottom_y);
        used = text_length(line);
    }
    if (e.screens & 2u) {
        text_format(line + used, sizeof line - used, " top %d,%d", (int)e.top_x, (int)e.top_y);
    }
    say_line("%s: frame %lld:%s", engine_station_name(engine_current_station()), (long long)e.frame, line);
}
/* }}} */
