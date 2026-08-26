/*
 * 090-record.h -- the eight numbers a session tells about itself.
 *
 * A record is what survives a session. It becomes an engraving: a text file that
 * is also a picture that is also a spreadsheet, with these eight values in its
 * chambers.
 *
 * THE LIST IS SMALL, FIXED, AND CHOSEN. Not accumulated. That is a constraint the
 * format imposes -- a creature has only so many places to put a number, and the
 * engraving cannot grow a column without being redrawn -- and it is a good
 * pressure rather than a limitation. Most record formats grow columns until
 * nobody reads them, because adding one costs nothing at the moment of adding.
 * Here it costs a redrawn animal.
 *
 * WHAT IS NOT HERE, and both absences are decisions:
 *
 *   NAMES. A seat is a count. Display names are display-only everywhere in this
 *     project and a record that outlives the evening must not be keyed on one.
 *
 *   GEOMETRY. This carries statistics, not a map. A creature with last week's
 *     numbers in it does not contain the tavern the players burned down. Whether
 *     the world itself persists between sessions is open question 1.2, and this
 *     does not answer it.
 *
 * See docs/018-the-record-log-is-an-engraving.md and issue 1001.
 */

#ifndef VTT_RECORD_H
#define VTT_RECORD_H

#include <stdint.h>

#include "053-session.h"

/*
 * The cells, in the order they are engraved. Their order is part of the format:
 * the reader recovers them by position in the tiling, so reordering this is
 * changing the format and needs a version.
 */
#define CELL_BEATS      0u   /* How long it ran, in the unit the sim counts. */
#define CELL_TURNS      1u   /* How many were declared. A different question. */
#define CELL_SEATS      2u   /* How many people were at the table. */
#define CELL_COMMANDS   3u   /* How many things were asked for. */
#define CELL_REFUSED    4u   /* How many were refused. */
#define CELL_ROLLBACKS  5u   /* How many turns were taken back. */
#define CELL_THINGS     6u   /* How big the world got. */
/*
 * The world hash at the final beat.
 *
 * THE ONE THAT MATTERS MOST. It is the number that says a replay of this session
 * will reproduce it, and if a replay ever ends on a different number this is
 * where the two get compared. It is also the widest value in the table -- sixteen
 * hexadecimal digits -- which makes it the one that stresses the layout, so the
 * creature is drawn knowing about it.
 */
#define CELL_CHECKSUM   7u
#define RECORD_CELLS    8u

/* The longest label, and the longest value text. Both bound the chamber sizes. */
#define RECORD_LABEL_MAX 9
#define RECORD_VALUE_MAX 16

struct record {
    uint64_t value[RECORD_CELLS];

    /*
     * Which creature this run gets. Drawn from the session's own seed, so the
     * creature BELONGS TO THAT RUN -- bespoke, and reproducible, which is what
     * lets the round trip be a byte comparison rather than a judgement.
     */
    uint64_t seed;
};

/* The label engraved beside a cell. An index past the end names itself as one. */
const char *record_label(uint32_t cell);

/*
 * A cell's value as the text that goes in the chamber. Returns the length.
 *
 * Decimal for everything but the checksum, which is sixteen uppercase
 * hexadecimal digits, always -- a fixed width, because the checksum is what the
 * layout is built around and a number that sometimes needs fifteen columns and
 * sometimes seventeen is a creature that changes shape for no reason.
 */
uint32_t record_value_text(const struct record *r, uint32_t cell,
                           char *into, uint32_t capacity);

/*
 * Gather a record from a finished session.
 *
 * `seats` is passed in rather than read, because the session does not own the
 * viewer set -- the server does, and a session run by a test has none.
 */
void record_gather(struct record *r, const struct session *s, uint32_t seats);

/*
 * The widest text any value of this cell could ever need.
 *
 * The tiling is built from these rather than from the values in hand, so that a
 * session with small numbers and a session with large ones produce THE SAME
 * SHAPED CREATURE. Otherwise every run would be a different animal for reasons
 * that have nothing to do with the run, and a deformation would stop meaning
 * anything.
 */
uint32_t record_widest_value(uint32_t cell);

#endif
