/*
 * 131-radial-menu.c — the radial menu chord: one character from one hand's
 * direction and the other hand's face button (issue 506).
 *
 * General description: text entry on this device is a chord of one button
 * from each hand. The left hand holds a direction — the D-pad, eight ways
 * with its diagonals, or the left stick — and the radial menu shows the
 * four characters on offer there; the right hand presses A, B, X or Y to
 * type one of them. The triggers held at that moment pick the mode, so the
 * same thirty-two places hold lower case, upper case, digits and the rest.
 * The character is the cell at (direction, face button, mode) of a table
 * the map holds, which the editor (phase 8) can replace with the user's
 * own.
 *
 *   frame ──→ radial_read ──→ radial_track ──→ radial_chord ──→ a character
 *                               ▲         │
 *                               └─────────┘  (the history, going round)
 *
 * It reads the buttons and the sticks itself, at one instant, rather than
 * pairing the button history (502) with the sticks' (503): values may
 * leave a port in a different order than they arrived (034-ports.c), so
 * two streams joined at one station could pair one frame's buttons with
 * another frame's stick. One reading carries both, and one history goes
 * round one loop.
 *
 * The whole of it is src/maps/radial-menu-chord.map, a program with one
 * door in (the frame number) and one door out (the characters). A user's
 * own table replaces the default through src/system/133-radial-menu.h.
 */
#include <stdint.h>
#include "../engine/031-engine.h"
#include "../engine/027-primitives.h"
#include "../system/096-input.h"

/* {{{ value types */
/* Where the direction may come from, and how the sticks are read. Bit 0
 * of `sources` is the D-pad, bit 1 the left stick, bit 2 the right stick;
 * when more than one points, the first in that order wins. The sticks are
 * read as 503 reads them: a resting circle, then eight sectors. */
#define RADIAL_FROM_DPAD        1
#define RADIAL_FROM_LEFT_STICK  2
#define RADIAL_FROM_RIGHT_STICK 4
#define RADIAL_FROM_ALL         7

struct radial_source {
    int32_t             sources;
    int32_t             reserved;
    struct stick_tuning sticks;
};

/* One instant: every button, and the one direction the sources point. */
struct radial_snapshot {
    int64_t  frame;
    uint32_t pressed;
    int32_t  direction;
};

/* The history that goes round the loop: as the snapshot, plus which
 * buttons went down this frame. */
struct radial_history {
    int64_t  frame;
    uint32_t pressed;
    uint32_t went_down;
    int32_t  direction;
    uint32_t fresh;              /* 0: a stale reading changed nothing */
};

/* The characters, a mode to a line: thirty-two places each, in the order
 * n, ne, e, se, s, sw, w, nw, and within a direction A, B, X, Y. A line
 * shorter than thirty-two leaves the places after it empty, and an empty
 * place types nothing. `select` says which mode each combination of held
 * triggers is: its index is the triggers as bits (1 L1, 2 R1, 4 L2, 8 R2),
 * its value a mode 0 to 3, or -1 for none. */
#define RADIAL_PLACES 32
#define RADIAL_MODES  4

struct radial_table {
    char   mode0[RADIAL_PLACES + 1];
    char   mode1[RADIAL_PLACES + 1];
    char   mode2[RADIAL_PLACES + 1];
    char   mode3[RADIAL_PLACES + 1];
    int8_t select[16];
};

/* A character typed: which, and the chord that typed it. Ordered by the
 * character, so a comparator against an all-zero event lets only real
 * characters out. */
struct radial_event {
    int64_t  frame;
    uint32_t character;
    int32_t  direction;          /* enum direction */
    int32_t  button;             /* enum button: BUTTON_A to BUTTON_Y */
    int32_t  mode;
};

/* {{{ radial_event__compare */
int radial_event__compare(struct radial_event a, struct radial_event b)
{
    return a.character < b.character ? -1 : (a.character > b.character ? 1 : 0);
}
/* }}} */
/* }}} */

#define RADIAL_DPAD_BITS (BUTTON_BIT(BUTTON_DPAD_UP) | BUTTON_BIT(BUTTON_DPAD_DOWN) | \
                          BUTTON_BIT(BUTTON_DPAD_LEFT) | BUTTON_BIT(BUTTON_DPAD_RIGHT))
#define RADIAL_FACE_BITS (BUTTON_BIT(BUTTON_A) | BUTTON_BIT(BUTTON_B) | \
                          BUTTON_BIT(BUTTON_X) | BUTTON_BIT(BUTTON_Y))

/* {{{ dpad_direction */
/* The D-pad's four bits as one of eight directions: one bit is straight,
 * two neighbours are the diagonal between them. Two opposites, three or
 * four at once point nowhere. */
static int32_t dpad_direction(uint32_t pressed)
{
    int up = (pressed & BUTTON_BIT(BUTTON_DPAD_UP)) != 0;
    int down = (pressed & BUTTON_BIT(BUTTON_DPAD_DOWN)) != 0;
    int left = (pressed & BUTTON_BIT(BUTTON_DPAD_LEFT)) != 0;
    int right = (pressed & BUTTON_BIT(BUTTON_DPAD_RIGHT)) != 0;
    if ((up && down) || (left && right)) {
        return DIRECTION_NONE;
    }
    if (up)   return right ? DIRECTION_NE : (left ? DIRECTION_NW : DIRECTION_N);
    if (down) return right ? DIRECTION_SE : (left ? DIRECTION_SW : DIRECTION_S);
    if (right) return DIRECTION_E;
    if (left)  return DIRECTION_W;
    return DIRECTION_NONE;
}
/* }}} */

/* {{{ stick_points */
/* One stick as 503 reads it: inside its resting circle it points nowhere,
 * outside it one of eight ways (the two steps 096-input.h shares). */
static int32_t stick_points(int32_t x, int32_t y, int32_t radius, int32_t edge)
{
    if (input_stick_inside(x, y, radius)) {
        return DIRECTION_NONE;
    }
    return input_stick_direction(x, y, edge);
}
/* }}} */

/* {{{ radial_read */
/* Every button and both sticks at one instant, and the direction the
 * sources point. A `sources` with none of the three bits, or a bit beyond
 * them, refuses the station on its first run (detail 1). */
struct radial_snapshot radial_read(int64_t frame, struct radial_source src)
{
    struct radial_snapshot s;
    bytes_zero(&s, sizeof s);
    s.frame = frame;
    if (src.sources <= 0 || (src.sources & ~RADIAL_FROM_ALL)) {
        engine_refuse(1);
        return s;
    }
    s.pressed = input_buttons_now() & BUTTON_ALL;
    int32_t axes[STICK_AXES];
    input_sticks_now(axes);
    int32_t from_dpad = dpad_direction(s.pressed);
    int32_t from_left = stick_points(axes[0], axes[1], src.sticks.left_deadband, src.sticks.left_edge);
    int32_t from_right = stick_points(axes[2], axes[3], src.sticks.right_deadband, src.sticks.right_edge);
    if ((src.sources & RADIAL_FROM_DPAD) && from_dpad != DIRECTION_NONE) {
        s.direction = from_dpad;
    } else if ((src.sources & RADIAL_FROM_LEFT_STICK) && from_left != DIRECTION_NONE) {
        s.direction = from_left;
    } else if (src.sources & RADIAL_FROM_RIGHT_STICK) {
        s.direction = from_right;
    }
    return s;
}
/* }}} */

/* {{{ radial_at_rest */
/* The history before the first frame: nothing held, pointing nowhere. */
struct radial_history radial_at_rest(int64_t start)
{
    struct radial_history h;
    bytes_zero(&h, sizeof h);
    h.frame = start;
    return h;
}
/* }}} */

/* {{{ radial_track */
/* This frame's reading against the history: what went down. A reading no
 * newer than the history is stale and changes nothing (fresh = 0), as for
 * the buttons (502). */
struct radial_history radial_track(struct radial_snapshot now, struct radial_history before)
{
    struct radial_history h = before;
    h.went_down = 0;
    if (now.frame <= before.frame) {
        h.fresh = 0;
        return h;
    }
    h.frame = now.frame;
    h.fresh = 1;
    h.pressed = now.pressed;
    h.went_down = now.pressed & ~before.pressed;
    h.direction = now.direction;
    return h;
}
/* }}} */

/* {{{ radial_mode */
/* Which mode the held triggers choose: -1 for none. */
static int32_t radial_mode(uint32_t pressed, const struct radial_table *t)
{
    uint32_t triggers = ((pressed & BUTTON_BIT(BUTTON_L1)) ? 1u : 0u) |
                        ((pressed & BUTTON_BIT(BUTTON_R1)) ? 2u : 0u) |
                        ((pressed & BUTTON_BIT(BUTTON_L2)) ? 4u : 0u) |
                        ((pressed & BUTTON_BIT(BUTTON_R2)) ? 8u : 0u);
    return t->select[triggers];
}
/* }}} */

/* {{{ radial_chord */
/* The chord (issue 506): a face button goes down while a direction is
 * held. The direction comes first — pushing it is what shows the menu —
 * and stays held while the right hand types, so each press of a face
 * button types one character, and a direction pushed while a face button
 * is already down types nothing. Two face buttons going down in one frame
 * are not one chord, and type nothing. The triggers held at that frame
 * choose the mode; a combination with no mode types nothing, and so does
 * an empty place.
 *
 * A table whose `select` names a mode outside 0 to 3 (other than -1)
 * refuses the station on its first run (detail 2 + the combination), so
 * the person sees which. */
struct radial_event radial_chord(struct radial_history h, struct radial_table t)
{
    struct radial_event e;
    bytes_zero(&e, sizeof e);
    e.frame = h.frame;
    for (int i = 0; i < 16; i++) {
        if (t.select[i] < -1 || t.select[i] >= RADIAL_MODES) {
            engine_refuse(2 + (uint64_t)i);
            return e;
        }
    }
    uint32_t face = h.went_down & RADIAL_FACE_BITS;
    if (!h.fresh || h.direction == DIRECTION_NONE || face == 0 || (face & (face - 1)) != 0) {
        return e;
    }
    int32_t mode = radial_mode(h.pressed, &t);
    if (mode < 0) {
        return e;
    }
    int32_t button = BUTTON_A;
    while (!(face & BUTTON_BIT(button))) {
        button++;
    }
    const char *line = mode == 0 ? t.mode0 : mode == 1 ? t.mode1 : mode == 2 ? t.mode2 : t.mode3;
    int place = (h.direction - DIRECTION_N) * 4 + (button - BUTTON_A);
    for (int i = 0; i < place; i++) {
        if (!line[i]) {
            return e;                     /* the line ended before this place */
        }
    }
    e.character = (uint8_t)line[place];
    if (e.character) {
        e.direction = h.direction;
        e.button = button;
        e.mode = mode;
    }
    return e;
}
/* }}} */

/* {{{ say_radial */
/* A character on the developer line: the station's name, the frame, the
 * character and the chord that typed it. A character that does not print
 * is given as its number. */
void say_radial(struct radial_event e)
{
    char shown[16];
    if (e.character > 32 && e.character < 127) {
        text_format(shown, sizeof shown, "'%c'", (int)e.character);
    } else {
        text_format(shown, sizeof shown, "#%u", (unsigned)e.character);
    }
    say_line("%s: frame %lld: %s (%s + %s, mode %d)", engine_station_name(engine_current_station()),
             (long long)e.frame, shown, direction_name(e.direction), button_name(e.button), (int)e.mode);
}
/* }}} */
