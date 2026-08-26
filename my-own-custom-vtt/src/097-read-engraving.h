/*
 * 097-read-engraving.h -- engraving in, variables out.
 *
 * The other direction, and the important thing about it is what it does not
 * know.
 *
 * IT WALKS THE CARVING. It does not know which creature it is looking at, does
 * not know the tiling rule, and does not ask the writer anything. It scans the
 * characters, finds the rectangles that walls enclose, and pulls the label and
 * the number out of each one.
 *
 * That is the strongest form the independence can take. The writer could get the
 * anatomy wrong in a way that still produced a valid tiling, and this would not
 * care, because it is reading WHAT IS ON THE PAGE rather than what the writer
 * meant to put there. It also makes the format self-describing: a creature
 * nobody has written a rule for yet still reads, as long as its chambers are
 * chambers.
 *
 * IT IS INTENTIONALLY FRAGILE. Not tolerant of whitespace drift, not forgiving of
 * a hand-edit, no best-effort recovery, no "we salvaged four of the eight cells".
 * The argument is in docs/018 and in issue 1006, and the short form is that the
 * art is a checksum you can see -- a corrupted binary file looks exactly like a
 * good one until something reads it, and a corrupted engraving LOOKS corrupted.
 *
 * Fragile is not the same as unhelpful. Every refusal carries a row, a column,
 * and a sentence, because the person reading it is going to go and look at that
 * spot in a text editor.
 *
 * See docs/018-the-record-log-is-an-engraving.md and issue 1005.
 */

#ifndef VTT_READ_ENGRAVING_H
#define VTT_READ_ENGRAVING_H

#include <stdint.h>

#include "090-record.h"

#define ENGRAVING_MAX_ROWS 120
#define ENGRAVING_MAX_COLS 200

struct engraving_error {
    /* One-based, the way a person counts lines and columns in an editor. Zero
     * means the fault is not at a place -- a missing file, a bad marker. */
    uint32_t row;
    uint32_t column;
    char     sentence[192];
};

/*
 * How much text one row of a chamber's interior can be.
 *
 * The interior is as wide as the widest of the label and the value, plus a
 * column of padding either side -- so a buffer sized to the label alone is one
 * short for the padding and two short for a chamber whose value is wider than
 * its label. That was a real bug: "rollbacks" came back as "rollback" and a
 * sixteen-digit checksum came back as fifteen, silently, and the round trip said
 * the record was missing cells rather than saying anything about widths.
 */
#define ENGRAVED_TEXT_MAX (RECORD_VALUE_MAX + 4)

/* One chamber, as text, exactly as it was found. */
struct engraved_cell {
    char     label[ENGRAVED_TEXT_MAX];
    char     value[ENGRAVED_TEXT_MAX];
    uint32_t row;        /* Where it was, so a refusal can point at it. */
    uint32_t column;
};

struct engraving {
    uint32_t version;
    uint8_t  alphabet;
    uint64_t seed;

    struct engraved_cell cells[RECORD_CELLS];
    uint32_t             cell_count;
};

/* Read from text already in memory. Returns 1, or 0 with the fault located. */
int engraving_read_text(struct engraving *e, const char *text,
                        struct engraving_error *why);

/* The same, from a file. A missing file is a fault with no place. */
int engraving_read_file(struct engraving *e, const char *path,
                        struct engraving_error *why);

/*
 * Turn what was found into the eight numbers.
 *
 * Separate from reading, because "this is a well-formed carving" and "this
 * carving holds the cells a record needs" are different questions, and a
 * creature somebody drew by hand may well answer the first and not the second.
 */
int engraving_to_record(const struct engraving *e, struct record *r,
                        struct engraving_error *why);

/* A fault as one line, for printing. Returns `into`. */
const char *engraving_error_sentence(const struct engraving_error *why,
                                     char *into, uint32_t capacity);

#endif
