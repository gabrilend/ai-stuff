/*
 * 082-sprite.c -- making a picture out of a word, and reading it back.
 *
 * Three separate jobs live here, and they are kept separate on purpose.
 *
 *   MAKING     a category and a seed become a struct sprite. Pure arithmetic,
 *              no clock, no ambient randomness, no file.
 *   WRITING    a struct sprite becomes SVG text. String-writing, nothing more.
 *   READING    SVG text becomes a struct sprite again -- and this half is
 *              written as though it had never seen the writer.
 *
 * The reader is the point of the exercise. An encoder that is confidently wrong
 * produces a file that mostly works, and the only thing that notices is somebody
 * trying to read it. So the reader does not share a single line with the writer:
 * it recovers each field from the DRAWING rather than from a restatement of the
 * struct. The palette slot of a layer is recovered by matching the fill colour
 * against the palette. Which way the sprite moves is recovered by looking at
 * where the animation actually moves it. Two independent readers is proof; one
 * is an opinion.
 *
 * See 082-sprite.h for the vocabulary and issues 901 and 902.
 */

#include "082-sprite.h"

#include <stdio.h>
#include <string.h>

#include "047-streams.h"

/*
 * The viewbox is a hundred by a hundred and the middle is fifty, fifty. Every
 * offset and radius in a layer is in these hundredths, which is why they fit in
 * a byte: the sprite is described in its own units and the renderer decides how
 * big a metre is. Changing this number changes every stored sprite, so it is
 * written once and referred to rather than typed into each formula.
 */
#define VIEWBOX ((int)SPRITE_CANVAS)
#define MIDDLE  (VIEWBOX / 2)

/*
 * How thick a ring is drawn. A ring with no thickness is an invisible sprite
 * that passes every test, so the number lives here rather than inside a format
 * string where nobody would find it.
 */
#define RING_THICKNESS 4

/* ------------------------------------------------------------------------- */
/* The paintbrush: one table per kind, read forwards for names and backwards   */
/* for words. Both halves of the vocabulary come from here, so the document    */
/* and the wall cannot describe different paintbrushes.                        */
/* ------------------------------------------------------------------------- */

static const char *const shape_words[SHAPE_COUNT] = {
    "circle", "rect", "triangle", "ring"
};

static const char *const slot_words[SLOT_COUNT] = {
    "primary", "secondary", "accent"
};

static const char *const motion_words[MOTION_COUNT] = {
    "still", "bob", "walk", "flicker", "turn"
};

/*
 * The same words flattened, for edit distance and for printing the contract.
 * Kept in one array rather than three so a caller asking "is this a word this
 * project knows?" does not have to know which kind of word it was hoping for --
 * which is exactly the question somebody has when they have just mistyped one.
 */
static const char *const every_word[SHAPE_COUNT + SLOT_COUNT + MOTION_COUNT] = {
    "circle", "rect", "triangle", "ring",
    "primary", "secondary", "accent",
    "still", "bob", "walk", "flicker", "turn"
};

/* {{{ const char *shape_name */
const char *shape_name(uint8_t shape)
{
    /* Out of range means a caller built a layer we cannot draw. Say so in the
     * string rather than returning "circle" and drawing something plausible. */
    if (shape >= SHAPE_COUNT) {
        return "(not a shape)";
    }
    return shape_words[shape];
}
/* }}} */

/* {{{ const char *slot_name */
const char *slot_name(uint8_t slot)
{
    if (slot >= SLOT_COUNT) {
        return "(not a slot)";
    }
    return slot_words[slot];
}
/* }}} */

/* {{{ const char *motion_name */
const char *motion_name(uint8_t motion)
{
    if (motion >= MOTION_COUNT) {
        return "(not a motion)";
    }
    return motion_words[motion];
}
/* }}} */

/* {{{ static uint8_t word_in */
static uint8_t word_in(const char *const *table, uint8_t count, const char *word)
{
    uint8_t i;

    for (i = 0; i < count; i++) {
        if (strcmp(table[i], word) == 0) {
            return i;
        }
    }

    /* The count is returned, which is not a legal value for its kind. A caller
     * that stores it without checking gets a loud failure at the wall rather
     * than a sprite that quietly became a circle. */
    return count;
}
/* }}} */

/* {{{ uint8_t shape_from_word */
uint8_t shape_from_word(const char *word)
{
    return word_in(shape_words, SHAPE_COUNT, word);
}
/* }}} */

/* {{{ uint8_t slot_from_word */
uint8_t slot_from_word(const char *word)
{
    return word_in(slot_words, SLOT_COUNT, word);
}
/* }}} */

/* {{{ uint8_t motion_from_word */
uint8_t motion_from_word(const char *word)
{
    return word_in(motion_words, MOTION_COUNT, word);
}
/* }}} */

/* {{{ const char *const *sprite_vocabulary */
const char *const *sprite_vocabulary(uint32_t *count)
{
    *count = (uint32_t)(SHAPE_COUNT + SLOT_COUNT + MOTION_COUNT);
    return every_word;
}
/* }}} */

/* {{{ static uint32_t smallest_of_three */
static uint32_t smallest_of_three(uint32_t a, uint32_t b, uint32_t c)
{
    uint32_t least = a;

    if (b < least) {
        least = b;
    }
    if (c < least) {
        least = c;
    }
    return least;
}
/* }}} */

/*
 * How many single-character edits turn one word into another. The ordinary
 * Levenshtein distance, computed in two rows rather than a full table because
 * the words are short and the whole point is that this is cheap enough to run
 * against the entire vocabulary on every fault.
 */
/* {{{ static uint32_t edit_distance */
static uint32_t edit_distance(const char *a, const char *b)
{
    uint32_t length_a = (uint32_t)strlen(a);
    uint32_t length_b = (uint32_t)strlen(b);
    uint32_t previous[SPRITE_NAME_MAX + 2];
    uint32_t current[SPRITE_NAME_MAX + 2];
    uint32_t i;
    uint32_t j;

    /* A word longer than a name can be is not a near miss for anything. */
    if (length_a > SPRITE_NAME_MAX || length_b > SPRITE_NAME_MAX) {
        return 0xFFFFFFFFu;
    }

    for (j = 0; j <= length_b; j++) {
        previous[j] = j;
    }

    for (i = 1; i <= length_a; i++) {
        current[0] = i;

        for (j = 1; j <= length_b; j++) {
            uint32_t substitution_cost = (a[i - 1] == b[j - 1]) ? 0u : 1u;

            current[j] = smallest_of_three(previous[j] + 1u,
                                           current[j - 1] + 1u,
                                           previous[j - 1] + substitution_cost);
        }

        for (j = 0; j <= length_b; j++) {
            previous[j] = current[j];
        }
    }

    return previous[length_b];
}
/* }}} */

/* {{{ const char *sprite_nearest_word */
const char *sprite_nearest_word(const char *given)
{
    uint32_t count = 0;
    const char *const *words = sprite_vocabulary(&count);
    const char *best = NULL;
    uint32_t best_distance = 0xFFFFFFFFu;
    uint32_t i;

    for (i = 0; i < count; i++) {
        uint32_t distance = edit_distance(given, words[i]);

        if (distance < best_distance) {
            best_distance = distance;
            best = words[i];
        }
    }

    /*
     * Beyond three edits the "nearest" word is noise, and a wrong suggestion is
     * worse than none -- it sends somebody to check a word they never typed.
     * The vocabulary being twelve words long is what makes three a sensible
     * line; across a thousand words it would not be.
     *
     * The second condition is the one that is easy to leave out. A fixed
     * distance alone will happily offer "bob" for an empty word and "turn" for a
     * single letter, because three edits is the whole of a three-letter word.
     * A suggestion is only worth making when MOST of what was typed survives
     * into the suggestion -- so the distance must also be shorter than the word
     * it is correcting.
     */
    if (best_distance > 3u || best_distance >= (uint32_t)strlen(given)) {
        return NULL;
    }

    return best;
}
/* }}} */

/* ------------------------------------------------------------------------- */
/* Making one.                                                                 */
/* ------------------------------------------------------------------------- */

/*
 * A colour channel scaled by a fraction, in integers. Used to darken and to
 * lighten, which is the whole of what a colour scheme needs beyond the draw.
 */
/* {{{ static uint32_t scale_channel */
static uint32_t scale_channel(uint32_t channel, uint32_t numerator, uint32_t denominator)
{
    uint32_t scaled = (channel * numerator) / denominator;

    if (scaled > 255u) {
        scaled = 255u;
    }
    return scaled;
}
/* }}} */

/* {{{ static uint32_t pack_colour */
static uint32_t pack_colour(uint32_t red, uint32_t green, uint32_t blue)
{
    return ((red & 0xFFu) << 16) | ((green & 0xFFu) << 8) | (blue & 0xFFu);
}
/* }}} */

/*
 * Build the three palette slots.
 *
 * A SCHEME IS DRAWN FIRST, and that is deliberate. If every sprite were coloured
 * the same way, the machine grader's palette test would have nothing to
 * discriminate -- every sprite would score identically on it and the component
 * would be dead weight pretending to be judgement. Three schemes that genuinely
 * differ is what gives the heuristic something to be right or wrong about.
 */
/* {{{ static void make_palette */
static void make_palette(struct sprite *s, struct stream_registry *r, uint32_t colour_stream)
{
    uint32_t red   = 40u + (uint32_t)stream_below(r, colour_stream, 180);
    uint32_t green = 40u + (uint32_t)stream_below(r, colour_stream, 180);
    uint32_t blue  = 40u + (uint32_t)stream_below(r, colour_stream, 180);
    uint64_t scheme = stream_below(r, colour_stream, 3);

    s->palette[SLOT_PRIMARY] = pack_colour(red, green, blue);

    if (scheme == 0) {
        /* Monochrome: one colour, darkened and lightened. The secondary sits
         * close to the primary and the accent sits far, which is the shape the
         * grader calls coherent. */
        s->palette[SLOT_SECONDARY] = pack_colour(scale_channel(red, 3, 5),
                                                 scale_channel(green, 3, 5),
                                                 scale_channel(blue, 3, 5));
        s->palette[SLOT_ACCENT]    = pack_colour(255u - scale_channel(255u - red, 2, 5),
                                                 255u - scale_channel(255u - green, 2, 5),
                                                 255u - scale_channel(255u - blue, 2, 5));
    } else if (scheme == 1) {
        /* Analogous: the channels rotate by one place, which lands somewhere
         * neighbouring rather than opposite. */
        s->palette[SLOT_SECONDARY] = pack_colour(green, blue, red);
        s->palette[SLOT_ACCENT]    = pack_colour(blue, red, green);
    } else {
        /* Clashing: every slot drawn fresh. This is the scheme the grader is
         * meant to mark down, and it exists so that it can. */
        s->palette[SLOT_SECONDARY] = pack_colour(
            40u + (uint32_t)stream_below(r, colour_stream, 180),
            40u + (uint32_t)stream_below(r, colour_stream, 180),
            40u + (uint32_t)stream_below(r, colour_stream, 180));
        s->palette[SLOT_ACCENT] = pack_colour(
            40u + (uint32_t)stream_below(r, colour_stream, 180),
            40u + (uint32_t)stream_below(r, colour_stream, 180),
            40u + (uint32_t)stream_below(r, colour_stream, 180));
    }
}
/* }}} */

/* {{{ void sprite_make */
void sprite_make(struct sprite *s, const char *category, uint64_t seed)
{
    struct stream_registry registry;
    char stream_name[STREAM_NAME_MAX + 1];
    uint32_t shape_stream;
    uint32_t colour_stream;
    uint32_t motion_stream;
    uint32_t i;
    int bilateral;

    memset(s, 0, sizeof(*s));

    snprintf(s->category, sizeof(s->category), "%.31s", category);
    s->seed = seed;

    /*
     * A private registry, seeded from the seed alone. See the note in the
     * header: the sprite must be a pure function of what names it, and a
     * session-owned stream carries a position that would make it a function of
     * when it was asked for.
     */
    streams_init(&registry, seed);

    /*
     * Three streams rather than one, named after the category so two categories
     * with the same seed do not draw the same numbers. Three because adding a
     * draw to the layer code must not silently repaint every sprite -- the same
     * argument that made the whole project use named streams, applied one level
     * down.
     */
    snprintf(stream_name, sizeof(stream_name), "sprite-shape:%.40s", s->category);
    shape_stream = stream_named(&registry, stream_name);

    snprintf(stream_name, sizeof(stream_name), "sprite-colour:%.40s", s->category);
    colour_stream = stream_named(&registry, stream_name);

    snprintf(stream_name, sizeof(stream_name), "sprite-motion:%.40s", s->category);
    motion_stream = stream_named(&registry, stream_name);

    /*
     * The first layer is the body: centred, large, primary, and SOLID.
     *
     * Two constraints, both learned by looking at the output rather than by
     * reasoning about it. Centred and large is what stops the generator making a
     * sprite of small dots near one edge -- technically a sprite, visibly
     * nothing. Solid is because a ring for a body is a hollow outline with the
     * detail floating inside it, which reads as a diagram rather than as a thing
     * standing somewhere. A ring is a detail; it is not a body.
     */
    s->layers[0].shape    = (uint8_t)stream_below(&registry, shape_stream, SHAPE_RING);
    s->layers[0].slot     = SLOT_PRIMARY;
    s->layers[0].offset_x = 0;
    s->layers[0].offset_y = 0;
    s->layers[0].radius   = (uint8_t)(25u + stream_below(&registry, shape_stream, 16));

    /*
     * WHETHER THE DETAIL IS MIRRORED.
     *
     * Half of them are. A pair of matching shapes either side of the middle
     * reads as eyes, or arms, or wheels -- as a thing with a front -- and the
     * same shapes scattered freely read as a pile. This is the single cheapest
     * change that made the output look like creatures, and it cost no new words
     * in the paintbrush, which is why it was preferred to adding shapes.
     *
     * It is drawn rather than decided by category, because whether a goblin is
     * bilateral and a torch is not depends on what a category MEANS, and
     * categories are the ruleset's to name -- see open question 10.4. Until that
     * is settled, symmetry is a property some sprites have.
     */
    bilateral = (stream_below(&registry, shape_stream, 2) == 1);

    if (bilateral) {
        /* One pair or two, so the count is the body plus an even number. */
        uint32_t pairs = 1u + (uint32_t)stream_below(&registry, shape_stream, 2);

        s->layer_count = (uint8_t)(1u + pairs * 2u);

        for (i = 0; i < pairs; i++) {
            struct sprite_layer *left  = &s->layers[1u + i * 2u];
            struct sprite_layer *right = &s->layers[2u + i * 2u];

            left->shape  = (uint8_t)stream_below(&registry, shape_stream, SHAPE_COUNT);
            left->slot   = (uint8_t)(1u + stream_below(&registry, shape_stream, SLOT_COUNT - 1));
            left->radius = (uint8_t)(5u + stream_below(&registry, shape_stream, 14));

            /* Away from the middle by a visible amount. A mirrored pair sitting
             * on top of each other is one shape drawn twice. */
            left->offset_x = (int8_t)stream_between(&registry, shape_stream, 6, 24);
            left->offset_y = (int8_t)stream_between(&registry, shape_stream, -20, 20);

            *right = *left;
            right->offset_x = (int8_t)(-left->offset_x);
        }
    } else {
        s->layer_count = (uint8_t)(2u + stream_below(&registry, shape_stream, 5));

        for (i = 1; i < s->layer_count; i++) {
            s->layers[i].shape    = (uint8_t)stream_below(&registry, shape_stream, SHAPE_COUNT);
            s->layers[i].slot     = (uint8_t)(1u + stream_below(&registry, shape_stream, SLOT_COUNT - 1));
            s->layers[i].offset_x = (int8_t)stream_between(&registry, shape_stream, -22, 22);
            s->layers[i].offset_y = (int8_t)stream_between(&registry, shape_stream, -22, 22);
            s->layers[i].radius   = (uint8_t)(5u + stream_below(&registry, shape_stream, 14));
        }
    }

    make_palette(s, &registry, colour_stream);

    /*
     * EVERY SLOT MUST BE A DIFFERENT COLOUR, and here is where that is made
     * true rather than hoped for.
     *
     * The reader recovers which slot a layer draws from by matching the layer's
     * fill against the palette. If two slots ever held the same colour the
     * match would be ambiguous and the round trip would fail -- rarely, on some
     * seeds and not others, which is the worst way for anything to fail.
     *
     * So the two lowest bits of the blue channel carry the slot number. Three
     * parts in two hundred and fifty-five: invisible to a person, decisive to a
     * reader. This is the file format reaching back and constraining the
     * generator, which is uncomfortable and correct -- a picture that cannot be
     * read is not a picture this project has.
     */
    for (i = 0; i < SLOT_COUNT; i++) {
        s->palette[i] = (s->palette[i] & ~3u) | i;
    }

    s->motion = (uint8_t)stream_below(&registry, motion_stream, MOTION_COUNT);
}
/* }}} */

/* ------------------------------------------------------------------------- */
/* Writing it out.                                                             */
/* ------------------------------------------------------------------------- */

/*
 * Append to a buffer, tracking the cursor and refusing to half-write.
 *
 * Returns 1 while everything still fits. Once it has returned 0 the caller stops
 * -- a truncated SVG is not a smaller picture, it is an unparseable file, and
 * the failure has to be visible at the call that asked for a buffer too small
 * rather than in a renderer six steps later.
 */
/* {{{ static int append */
static int append(char *into, uint32_t capacity, uint32_t *cursor, const char *text)
{
    uint32_t length = (uint32_t)strlen(text);

    if (*cursor + length + 1u > capacity) {
        return 0;
    }

    memcpy(into + *cursor, text, length);
    *cursor += length;
    into[*cursor] = '\0';
    return 1;
}
/* }}} */

/* {{{ static void colour_text */
static void colour_text(uint32_t packed, char *into, uint32_t capacity)
{
    snprintf(into, capacity, "#%02X%02X%02X",
             (unsigned)((packed >> 16) & 0xFFu),
             (unsigned)((packed >> 8) & 0xFFu),
             (unsigned)(packed & 0xFFu));
}
/* }}} */

/*
 * One layer as one drawing element.
 *
 * Nothing about the struct is restated in the file. A rect is written as a rect
 * with a corner and a width, not as "shape=rect offset=3 radius=12", because a
 * file that restates the struct is a file the reader can agree with while the
 * drawing says something else entirely.
 */
/* {{{ static int write_layer */
static int write_layer(const struct sprite *s, uint32_t index,
                       char *into, uint32_t capacity, uint32_t *cursor)
{
    const struct sprite_layer *layer = &s->layers[index];
    char line[256];
    char colour[16];
    int centre_x = MIDDLE + layer->offset_x;
    int centre_y = MIDDLE + layer->offset_y;
    int radius   = (int)layer->radius;

    colour_text(s->palette[layer->slot], colour, sizeof(colour));

    if (layer->shape == SHAPE_CIRCLE) {
        snprintf(line, sizeof(line),
                 "  <circle cx=\"%d\" cy=\"%d\" r=\"%d\" fill=\"%s\"/>\n",
                 centre_x, centre_y, radius, colour);
    } else if (layer->shape == SHAPE_RING) {
        /* A ring is a circle that is only its edge. The reader tells the two
         * apart by the absence of a fill, which is the same thing a person
         * looking at the picture would notice. */
        snprintf(line, sizeof(line),
                 "  <circle cx=\"%d\" cy=\"%d\" r=\"%d\" fill=\"none\""
                 " stroke=\"%s\" stroke-width=\"%d\"/>\n",
                 centre_x, centre_y, radius, colour, RING_THICKNESS);
    } else if (layer->shape == SHAPE_RECT) {
        snprintf(line, sizeof(line),
                 "  <rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" fill=\"%s\"/>\n",
                 centre_x - radius, centre_y - radius,
                 radius * 2, radius * 2, colour);
    } else {
        /* Apex at the top, base at the bottom, so the reader recovers the
         * centre from the base's midpoint and the radius from its half-width. */
        snprintf(line, sizeof(line),
                 "  <polygon points=\"%d,%d %d,%d %d,%d\" fill=\"%s\"/>\n",
                 centre_x, centre_y - radius,
                 centre_x - radius, centre_y + radius,
                 centre_x + radius, centre_y + radius,
                 colour);
    }

    return append(into, capacity, cursor, line);
}
/* }}} */

/*
 * The animation, as SMIL inside the group.
 *
 * SMIL rather than CSS because the file has to animate when it is opened on its
 * own, with no stylesheet and no page around it. A rater shown a still frame of
 * an animation is rating an illustration.
 *
 * Each motion is recoverable from what it does rather than from a label: bob
 * moves along y, walk moves along x, flicker changes opacity, turn rotates.
 */
/* {{{ static int write_motion */
static int write_motion(const struct sprite *s, char *into, uint32_t capacity, uint32_t *cursor)
{
    if (s->motion == MOTION_STILL) {
        /* Nothing at all. A "still" animation element that animates to where it
         * already is would be a thing the reader has to special-case, and a
         * still sprite is genuinely the absence of motion. */
        return 1;
    }

    if (s->motion == MOTION_BOB) {
        return append(into, capacity, cursor,
                      "  <animateTransform attributeName=\"transform\" type=\"translate\""
                      " values=\"0 0;0 -6;0 0\" dur=\"1.6s\" repeatCount=\"indefinite\"/>\n");
    }

    if (s->motion == MOTION_WALK) {
        return append(into, capacity, cursor,
                      "  <animateTransform attributeName=\"transform\" type=\"translate\""
                      " values=\"-4 0;4 0;-4 0\" dur=\"0.8s\" repeatCount=\"indefinite\"/>\n");
    }

    if (s->motion == MOTION_FLICKER) {
        return append(into, capacity, cursor,
                      "  <animate attributeName=\"opacity\""
                      " values=\"1;0.55;1\" dur=\"0.5s\" repeatCount=\"indefinite\"/>\n");
    }

    return append(into, capacity, cursor,
                  "  <animateTransform attributeName=\"transform\" type=\"rotate\""
                  " values=\"0 50 50;360 50 50\" dur=\"4s\" repeatCount=\"indefinite\"/>\n");
}
/* }}} */

/* {{{ uint32_t sprite_to_svg */
uint32_t sprite_to_svg(const struct sprite *s, char *into, uint32_t capacity)
{
    uint32_t cursor = 0;
    char line[512];
    char primary[16];
    char secondary[16];
    char accent[16];
    uint32_t i;

    if (capacity == 0) {
        return 0;
    }

    into[0] = '\0';

    snprintf(line, sizeof(line),
             "<svg xmlns=\"http://www.w3.org/2000/svg\""
             " viewBox=\"0 0 %d %d\" width=\"%d\" height=\"%d\">\n",
             VIEWBOX, VIEWBOX, VIEWBOX, VIEWBOX);
    if (!append(into, capacity, &cursor, line)) {
        return 0;
    }

    colour_text(s->palette[SLOT_PRIMARY], primary, sizeof(primary));
    colour_text(s->palette[SLOT_SECONDARY], secondary, sizeof(secondary));
    colour_text(s->palette[SLOT_ACCENT], accent, sizeof(accent));

    /*
     * The description line carries only what the drawing cannot: what this is a
     * picture OF, which seed made it, and the palette. The palette is here
     * because the reader recovers a layer's SLOT by matching its fill against
     * these three -- which is a real recovery from the drawing, and would be a
     * restatement of the struct if each element carried its slot as a label.
     */
    snprintf(line, sizeof(line),
             "  <desc>vtt-sprite category=\"%.31s\" seed=\"%llu\" palette=\"%s,%s,%s\"</desc>\n",
             s->category, (unsigned long long)s->seed, primary, secondary, accent);
    if (!append(into, capacity, &cursor, line)) {
        return 0;
    }

    if (!append(into, capacity, &cursor, "  <g>\n")) {
        return 0;
    }

    for (i = 0; i < s->layer_count; i++) {
        if (!write_layer(s, i, into, capacity, &cursor)) {
            return 0;
        }
    }

    if (!write_motion(s, into, capacity, &cursor)) {
        return 0;
    }

    if (!append(into, capacity, &cursor, "  </g>\n</svg>\n")) {
        return 0;
    }

    return cursor;
}
/* }}} */

/* ------------------------------------------------------------------------- */
/* Reading it back. Written as though the writer above did not exist.          */
/* ------------------------------------------------------------------------- */

/* {{{ static const char *after */
static const char *after(const char *text, const char *needle)
{
    const char *found = strstr(text, needle);

    if (found == NULL) {
        return NULL;
    }
    return found + strlen(needle);
}
/* }}} */

/*
 * Read a signed decimal number sitting at a cursor, advancing it past.
 *
 * Returns 1 when a number was there. A caller that ignores the return value and
 * uses the number anyway is reading whatever was in the variable before, which
 * is exactly the class of bug a round-trip test is supposed to catch.
 */
/* {{{ static int read_number */
static int read_number(const char **cursor, int *value)
{
    const char *p = *cursor;
    int sign = 1;
    int digits = 0;
    int result = 0;

    while (*p == ' ') {
        p++;
    }

    if (*p == '-') {
        sign = -1;
        p++;
    }

    while (*p >= '0' && *p <= '9') {
        result = result * 10 + (*p - '0');
        digits++;
        p++;
    }

    if (digits == 0) {
        return 0;
    }

    *value = result * sign;
    *cursor = p;
    return 1;
}
/* }}} */

/*
 * The value of an attribute, searched for only inside one element.
 *
 * The end of the element is passed in, and that bound is the whole safety of
 * this function: without it, an element missing an attribute quietly borrows the
 * next element's, and every layer after the missing one reads correctly while
 * being wrong.
 */
/* {{{ static int attribute_in */
static int attribute_in(const char *element, const char *element_end,
                        const char *name, char *into, uint32_t capacity)
{
    char pattern[64];
    const char *found;
    uint32_t length = 0;

    snprintf(pattern, sizeof(pattern), "%.32s=\"", name);

    found = strstr(element, pattern);
    if (found == NULL || found >= element_end) {
        return 0;
    }

    found += strlen(pattern);

    while (found < element_end && *found != '"' && length + 1u < capacity) {
        into[length] = *found;
        length++;
        found++;
    }

    into[length] = '\0';
    return 1;
}
/* }}} */

/* {{{ static int number_attribute_in */
static int number_attribute_in(const char *element, const char *element_end,
                               const char *name, int *value)
{
    char text[32];
    const char *cursor = text;

    if (!attribute_in(element, element_end, name, text, sizeof(text))) {
        return 0;
    }

    return read_number(&cursor, value);
}
/* }}} */

/* {{{ static int colour_from_text */
static int colour_from_text(const char *text, uint32_t *packed)
{
    uint32_t value = 0;
    int i;

    if (text[0] != '#') {
        return 0;
    }

    for (i = 1; i <= 6; i++) {
        char c = text[i];
        uint32_t digit;

        if (c >= '0' && c <= '9') {
            digit = (uint32_t)(c - '0');
        } else if (c >= 'A' && c <= 'F') {
            digit = (uint32_t)(c - 'A') + 10u;
        } else if (c >= 'a' && c <= 'f') {
            digit = (uint32_t)(c - 'a') + 10u;
        } else {
            return 0;
        }

        value = (value << 4) | digit;
    }

    *packed = value;
    return 1;
}
/* }}} */

/*
 * Which palette slot a colour is.
 *
 * This is the recovery that makes the reader independent. The file never says
 * "this layer uses the accent"; it says what colour the layer is, and the slot
 * is worked out by looking it up. If the writer put the wrong colour on a layer,
 * this is what notices -- a label would have agreed with the mistake.
 *
 * Returns SLOT_COUNT when the colour is in no slot, which is a genuine failure
 * to read the file rather than a layer to guess at.
 */
/* {{{ static uint8_t slot_of_colour */
static uint8_t slot_of_colour(const uint32_t *palette, uint32_t colour)
{
    uint8_t slot;

    for (slot = 0; slot < SLOT_COUNT; slot++) {
        if (palette[slot] == colour) {
            return slot;
        }
    }
    return SLOT_COUNT;
}
/* }}} */

/*
 * Recover the motion from what the animation does.
 *
 * Not from a name. An element that says type="translate" and then translates
 * along y is bobbing, whatever anybody called it, and reading it this way means
 * the test compares the picture's behaviour with the struct's intention rather
 * than comparing a string with itself.
 */
/* {{{ static uint8_t motion_from_svg */
static uint8_t motion_from_svg(const char *svg)
{
    const char *element = strstr(svg, "<animate");
    const char *element_end;
    char kind[32];
    char values[64];
    const char *cursor;
    int first_x = 0;
    int first_y = 0;
    int second_x = 0;
    int second_y = 0;

    if (element == NULL) {
        return MOTION_STILL;
    }

    element_end = strchr(element, '>');
    if (element_end == NULL) {
        return MOTION_COUNT;
    }

    /* An opacity animation is a flicker; nothing else animates opacity. */
    if (attribute_in(element, element_end, "attributeName", kind, sizeof(kind))
        && strcmp(kind, "opacity") == 0) {
        return MOTION_FLICKER;
    }

    if (!attribute_in(element, element_end, "type", kind, sizeof(kind))) {
        return MOTION_COUNT;
    }

    if (strcmp(kind, "rotate") == 0) {
        return MOTION_TURN;
    }

    if (strcmp(kind, "translate") != 0) {
        return MOTION_COUNT;
    }

    if (!attribute_in(element, element_end, "values", values, sizeof(values))) {
        return MOTION_COUNT;
    }

    /* Two keyframes are enough to say which axis it travels along. */
    cursor = values;
    if (!read_number(&cursor, &first_x) || !read_number(&cursor, &first_y)) {
        return MOTION_COUNT;
    }

    while (*cursor != '\0' && *cursor != ';') {
        cursor++;
    }
    if (*cursor == ';') {
        cursor++;
    }

    if (!read_number(&cursor, &second_x) || !read_number(&cursor, &second_y)) {
        return MOTION_COUNT;
    }

    if (second_x != first_x) {
        return MOTION_WALK;
    }
    if (second_y != first_y) {
        return MOTION_BOB;
    }

    /* It animates and goes nowhere. That is not "still" -- still has no
     * animation element at all -- it is a file we do not understand. */
    return MOTION_COUNT;
}
/* }}} */

/* {{{ static int read_one_element */
static int read_one_element(struct sprite *s, const char *element, const char *element_end)
{
    struct sprite_layer *layer = &s->layers[s->layer_count];
    char colour_text_read[32];
    uint32_t colour = 0;
    int centre_x = 0;
    int centre_y = 0;
    int radius = 0;

    if (s->layer_count >= SPRITE_MAX_LAYERS) {
        return 0;
    }

    if (strncmp(element, "<circle", 7) == 0) {
        char fill[16];

        if (!number_attribute_in(element, element_end, "cx", &centre_x)
            || !number_attribute_in(element, element_end, "cy", &centre_y)
            || !number_attribute_in(element, element_end, "r", &radius)) {
            return 0;
        }

        if (!attribute_in(element, element_end, "fill", fill, sizeof(fill))) {
            return 0;
        }

        if (strcmp(fill, "none") == 0) {
            /* Only its edge is drawn, so it is a ring, and its colour is the
             * stroke because there is nothing inside it to be coloured. */
            layer->shape = SHAPE_RING;
            if (!attribute_in(element, element_end, "stroke",
                              colour_text_read, sizeof(colour_text_read))) {
                return 0;
            }
        } else {
            layer->shape = SHAPE_CIRCLE;
            snprintf(colour_text_read, sizeof(colour_text_read), "%s", fill);
        }
    } else if (strncmp(element, "<rect", 5) == 0) {
        int corner_x = 0;
        int corner_y = 0;
        int width = 0;

        if (!number_attribute_in(element, element_end, "x", &corner_x)
            || !number_attribute_in(element, element_end, "y", &corner_y)
            || !number_attribute_in(element, element_end, "width", &width)) {
            return 0;
        }

        /* The corner and the width give back the centre and the radius, which
         * is the arithmetic the writer did, run backwards. */
        radius   = width / 2;
        centre_x = corner_x + radius;
        centre_y = corner_y + radius;

        layer->shape = SHAPE_RECT;

        if (!attribute_in(element, element_end, "fill",
                          colour_text_read, sizeof(colour_text_read))) {
            return 0;
        }
    } else if (strncmp(element, "<polygon", 8) == 0) {
        char points[128];
        const char *cursor;
        int apex_x = 0;
        int apex_y = 0;
        int left_x = 0;
        int left_y = 0;
        int right_x = 0;
        int right_y = 0;

        if (!attribute_in(element, element_end, "points", points, sizeof(points))) {
            return 0;
        }

        cursor = points;
        if (!read_number(&cursor, &apex_x)) {
            return 0;
        }
        cursor++;                       /* past the comma */
        if (!read_number(&cursor, &apex_y)) {
            return 0;
        }
        if (!read_number(&cursor, &left_x)) {
            return 0;
        }
        cursor++;
        if (!read_number(&cursor, &left_y)) {
            return 0;
        }
        if (!read_number(&cursor, &right_x)) {
            return 0;
        }
        cursor++;
        if (!read_number(&cursor, &right_y)) {
            return 0;
        }

        radius   = (right_x - left_x) / 2;
        centre_x = left_x + radius;
        centre_y = left_y - radius;

        /* The apex has to sit above the base by the same radius, or this is not
         * the triangle we draw and reading it as one would be a guess. */
        if (apex_x != centre_x || apex_y != centre_y - radius || left_y != right_y) {
            return 0;
        }

        layer->shape = SHAPE_TRIANGLE;

        if (!attribute_in(element, element_end, "fill",
                          colour_text_read, sizeof(colour_text_read))) {
            return 0;
        }
    } else {
        return 0;
    }

    if (!colour_from_text(colour_text_read, &colour)) {
        return 0;
    }

    layer->slot = slot_of_colour(s->palette, colour);
    if (layer->slot >= SLOT_COUNT) {
        return 0;
    }

    layer->offset_x = (int8_t)(centre_x - MIDDLE);
    layer->offset_y = (int8_t)(centre_y - MIDDLE);
    layer->radius   = (uint8_t)radius;

    s->layer_count++;
    return 1;
}
/* }}} */

/* {{{ int sprite_from_svg */
int sprite_from_svg(struct sprite *s, const char *svg)
{
    const char *cursor;
    const char *palette_text;
    char field[64];
    int i;

    memset(s, 0, sizeof(*s));

    /* What it is a picture of, and which seed made it. */
    cursor = after(svg, "category=\"");
    if (cursor == NULL) {
        return 0;
    }
    {
        uint32_t length = 0;

        while (cursor[length] != '"' && cursor[length] != '\0'
               && length < SPRITE_NAME_MAX) {
            s->category[length] = cursor[length];
            length++;
        }
        s->category[length] = '\0';
    }

    cursor = after(svg, "seed=\"");
    if (cursor == NULL) {
        return 0;
    }
    {
        uint64_t seed = 0;

        while (*cursor >= '0' && *cursor <= '9') {
            seed = seed * 10u + (uint64_t)(*cursor - '0');
            cursor++;
        }
        s->seed = seed;
    }

    /* The palette, which every layer's slot is then recovered against. */
    palette_text = after(svg, "palette=\"");
    if (palette_text == NULL) {
        return 0;
    }

    for (i = 0; i < (int)SLOT_COUNT; i++) {
        uint32_t length = 0;

        while (palette_text[length] != ',' && palette_text[length] != '"'
               && palette_text[length] != '\0' && length + 1u < sizeof(field)) {
            field[length] = palette_text[length];
            length++;
        }
        field[length] = '\0';

        if (!colour_from_text(field, &s->palette[i])) {
            return 0;
        }

        palette_text += length;
        if (*palette_text == ',') {
            palette_text++;
        }
    }

    /*
     * Every drawing element, in the order they are drawn, which is the order
     * they are layered. Scanning for '<' and testing each element name keeps one
     * cursor for the whole document rather than three independent searches --
     * three searches would recover every circle, then every rect, and lose the
     * layering entirely.
     */
    cursor = svg;
    s->layer_count = 0;

    while (*cursor != '\0') {
        const char *open = strchr(cursor, '<');
        const char *close;

        if (open == NULL) {
            break;
        }

        close = strchr(open, '>');
        if (close == NULL) {
            break;
        }

        if (strncmp(open, "<circle", 7) == 0
            || strncmp(open, "<rect", 5) == 0
            || strncmp(open, "<polygon", 8) == 0) {
            if (!read_one_element(s, open, close)) {
                return 0;
            }
        }

        cursor = close + 1;
    }

    if (s->layer_count == 0) {
        return 0;
    }

    s->motion = motion_from_svg(svg);
    if (s->motion >= MOTION_COUNT) {
        return 0;
    }

    return 1;
}
/* }}} */

/* ------------------------------------------------------------------------- */
/* One number standing for the whole paintbrush.                               */
/* ------------------------------------------------------------------------- */

/*
 * The witnesses: fixed words and fixed numbers, never changed.
 *
 * If this list were ever edited the fingerprint would change without the
 * paintbrush changing, and every rating in every pool would be marked stale for
 * no reason. It is frozen for the same reason a stream's name hash is frozen.
 */
static const struct {
    const char *category;
    uint64_t    seed;
} fingerprint_witnesses[] = {
    { "goblin", 1 }, { "goblin", 2 },   { "torch", 3 },  { "torch", 5 },
    { "chest",  8 }, { "wolf",   13 },  { "barrel", 21 }, { "door", 34 }
};

/* {{{ uint64_t sprite_paintbrush_fingerprint */
uint64_t sprite_paintbrush_fingerprint(void)
{
    /* FNV-1a, over the finished files rather than over the structs.
     *
     * Over the FILES, deliberately. A struct has padding whose contents depend
     * on the compiler, and hashing it would make the same paintbrush fingerprint
     * differently on two machines -- so a pool copied between them would report
     * every entry as stale. The text is the text everywhere. It also means the
     * encoder is inside the fingerprint, which is right: a changed encoder makes
     * a changed picture just as surely as a changed generator does. */
    uint64_t hash = 14695981039346656037u;
    uint32_t which;

    for (which = 0; which < sizeof(fingerprint_witnesses) / sizeof(fingerprint_witnesses[0]);
         which++) {
        struct sprite s;
        char svg[4096];
        uint32_t length;
        uint32_t i;

        sprite_make(&s, fingerprint_witnesses[which].category,
                    fingerprint_witnesses[which].seed);

        length = sprite_to_svg(&s, svg, sizeof(svg));

        for (i = 0; i < length; i++) {
            hash ^= (uint64_t)(unsigned char)svg[i];
            hash *= 1099511628211u;
        }
    }

    return hash;
}
/* }}} */

/* ------------------------------------------------------------------------- */
/* The machine grader, which is a heuristic and says so.                       */
/* ------------------------------------------------------------------------- */

/*
 * What the heuristic weighs, kept as one table so that a demo can print the
 * breakdown and a person can argue with a specific number rather than with the
 * whole idea. Five components, a hundred points between them.
 */
#define GRADE_LAYERS_MAX   24
#define GRADE_MOTION_MAX   20
#define GRADE_PALETTE_MAX  30
#define GRADE_FILL_MAX     14
#define GRADE_BALANCE_MAX  12

/* {{{ static uint32_t absolute_difference */
static uint32_t absolute_difference(uint32_t a, uint32_t b)
{
    if (a > b) {
        return a - b;
    }
    return b - a;
}
/* }}} */

/*
 * How far apart two packed colours are, adding up the three channels. Zero is
 * identical, 765 is black against white. A crude measure of difference and an
 * honest one -- it has no opinion about hue, which is one of several reasons
 * this grader is a proxy for taste and not taste.
 */
/* {{{ static uint32_t colour_distance */
static uint32_t colour_distance(uint32_t a, uint32_t b)
{
    return absolute_difference((a >> 16) & 0xFFu, (b >> 16) & 0xFFu)
         + absolute_difference((a >> 8) & 0xFFu, (b >> 8) & 0xFFu)
         + absolute_difference(a & 0xFFu, b & 0xFFu);
}
/* }}} */

/* {{{ static uint32_t grade_layers */
static uint32_t grade_layers(const struct sprite *s)
{
    /* Peaks at four. One layer is a blob; six is a pile. A table rather than a
     * formula because the shape of this opinion is not a curve, it is five
     * separate judgements. */
    static const uint32_t by_count[SPRITE_MAX_LAYERS + 1] = {
        0, 5, 13, 20, GRADE_LAYERS_MAX, 22, 17
    };

    if (s->layer_count > SPRITE_MAX_LAYERS) {
        return 0;
    }
    return by_count[s->layer_count];
}
/* }}} */

/* {{{ static uint32_t grade_motion */
static uint32_t grade_motion(const struct sprite *s)
{
    /* The vision asked for something more like a video game than a picture, so
     * a sprite that moves is worth more here than one that does not. This is
     * the component most obviously an opinion, and it is the project's. */
    if (s->motion == MOTION_STILL) {
        return 4;
    }
    return GRADE_MOTION_MAX;
}
/* }}} */

/* {{{ static uint32_t grade_palette */
static uint32_t grade_palette(const struct sprite *s)
{
    uint32_t near = colour_distance(s->palette[SLOT_PRIMARY], s->palette[SLOT_SECONDARY]);
    uint32_t far  = colour_distance(s->palette[SLOT_PRIMARY], s->palette[SLOT_ACCENT]);
    uint32_t score = 0;

    /*
     * A palette that holds together has a secondary near the primary and an
     * accent away from it. Both halves matter: three colours all alike is
     * washed out, and three colours all different is noise.
     */
    if (near < 220u) {
        score += 15u - (near / 20u);
    }

    if (far > 180u) {
        uint32_t reach = far - 180u;

        if (reach > 150u) {
            reach = 150u;
        }
        score += (reach * 15u) / 150u;
    }

    if (score > GRADE_PALETTE_MAX) {
        score = GRADE_PALETTE_MAX;
    }
    return score;
}
/* }}} */

/* {{{ static uint32_t grade_fill */
static uint32_t grade_fill(const struct sprite *s)
{
    uint32_t widest = 0;
    uint32_t i;

    for (i = 0; i < s->layer_count; i++) {
        if (s->layers[i].radius > widest) {
            widest = s->layers[i].radius;
        }
    }

    /* A sprite that fills a third of its box reads at a distance. Smaller
     * disappears on the map; larger touches the edges and stops looking like a
     * thing standing somewhere. */
    if (widest >= 28u && widest <= 40u) {
        return GRADE_FILL_MAX;
    }
    if (widest >= 20u && widest <= 46u) {
        return GRADE_FILL_MAX / 2u;
    }
    return 0;
}
/* }}} */

/* {{{ static uint32_t grade_balance */
static uint32_t grade_balance(const struct sprite *s)
{
    int sum_x = 0;
    int sum_y = 0;
    uint32_t drift;
    uint32_t i;

    for (i = 0; i < s->layer_count; i++) {
        sum_x += s->layers[i].offset_x;
        sum_y += s->layers[i].offset_y;
    }

    /* Where the detail sits on average. Near the middle is a creature; far off
     * to one side is a creature and a smudge. */
    drift = (uint32_t)((sum_x < 0 ? -sum_x : sum_x) + (sum_y < 0 ? -sum_y : sum_y));

    if (drift >= 48u) {
        return 0;
    }
    return GRADE_BALANCE_MAX - ((drift * GRADE_BALANCE_MAX) / 48u);
}
/* }}} */

/* {{{ static uint32_t grade_total */
static uint32_t grade_total(const struct sprite *s)
{
    return grade_layers(s) + grade_motion(s) + grade_palette(s)
         + grade_fill(s) + grade_balance(s);
}
/* }}} */

/* {{{ uint32_t sprite_machine_score */
uint32_t sprite_machine_score(const struct sprite *s)
{
    return grade_total(s);
}
/* }}} */

/* {{{ uint8_t sprite_machine_tier */
uint8_t sprite_machine_tier(const struct sprite *s)
{
    uint32_t score = grade_total(s);

    /*
     * The cut lines, and where they came from.
     *
     * THESE ARE MEASURED, NOT CHOSEN. The first set was four round numbers that
     * looked reasonable, and against the real output of the generator they put
     * ninety per cent of every sprite into two tiers and left tier one entirely
     * empty. A five-point scale that is really a three-point scale is worse than
     * a three-point scale, because the two dead numbers look like information.
     *
     * So 084-calibrate was written, it histogrammed thirty-two thousand
     * generated sprites, and these four numbers are the tenth, thirtieth,
     * seventieth and ninetieth percentiles of that distribution. The tiers come
     * out near 10 / 20 / 40 / 20 / 10.
     *
     * AND IT HAS ALREADY EARNED ITS KEEP ONCE. Detail layers were changed to
     * come in mirrored pairs, which made the sprites read as creatures instead
     * of as piles -- and moved every one of these four lines by two points. The
     * tool said so; nothing else would have.
     *
     * WHAT THAT MAKES A TIER MEAN: a ranking, not a verdict. Tier five is "in
     * the best tenth of what this paintbrush produces", not "good". That is the
     * right meaning for the quality dial, whose job is to hand back the better
     * ones, and it is worth being clear-eyed that it is not the other meaning.
     *
     * WHAT IT LEAVES OPEN: these numbers are frozen and the distribution is not.
     * Add a shape to the paintbrush and every tier silently re-means itself.
     * That is why the calibration tool is a program that ships rather than a
     * script somebody ran once -- run it after changing the generator, and if
     * the percentages have moved, these four numbers are stale. Open question
     * 15.1 is where that is written down.
     */
    uint8_t tier;

    /* Downwards, so the first line the score clears is the tier it is. */
    for (tier = 5; tier >= 2; tier--) {
        if (score >= sprite_machine_cut(tier)) {
            return tier;
        }
    }
    return 1;
}
/* }}} */

/* {{{ uint32_t sprite_machine_cut */
uint32_t sprite_machine_cut(uint8_t tier)
{
    /*
     * The tenth, thirtieth, seventieth and ninetieth percentiles, measured. See
     * the long note in sprite_machine_tier for where they came from and what
     * they leave open. Tier one has no line: it is everything below tier two.
     */
    static const uint32_t lowest_score[6] = { 0u, 0u, 51u, 61u, 71u, 77u };

    if (tier < 1u || tier > 5u) {
        return 0u;
    }
    return lowest_score[tier];
}
/* }}} */

/* {{{ const char *sprite_machine_reasoning */
const char *sprite_machine_reasoning(const struct sprite *s, char *into, uint32_t capacity)
{
    snprintf(into, capacity,
             "%u layers %u/%u, %s %u/%u, palette %u/%u, size %u/%u, balance %u/%u"
             " = %u of 100, tier %u (heuristic)",
             (unsigned)s->layer_count, (unsigned)grade_layers(s), (unsigned)GRADE_LAYERS_MAX,
             motion_name(s->motion), (unsigned)grade_motion(s), (unsigned)GRADE_MOTION_MAX,
             (unsigned)grade_palette(s), (unsigned)GRADE_PALETTE_MAX,
             (unsigned)grade_fill(s), (unsigned)GRADE_FILL_MAX,
             (unsigned)grade_balance(s), (unsigned)GRADE_BALANCE_MAX,
             (unsigned)grade_total(s), (unsigned)sprite_machine_tier(s));

    return into;
}
/* }}} */
