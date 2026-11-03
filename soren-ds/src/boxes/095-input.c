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
 *   tick ──→ frame_next ──┬──→ read_buttons ──→ button_events
 *              ▲          ├──→ read_sticks  ──→ stick_events
 *              │          ├──→ read_touch   ──→ touch_events
 *              └──────────┘  (the previous frame, going round)
 *
 * The read boxes are stubs for now (issue 501): each answers an empty
 * state stamped with its frame, and each event box only tallies the frame
 * it was handed, so a test can see that every frame reached every
 * surface exactly once. Issues 502, 503 and 504 replace them.
 *
 * The value types are declared here, once, because later box files are
 * included after this one in the catalogue and may use them by name.
 */
#include <stdint.h>
#include "../engine/031-engine.h"
#include "../engine/038-tallies.h"

/* {{{ value types */
/* Every button-shaped input as one bitmap, sampled at one instant. The
 * bit order is notes/diagnostics/001-button-bit-order.md (issue 502). */
struct button_snapshot {
    int64_t  frame;
    uint32_t pressed;            /* bit set: held down at this frame */
    uint32_t reserved;           /* zero; keeps the value a whole number of words */
};

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
/* Stub (issue 501): nothing is pressed. Issue 502 makes it read. */
struct button_snapshot read_buttons(int64_t frame)
{
    struct button_snapshot s = { frame, 0, 0 };
    return s;
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

/* {{{ button_events */
/* Stub (issue 501): records which frame arrived — the tally is the
 * outside world this box writes to, like a screen or a serial line. */
void button_events(struct button_snapshot s)
{
    tally_add(engine_current_station(), s.frame);
}
/* }}} */

/* {{{ stick_events */
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
