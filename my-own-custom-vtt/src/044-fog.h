/*
 * 044-fog.h -- what somebody has ever seen.
 *
 * Sight is recomputed from scratch every time it is asked for and never stored.
 * Memory accumulates forever and is never recomputed. This file is memory.
 *
 * A corridor you walked an hour ago is in this and not in sight, and that
 * difference is the difference between a floor plan you remember and a goblin
 * standing in it now. When the outbound filter builds a viewer's update, walls
 * are sent for everything in their memory and bodies only for what is in their
 * sight -- so you keep the shape of the room and have no idea whether the goblin
 * is still there.
 *
 * Like sight, this is not a drawing feature. The filter reads it to decide which
 * walls a viewer may be sent, which makes it part of the security boundary.
 *
 * See docs/007-sight-and-what-it-remembers.md and issues/205-the-fog-is-a-bitmap.md.
 */

#ifndef VTT_FOG_H
#define VTT_FOG_H

#include <stdint.h>

#include "027-world.h"

/*
 * One bit per cell, set the first time that cell is seen and never cleared.
 *
 * A grid appears here, in a project that insists the map is not a grid, and the
 * two are answering different questions. A rules grid, if a ruleset has one,
 * decides WHERE THINGS MAY STAND -- that is a constraint on the world and is
 * deliberately kept out. This grid decides HOW FINELY WE RECORD HAVING BEEN
 * SOMEWHERE, and memory is approximate by nature: nobody needs millimetre
 * precision on "have I been down this corridor".
 *
 * The two need not be the same size and neither knows the other exists.
 */
struct fog {
    wcoord   origin_x;    /* The world position of cell (0, 0)'s corner. */
    wcoord   origin_y;
    wcoord   cell_size;

    uint32_t columns;
    uint32_t rows;

    uint32_t byte_count;
    uint8_t *bits;
};

/*
 * Prepare a fog covering the world's extent, at the given cell size.
 * A cell size of 0 uses one world metre, which for a map a hundred and twenty
 * metres across costs under two kilobytes.
 * Returns 1 on success, 0 if memory could not be found.
 */
int fog_init(struct fog *f, const struct world *w, wcoord cell_size);

/* Release a fog's memory. */
void fog_release(struct fog *f);

/*
 * Fold what the body at `body` can see right now into this fog. Bits are only
 * ever set, never cleared -- that is what makes it memory rather than sight.
 */
void fog_fold(struct fog *f, const struct world *w, uint32_t body);

/* Whether this position has ever been seen. Outside the grid is never seen. */
int fog_remembers(const struct fog *f, wcoord x, wcoord y);

/* How many cells have been seen. What a demo reports as the fog accumulating. */
uint32_t fog_cells_seen(const struct fog *f);

/* How many cells there are in total. */
uint32_t fog_cell_count(const struct fog *f);

/*
 * Copy one fog over another. Both must have been built for the same world at the
 * same cell size.
 *
 * ROLLBACK USES THIS. When a turn is taken back, the fog goes back with the
 * world -- a full state restore, decided knowing that the person still remembers
 * the corridor they looked at, because the alternative leaves a permanent
 * contradiction between a map and the world it claims to describe.
 *
 * Returns 1 on success, 0 if the two do not match.
 */
int fog_copy(struct fog *destination, const struct fog *source);

#endif
