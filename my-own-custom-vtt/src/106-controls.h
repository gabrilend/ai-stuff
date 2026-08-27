/*
 * 106-controls.h -- three dials and a handful of verbs.
 *
 * ONE KEYBOARD GENUINELY CANNOT DRIVE FOUR BODIES. The three obvious answers --
 * drive one and have three follow, order all four at once, drive one at a time --
 * are each half of what somebody wants. This is all of it: point at all four and
 * say GO, point at one and say STAY, point northeast-far and say ATTACK.
 *
 * A command is (which units) x (which way) x (how far) x (what to do), and the
 * first three are STATE that keys change rather than arguments a key carries.
 *
 * WHERE THIS COMES FROM: a real control scheme, built by the person who asked for
 * this project, for commanding a squad in an action game. It is a modal state
 * machine made of bind files -- loading a different file changes what every key
 * does -- holding which group, which of eight compass directions, and one of
 * three distances. And every key that turns a dial prints a small diagram of
 * where the dials now point.
 *
 * WHY IT IS IN C RATHER THAN IN THE VIEW. The dials themselves belong to a view
 * and the server must never hear about them. But the ARITHMETIC -- from three
 * dial positions to a point in the world -- is arithmetic, and arithmetic in C is
 * arithmetic that can be tested without a browser. Both views take the direction
 * table from here so that they cannot drift apart about what northeast means.
 *
 * THE SERVER NEVER LEARNS ANY OF THIS. A view resolves the dials into a point and
 * sends an ordinary order, which is a verb the server has had since phase 3. A
 * server that knew what "northeast, far" meant would be a server with an opinion
 * about how people play.
 *
 * See docs/008-who-controls-what.md and issues 1204 and 1205.
 */

#ifndef VTT_CONTROLS_H
#define VTT_CONTROLS_H

#include <stdint.h>

#include "021-fixed-point.h"

/* Eight compass points, clockwise from north, the way a compass is read. */
#define AIM_NORTH      0u
#define AIM_NORTHEAST  1u
#define AIM_EAST       2u
#define AIM_SOUTHEAST  3u
#define AIM_SOUTH      4u
#define AIM_SOUTHWEST  5u
#define AIM_WEST       6u
#define AIM_NORTHWEST  7u
#define AIM_COUNT      8u

/*
 * How far. Three, because three is how many distinctions a person can hold
 * without looking -- and because the original scheme used three, having been
 * used in anger for years.
 */
#define REACH_CLOSE 0u
#define REACH_NEAR  1u
#define REACH_FAR   2u
#define REACH_COUNT 3u

/* What the action keys do to whatever the dials point at. */
#define ACT_GO      0u   /* Walk there. */
#define ACT_FACE    1u   /* Look that way, without moving. */
#define ACT_STOP    2u   /* Cancel standing orders. */
#define ACT_REACH   3u   /* Act on whatever is there -- the ruleset decides. */
#define ACT_COUNT   4u

/*
 * Who the dials are pointing at.
 *
 * WHOLE_PARTY and ONE, rather than an arbitrary set. A set needs a way to build
 * a set, which is a second control scheme inside the first one; the original
 * solved it with named groups declared in advance, which is the same idea and
 * belongs to whoever names the scopes.
 */
#define CHOOSING_WHOLE_PARTY 0u
#define CHOOSING_ONE         1u

struct dial {
    uint8_t  aim;
    uint8_t  reach;
    uint8_t  choosing;

    /*
     * Which one, when not the whole party. An INDEX INTO THE PARTY rather than a
     * thing index, so that cycling is arithmetic and so that a body leaving the
     * party cannot leave the dial pointing at something that is not there.
     */
    uint32_t which;
};

/* Every dial starts pointing north, at the middle distance, at everybody. */
void dial_init(struct dial *d);

/* Turn a dial. Each wraps, because a control you can walk off the end of is a
 * control that needs a boundary check every time it is read. */
void dial_turn_aim(struct dial *d, int by);
void dial_turn_reach(struct dial *d, int by);
void dial_cycle_choice(struct dial *d, uint32_t party_size);

/* Point at everybody, or at one. */
void dial_choose_whole_party(struct dial *d);
void dial_choose_one(struct dial *d, uint32_t which);

/*
 * Where the dials point, from a body standing at (x, y).
 *
 * This is the whole of what leaves the view: a point. The server is sent an
 * ordinary order to walk there, and never hears the words north or far.
 */
void dial_resolve(const struct dial *d, wcoord from_x, wcoord from_y,
                  wcoord *to_x, wcoord *to_y);

/* How far a reach is, in metres. Exposed so a readout can say the number. */
uint32_t reach_in_metres(uint8_t reach);

/* The names, for a readout and for the documentation half of the contract. */
const char *aim_name(uint8_t aim);
const char *reach_name(uint8_t reach);
const char *act_name(uint8_t act);

/*
 * The dials, drawn.
 *
 * A MODAL CONTROL SCHEME WHOSE MODE IS INVISIBLE IS A CONTROL SCHEME NOBODY CAN
 * HOLD IN THEIR HEAD. Seven lines of characters: `o` is you, `X` is where the
 * order lands, and the line between them is the direction and its length is the
 * distance.
 *
 * DRAWN FROM THE DIAL ITSELF rather than from a copy of it, so it cannot
 * disagree with the state it is showing. That is the same idea as the engraving
 * being a picture and a database at once, arriving for the third time from a
 * third direction: make the state its own display.
 *
 * Writes a seven-line block ending in a newline. Returns `into`.
 */
const char *dial_diagram(const struct dial *d, char *into, uint32_t capacity);

/* One line saying where every dial points, for a readout beside the diagram. */
const char *dial_sentence(const struct dial *d, uint32_t party_size,
                          char *into, uint32_t capacity);

#endif
