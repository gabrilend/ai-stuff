/*
 * 092-canvas.c -- strokes in, characters out.
 *
 * The interesting part is one lookup table with sixteen rows. Everything else is
 * bookkeeping around it.
 *
 * See 092-canvas.h for why the strokes are stored rather than the characters.
 */

#include "092-canvas.h"

#include <string.h>

/*
 * The sixteen combinations, indexed by the four stroke bits: up, down, left,
 * right, in that order as bit 0 through bit 3.
 *
 * A DISPATCH TABLE RATHER THAN A CHAIN OF CONDITIONALS. Sixteen cases, each one
 * line, all visible at once and comparable against each other -- which is how
 * you notice that the one for "up and left" is the wrong corner. Written as
 * conditionals it would be twenty branches nobody reads twice.
 *
 * Index 0 is no stroke at all, which draws as a space rather than as nothing:
 * the row is trimmed at emit time, so an interior gap stays a gap and a trailing
 * one disappears.
 */
static const char *const carved[16] = {
    /* 0  ....  */ " ",
    /* 1  u...  */ "\xe2\x95\xb5",   /* ╵ upward half-stroke */
    /* 2  .d..  */ "\xe2\x95\xb7",   /* ╷ downward half */
    /* 3  ud..  */ "\xe2\x94\x82",   /* │ */
    /* 4  ..l.  */ "\xe2\x95\xb4",   /* ╴ leftward half */
    /* 5  u.l.  */ "\xe2\x94\x98",   /* ┘ */
    /* 6  .dl.  */ "\xe2\x94\x90",   /* ┐ */
    /* 7  udl.  */ "\xe2\x94\xa4",   /* ┤ */
    /* 8  ...r  */ "\xe2\x95\xb6",   /* ╶ rightward half */
    /* 9  u..r  */ "\xe2\x94\x94",   /* └ */
    /* 10 .d.r  */ "\xe2\x94\x8c",   /* ┌ */
    /* 11 ud.r  */ "\xe2\x94\x9c",   /* ├ */
    /* 12 ..lr  */ "\xe2\x94\x80",   /* ─ */
    /* 13 u.lr  */ "\xe2\x94\xb4",   /* ┴ */
    /* 14 .dlr  */ "\xe2\x94\xac",   /* ┬ */
    /* 15 udlr  */ "\xe2\x94\xbc"    /* ┼ */
};

/*
 * The plain alphabet. NOT a degraded version of the one above -- a different
 * artifact, for a terminal that cannot show the other. It loses the distinction
 * between corners, which is exactly why a reader must be told which alphabet it
 * is holding rather than accepting either.
 */
static const char *const plain[16] = {
    " ", "|", "|", "|",
    "-", "+", "+", "+",
    "-", "+", "+", "+",
    "-", "+", "+", "+"
};

/* {{{ const char *canvas_glyph_for */
const char *canvas_glyph_for(uint8_t strokes, uint8_t alphabet)
{
    uint8_t index = strokes & 0x0Fu;

    if (alphabet == ALPHABET_PLAIN) {
        return plain[index];
    }
    return carved[index];
}
/* }}} */

/* {{{ int canvas_init */
int canvas_init(struct canvas *c, uint32_t width, uint32_t height, uint8_t alphabet)
{
    /*
     * Refused rather than clipped. A clipped creature is a creature with a wall
     * missing, and the reader finds chambers by following walls -- so it would
     * walk out of the animal and read the page.
     */
    if (width == 0 || height == 0
        || width > CANVAS_MAX_WIDTH || height > CANVAS_MAX_HEIGHT) {
        return 0;
    }

    memset(c, 0, sizeof(*c));
    c->width = width;
    c->height = height;
    c->alphabet = alphabet;
    return 1;
}
/* }}} */

/* {{{ static int inside */
static int inside(const struct canvas *c, uint32_t x, uint32_t y)
{
    return x < c->width && y < c->height;
}
/* }}} */

/* {{{ void canvas_across */
void canvas_across(struct canvas *c, uint32_t y, uint32_t x0, uint32_t x1)
{
    uint32_t x;

    if (x1 < x0) {
        uint32_t swap = x0;
        x0 = x1;
        x1 = swap;
    }

    for (x = x0; x <= x1; x++) {
        if (!inside(c, x, y)) {
            continue;
        }

        /* Each end gets only the half-stroke that points along the run, so a run
         * meeting another run at its end produces a junction. */
        if (x > x0) {
            c->strokes[y][x] |= STROKE_LEFT;
        }
        if (x < x1) {
            c->strokes[y][x] |= STROKE_RIGHT;
        }
    }
}
/* }}} */

/* {{{ void canvas_down */
void canvas_down(struct canvas *c, uint32_t x, uint32_t y0, uint32_t y1)
{
    uint32_t y;

    if (y1 < y0) {
        uint32_t swap = y0;
        y0 = y1;
        y1 = swap;
    }

    for (y = y0; y <= y1; y++) {
        if (!inside(c, x, y)) {
            continue;
        }

        if (y > y0) {
            c->strokes[y][x] |= STROKE_UP;
        }
        if (y < y1) {
            c->strokes[y][x] |= STROKE_DOWN;
        }
    }
}
/* }}} */

/* {{{ void canvas_box */
void canvas_box(struct canvas *c, uint32_t x0, uint32_t y0, uint32_t x1, uint32_t y1)
{
    canvas_across(c, y0, x0, x1);
    canvas_across(c, y1, x0, x1);
    canvas_down(c, x0, y0, y1);
    canvas_down(c, x1, y0, y1);
}
/* }}} */

/* {{{ void canvas_put */
void canvas_put(struct canvas *c, uint32_t x, uint32_t y, char glyph)
{
    if (!inside(c, x, y)) {
        return;
    }

    /*
     * Written anyway, and counted. Dropping it would hide a fin drawn through a
     * wall; refusing to draw would leave the caller believing it had drawn.
     * A space is not ornament and does not count -- padding a label is not
     * cutting a hole in an animal.
     */
    if (glyph != ' ' && (c->strokes[y][x] & 0x0Fu) != 0) {
        c->ornament_collisions++;
    }

    c->glyphs[y][x] = glyph;
}
/* }}} */

/* {{{ void canvas_text */
void canvas_text(struct canvas *c, uint32_t x, uint32_t y, const char *text)
{
    uint32_t i;

    for (i = 0; text[i] != '\0'; i++) {
        canvas_put(c, x + i, y, text[i]);
    }
}
/* }}} */

/* {{{ void canvas_text_right */
void canvas_text_right(struct canvas *c, uint32_t x, uint32_t y, const char *text)
{
    uint32_t length = (uint32_t)strlen(text);

    if (length == 0 || length > x + 1u) {
        /* It would start left of the page. Written from column zero anyway, so
         * that the overflow is VISIBLE as a number colliding with a wall rather
         * than as a number that quietly is not there. */
        canvas_text(c, 0, y, text);
        return;
    }

    canvas_text(c, x + 1u - length, y, text);
}
/* }}} */

/* {{{ static uint32_t row_extent */
static uint32_t row_extent(const struct canvas *c, uint32_t y)
{
    uint32_t x;
    uint32_t last = 0;
    int seen = 0;

    for (x = 0; x < c->width; x++) {
        if (c->glyphs[y][x] != '\0' && c->glyphs[y][x] != ' ') {
            last = x;
            seen = 1;
        } else if ((c->strokes[y][x] & 0x0Fu) != 0) {
            last = x;
            seen = 1;
        }
    }

    if (!seen) {
        return 0;
    }
    return last + 1u;
}
/* }}} */

/* {{{ uint32_t canvas_to_text */
uint32_t canvas_to_text(const struct canvas *c, char *into, uint32_t capacity)
{
    uint32_t cursor = 0;
    uint32_t y;

    if (capacity == 0) {
        return 0;
    }
    into[0] = '\0';

    for (y = 0; y < c->height; y++) {
        uint32_t extent = row_extent(c, y);
        uint32_t x;

        for (x = 0; x < extent; x++) {
            const char *piece;
            char one[2];
            uint32_t length;

            if (c->glyphs[y][x] != '\0') {
                one[0] = c->glyphs[y][x];
                one[1] = '\0';
                piece = one;
            } else {
                piece = canvas_glyph_for(c->strokes[y][x], c->alphabet);
            }

            length = (uint32_t)strlen(piece);

            if (cursor + length + 2u > capacity) {
                return 0;
            }

            memcpy(into + cursor, piece, length);
            cursor += length;
        }

        if (cursor + 2u > capacity) {
            return 0;
        }
        into[cursor] = '\n';
        cursor++;
    }

    into[cursor] = '\0';
    return cursor;
}
/* }}} */

/* {{{ void canvas_emit */
void canvas_emit(const struct canvas *c, FILE *out)
{
    uint32_t y;

    for (y = 0; y < c->height; y++) {
        uint32_t extent = row_extent(c, y);
        uint32_t x;

        for (x = 0; x < extent; x++) {
            if (c->glyphs[y][x] != '\0') {
                fputc(c->glyphs[y][x], out);
            } else {
                fputs(canvas_glyph_for(c->strokes[y][x], c->alphabet), out);
            }
        }

        fputc('\n', out);
    }
}
/* }}} */
