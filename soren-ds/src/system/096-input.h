/*
 * 096-input.h — starting and stopping the input frame (issue 501).
 *
 * General description: the input-poll map (src/maps/input-poll.map) is
 * an ordinary program; what makes it run 60 times a second is an engine
 * timer writing into its argument door. These two calls are the whole of
 * the outside's part: load and bring up the map, arm the timer; and, for
 * the laptop twin's tests, disarm it again. On the device the first call
 * belongs at the end of boot, once the engine's cores are running.
 */
#ifndef SOREN_INPUT_H
#define SOREN_INPUT_H

#include <stdint.h>
#include "../engine/068-programs.h"

#define INPUT_POLL_MAP "src/maps/input-poll.map"

/* {{{ the buttons (issue 502) */
/* Every button-shaped input is one bit of one 32-bit snapshot, in this
 * order (notes/diagnostics/001-button-bit-order.md says why). The names
 * are the ones the developer line prints and chord-of (505) will take. */
enum button {
    BUTTON_DPAD_UP,          /* dpad-up */
    BUTTON_DPAD_DOWN,        /* dpad-down */
    BUTTON_DPAD_LEFT,        /* dpad-left */
    BUTTON_DPAD_RIGHT,       /* dpad-right */
    BUTTON_A,                /* abxy-a */
    BUTTON_B,                /* abxy-b */
    BUTTON_X,                /* abxy-x */
    BUTTON_Y,                /* abxy-y */
    BUTTON_L1,               /* l1 */
    BUTTON_R1,               /* r1 */
    BUTTON_L2,               /* l2 */
    BUTTON_R2,               /* r2 */
    BUTTON_START1,           /* start1 */
    BUTTON_SELECT1,          /* select1 */
    BUTTON_SELECT2,          /* select2 */
    BUTTON_START2,           /* start2 */
    BUTTON_STICK_LEFT,       /* stick-left (the left stick's click) */
    BUTTON_STICK_RIGHT,      /* stick-right */
    BUTTON_COUNT
};
#define BUTTON_BIT(b) (1u << (b))
#define BUTTON_ALL    ((1u << BUTTON_COUNT) - 1u)

/* The name of one button, or "?" for a number that is not one. */
const char *button_name(int button);

/* Every button's state at this instant, one batched read: a bit set for
 * each button held down. Each side of the platform answers it its own way
 * — the device from the GPIO banks (101 maps the pins; until then it
 * answers 0), the twin from whatever a test set. */
uint32_t input_buttons_now(void);
/* }}} */

/* {{{ the sticks (issue 503) */
/* Both sticks' four axes at this instant, in one batched read, into
 * axes[0..3] = left x, left y, right x, right y. Each is centred on 0,
 * x growing to the right and y growing up, over about -2048 to 2047 (a
 * 12-bit converter with its middle taken off; 101 says which converter
 * and channels, and the device answers all zeros until then). */
#define STICK_AXES 4
void input_sticks_now(int32_t axes[STICK_AXES]);

/* The eight ways a stick (or the D-pad, two neighbouring bits at once)
 * can point, and none. Shared with 506 so either can choose a direction. */
enum direction {
    DIRECTION_NONE,
    DIRECTION_N, DIRECTION_NE, DIRECTION_E, DIRECTION_SE,
    DIRECTION_S, DIRECTION_SW, DIRECTION_W, DIRECTION_NW,
    DIRECTION_COUNT
};
const char *direction_name(int direction);
/* }}} */

/* {{{ the touch panels (issue 504) */
/* One panel's controller at this instant: out[0] 1 if touched, out[1]
 * and out[2] the position in that screen's pixels, out[3] the pressure.
 * Screen 0 is the bottom panel, 1 the top. A controller that does not
 * answer in time answers "not touched". The device answers that for both
 * until 101 names the controllers. */
#define TOUCH_SCREENS 2
#define TOUCH_FIELDS 4
void input_touch_now(int screen, int32_t out[TOUCH_FIELDS]);
/* }}} */

/* One frame. A second is not a whole number of nanoseconds over 60, so
 * this rounds 16 666 666.67 up: the frame drifts 20 ns a second (1.7 ms
 * a day) behind the true 60 Hz. Nothing on this device keeps wall time by
 * counting frames, so that is accepted rather than made exact. */
#define INPUT_FRAME_NS 16666667ull

struct input_poll {
    int program;                 /* the input-poll program, or -1 */
    int timer;                   /* the engine timer driving it, or -1 */
};

/* Load and bring up the input-poll map and start its frame, the first
 * tick one frame from now. Answers the program number, or -1 with the
 * reason in `report` (nothing is left placed or armed). */
int input_poll_start(struct input_poll *poll, struct map_report *report);

/* Stop the frame. The program stays placed, idle, with the next frame
 * number waiting on its loop; program_remove takes it away. */
void input_poll_stop(struct input_poll *poll);

#endif
