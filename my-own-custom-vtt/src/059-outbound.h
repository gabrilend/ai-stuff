/*
 * 059-outbound.h -- the only place a thing may be written to a socket.
 *
 * ONE RULE, and everything in this file is a consequence of it:
 *
 *   The server never sends a viewer something they are not entitled to know.
 *   Not sends-and-marks-it-hidden. Not sends-and-trusts-the-client. NEVER PUTS
 *   IT ON THE SOCKET.
 *
 * There is exactly one function that writes a thing record outward, and it takes
 * the viewer as an argument. Nothing else in the server may do it.
 *
 * That discipline is what makes the rule auditable: "can this leak?" is answered
 * by reading one function and checking its callers, rather than by reading the
 * whole program. A rule enforced in one place is a rule; a rule enforced in
 * forty places is a habit.
 *
 * WHY NOT SEND EVERYTHING AND HIDE IT CLIENT-SIDE
 *
 * It is one message instead of twelve, it makes the client simpler, and it works
 * perfectly until somebody presses F12. Then they have the position of every
 * ambush, the layout of every unexplored corridor, and whatever the GM wrote
 * down -- not through cleverness, by reading a variable.
 *
 * The fog would be a curtain. This project needs a wall.
 *
 * See docs/009-what-a-viewer-is-allowed-to-know.md and issues 404, 405, 407.
 */

#ifndef VTT_OUTBOUND_H
#define VTT_OUTBOUND_H

#include <stdint.h>

#include "058-viewer.h"
#include "042-sight.h"
#include "053-session.h"

/*
 * Which body a viewer sees from.
 *
 * In phase 6 this becomes the union across every body in every scope they hold.
 * For now a viewer has one pair of eyes, and the interface is already shaped for
 * the plural so that adding scopes is adding a loop rather than changing every
 * caller.
 */
struct viewpoint {
    uint32_t body;        /* Which thing they see from. 0 means they see nothing. */
    uint8_t  sees_all;    /* A GM. Skips the geometry entirely. */
};

/*
 * Build one viewer's update into their outbound buffer.
 *
 * Clears the buffer first: an update is the whole of what a viewer should have
 * this beat, not a difference from something they might have missed.
 *
 * Returns the number of instructions written.
 */
uint32_t outbound_build(struct session *s,
                        struct viewer_set *set,
                        uint32_t viewer_index,
                        const struct viewpoint *from);

/*
 * Tell a viewer that a command of theirs was refused, and why. A sentence, not a
 * number -- see 051-commandlog.h for the reasoning, which is that nobody reads a
 * rules screen and a refusal is where somebody finds out what the rules are.
 */
void outbound_refusal(struct viewer_set *set, uint32_t viewer_index,
                      uint16_t verb, uint32_t subject, uint16_t reason);

/*
 * Tell a viewer that a stretch of time did not happen and here is the world
 * again.
 *
 * Sent explicitly rather than by quietly following with a contradictory update.
 * A client that is never told is a client that flickers, and a person who has
 * watched their screen contradict itself once stops trusting it.
 */
void outbound_recall(struct viewer_set *set, uint32_t viewer_index, uint32_t turn);

/*
 * THE FOUR GATES, exposed so a test can ask them directly rather than inferring
 * them from bytes.
 *
 * Cheapest first:
 *   1. Scope   -- inside a scope this viewer holds? Then everything below passes.
 *   2. Hidden  -- THING_HIDDEN and no MAY_SEE_HIDDEN? Never passes, whatever the
 *                 geometry says.
 *   3. Sight   -- visible right now? Bodies need this.
 *   4. Memory  -- in their fog? Walls need only this.
 */
int outbound_may_send_thing(const struct session *s,
                            const struct viewer_set *set,
                            uint32_t viewer_index,
                            const struct viewpoint *from,
                            uint32_t thing);

int outbound_may_send_wall(const struct session *s,
                           const struct viewer_set *set,
                           uint32_t viewer_index,
                           uint32_t wall);

#endif
