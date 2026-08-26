/*
 * 096-engrave.c -- composing the creature around the values.
 *
 * Short, because everything hard is somewhere else: the tiling is in
 * 094-creature and the character resolution is in 092-canvas. What is left is
 * choosing the animal, checking that every value fits, and writing three header
 * lines.
 *
 * See 096-engrave.h for what is deliberately not in the file.
 */

#include "096-engrave.h"
#include "094-creature.h"

#include <stdio.h>
#include <string.h>

/* {{{ static int every_value_fits */
static int every_value_fits(const struct record *r, const char **why)
{
    static char reason[160];
    uint32_t cell;

    for (cell = 0; cell < RECORD_CELLS; cell++) {
        char text[RECORD_VALUE_MAX + 8];
        uint32_t length = record_value_text(r, cell, text, sizeof(text));

        if (length <= record_widest_value(cell)) {
            continue;
        }

        /*
         * Refused, by name, with both numbers. The alternative is a chamber
         * whose value runs into its own wall -- which the drawing would show,
         * and which would then be a broken artifact rather than a refused one.
         *
         * A person reading this needs to know which cell and by how much,
         * because the answer is either "widen the chamber" or "that number is
         * wrong", and the two look identical without the figures.
         */
        snprintf(reason, sizeof(reason),
                 "the %s cell holds %s, which is %u characters where the chamber"
                 " was drawn for %u -- the creature has no room for it",
                 record_label(cell), text,
                 (unsigned)length, (unsigned)record_widest_value(cell));
        *why = reason;
        return 0;
    }

    return 1;
}
/* }}} */

/* {{{ uint32_t engrave_to_text */
uint32_t engrave_to_text(const struct record *r, uint8_t alphabet,
                         char *into, uint32_t capacity, const char **why)
{
    struct creature c;
    struct canvas canvas;
    uint32_t cursor;
    uint32_t drawn;

    *why = "";

    if (alphabet != ALPHABET_CARVED && alphabet != ALPHABET_PLAIN) {
        *why = "there are two alphabets and that is neither of them";
        return 0;
    }

    if (!every_value_fits(r, why)) {
        return 0;
    }

    if (!creature_lay_out(&c, creature_from_seed(r->seed))) {
        *why = "the creature this seed asks for would not fit on a canvas";
        return 0;
    }

    if (!canvas_init(&canvas, c.width, c.height, alphabet)) {
        *why = "the creature is larger than a carving may be";
        return 0;
    }

    creature_draw(&c, r, &canvas);

    /*
     * Ornament touching a wall is a bug in the anatomy, not a cosmetic problem:
     * the reader finds chambers by following walls, so a fin drawn across one
     * punches a hole it falls through. Caught here as well as in the tests,
     * because a creature added later will be added by somebody who has not read
     * the tests.
     */
    if (canvas.ornament_collisions != 0) {
        static char reason[160];

        snprintf(reason, sizeof(reason),
                 "the %s's ornament crosses its own walls in %u places, which"
                 " would leave the reader holes to fall through",
                 creature_name(c.kind), (unsigned)canvas.ornament_collisions);
        *why = reason;
        return 0;
    }

    cursor = (uint32_t)snprintf(into, capacity,
                                "%s %u\nalphabet %s\nseed %016llX\n\n",
                                ENGRAVING_MARKER, (unsigned)ENGRAVING_VERSION,
                                alphabet == ALPHABET_CARVED ? "carved" : "plain",
                                (unsigned long long)r->seed);

    if (cursor >= capacity) {
        *why = "the buffer could not hold even the header";
        return 0;
    }

    drawn = canvas_to_text(&canvas, into + cursor, capacity - cursor);
    if (drawn == 0) {
        *why = "the buffer could not hold the carving";
        return 0;
    }

    return cursor + drawn;
}
/* }}} */

/* {{{ int engrave_to_file */
int engrave_to_file(const struct record *r, uint8_t alphabet,
                    const char *path, const char **why)
{
    static char text[ENGRAVING_MAX_BYTES];
    static char reason[256];
    uint32_t length;
    FILE *out;

    length = engrave_to_text(r, alphabet, text, sizeof(text), why);
    if (length == 0) {
        return 0;
    }

    out = fopen(path, "w");
    if (out == NULL) {
        snprintf(reason, sizeof(reason),
                 "could not open %.180s for writing", path);
        *why = reason;
        return 0;
    }

    fwrite(text, 1, length, out);
    fclose(out);

    *why = "";
    return 1;
}
/* }}} */
