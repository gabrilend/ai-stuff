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
 *              │          ├──→ read_sticks  ──→ stick_events
 *              │          ├──→ read_touch   ──→ touch_events
 *              └──────────┘  (the previous frame, going round)
 *
 * The buttons are real (issue 502), and chord_of (505) hangs off their
 * history where a map wants a chord. The sticks and the touch panels are
 * still stubs (issue 501): each answers an empty state stamped with its
 * frame, and its event box only tallies the frame it was handed. Issues
 * 503 and 504 replace them.
 *
 * The value types are declared here, once, because later box files are
 * included after this one in the catalogue and may use them by name.
 */
#include <stdint.h>
#include "../engine/031-engine.h"
#include "../engine/038-tallies.h"
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
/* Stub (issue 501): both sticks centred. Issue 503 makes it read. */
struct stick_snapshot read_sticks(int64_t frame)
{
    struct stick_snapshot s = { frame, 0, 0, 0, 0 };
    return s;
}
/* }}} */

/* {{{ read_touch */
/* Stub (issue 501): neither panel touched. Issue 504 makes it read. */
struct touch_snapshot read_touch(int64_t frame)
{
    struct touch_snapshot s = { frame, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } };
    return s;
}
/* }}} */

/* {{{ stick_events */
/* Stub (issue 501): records which frame arrived — the tally is the
 * outside world this box writes to, like a screen or a serial line. */
void stick_events(struct stick_snapshot s)
{
    tally_add(engine_current_station(), s.frame);
}
/* }}} */

/* {{{ touch_events */
void touch_events(struct touch_snapshot s)
{
    tally_add(engine_current_station(), s.frame);
}
/* }}} */
