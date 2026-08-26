/*
 * 090-record.c -- gathering the eight numbers, and writing them as text.
 *
 * See 090-record.h for what the eight are and why there are only eight.
 */

#include "090-record.h"
#include "035-worldfile.h"

#include <stdio.h>
#include <string.h>

/*
 * The labels. One table, and the order is the format's order -- the reader
 * recovers cells by their position in the tiling, so this list is a contract
 * rather than a convenience.
 */
static const char *const labels[RECORD_CELLS] = {
    "beats", "turns", "seats", "commands",
    "refused", "rollbacks", "things", "checksum"
};

/* {{{ const char *record_label */
const char *record_label(uint32_t cell)
{
    if (cell >= RECORD_CELLS) {
        return "(not a cell)";
    }
    return labels[cell];
}
/* }}} */

/* {{{ uint32_t record_value_text */
uint32_t record_value_text(const struct record *r, uint32_t cell,
                           char *into, uint32_t capacity)
{
    if (cell >= RECORD_CELLS) {
        snprintf(into, capacity, "%s", "?");
        return 1;
    }

    if (cell == CELL_CHECKSUM) {
        /* Always sixteen digits. A fixed width, because the layout is built
         * around this value and a number that is sometimes fifteen columns and
         * sometimes seventeen is a creature that changes shape for no reason. */
        snprintf(into, capacity, "%016llX", (unsigned long long)r->value[cell]);
        return 16;
    }

    snprintf(into, capacity, "%llu", (unsigned long long)r->value[cell]);
    return (uint32_t)strlen(into);
}
/* }}} */

/* {{{ uint32_t record_widest_value */
uint32_t record_widest_value(uint32_t cell)
{
    if (cell == CELL_CHECKSUM) {
        return 16;
    }

    if (cell == CELL_BEATS) {
        /*
         * Eight digits: a hundred million beats, which at sixty a second is
         * nineteen days of continuous play. Chosen rather than derived from the
         * type, because these numbers set the creature's proportions and a
         * column sized for a value nobody will ever reach is a chamber that is
         * mostly empty in every engraving anybody ever looks at.
         */
        return 8;
    }

    if (cell == CELL_SEATS) {
        return 3;    /* A table of a thousand people is not a table. */
    }

    if (cell == CELL_ROLLBACKS) {
        return 4;
    }

    if (cell == CELL_TURNS || cell == CELL_THINGS) {
        return 6;
    }

    /* Commands and refusals. A million of either is a very long evening. */
    return 7;
}
/* }}} */

/* {{{ void record_gather */
void record_gather(struct record *r, const struct session *s, uint32_t seats)
{
    memset(r, 0, sizeof(*r));

    r->value[CELL_BEATS]     = s->sim.tick;
    r->value[CELL_TURNS]     = s->turn;
    r->value[CELL_SEATS]     = seats;
    r->value[CELL_COMMANDS]  = s->log.count;
    r->value[CELL_REFUSED]   = log_refused_count(&s->log);
    r->value[CELL_ROLLBACKS] = s->rollbacks;
    r->value[CELL_THINGS]    = world_thing_count(s->world) - 1u;

    /*
     * The world hash is a test instrument and compiles out of a release build,
     * where it reads as zero. That is honest rather than broken: an engraving
     * from a release build carries a zero checksum and says so by being zero,
     * and the alternative -- a second hash function that exists only for this --
     * would be a number nobody had ever compared against anything.
     */
    r->value[CELL_CHECKSUM] = world_hash(s->world);

    /*
     * Which creature. Folded from the session seed and the final beat, so two
     * sessions from one seed that ran different lengths get different animals --
     * they are different runs and the carving belongs to the run.
     */
    r->seed = s->sim.streams.seed ^ (s->sim.tick * 0x9E3779B97F4A7C15ull);
}
/* }}} */
