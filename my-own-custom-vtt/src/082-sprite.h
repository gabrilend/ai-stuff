/*
 * 082-sprite.h -- one animated SVG, and the closed set of moves that make it.
 *
 * The renderer draws things from a described appearance rather than a picture
 * file. This is where a description becomes something to draw.
 *
 * WHY SVG, AND WHY ANIMATED
 *
 *   It is not a .png, which is the vision's requirement stated as a format.
 *   It is watchable as it stands -- open it and the goblin walks. A rater shown
 *     a still frame of an animation is rating an illustration, and a project
 *     about motion cannot be judged by somebody blind to motion.
 *   It is text, so it diffs, and the encoder is string-writing rather than a
 *     compression format. Nothing is borrowed to produce it.
 *   The renderer can transform it -- scale, tint, recolour a layer -- because
 *     vector parts survive that and a raster sprite does not.
 *
 * THE PAINTBRUSH IS CLOSED. A description may use the words below and no others.
 * Handed a complete reference, anything generating descriptions will invent
 * plausible neighbouring words that do not exist, confidently and in good style.
 * A short allowlist has nowhere for the analogy to go.
 *
 * See docs/017-the-sprite-studio.md and issues 901 through 905.
 */

#ifndef VTT_SPRITE_H
#define VTT_SPRITE_H

#include <stdint.h>

/* The shapes a layer may be. Extracted from what the renderer can draw. */
#define SHAPE_CIRCLE    0u
#define SHAPE_RECT      1u
#define SHAPE_TRIANGLE  2u
#define SHAPE_RING      3u
#define SHAPE_COUNT     4u

/* Which palette slot a layer tints from. */
#define SLOT_PRIMARY    0u
#define SLOT_SECONDARY  1u
#define SLOT_ACCENT     2u
#define SLOT_COUNT      3u

/* What the whole sprite does. The renderer drives these by name. */
#define MOTION_STILL    0u
#define MOTION_BOB      1u
#define MOTION_WALK     2u
#define MOTION_FLICKER  3u
#define MOTION_TURN     4u
#define MOTION_COUNT    5u

#define SPRITE_MAX_LAYERS 6
#define SPRITE_NAME_MAX   31

struct sprite_layer {
    uint8_t shape;
    uint8_t slot;
    int8_t  offset_x;    /* Hundredths of the viewbox, from the middle. */
    int8_t  offset_y;
    uint8_t radius;      /* Hundredths of the viewbox. */
};

struct sprite {
    char     category[SPRITE_NAME_MAX + 1];
    uint64_t seed;

    struct sprite_layer layers[SPRITE_MAX_LAYERS];
    uint8_t             layer_count;

    uint32_t palette[SLOT_COUNT];   /* Packed 0xRRGGBB. */
    uint8_t  motion;
};

/*
 * Make one, deterministically, from a category and a seed.
 *
 * THE SAME DESCRIPTION GIVES BYTE-IDENTICAL OUTPUT. That is what lets a test
 * assert on bytes rather than on somebody squinting, and what makes every rating
 * in the pool reproducible rather than a memory.
 *
 * NOTE WHAT IS NOT AN ARGUMENT: the session's stream registry.
 *
 * Every other draw of randomness in this project comes from a named stream owned
 * by the session, and that is right for them, because a wandering monster ought
 * to depend on everything that wandered before it. A sprite must not. A stream
 * carries a POSITION, so a sprite drawn from one would depend on how many
 * sprites were drawn earlier -- and then "goblin, seed 7" would mean one picture
 * on Tuesday and a different picture on Wednesday, and every rating anybody had
 * written down would be pointing at a picture that no longer exists.
 *
 * So this makes its own registry, seeded from the seed, and names a stream after
 * the category. The named-stream discipline is kept; the position is not.
 */
void sprite_make(struct sprite *s, const char *category, uint64_t seed);

/*
 * Write it as SVG into a caller's buffer. Returns the length written, or 0 if it
 * would not fit.
 *
 * The encoder is ours rather than borrowed. Writing SVG is writing strings, and
 * a borrowed encoder would be a dependency to install on every machine for a
 * format that is text -- and would convert our errors into somebody else's
 * silence.
 */
uint32_t sprite_to_svg(const struct sprite *s, char *into, uint32_t capacity);

/*
 * Read one back from SVG, well enough to compare.
 *
 * AN INDEPENDENT READER, deliberately not sharing code with the writer. Two
 * independent readers is proof; one is an opinion -- and an encoder that is
 * confidently wrong produces a file that mostly works, which only a reader
 * notices.
 */
int sprite_from_svg(struct sprite *s, const char *svg);

/* The names, for the paintbrush's document half and for a demo. */
const char *shape_name(uint8_t shape);
const char *slot_name(uint8_t slot);
const char *motion_name(uint8_t motion);

/*
 * The same three tables read the other way -- a word in, a value out.
 *
 * An unknown word returns the COUNT for its kind, which is not a legal value and
 * so cannot be quietly drawn. A caller must name what it could not understand.
 * There is no "and otherwise a circle": a paintbrush that substitutes when it
 * does not recognise a word is not closed, it is merely quiet.
 */
uint8_t shape_from_word(const char *word);
uint8_t slot_from_word(const char *word);
uint8_t motion_from_word(const char *word);

/*
 * Every word the paintbrush knows, in one flat list.
 *
 * ONE TABLE, TWO HALVES. The wall checks against this and the documentation is
 * printed from it, so the contract and the enforcement cannot drift apart -- the
 * usual way a closed vocabulary stops being closed is that somebody adds a word
 * to the code and the document goes on describing last month's paintbrush.
 */
const char *const *sprite_vocabulary(uint32_t *count);

/*
 * The legal word closest to a given one, or NULL when nothing is close.
 *
 * The vocabulary being SMALL is what makes this meaningful. Across ten thousand
 * words the nearest is noise; across fourteen it is almost always the thing that
 * was meant.
 */
const char *sprite_nearest_word(const char *given);

/*
 * A tier from 1 to 5, judged by machine.
 *
 * A HEURISTIC, and it is called one everywhere it appears. It weighs a handful
 * of measurable properties -- layer count, palette coherence, whether it moves,
 * how much of the viewbox it fills -- and that is a proxy for taste, and a crude
 * one.
 *
 * Saying so matters, because the whole apparatus around it exists to measure how
 * far the machine's taste has drifted from a person's, and a grader that is
 * really a complexity metric will drift somewhere nobody predicted.
 */
uint8_t sprite_machine_tier(const struct sprite *s);

/*
 * The raw score behind the tier, from 0 to 100.
 *
 * Public because the tier's cut lines are a CALIBRATION against a real
 * distribution, not four numbers somebody liked the look of. Somebody has to be
 * able to histogram the pool and see whether the five tiers are five tiers or
 * three tiers and two empty ones -- and later, whether the machine's scores and
 * a person's ratings still point the same way.
 */
uint32_t sprite_machine_score(const struct sprite *s);

/*
 * The lowest score that still counts as a given tier, 1 to 5.
 *
 * One place holds these four numbers, so that the calibration tool can print
 * the line it is checking beside the percentile it measured. A tool that
 * reprinted the numbers from its own copy would agree with itself forever.
 */
uint32_t sprite_machine_cut(uint8_t tier);

/* What the heuristic actually looked at, for a demo that refuses to be vague. */
const char *sprite_machine_reasoning(const struct sprite *s,
                                     char *into, uint32_t capacity);

#endif
