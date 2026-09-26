/*
 * 038-starter-boxes.h — a handful of boxes written by hand, so the engine
 * can be exercised and measured before phase 3 can read box sources
 * (issue 212).
 *
 * General description: each box is an ordinary C function plus a small
 * record describing its parameters, written in exactly the shape the phase
 * 3 generator will later emit — so phase 3 replaces a file, not a design.
 */
#ifndef SOREN_STARTER_BOXES_H
#define SOREN_STARTER_BOXES_H

#include <stdint.h>
#include "031-engine.h"

extern const struct box box_constant;   /* (int64 value) → value: the thing that starts a chain */
extern const struct box box_pass;       /* (int64 v) → v: the cheapest box; engine overhead alone */
extern const struct box box_increment;  /* (int64 v) → v + 1 */
extern const struct box box_add;        /* (int64 a, int64 b) → a + b: the two-input case */
extern const struct box box_countdown;  /* (int64 v) → v - 1; place as a comparator against 0 with
                                           the "below" exit unwired, so the chain ends by itself */
extern const struct box box_discard;    /* (int64 v) → nothing: a sink that tallies count and sum */
extern const struct box box_say;        /* (int64 v) → nothing: one line out the developer's line */
extern const struct box box_chew;       /* (int64 seed, int64 rounds) → a checksum after `rounds` of mixing */
extern const struct box box_picky;      /* (int64 v, int64 limit) → v, or refuses if v > limit */

/* Every starter box, for name lookups until phase 3's catalogue exists. */
extern const struct box *const starter_boxes[];
extern const int starter_box_count;
const struct box *starter_box_named(const char *name);

/* The discard sink's tally for one station: how many values it consumed
 * and their sum. The sink writes these the way a box writes to hardware —
 * the tally is the outside world, not memory the box keeps. Stations
 * numbered 4096 and up share tallies modulo 4096. */
void starter_discard_tally(int32_t station, uint64_t *count, int64_t *sum);
void starter_discard_reset(void);

/* The values a picky station turned away: how many, and their sum. */
void starter_refused_tally(int32_t station, uint64_t *count, int64_t *sum);

#endif
