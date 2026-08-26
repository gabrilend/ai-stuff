/*
 * 035-worldfile.h -- a world, written down, in a format that has to last.
 *
 * The world persists between sessions: a session ends by writing the world out
 * and the next one loads it, so the tavern the players burned down is still
 * burned next week.
 *
 * That single decision turns this from a debugging convenience into a format
 * with obligations that never go away. Every file carries a version. Every
 * change to a record's shape needs a converter. The version machinery is here
 * from the first commit, because the first world saved without one is the first
 * world that cannot be moved forward.
 *
 * This is the slow, careful path. The fast path -- the rollback ring's snapshot
 * at the head of every turn -- is world_copy in 027-world.h, which copies blocks
 * and never encodes anything, because it never leaves the process.
 *
 * See issues/108-a-world-writes-itself-down.md.
 */

#ifndef VTT_WORLDFILE_H
#define VTT_WORLDFILE_H

#include <stdint.h>
#include <stdio.h>

#include "027-world.h"

/* Every file begins with this. One that does not is not ours and is refused. */
#define WORLDFILE_MAGIC 0x56545457u   /* "VTTW" little-endian */

/*
 * The format this build speaks. Raised whenever a record changes shape, together
 * with a converter added to the chain in 035-worldfile.c.
 */
#define WORLDFILE_VERSION 1u

/*
 * What went wrong. Every failure is a sentence naming what was found and what
 * was expected -- never "failed to load", which is the worst possible symptom of
 * a version skew because it tells a person nothing about which of the two ends
 * to change.
 */
struct worldfile_error {
    const char *what;      /* A sentence. */
    int64_t     found;
    int64_t     expected;
};

/*
 * Write a world. Returns 1 on success, 0 with `error` filled in.
 *
 * Fields are written one at a time, little-endian, never by dumping a struct.
 * Dumping is faster and is how a file becomes unreadable on the next compiler,
 * because a compiler's choice of padding would end up on the disk.
 */
int worldfile_write(const struct world *w, FILE *out, struct worldfile_error *error);

/*
 * Read a world. The world must already be initialised; it is filled from the
 * file, growing as needed. Returns 1 on success, 0 with `error` filled in.
 *
 * A file whose version is older than this build's is run through the converter
 * chain on the way in. A file newer than this build is refused, naming both
 * versions, because there is no way to guess what a future format meant.
 *
 * This does NOT validate. A file that parsed is not a file that is valid, and the
 * caller runs world_validate afterwards -- always.
 */
int worldfile_read(struct world *w, FILE *in, struct worldfile_error *error);

/*
 * One number standing for the entire state of a world at one instant.
 *
 * Three uses and one function: checking a file survived the disk, checking a
 * replay reproduced a session, and checking two thread counts agree. Three
 * separate functions could disagree about what "the same world" means.
 *
 * Padding is not hashed -- this walks fields, exactly as the writer does -- so the
 * same world hashes the same on two different builds.
 */
uint64_t world_hash(const struct world *w);

/* Write an error as a sentence into a caller's buffer, and return the buffer. */
const char *worldfile_error_describe(const struct worldfile_error *error,
                                     char *buffer,
                                     uint32_t buffer_size);

#endif
