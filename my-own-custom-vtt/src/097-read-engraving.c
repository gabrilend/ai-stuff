/*
 * 097-read-engraving.c -- following walls until they close.
 *
 * NOTHING HERE IS SHARED WITH THE WRITER, deliberately, down to the way the
 * alphabet is described. The writer holds one table of sixteen rows indexed by
 * four stroke bits. This holds four sets of characters, one per direction, and
 * asks "does this glyph carry a stroke to the right". Two formulations of the
 * same knowledge, so that a mistake in one does not mirror a mistake in the
 * other -- which is the entire reason for writing the pair twice.
 *
 * The scan is four steps:
 *
 *   Split the text into rows and decode each row into GLYPHS. Box-drawing
 *     characters are three bytes of UTF-8 and everything else is one, so a
 *     column is not a byte offset and cannot be treated as one.
 *   Find every top-left corner -- a glyph carrying strokes right and down.
 *   From each, follow the top edge to a corner that turns down, follow that
 *     side to one that turns left, and check the rectangle closes.
 *   Reject any rectangle with a stroke inside it, because that is two chambers
 *     with the dividing wall mistaken for a wall of one.
 *
 * See 097-read-engraving.h for why it is fragile on purpose.
 */

#include "097-read-engraving.h"

#include <stdio.h>
#include <string.h>

/* A decoded page: one short string per column, per row. */
struct page {
    char     glyph[ENGRAVING_MAX_ROWS][ENGRAVING_MAX_COLS][5];
    uint32_t width[ENGRAVING_MAX_ROWS];
    uint32_t height;
    uint32_t first_line;    /* Which line of the file row 0 was, for messages. */
};

/*
 * The four directions, as sets of glyphs. Written out rather than computed, so
 * that reading this file tells you what the alphabet is without consulting the
 * one that draws it.
 *
 * Both alphabets appear here and a reader accepts only the one the file
 * declares -- checked in the scan, so a file mixing the two is refused at the
 * first character that belongs to the wrong one.
 */
static const char *const carries_right[] = {
    "\xe2\x94\x80", "\xe2\x94\x8c", "\xe2\x94\x94", "\xe2\x94\x9c",
    "\xe2\x94\xac", "\xe2\x94\xb4", "\xe2\x94\xbc", "\xe2\x95\xb6", NULL
};
static const char *const carries_left[] = {
    "\xe2\x94\x80", "\xe2\x94\x90", "\xe2\x94\x98", "\xe2\x94\xa4",
    "\xe2\x94\xac", "\xe2\x94\xb4", "\xe2\x94\xbc", "\xe2\x95\xb4", NULL
};
static const char *const carries_down[] = {
    "\xe2\x94\x82", "\xe2\x94\x8c", "\xe2\x94\x90", "\xe2\x94\x9c",
    "\xe2\x94\xa4", "\xe2\x94\xac", "\xe2\x94\xbc", "\xe2\x95\xb7", NULL
};
static const char *const carries_up[] = {
    "\xe2\x94\x82", "\xe2\x94\x94", "\xe2\x94\x98", "\xe2\x94\x9c",
    "\xe2\x94\xa4", "\xe2\x94\xb4", "\xe2\x94\xbc", "\xe2\x95\xb5", NULL
};

/* The plain alphabet cannot tell one corner from another, so every junction
 * character carries every direction and the geometry has to do the work. */
static const char *const plain_any[] = { "+", NULL };
static const char *const plain_across[] = { "-", "+", NULL };
static const char *const plain_along[] = { "|", "+", NULL };

/* {{{ static int glyph_in */
static int glyph_in(const char *glyph, const char *const *set)
{
    uint32_t i;

    for (i = 0; set[i] != NULL; i++) {
        if (strcmp(glyph, set[i]) == 0) {
            return 1;
        }
    }
    return 0;
}
/* }}} */

/* {{{ static int carries */
static int carries(const struct page *p, uint8_t alphabet,
                   uint32_t x, uint32_t y, uint8_t direction)
{
    const char *glyph;

    if (y >= p->height || x >= p->width[y]) {
        return 0;
    }

    glyph = p->glyph[y][x];

    if (alphabet == 1u) {
        /* Plain. Horizontal runs and vertical runs are told apart by the
         * character, and a plus sign is both. */
        if (direction == 0u || direction == 1u) {
            return glyph_in(glyph, plain_along) || glyph_in(glyph, plain_any);
        }
        return glyph_in(glyph, plain_across) || glyph_in(glyph, plain_any);
    }

    if (direction == 0u) { return glyph_in(glyph, carries_up); }
    if (direction == 1u) { return glyph_in(glyph, carries_down); }
    if (direction == 2u) { return glyph_in(glyph, carries_left); }
    return glyph_in(glyph, carries_right);
}
/* }}} */

#define GOING_UP    0u
#define GOING_DOWN  1u
#define GOING_LEFT  2u
#define GOING_RIGHT 3u

/* {{{ static int any_stroke */
static int any_stroke(const struct page *p, uint8_t alphabet, uint32_t x, uint32_t y)
{
    return carries(p, alphabet, x, y, GOING_UP)
        || carries(p, alphabet, x, y, GOING_DOWN)
        || carries(p, alphabet, x, y, GOING_LEFT)
        || carries(p, alphabet, x, y, GOING_RIGHT);
}
/* }}} */

/* {{{ static void fault */
static void fault(struct engraving_error *why, uint32_t row, uint32_t column,
                  const char *sentence)
{
    why->row = row;
    why->column = column;
    snprintf(why->sentence, sizeof(why->sentence), "%s", sentence);
}
/* }}} */

/*
 * How many bytes this character occupies. UTF-8's leading byte says so, and the
 * carving uses exactly two lengths -- one for ASCII, three for box-drawing --
 * but the general rule is written because getting it half right is how a reader
 * comes to disagree with itself about where column forty is.
 */
/* {{{ static uint32_t glyph_bytes */
static uint32_t glyph_bytes(unsigned char lead)
{
    if (lead < 0x80u) { return 1; }
    if ((lead & 0xE0u) == 0xC0u) { return 2; }
    if ((lead & 0xF0u) == 0xE0u) { return 3; }
    if ((lead & 0xF8u) == 0xF0u) { return 4; }
    return 1;
}
/* }}} */

/* {{{ static int decode_page */
static int decode_page(struct page *p, const char *text, uint32_t first_line,
                       struct engraving_error *why)
{
    uint32_t row = 0;
    uint32_t column = 0;
    uint32_t i = 0;

    memset(p, 0, sizeof(*p));
    p->first_line = first_line;

    while (text[i] != '\0') {
        uint32_t length;

        if (text[i] == '\n') {
            p->width[row] = column;
            row++;
            column = 0;
            i++;

            if (row >= ENGRAVING_MAX_ROWS) {
                fault(why, first_line + row, 1,
                      "the carving is taller than a carving may be");
                return 0;
            }
            continue;
        }

        if (column >= ENGRAVING_MAX_COLS) {
            fault(why, first_line + row, column + 1u,
                  "the carving is wider than a carving may be");
            return 0;
        }

        length = glyph_bytes((unsigned char)text[i]);

        /* A character cut short is a file that was truncated mid-glyph, and
         * carrying on would read the next row's first byte as this row's last
         * column. */
        {
            uint32_t n;

            for (n = 0; n < length; n++) {
                if (text[i + n] == '\0') {
                    fault(why, first_line + row, column + 1u,
                          "the file ends in the middle of a character");
                    return 0;
                }
                p->glyph[row][column][n] = text[i + n];
            }
            p->glyph[row][column][length] = '\0';
        }

        i += length;
        column++;
    }

    if (column > 0) {
        p->width[row] = column;
        row++;
    }

    p->height = row;
    return 1;
}
/* }}} */

/*
 * Lift one row of a chamber's interior out as text, trimmed of its padding.
 *
 * Returns 0 rather than truncating. That distinction cost an afternoon: an
 * earlier version stopped quietly when the buffer filled, so "rollbacks" came
 * back as "rollback" and a sixteen-digit checksum as fifteen -- and the failure
 * surfaced two layers away as "this carving has no chamber labelled rollbacks",
 * which is a true sentence that points at entirely the wrong thing.
 */
/* {{{ static int take_text */
static int take_text(const struct page *p, uint32_t x0, uint32_t x1, uint32_t y,
                     char *into, uint32_t capacity)
{
    uint32_t written = 0;
    uint32_t x;
    uint32_t last_solid = 0;
    int seen = 0;

    into[0] = '\0';

    for (x = x0; x <= x1; x++) {
        const char *glyph = (y < p->height && x < p->width[y]) ? p->glyph[y][x] : " ";
        uint32_t length = (uint32_t)strlen(glyph);

        if (written + length + 1u >= capacity) {
            return 0;
        }

        memcpy(into + written, glyph, length);
        written += length;

        if (glyph[0] != ' ') {
            last_solid = written;
            seen = 1;
        }
    }

    /* Trimmed of the padding either side, because a chamber pads its contents
     * and the padding is not part of the word. */
    into[seen ? last_solid : 0u] = '\0';

    if (seen) {
        uint32_t start = 0;

        while (into[start] == ' ') {
            start++;
        }
        if (start > 0) {
            memmove(into, into + start, strlen(into + start) + 1u);
        }
    }

    return 1;
}
/* }}} */

/*
 * A chamber is four rows: the top wall, the label, the value, the bottom wall.
 * That is the format, and fixing it here rather than following walls to wherever
 * they close is what lets the same scan work in both alphabets.
 *
 * The plain alphabet cannot tell a corner from a crossing -- a plus sign is
 * every junction there is -- so nothing may depend on the SHAPE of a character,
 * only on which directions it carries. The geometry does the rest: four walls
 * present, and an interior with no stroke in it.
 */
#define CHAMBER_ROWS 4u

/* The narrowest a chamber can be: two walls, two pads, and a character. */
#define CHAMBER_NARROWEST 5u

/* {{{ static int chamber_closes */
static int chamber_closes(const struct engraving *e, const struct page *p,
                          uint32_t x, uint32_t y, uint32_t right)
{
    uint32_t bottom = y + CHAMBER_ROWS - 1u;
    uint32_t probe;

    /* Both side walls run the full height. */
    for (probe = y + 1u; probe < bottom; probe++) {
        if (!carries(p, e->alphabet, x, probe, GOING_UP)
            || !carries(p, e->alphabet, x, probe, GOING_DOWN)
            || !carries(p, e->alphabet, right, probe, GOING_UP)
            || !carries(p, e->alphabet, right, probe, GOING_DOWN)) {
            return 0;
        }
    }

    /* Both corners at the bottom turn the right way. */
    if (!carries(p, e->alphabet, x, bottom, GOING_UP)
        || !carries(p, e->alphabet, x, bottom, GOING_RIGHT)
        || !carries(p, e->alphabet, right, bottom, GOING_UP)
        || !carries(p, e->alphabet, right, bottom, GOING_LEFT)) {
        return 0;
    }

    /* Both horizontal walls run unbroken between the corners. */
    for (probe = x + 1u; probe < right; probe++) {
        if (!carries(p, e->alphabet, probe, y, GOING_LEFT)
            || !carries(p, e->alphabet, probe, y, GOING_RIGHT)
            || !carries(p, e->alphabet, probe, bottom, GOING_LEFT)
            || !carries(p, e->alphabet, probe, bottom, GOING_RIGHT)) {
            return 0;
        }
    }

    /*
     * And the inside is empty of walls. A rectangle with a wall running through
     * it is two chambers being mistaken for one, and the value it would read is
     * two values with a wall between them.
     */
    for (probe = y + 1u; probe < bottom; probe++) {
        uint32_t ix;

        for (ix = x + 1u; ix < right; ix++) {
            if (any_stroke(p, e->alphabet, ix, probe)) {
                return 0;
            }
        }
    }

    return 1;
}
/* }}} */

/* {{{ static int read_chambers */
static int read_chambers(struct engraving *e, const struct page *p,
                         struct engraving_error *why)
{
    uint32_t y;

    for (y = 0; y + CHAMBER_ROWS <= p->height; y++) {
        uint32_t x;

        for (x = 0; x < p->width[y]; x++) {
            uint32_t right;
            struct engraved_cell *cell;
            int closed = 0;

            /* A corner a chamber could start at: strokes leaving right and
             * downward. In the carved alphabet that is a handful of characters;
             * in the plain one it is every plus sign, which is why the test
             * cannot be about the character. */
            if (!carries(p, e->alphabet, x, y, GOING_RIGHT)
                || !carries(p, e->alphabet, x, y, GOING_DOWN)) {
                continue;
            }

            /*
             * Walk right along the top wall, trying every position that also
             * turns downward. The FIRST one that closes a chamber is the right
             * wall -- first, because chambers do not nest, so a wider rectangle
             * enclosing a narrower one would have the narrower one's wall inside
             * it and be rejected anyway.
             */
            for (right = x + CHAMBER_NARROWEST - 1u; right < p->width[y]; right++) {
                if (!carries(p, e->alphabet, right, y, GOING_LEFT)) {
                    break;    /* The top wall ended. */
                }

                if (!carries(p, e->alphabet, right, y, GOING_DOWN)) {
                    continue;
                }

                if (chamber_closes(e, p, x, y, right)) {
                    closed = 1;
                    break;
                }
            }

            if (!closed) {
                continue;
            }

            if (e->cell_count >= RECORD_CELLS) {
                fault(why, p->first_line + y, x + 1u,
                      "there are more chambers in this carving than a record has"
                      " cells");
                return 0;
            }

            cell = &e->cells[e->cell_count];
            cell->row = p->first_line + y;
            cell->column = x + 1u;

            if (!take_text(p, x + 1u, right - 1u, y + 1u,
                           cell->label, sizeof(cell->label))
                || !take_text(p, x + 1u, right - 1u, y + 2u,
                              cell->value, sizeof(cell->value))) {
                fault(why, p->first_line + y, x + 1u,
                      "this chamber is wider than any chamber a record has, so"
                      " whatever is inside it would have to be cut short to be"
                      " read");
                return 0;
            }

            if (cell->label[0] == '\0') {
                fault(why, p->first_line + y + 1u, x + 2u,
                      "this chamber has no label, so nothing says what its"
                      " number means");
                return 0;
            }

            e->cell_count++;
        }
    }

    if (e->cell_count == 0) {
        fault(why, p->first_line, 1,
              "no chambers were found -- either the walls are broken or this is"
              " not a carving");
        return 0;
    }

    return 1;
}
/* }}} */

/* {{{ static int read_header */
static int read_header(struct engraving *e, const char *text, uint32_t *body,
                       uint32_t *first_line, struct engraving_error *why)
{
    unsigned version = 0;
    char alphabet[32];
    unsigned long long seed = 0;
    uint32_t i = 0;
    uint32_t newlines = 0;

    if (sscanf(text, "vtt-engraving %u", &version) != 1) {
        fault(why, 1, 1,
              "this does not begin with the engraving marker, so it is not an"
              " engraving");
        return 0;
    }

    if (version != 1u) {
        fault(why, 1, 1,
              "this engraving was written in a format version this build does"
              " not know");
        return 0;
    }
    e->version = version;

    {
        const char *line = strstr(text, "\nalphabet ");

        if (line == NULL || sscanf(line, "\nalphabet %31s", alphabet) != 1) {
            fault(why, 2, 1,
                  "the second line must name the alphabet, carved or plain --"
                  " a file that accepts either is a file where a corrupted"
                  " character can hide");
            return 0;
        }

        if (strcmp(alphabet, "carved") == 0) {
            e->alphabet = 0u;
        } else if (strcmp(alphabet, "plain") == 0) {
            e->alphabet = 1u;
        } else {
            fault(why, 2, 10, "there are two alphabets and that is neither");
            return 0;
        }
    }

    {
        const char *line = strstr(text, "\nseed ");

        if (line == NULL || sscanf(line, "\nseed %llx", &seed) != 1) {
            fault(why, 3, 1,
                  "the third line must carry the seed, without which the"
                  " creature cannot be regenerated and compared");
            return 0;
        }
        e->seed = (uint64_t)seed;
    }

    /* The carving begins after the blank line that follows the header. */
    while (text[i] != '\0' && newlines < 4u) {
        if (text[i] == '\n') {
            newlines++;
        }
        i++;
    }

    if (newlines < 4u) {
        fault(why, 4, 1, "the file ends before the carving begins");
        return 0;
    }

    *body = i;
    *first_line = 5u;
    return 1;
}
/* }}} */

/* {{{ int engraving_read_text */
int engraving_read_text(struct engraving *e, const char *text,
                        struct engraving_error *why)
{
    static struct page p;
    uint32_t body = 0;
    uint32_t first_line = 0;

    memset(e, 0, sizeof(*e));
    memset(why, 0, sizeof(*why));

    if (!read_header(e, text, &body, &first_line, why)) {
        return 0;
    }

    if (!decode_page(&p, text + body, first_line, why)) {
        return 0;
    }

    return read_chambers(e, &p, why);
}
/* }}} */

/* {{{ int engraving_read_file */
int engraving_read_file(struct engraving *e, const char *path,
                        struct engraving_error *why)
{
    static char text[32768];
    FILE *in;
    size_t length;

    memset(e, 0, sizeof(*e));
    memset(why, 0, sizeof(*why));

    in = fopen(path, "r");
    if (in == NULL) {
        char sentence[192];

        snprintf(sentence, sizeof(sentence),
                 "there is no engraving at %.140s", path);
        fault(why, 0, 0, sentence);
        return 0;
    }

    length = fread(text, 1, sizeof(text) - 1u, in);
    fclose(in);
    text[length] = '\0';

    return engraving_read_text(e, text, why);
}
/* }}} */

/*
 * Text to number, written here rather than borrowed.
 *
 * Ten lines that the writer also has, in its own words. Sharing them would be
 * harmless and would also be the first crack in "they share no code" -- and the
 * value of that sentence is that it is true without exceptions, because the
 * moment there is one there is an argument about the second.
 */
/* {{{ static int number_from */
static int number_from(const char *text, int hexadecimal, uint64_t *value)
{
    uint64_t result = 0;
    uint32_t i;

    if (text[0] == '\0') {
        return 0;
    }

    for (i = 0; text[i] != '\0'; i++) {
        char c = text[i];
        uint64_t digit;

        if (c >= '0' && c <= '9') {
            digit = (uint64_t)(c - '0');
        } else if (hexadecimal && c >= 'A' && c <= 'F') {
            digit = (uint64_t)(c - 'A') + 10u;
        } else if (hexadecimal && c >= 'a' && c <= 'f') {
            digit = (uint64_t)(c - 'a') + 10u;
        } else {
            return 0;
        }

        result = result * (hexadecimal ? 16u : 10u) + digit;
    }

    *value = result;
    return 1;
}
/* }}} */

/* {{{ int engraving_to_record */
int engraving_to_record(const struct engraving *e, struct record *r,
                        struct engraving_error *why)
{
    uint32_t found = 0;
    uint32_t cell;

    memset(r, 0, sizeof(*r));
    memset(why, 0, sizeof(*why));

    r->seed = e->seed;

    for (cell = 0; cell < RECORD_CELLS; cell++) {
        const char *wanted = record_label(cell);
        uint32_t i;
        int matched = 0;

        for (i = 0; i < e->cell_count; i++) {
            uint64_t value = 0;

            if (strcmp(e->cells[i].label, wanted) != 0) {
                continue;
            }

            if (!number_from(e->cells[i].value, cell == CELL_CHECKSUM, &value)) {
                char sentence[192];

                snprintf(sentence, sizeof(sentence),
                         "the %s chamber holds '%.40s', which is not a number",
                         wanted, e->cells[i].value);
                fault(why, e->cells[i].row + 2u, e->cells[i].column + 2u,
                      sentence);
                return 0;
            }

            r->value[cell] = value;
            matched = 1;
            found++;
            break;
        }

        if (!matched) {
            char sentence[192];

            snprintf(sentence, sizeof(sentence),
                     "this carving has no chamber labelled %s, so it is a"
                     " well-formed picture and not a record", wanted);
            fault(why, 0, 0, sentence);
            return 0;
        }
    }

    if (found != RECORD_CELLS) {
        fault(why, 0, 0, "the carving is missing cells a record needs");
        return 0;
    }

    return 1;
}
/* }}} */

/* {{{ const char *engraving_error_sentence */
const char *engraving_error_sentence(const struct engraving_error *why,
                                     char *into, uint32_t capacity)
{
    if (why->row == 0) {
        snprintf(into, capacity, "%s", why->sentence);
        return into;
    }

    snprintf(into, capacity, "line %u, column %u: %s",
             (unsigned)why->row, (unsigned)why->column, why->sentence);
    return into;
}
/* }}} */
