/*
 * 092-canvas.h -- a character grid that knows about lines rather than
 * characters, so that where two lines meet it produces the right corner without
 * anybody having chosen one.
 *
 * WHY THIS IS A MODULE AND NOT FOUR PRINTF CALLS.
 *
 * The engraving's whole premise is that the carving's lines are the cell walls.
 * A cell wall meets another cell wall at every shared corner, and there are
 * eleven different junction characters depending on which of the four directions
 * carry a stroke. Choosing them by hand is how a drawing ends up with a plus
 * sign where it wanted a tee -- and one wrong junction is a hole the reader falls
 * through, because the reader finds chambers by following walls.
 *
 * So the canvas stores, for every position, WHICH OF THE FOUR DIRECTIONS have a
 * stroke leaving it, and resolves the whole grid to characters once, at the end.
 * Nobody draws a corner.
 *
 * Two alphabets, and they are two different artifacts rather than one and a
 * degraded one. A file says which it is in its first lines, and a reader accepts
 * exactly one at a time -- a format that accepts either is a format where a
 * corrupted character has somewhere to hide.
 *
 * See docs/018-the-record-log-is-an-engraving.md and issue 1002.
 */

#ifndef VTT_CANVAS_H
#define VTT_CANVAS_H

#include <stdint.h>
#include <stdio.h>

/* Which directions a stroke leaves a position in. */
#define STROKE_UP    (1u << 0)
#define STROKE_DOWN  (1u << 1)
#define STROKE_LEFT  (1u << 2)
#define STROKE_RIGHT (1u << 3)

/*
 * How large a carving may be. Generous: the widest creature is a dragon holding
 * a sixteen-digit checksum, and a terminal is eighty columns, and going over
 * eighty is a decision somebody should have to make on purpose.
 */
#define CANVAS_MAX_WIDTH  200
#define CANVAS_MAX_HEIGHT 120

/* The two alphabets. */
#define ALPHABET_CARVED 0u   /* Box-drawing characters. The real artifact. */
#define ALPHABET_PLAIN  1u   /* Dashes, pipes and plus signs. A different one. */

struct canvas {
    uint32_t width;
    uint32_t height;
    uint8_t  alphabet;

    /* Four bits per position: which directions carry a stroke. */
    uint8_t strokes[CANVAS_MAX_HEIGHT][CANVAS_MAX_WIDTH];

    /*
     * Characters placed directly -- labels, values, an eye, a whisker. Zero
     * means nothing was placed.
     *
     * A glyph WINS over a stroke where both exist, and that is deliberate: a
     * label sitting on a wall means the wall was drawn in the wrong place, and
     * hiding the label under the wall would hide the mistake.
     */
    char glyphs[CANVAS_MAX_HEIGHT][CANVAS_MAX_WIDTH];

    /*
     * How many times a glyph landed on a stroke.
     *
     * ORNAMENT MUST NEVER TOUCH A WALL. The reader finds chambers by following
     * walls, so a fin drawn across one punches a hole the reader falls through --
     * and the drawing would still look roughly like an animal, which is the
     * worst way for it to be wrong.
     *
     * The glyph is written anyway, so the damage is visible rather than silently
     * dropped, and this counts it so a test can insist on zero for every
     * creature. Detected rather than hoped for.
     */
    uint32_t ornament_collisions;
};

/*
 * Prepare a canvas. Returns 1, or 0 when the size is beyond what a carving may
 * be -- refused rather than clipped, because a clipped creature is a creature
 * with a wall missing and the reader would fall through it.
 */
int canvas_init(struct canvas *c, uint32_t width, uint32_t height, uint8_t alphabet);

/*
 * A horizontal run of stroke, from x0 to x1 inclusive, on row y. Both ends get
 * the appropriate half-stroke, so a run that meets another run at its end
 * produces a junction rather than an overwrite.
 */
void canvas_across(struct canvas *c, uint32_t y, uint32_t x0, uint32_t x1);

/* The same, downward, on column x from y0 to y1 inclusive. */
void canvas_down(struct canvas *c, uint32_t x, uint32_t y0, uint32_t y1);

/* A closed rectangle: four runs, and the corners fall out of the junctions. */
void canvas_box(struct canvas *c, uint32_t x0, uint32_t y0, uint32_t x1, uint32_t y1);

/* One character, placed over whatever is there. */
void canvas_put(struct canvas *c, uint32_t x, uint32_t y, char glyph);

/* A run of characters, left to right. Anything past the edge is dropped. */
void canvas_text(struct canvas *c, uint32_t x, uint32_t y, const char *text);

/*
 * The same, right-aligned so that its LAST character sits at x. What a number in
 * a chamber wants, because a column of numbers is read by its right edge.
 */
void canvas_text_right(struct canvas *c, uint32_t x, uint32_t y, const char *text);

/*
 * Resolve the whole grid and write it out. Rows are trimmed of trailing blanks
 * and end with a newline.
 *
 * Trimmed because trailing spaces are invisible, and an artifact whose
 * correctness depends on something invisible is an artifact somebody will break
 * by accident and never see why.
 */
void canvas_emit(const struct canvas *c, FILE *out);

/*
 * The same, into a buffer. Returns the length written, or 0 if it would not fit
 * -- a half-written carving is not a smaller picture, it is an unreadable file.
 */
uint32_t canvas_to_text(const struct canvas *c, char *into, uint32_t capacity);

/*
 * The character one position resolves to. Exposed so a test can check all
 * sixteen stroke combinations directly rather than by reading them back out of a
 * finished drawing.
 *
 * Returns a pointer to a short string, because a box-drawing character is three
 * bytes of UTF-8 and a char cannot hold one.
 */
const char *canvas_glyph_for(uint8_t strokes, uint8_t alphabet);

#endif
