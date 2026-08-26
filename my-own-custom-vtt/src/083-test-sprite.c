/*
 * 083-test-sprite.c -- can the picture be read back, and does it say the same
 * thing?
 *
 * The centre of this file is one loop that makes several thousand sprites,
 * writes each as SVG, reads each back with the independent reader, and compares
 * every field. That is the whole argument for the format: a writer alone can be
 * confidently wrong and produce a file that mostly works, and only a reader
 * notices.
 *
 * The other tests are about the two properties that everything downstream leans
 * on. That the same category and seed give byte-identical output, because every
 * rating in the pool is a rating of a specific picture and would be pointing at
 * nothing otherwise. And that the machine grader actually discriminates -- a
 * heuristic that gives everything a three is not a lenient judge, it is a
 * constant function wearing a judge's clothes.
 */

#include "020-test-harness.h"
#include "082-sprite.h"

#include <string.h>

/*
 * Big enough for six layers, the description line, and an animation. A sprite
 * that does not fit is a failure to be seen rather than a picture to be cut
 * short, so the buffer is generous and the encoder refuses rather than truncates.
 */
#define SVG_BUFFER 4096

/* {{{ static int layers_match */
static int layers_match(const struct sprite_layer *a, const struct sprite_layer *b)
{
    return a->shape == b->shape
        && a->slot == b->slot
        && a->offset_x == b->offset_x
        && a->offset_y == b->offset_y
        && a->radius == b->radius;
}
/* }}} */

/*
 * The round trip, across enough seeds that every branch of the generator and
 * every branch of the reader is exercised many times.
 *
 * THREE THOUSAND rather than three. Every shape, every palette scheme, every
 * motion, at every layer count, with offsets that go negative and radii that
 * push a triangle's apex above the top of the viewbox -- none of that is reached
 * by a handful of hand-picked cases, and all of it is where a reader breaks.
 */
/* {{{ static void test_the_round_trip */
static void test_the_round_trip(void)
{
    static const char *const categories[] = {
        "goblin", "torch", "chest", "wolf", "innkeeper", "barrel"
    };
    char svg[SVG_BUFFER];
    uint64_t seed;
    uint32_t which;

    TEST_CASE("what was written is what is read back");

    for (seed = 1; seed <= 500; seed++) {
        for (which = 0; which < 6; which++) {
            struct sprite made;
            struct sprite read_back;
            uint32_t length;
            uint32_t layer;

            sprite_make(&made, categories[which], seed);

            length = sprite_to_svg(&made, svg, sizeof(svg));
            if (length == 0) {
                CHECK(length != 0);
                continue;
            }

            if (!sprite_from_svg(&read_back, svg)) {
                /* Print the file, because a reader that refused is a file
                 * somebody has to look at, and "the reader returned zero" ends
                 * no investigation. */
                fprintf(stderr, "    could not read back %s seed %llu:\n%s\n",
                        categories[which], (unsigned long long)seed, svg);
                CHECK(0);
                continue;
            }

            CHECK(strcmp(read_back.category, made.category) == 0);
            CHECK_EQ(read_back.seed, made.seed);
            CHECK_EQ(read_back.motion, made.motion);
            CHECK_EQ(read_back.layer_count, made.layer_count);

            CHECK_EQ(read_back.palette[SLOT_PRIMARY], made.palette[SLOT_PRIMARY]);
            CHECK_EQ(read_back.palette[SLOT_SECONDARY], made.palette[SLOT_SECONDARY]);
            CHECK_EQ(read_back.palette[SLOT_ACCENT], made.palette[SLOT_ACCENT]);

            for (layer = 0; layer < made.layer_count; layer++) {
                if (!layers_match(&made.layers[layer], &read_back.layers[layer])) {
                    fprintf(stderr,
                            "    layer %u of %s seed %llu differs:"
                            " wrote %s/%s at %d,%d r%u, read %s/%s at %d,%d r%u\n",
                            (unsigned)layer, categories[which],
                            (unsigned long long)seed,
                            shape_name(made.layers[layer].shape),
                            slot_name(made.layers[layer].slot),
                            (int)made.layers[layer].offset_x,
                            (int)made.layers[layer].offset_y,
                            (unsigned)made.layers[layer].radius,
                            shape_name(read_back.layers[layer].shape),
                            slot_name(read_back.layers[layer].slot),
                            (int)read_back.layers[layer].offset_x,
                            (int)read_back.layers[layer].offset_y,
                            (unsigned)read_back.layers[layer].radius);
                }
                CHECK(layers_match(&made.layers[layer], &read_back.layers[layer]));
            }
        }
    }
}
/* }}} */

/*
 * Every slot a different colour, on every seed.
 *
 * This is not decoration. The reader works out which slot a layer draws from by
 * matching the fill against the palette, so two slots holding one colour would
 * make that match ambiguous -- and it would fail on some seeds and not others,
 * which is a bug that arrives months later looking like a mystery.
 */
/* {{{ static void test_the_palette_slots_are_distinct */
static void test_the_palette_slots_are_distinct(void)
{
    uint64_t seed;

    TEST_CASE("no two palette slots ever hold the same colour");

    for (seed = 1; seed <= 2000; seed++) {
        struct sprite s;

        sprite_make(&s, "goblin", seed);

        CHECK(s.palette[SLOT_PRIMARY] != s.palette[SLOT_SECONDARY]);
        CHECK(s.palette[SLOT_PRIMARY] != s.palette[SLOT_ACCENT]);
        CHECK(s.palette[SLOT_SECONDARY] != s.palette[SLOT_ACCENT]);
    }
}
/* }}} */

/*
 * The same word and the same number give the same bytes -- now, and after a
 * hundred other sprites have been made in between.
 *
 * The second half is the point. A generator drawing from a shared, positioned
 * stream would pass the first check and fail this one, and the failure would
 * look like corruption rather than like a design mistake.
 */
/* {{{ static void test_the_same_description */
static void test_the_same_description(void)
{
    struct sprite first;
    struct sprite again;
    char svg_first[SVG_BUFFER];
    char svg_again[SVG_BUFFER];
    uint32_t i;

    TEST_CASE("the same category and seed give the same bytes");

    sprite_make(&first, "goblin", 4242);
    CHECK(sprite_to_svg(&first, svg_first, sizeof(svg_first)) > 0);

    for (i = 0; i < 100; i++) {
        struct sprite distraction;

        sprite_make(&distraction, "wolf", i);
    }

    sprite_make(&again, "goblin", 4242);
    CHECK(sprite_to_svg(&again, svg_again, sizeof(svg_again)) > 0);

    CHECK(strcmp(svg_first, svg_again) == 0);
    CHECK(memcmp(&first, &again, sizeof(struct sprite)) == 0);
}
/* }}} */

/*
 * A different word means a different picture, and a different number means a
 * different picture.
 *
 * Without this, a generator that ignored its arguments entirely would pass every
 * other test in this file with flying colours.
 */
/* {{{ static void test_different_descriptions_differ */
static void test_different_descriptions_differ(void)
{
    struct sprite goblin;
    struct sprite wolf;
    struct sprite goblin_later;

    TEST_CASE("the category and the seed both matter");

    sprite_make(&goblin, "goblin", 7);
    sprite_make(&wolf, "wolf", 7);
    sprite_make(&goblin_later, "goblin", 8);

    CHECK(memcmp(&goblin, &wolf, sizeof(struct sprite)) != 0);
    CHECK(memcmp(&goblin, &goblin_later, sizeof(struct sprite)) != 0);
}
/* }}} */

/*
 * The encoder refuses a buffer it cannot fill rather than writing part of a
 * picture.
 *
 * Half an SVG is not a smaller sprite. It is a file that no reader can open, and
 * the failure has to be at the call that asked for too little room.
 */
/* {{{ static void test_a_buffer_too_small */
static void test_a_buffer_too_small(void)
{
    struct sprite s;
    char tiny[40];

    TEST_CASE("a buffer too small is refused, not half-filled");

    sprite_make(&s, "goblin", 1);

    CHECK_EQ(sprite_to_svg(&s, tiny, sizeof(tiny)), 0);

    /* And nothing readable was left behind pretending to be a sprite. */
    {
        struct sprite recovered;

        CHECK_EQ(sprite_from_svg(&recovered, tiny), 0);
    }
}
/* }}} */

/*
 * Rubbish in is refused, and refused by saying so rather than by producing a
 * default sprite.
 */
/* {{{ static void test_what_is_not_a_sprite */
static void test_what_is_not_a_sprite(void)
{
    struct sprite s;

    TEST_CASE("things that are not sprites are refused");

    CHECK_EQ(sprite_from_svg(&s, ""), 0);
    CHECK_EQ(sprite_from_svg(&s, "<svg></svg>"), 0);

    /* A description line and no drawing: nothing to look at. */
    CHECK_EQ(sprite_from_svg(&s,
        "<svg><desc>vtt-sprite category=\"x\" seed=\"1\""
        " palette=\"#000000,#111111,#222222\"</desc><g></g></svg>"), 0);

    /* A drawing whose colour is in no palette slot. The reader cannot say which
     * slot the layer draws from, so it says nothing rather than guessing. */
    CHECK_EQ(sprite_from_svg(&s,
        "<svg><desc>vtt-sprite category=\"x\" seed=\"1\""
        " palette=\"#000000,#111111,#222222\"</desc>"
        "<g><circle cx=\"50\" cy=\"50\" r=\"30\" fill=\"#ABCDEF\"/></g></svg>"), 0);
}
/* }}} */

/*
 * The paintbrush refuses a word it does not know, and offers the one that was
 * probably meant.
 *
 * The suggestion is only worth having because the vocabulary is twelve words
 * long. Across a thousand words the nearest is noise and a wrong suggestion
 * sends somebody to check a word they never typed.
 */
/* {{{ static void test_the_closed_vocabulary */
static void test_the_closed_vocabulary(void)
{
    uint32_t count = 0;
    const char *const *words = sprite_vocabulary(&count);
    uint32_t i;

    TEST_CASE("a word the renderer cannot draw is refused");

    CHECK_EQ(count, SHAPE_COUNT + SLOT_COUNT + MOTION_COUNT);

    /* Every listed word is a word one of the three tables actually knows. The
     * flat list and the three tables are the contract and the enforcement, and
     * this is the check that they have not drifted apart. */
    for (i = 0; i < count; i++) {
        int known = (shape_from_word(words[i]) < SHAPE_COUNT)
                  + (slot_from_word(words[i]) < SLOT_COUNT)
                  + (motion_from_word(words[i]) < MOTION_COUNT);

        CHECK_EQ(known, 1);
    }

    /* Words the renderer cannot draw. Each is plausible, which is the point --
     * "ellipse" and "hexagon" are what something generating descriptions
     * invents when handed a shape vocabulary. */
    CHECK_EQ(shape_from_word("ellipse"), SHAPE_COUNT);
    CHECK_EQ(shape_from_word("hexagon"), SHAPE_COUNT);
    CHECK_EQ(shape_from_word("Circle"), SHAPE_COUNT);
    CHECK_EQ(slot_from_word("tertiary"), SLOT_COUNT);
    CHECK_EQ(motion_from_word("idle"), MOTION_COUNT);

    /* And the names come back out the way they went in. */
    CHECK(strcmp(shape_name(SHAPE_TRIANGLE), "triangle") == 0);
    CHECK(strcmp(slot_name(SLOT_ACCENT), "accent") == 0);
    CHECK(strcmp(motion_name(MOTION_FLICKER), "flicker") == 0);

    /* Out of range says so rather than returning the first entry. */
    CHECK(strcmp(shape_name(SHAPE_COUNT), "circle") != 0);
    CHECK(strcmp(motion_name(200), "still") != 0);
}
/* }}} */

/* {{{ static void test_the_nearest_word */
static void test_the_nearest_word(void)
{
    TEST_CASE("a misspelling is met with the word that was meant");

    CHECK(strcmp(sprite_nearest_word("circel"), "circle") == 0);
    CHECK(strcmp(sprite_nearest_word("trianlge"), "triangle") == 0);
    CHECK(strcmp(sprite_nearest_word("flikcer"), "flicker") == 0);
    CHECK(strcmp(sprite_nearest_word("secondry"), "secondary") == 0);

    /* Nothing close means nothing offered. A confident wrong suggestion costs
     * more than silence. */
    CHECK(sprite_nearest_word("aardvark") == NULL);
    CHECK(sprite_nearest_word("") == NULL);
}
/* }}} */

/*
 * The heuristic has to actually separate sprites, and it has to be stable.
 *
 * A grader that returns three for everything would pass a test that only checks
 * the range. What is checked here is that all five tiers get used across a
 * sweep, that no tier swallows the whole pool, and that the same sprite is
 * always graded the same.
 */
/* {{{ static void test_the_machine_grader_discriminates */
static void test_the_machine_grader_discriminates(void)
{
    uint32_t seen[6];
    uint64_t seed;
    uint32_t tier;
    uint32_t total = 0;

    TEST_CASE("the heuristic separates sprites instead of agreeing with itself");

    memset(seen, 0, sizeof(seen));

    for (seed = 1; seed <= 2000; seed++) {
        struct sprite s;
        uint8_t judged;

        sprite_make(&s, "goblin", seed);
        judged = sprite_machine_tier(&s);

        CHECK(judged >= 1 && judged <= 5);
        seen[judged]++;
        total++;

        /* Same sprite, same answer, every time it is asked. */
        CHECK_EQ(sprite_machine_tier(&s), judged);
    }

    /* Every tier is reachable. A tier nothing ever lands in is a tier that does
     * not exist, and a five-point scale that is really a three-point scale is
     * worse than a three-point scale, because the two dead numbers look like
     * information. */
    for (tier = 1; tier <= 5; tier++) {
        if (seen[tier] == 0) {
            fprintf(stderr, "    no sprite in 2000 was graded tier %u\n",
                    (unsigned)tier);
        }
        CHECK(seen[tier] > 0);
    }

    /* And no single tier swallows the pool. Nine in ten landing in one bucket
     * is a constant function with a rounding error. */
    for (tier = 1; tier <= 5; tier++) {
        CHECK(seen[tier] * 10u < total * 9u);
    }
}
/* }}} */

/*
 * The grader's opinions are the ones it claims to have.
 *
 * Built by hand rather than drawn, so that each check isolates one component.
 * If the palette component stops working, this says so; the sweep above would
 * only say that the distribution shifted.
 */
/* {{{ static void test_what_the_heuristic_weighs */
static void test_what_the_heuristic_weighs(void)
{
    struct sprite moving;
    struct sprite still;
    char reasoning[256];

    TEST_CASE("motion is worth more than stillness, and the grader says why");

    memset(&moving, 0, sizeof(moving));
    snprintf(moving.category, sizeof(moving.category), "%s", "bench");
    moving.layer_count = 4;
    moving.layers[0].shape = SHAPE_CIRCLE;
    moving.layers[0].slot = SLOT_PRIMARY;
    moving.layers[0].radius = 32;
    moving.layers[1].shape = SHAPE_RECT;
    moving.layers[1].slot = SLOT_SECONDARY;
    moving.layers[1].radius = 10;
    moving.layers[2].shape = SHAPE_RING;
    moving.layers[2].slot = SLOT_ACCENT;
    moving.layers[2].radius = 8;
    moving.layers[3].shape = SHAPE_TRIANGLE;
    moving.layers[3].slot = SLOT_SECONDARY;
    moving.layers[3].radius = 6;
    moving.palette[SLOT_PRIMARY]   = 0x406030;
    moving.palette[SLOT_SECONDARY] = 0x283c1d;
    moving.palette[SLOT_ACCENT]    = 0xC03020;
    moving.motion = MOTION_WALK;

    still = moving;
    still.motion = MOTION_STILL;

    CHECK(sprite_machine_tier(&moving) > sprite_machine_tier(&still));

    /* The reasoning names the components rather than announcing a number, and
     * it says out loud that it is a heuristic -- which is the whole point of
     * having it, since the apparatus around it exists to measure how far this
     * opinion has drifted from a person's. */
    sprite_machine_reasoning(&moving, reasoning, sizeof(reasoning));
    CHECK(strstr(reasoning, "heuristic") != NULL);
    CHECK(strstr(reasoning, "palette") != NULL);
    CHECK(strstr(reasoning, "upright") != NULL);
    CHECK(strstr(reasoning, "walk") != NULL);

    TEST_CASE("a palette that holds together beats one that does not");
    {
        struct sprite coherent = moving;
        struct sprite noisy = moving;

        /* Secondary near the primary, accent far from it. */
        coherent.palette[SLOT_PRIMARY]   = 0x406030;
        coherent.palette[SLOT_SECONDARY] = 0x364e29;
        coherent.palette[SLOT_ACCENT]    = 0xD02010;

        /* Three unrelated colours, all far from each other. */
        noisy.palette[SLOT_PRIMARY]   = 0x30A0F0;
        noisy.palette[SLOT_SECONDARY] = 0xF0C020;
        noisy.palette[SLOT_ACCENT]    = 0x209030;

        CHECK(sprite_machine_tier(&coherent) >= sprite_machine_tier(&noisy));
    }

    TEST_CASE("a sprite too small to read scores below one that fills its box");
    {
        struct sprite readable = moving;
        struct sprite speck = moving;
        uint32_t i;

        for (i = 0; i < speck.layer_count; i++) {
            speck.layers[i].radius = 4;
        }

        CHECK(sprite_machine_tier(&readable) > sprite_machine_tier(&speck));
    }
}
/* }}} */

/*
 * Every motion survives the trip, including the one that is the absence of one.
 *
 * "Still" is written as no animation element at all, and read back as the
 * absence of one. That asymmetry is worth a test of its own: it is the one case
 * where the file says something by not saying anything.
 */
/* {{{ static void test_every_motion_survives */
static void test_every_motion_survives(void)
{
    char svg[SVG_BUFFER];
    uint8_t motion;

    TEST_CASE("each motion is recovered from what it does, not from a label");

    for (motion = 0; motion < MOTION_COUNT; motion++) {
        struct sprite s;
        struct sprite read_back;

        sprite_make(&s, "torch", 11);
        s.motion = motion;

        CHECK(sprite_to_svg(&s, svg, sizeof(svg)) > 0);
        CHECK_EQ(sprite_from_svg(&read_back, svg), 1);
        CHECK_EQ(read_back.motion, motion);

        /* A still sprite carries no animation element whatsoever. */
        if (motion == MOTION_STILL) {
            CHECK(strstr(svg, "<animate") == NULL);
        } else {
            CHECK(strstr(svg, "<animate") != NULL);
        }
    }
}
/* }}} */

/*
 * The file is an SVG that something other than this project would open.
 *
 * Not a full parse -- that would be borrowing a parser to test a writer, which
 * is the dependency the project declined. What is checked is the handful of
 * things whose absence makes a browser show nothing at all: the namespace, the
 * viewbox, balanced angle brackets, and a root element that closes.
 */
/* {{{ static void test_it_is_an_svg */
static void test_it_is_an_svg(void)
{
    struct sprite s;
    char svg[SVG_BUFFER];
    uint32_t length;
    uint32_t i;
    uint32_t opens = 0;
    uint32_t closes = 0;

    TEST_CASE("the file is something a browser would open");

    sprite_make(&s, "innkeeper", 99);
    length = sprite_to_svg(&s, svg, sizeof(svg));
    CHECK(length > 0);

    CHECK(strstr(svg, "xmlns=\"http://www.w3.org/2000/svg\"") != NULL);
    CHECK(strstr(svg, "viewBox=\"0 0 100 100\"") != NULL);
    CHECK(strstr(svg, "</svg>") != NULL);
    CHECK(strncmp(svg, "<svg", 4) == 0);

    for (i = 0; i < length; i++) {
        if (svg[i] == '<') {
            opens++;
        }
        if (svg[i] == '>') {
            closes++;
        }
    }
    CHECK_EQ(opens, closes);

    /* The reported length is the string's length, so a caller can write exactly
     * that many bytes to a file and not carry a stray zero into it. */
    CHECK_EQ(strlen(svg), length);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_the_round_trip();
    test_the_palette_slots_are_distinct();
    test_the_same_description();
    test_different_descriptions_differ();
    test_a_buffer_too_small();
    test_what_is_not_a_sprite();
    test_the_closed_vocabulary();
    test_the_nearest_word();
    test_the_machine_grader_discriminates();
    test_what_the_heuristic_weighs();
    test_every_motion_survives();
    test_it_is_an_svg();

    return vtt_test_finish("083-test-sprite");
}
/* }}} */
