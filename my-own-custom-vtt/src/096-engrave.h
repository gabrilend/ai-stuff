/*
 * 096-engrave.h -- variables in, engraving out.
 *
 * One direction of the pair. A program takes the values it is holding and
 * produces a new record log with the creature composed around them.
 *
 * IT SHARES NO CODE WITH THE READER. Not a parser, not a character table, not a
 * helper. What they share is the CONTRACT -- the list of cell labels in
 * 090-record.h -- and nothing else, because two implementations that share a
 * parser agree with each other about their own mistakes.
 *
 * WHAT THE FILE CONTAINS BESIDES THE PICTURE: as little as possible, and all of
 * it above the creature. A marker naming the format and its version, so a reader
 * knows what it is holding before it starts. Which alphabet, because a file that
 * accepts either is a file where a corrupted character can hide. And the seed,
 * so the creature can be regenerated and compared.
 *
 * NO SEPARATE DATA BLOCK. A file with the numbers written twice -- once in the
 * picture and once in a header -- is a file that can disagree with itself, and
 * then somebody has to decide which copy is right.
 *
 * See docs/018-the-record-log-is-an-engraving.md and issue 1004.
 */

#ifndef VTT_ENGRAVE_H
#define VTT_ENGRAVE_H

#include <stdint.h>

#include "090-record.h"
#include "092-canvas.h"

/* The first line of every engraving. Its version is the format's. */
#define ENGRAVING_MARKER  "vtt-engraving"
#define ENGRAVING_VERSION 1u

/* Room for the largest carving plus its header. */
#define ENGRAVING_MAX_BYTES 32768

/*
 * Write an engraving into a caller's buffer. Returns the length, or 0 with a
 * sentence in `why`.
 *
 * It refuses rather than truncating. A truncated checksum is a number that looks
 * like a number and is not one, and a carving with a wall missing is a carving
 * the reader walks straight out of.
 */
uint32_t engrave_to_text(const struct record *r, uint8_t alphabet,
                         char *into, uint32_t capacity, const char **why);

/* The same, to a file. Returns 1, or 0 with a sentence naming the file. */
int engrave_to_file(const struct record *r, uint8_t alphabet,
                    const char *path, const char **why);

#endif
