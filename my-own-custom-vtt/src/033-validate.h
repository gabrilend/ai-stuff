/*
 * 033-validate.h -- establishes everything the rest of the program assumes.
 *
 * This file is what buys the absence of checking everywhere else. The project's
 * rule is that nothing in the world is ever nil and that index 0 means nothing,
 * and that rule is worth nothing unless something checks it -- but checking it
 * ten thousand times a tick inside a loop is exactly what it was meant to avoid.
 *
 * So it is checked here, once, when a world is loaded and after any structural
 * change. Everything downstream then reads indices without bounds tests and
 * dereferences without null tests, and is entitled to.
 *
 * A failure names the block, the index, the field, the value found, and what was
 * expected. Then it stops. It does not repair, clamp, substitute a default, or
 * carry on collecting more problems -- the first failure is the one worth
 * reading, and a wall of thirty consequential ones buries it.
 *
 * See issues/107-the-validator-refuses-to-guess.md.
 */

#ifndef VTT_VALIDATE_H
#define VTT_VALIDATE_H

#include <stdint.h>

#include "027-world.h"

/*
 * What went wrong. Filled in only when validation fails; untouched otherwise.
 *
 * The strings are literals owned by the validator, so this record can be copied
 * around and outlives nothing.
 */
struct validation_failure {
    const char *block;      /* "things", "walls", "regions", ... */
    uint32_t    index;      /* Which record. */
    const char *field;      /* Which field of it. */
    int64_t     found;      /* What was there. */
    const char *expected;   /* What should have been, in words. */
};

/*
 * Check a whole world. Returns 1 when every invariant holds, 0 otherwise, with
 * `failure` filled in.
 *
 * The checks run cheapest and most fundamental first, so that a badly wrong
 * world fails on something simple rather than deep inside polygon winding.
 */
int world_validate(const struct world *w, struct validation_failure *failure);

/*
 * Write a failure as a sentence a person can read, into a caller's buffer.
 * Returns the buffer, so it can be handed straight to a printf.
 *
 * One function, so that every message in the project has the same shape and none
 * of them is written in a hurry at the point of failure.
 */
const char *validation_failure_describe(const struct validation_failure *failure,
                                        char *buffer,
                                        uint32_t buffer_size);

/*
 * The invariants, listed so that the list itself is the specification of what a
 * valid world is. Each is checked in this order.
 *
 *   1. Index 0 of every block is untouched and means nothing.
 *   2. Every index field points inside its block.
 *   3. No wall has zero length.
 *   4. Every region has at least three vertices, and they sit inside the pool.
 *   5. Every region's parent chain terminates within REGION_MAX_DEPTH.
 *   6. Every region polygon has area, is wound counter-clockwise, and does not
 *      cross itself.
 *   7. Every light's thing exists and is flagged as emitting light.
 *   8. Every thing's region is the deepest region actually containing it.
 *   9. Every string offset is well formed and inside the pool.
 *
 * An invariant nobody depends on is a check nobody should be paying for. Each
 * one above exists because some later file skips a test on the strength of it.
 */

#endif
