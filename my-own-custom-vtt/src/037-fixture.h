/*
 * 037-fixture.h -- makes small worlds to run things against.
 *
 * Phase 8 builds the real generator, which reads a description and a seed and
 * produces a dungeon. This is not that. This is the stand-in that exists because
 * every phase before phase 8 needs a world to test against, and hand-writing one
 * inside each test would mean six copies of the same rooms drifting apart.
 *
 * It is a permanent tool rather than scaffolding. Even once the real generator
 * exists, a test wants a world it can predict exactly, and this is that world.
 *
 * Everything it builds is deterministic and takes no seed. There is nothing
 * random here on purpose: a test whose fixture varies is a test that fails
 * intermittently.
 *
 * See issues/109-the-phase-one-demo.md.
 */

#ifndef VTT_FIXTURE_H
#define VTT_FIXTURE_H

#include "027-world.h"

/*
 * Two rooms joined by a corridor, with a cellar under the first, a pillar to
 * cast a shadow, a door in the corridor, and a few things standing about.
 *
 * The shapes are chosen for what later phases will need rather than for
 * prettiness: the pillar is there so phase 2 has something to cast a shadow
 * around, the corridor so there is somewhere a body can be out of sight, the
 * cellar so region nesting is exercised, and the door so the flags-change
 * mechanism has something to change.
 *
 * The world must already be initialised, with room for what this adds --
 * fixture_capacity_hint says how much. Returns 1 on success, 0 if the world ran
 * out of room, which a caller should treat as fatal.
 */
int fixture_build_two_rooms(struct world *w);

/*
 * The capacities fixture_build_two_rooms needs. Written out so a caller does not
 * have to guess and then discover the guess was wrong halfway through.
 */
void fixture_capacity_hint(uint32_t *things,
                           uint32_t *walls,
                           uint32_t *regions,
                           uint32_t *vertices,
                           uint32_t *lights,
                           uint32_t *strings);

/*
 * Initialise a world at the right size and build the fixture into it, in one
 * call. What almost every test and demo actually wants.
 */
int fixture_make_two_rooms(struct world *w);

#endif
