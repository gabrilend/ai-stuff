/*
 * 098-test-engraving.c -- can the picture be read, and is it the same picture?
 *
 * The round trip has two halves and the second is the one that matters.
 *
 * Write values, read them back, compare the values. That catches a writer
 * drawing a number in the wrong place.
 *
 * Then write AGAIN from what was read, and compare the two files byte for byte.
 * That catches a reader recovering a value by accident -- from the header, from
 * a default, from the wrong chamber. A reader that guessed right once will guess
 * the same way twice, and only the bytes notice.
 *
 * The rest of this file is the fragility, tested rather than asserted. A format
 * that claims to refuse a hand-edit and quietly absorbs one is worse than a
 * tolerant format, because everybody has been told to trust it.
 */

#include "020-test-harness.h"
#include "096-engrave.h"
#include "097-read-engraving.h"
#include "094-creature.h"

#include <stdio.h>
#include <string.h>

/* {{{ static void some_record */
static void some_record(struct record *r, uint64_t seed)
{
    r->value[CELL_BEATS]     = 48210;
    r->value[CELL_TURNS]     = 482;
    r->value[CELL_SEATS]     = 4;
    r->value[CELL_COMMANDS]  = 1907;
    r->value[CELL_REFUSED]   = 63;
    r->value[CELL_ROLLBACKS] = 7;
    r->value[CELL_THINGS]    = 214;
    r->value[CELL_CHECKSUM]  = 0x5A2DA9ED845D85F1ull;
    r->seed = seed;
}
/* }}} */

/*
 * A seed that produces each creature in turn, so a test can walk all four
 * without knowing how the seed maps onto them.
 */
/* {{{ static uint64_t seed_for */
static uint64_t seed_for(uint8_t kind)
{
    uint64_t seed;

    for (seed = 1; seed < 100000u; seed++) {
        if (creature_from_seed(seed) == kind) {
            return seed;
        }
    }

    return 1;
}
/* }}} */

/* {{{ static void test_the_round_trip */
static void test_the_round_trip(void)
{
    uint8_t kind;
    uint8_t alphabet;

    TEST_CASE("what was engraved is what is read back");

    for (kind = 0; kind < CREATURE_COUNT; kind++) {
        for (alphabet = 0; alphabet < 2u; alphabet++) {
            struct record written;
            struct record read_back;
            struct engraving found;
            struct engraving_error why;
            char first[ENGRAVING_MAX_BYTES];
            char again[ENGRAVING_MAX_BYTES];
            const char *refusal = "";
            uint32_t length;
            uint32_t cell;

            some_record(&written, seed_for(kind));

            length = engrave_to_text(&written, alphabet, first, sizeof(first),
                                     &refusal);
            if (length == 0) {
                fprintf(stderr, "    could not engrave the %s: %s\n",
                        creature_name(kind), refusal);
                CHECK(0);
                continue;
            }

            if (!engraving_read_text(&found, first, &why)) {
                char sentence[256];

                fprintf(stderr, "    could not read the %s: %s\n%s\n",
                        creature_name(kind),
                        engraving_error_sentence(&why, sentence, sizeof(sentence)),
                        first);
                CHECK(0);
                continue;
            }

            /* Every chamber found, and the creature identified from the seed
             * the file carries rather than from anything remembered. */
            CHECK_EQ(found.cell_count, RECORD_CELLS);
            CHECK_EQ(found.seed, written.seed);
            CHECK_EQ(found.alphabet, alphabet);
            CHECK_EQ(creature_from_seed(found.seed), kind);

            if (!engraving_to_record(&found, &read_back, &why)) {
                char sentence[256];

                fprintf(stderr, "    the %s is not a record: %s\n",
                        creature_name(kind),
                        engraving_error_sentence(&why, sentence, sizeof(sentence)));
                CHECK(0);
                continue;
            }

            /* THE FIRST HALF: the values came back. */
            for (cell = 0; cell < RECORD_CELLS; cell++) {
                if (written.value[cell] != read_back.value[cell]) {
                    fprintf(stderr,
                            "    the %s's %s cell: wrote %llu, read %llu\n",
                            creature_name(kind), record_label(cell),
                            (unsigned long long)written.value[cell],
                            (unsigned long long)read_back.value[cell]);
                }
                CHECK_EQ(read_back.value[cell], written.value[cell]);
            }

            CHECK_EQ(read_back.seed, written.seed);

            /*
             * THE SECOND HALF: engraved again from what was read, byte for byte.
             * A reader that recovered a value from somewhere other than its own
             * chamber passes the first half and fails here.
             */
            CHECK(engrave_to_text(&read_back, alphabet, again, sizeof(again),
                                  &refusal) == length);
            CHECK(memcmp(first, again, length) == 0);
        }
    }
}
/* }}} */

/*
 * Ornament must never touch a wall. The reader follows walls to find chambers,
 * so a fin drawn across one is a hole it falls through -- and the drawing would
 * still look roughly like an animal, which is the worst way to be wrong.
 */
/* {{{ static void test_no_ornament_touches_a_wall */
static void test_no_ornament_touches_a_wall(void)
{
    uint8_t kind;

    TEST_CASE("no creature's ornament crosses its own walls");

    for (kind = 0; kind < CREATURE_COUNT; kind++) {
        struct creature c;
        struct canvas canvas;
        struct record r;

        some_record(&r, seed_for(kind));

        CHECK_EQ(creature_lay_out(&c, kind), 1);
        CHECK_EQ(canvas_init(&canvas, c.width, c.height, ALPHABET_CARVED), 1);

        creature_draw(&c, &r, &canvas);

        if (canvas.ornament_collisions != 0) {
            fprintf(stderr, "    the %s crosses its own walls %u times\n",
                    creature_name(kind), (unsigned)canvas.ornament_collisions);
        }
        CHECK_EQ(canvas.ornament_collisions, 0);
    }
}
/* }}} */

/* {{{ static void test_every_creature_holds_every_cell */
static void test_every_creature_holds_every_cell(void)
{
    uint8_t kind;

    TEST_CASE("every creature has a chamber for every cell, and no chamber twice");

    for (kind = 0; kind < CREATURE_COUNT; kind++) {
        struct creature c;
        uint32_t seen[RECORD_CELLS];
        uint32_t i;

        memset(seen, 0, sizeof(seen));

        CHECK_EQ(creature_lay_out(&c, kind), 1);
        CHECK_EQ(c.chamber_count, RECORD_CELLS);

        for (i = 0; i < c.chamber_count; i++) {
            CHECK(c.chambers[i].cell < RECORD_CELLS);
            seen[c.chambers[i].cell]++;
        }

        for (i = 0; i < RECORD_CELLS; i++) {
            if (seen[i] != 1) {
                fprintf(stderr, "    the %s holds %s %u times\n",
                        creature_name(kind), record_label(i), (unsigned)seen[i]);
            }
            CHECK_EQ(seen[i], 1);
        }

        /* And no chamber overlaps another. Two chambers sharing a wall is
         * normal; two chambers sharing an interior is a value written over a
         * value. */
        for (i = 0; i < c.chamber_count; i++) {
            uint32_t j;

            for (j = i + 1u; j < c.chamber_count; j++) {
                int apart = c.chambers[i].x1 <= c.chambers[j].x0
                         || c.chambers[j].x1 <= c.chambers[i].x0
                         || c.chambers[i].y1 <= c.chambers[j].y0
                         || c.chambers[j].y1 <= c.chambers[i].y0;

                CHECK(apart);
            }
        }
    }
}
/* }}} */

/* {{{ static void test_the_same_record_gives_the_same_bytes */
static void test_the_same_record_gives_the_same_bytes(void)
{
    struct record r;
    char first[ENGRAVING_MAX_BYTES];
    char again[ENGRAVING_MAX_BYTES];
    const char *why = "";

    TEST_CASE("the same record and seed engrave to the same bytes");

    some_record(&r, 4242);

    CHECK(engrave_to_text(&r, ALPHABET_CARVED, first, sizeof(first), &why) > 0);
    CHECK(engrave_to_text(&r, ALPHABET_CARVED, again, sizeof(again), &why) > 0);
    CHECK(strcmp(first, again) == 0);

    /* A different seed is a different creature and therefore different bytes. */
    r.seed = seed_for((uint8_t)((creature_from_seed(4242) + 1u) % CREATURE_COUNT));
    CHECK(engrave_to_text(&r, ALPHABET_CARVED, again, sizeof(again), &why) > 0);
    CHECK(strcmp(first, again) != 0);
}
/* }}} */

/*
 * The fragility, tested rather than asserted. Each of these is a specific way a
 * file can be wrong, and each must be refused with a place.
 */
/* {{{ static void test_a_hand_edit_is_refused */
static void test_a_hand_edit_is_refused(void)
{
    struct record r;
    struct engraving found;
    struct engraving_error why;
    char sound[ENGRAVING_MAX_BYTES];
    char damaged[ENGRAVING_MAX_BYTES];
    const char *refusal = "";
    uint32_t length;

    TEST_CASE("an extra digit typed into a value deforms the carving");

    some_record(&r, seed_for(CREATURE_DRAGON));
    length = engrave_to_text(&r, ALPHABET_CARVED, sound, sizeof(sound), &refusal);
    CHECK(length > 0);

    /*
     * Somebody opens it in an editor and adds a digit to a number. Everything to
     * the right of it on that line shifts one column, the walls stop lining up
     * with the walls above and below, and the animal is visibly wrong.
     */
    {
        const char *at = strstr(sound, "48210");
        uint32_t offset;

        CHECK(at != NULL);
        if (at == NULL) {
            return;
        }

        offset = (uint32_t)(at - sound);
        memcpy(damaged, sound, offset);
        memcpy(damaged + offset, "482100", 6);
        memcpy(damaged + offset + 6u, sound + offset + 5u, length - offset - 5u);
        damaged[length + 1u] = '\0';
    }

    /* The reader refuses it, and says where. */
    if (engraving_read_text(&found, damaged, &why)
        && engraving_to_record(&found, &r, &why)) {
        fprintf(stderr, "    a damaged carving was accepted:\n%s\n", damaged);
        CHECK(0);
    } else {
        CHECK(why.sentence[0] != '\0');
    }

    TEST_CASE("a wall with a gap in it is refused");
    {
        const char *at = strstr(sound, "\xe2\x94\x82");   /* a vertical wall */
        uint32_t offset;

        CHECK(at != NULL);
        if (at != NULL) {
            offset = (uint32_t)(at - sound);
            memcpy(damaged, sound, length + 1u);
            damaged[offset] = ' ';
            damaged[offset + 1u] = ' ';
            damaged[offset + 2u] = ' ';

            CHECK(!(engraving_read_text(&found, damaged, &why)
                    && engraving_to_record(&found, &r, &why)));
        }
    }

    TEST_CASE("things that are not engravings are refused, with a place");

    CHECK_EQ(engraving_read_text(&found, "", &why), 0);
    CHECK(strstr(why.sentence, "marker") != NULL);

    CHECK_EQ(engraving_read_text(&found, "somebody's shopping list\n", &why), 0);
    CHECK_EQ(why.row, 1);

    CHECK_EQ(engraving_read_text(&found,
        "vtt-engraving 9\nalphabet carved\nseed 0\n\n", &why), 0);
    CHECK(strstr(why.sentence, "version") != NULL);

    CHECK_EQ(engraving_read_text(&found,
        "vtt-engraving 1\nalphabet gilded\nseed 0\n\n", &why), 0);
    CHECK_EQ(why.row, 2);

    CHECK_EQ(engraving_read_text(&found,
        "vtt-engraving 1\nalphabet carved\n\n", &why), 0);
    CHECK(strstr(why.sentence, "seed") != NULL);

    /* A header and no carving: nothing to read. */
    CHECK_EQ(engraving_read_text(&found,
        "vtt-engraving 1\nalphabet carved\nseed 1\n\n\n", &why), 0);
    CHECK(strstr(why.sentence, "chambers") != NULL);
}
/* }}} */

/*
 * A well-formed picture is not automatically a record. The two questions are
 * separate and the refusal has to say which one failed.
 */
/* {{{ static void test_a_picture_is_not_a_record */
static void test_a_picture_is_not_a_record(void)
{
    struct engraving found;
    struct engraving_error why;
    struct record r;
    const char *drawn =
        "vtt-engraving 1\n"
        "alphabet plain\n"
        "seed 0000000000000001\n"
        "\n"
        "+--------+\n"
        "| apples |\n"
        "|      3 |\n"
        "+--------+\n";

    TEST_CASE("a carving that reads is still not necessarily a record");

    CHECK_EQ(engraving_read_text(&found, drawn, &why), 1);
    CHECK_EQ(found.cell_count, 1);
    CHECK(strcmp(found.cells[0].label, "apples") == 0);
    CHECK(strcmp(found.cells[0].value, "3") == 0);

    /* It read. It is not a record, and the refusal names the missing cell. */
    CHECK_EQ(engraving_to_record(&found, &r, &why), 0);
    CHECK(strstr(why.sentence, "beats") != NULL);
}
/* }}} */

/* {{{ static void test_a_value_too_wide_is_refused */
static void test_a_value_too_wide_is_refused(void)
{
    struct record r;
    char text[ENGRAVING_MAX_BYTES];
    const char *why = "";

    TEST_CASE("a number with nowhere to go is refused, not truncated");

    some_record(&r, 1);

    /* More beats than the chamber was drawn for. */
    r.value[CELL_BEATS] = 999999999999ull;

    CHECK_EQ(engrave_to_text(&r, ALPHABET_CARVED, text, sizeof(text), &why), 0);
    CHECK(strstr(why, "beats") != NULL);
    CHECK(strstr(why, "no room") != NULL);

    /* Back within range, and it engraves. */
    r.value[CELL_BEATS] = 99999999ull;
    CHECK(engrave_to_text(&r, ALPHABET_CARVED, text, sizeof(text), &why) > 0);

    /* A buffer too small is refused rather than half-filled -- half a carving is
     * not a smaller picture, it is a file with walls missing. */
    {
        char tiny[64];

        CHECK_EQ(engrave_to_text(&r, ALPHABET_CARVED, tiny, sizeof(tiny), &why), 0);
    }

    /* And an alphabet that is neither. */
    CHECK_EQ(engrave_to_text(&r, 7, text, sizeof(text), &why), 0);
}
/* }}} */

/*
 * Every stroke combination resolves to its own character, and a glyph placed
 * over a stroke shows the glyph and is counted.
 */
/* {{{ static void test_the_canvas_joins_its_lines */
static void test_the_canvas_joins_its_lines(void)
{
    struct canvas c;
    uint32_t a;
    uint32_t b;

    TEST_CASE("sixteen stroke combinations, sixteen different characters");

    for (a = 0; a < 16u; a++) {
        for (b = a + 1u; b < 16u; b++) {
            /* Carved: every combination is its own character, which is what
             * lets the reader tell a corner from a tee. */
            CHECK(strcmp(canvas_glyph_for((uint8_t)a, ALPHABET_CARVED),
                         canvas_glyph_for((uint8_t)b, ALPHABET_CARVED)) != 0);
        }
    }

    TEST_CASE("a box's corners fall out of its junctions");

    CHECK_EQ(canvas_init(&c, 20, 6, ALPHABET_CARVED), 1);
    canvas_box(&c, 0, 0, 10, 4);

    /* Top-left has strokes right and down and nothing else. */
    CHECK_EQ(c.strokes[0][0], STROKE_RIGHT | STROKE_DOWN);
    CHECK_EQ(c.strokes[0][10], STROKE_LEFT | STROKE_DOWN);
    CHECK_EQ(c.strokes[4][0], STROKE_RIGHT | STROKE_UP);
    CHECK_EQ(c.strokes[4][10], STROKE_LEFT | STROKE_UP);
    CHECK_EQ(c.strokes[0][5], STROKE_LEFT | STROKE_RIGHT);
    CHECK_EQ(c.strokes[2][0], STROKE_UP | STROKE_DOWN);

    /* Two boxes sharing a wall produce a tee, not an overwrite. */
    canvas_box(&c, 10, 0, 18, 4);
    CHECK_EQ(c.strokes[0][10], STROKE_LEFT | STROKE_RIGHT | STROKE_DOWN);

    TEST_CASE("a glyph over a stroke shows, and is counted");

    CHECK_EQ(c.ornament_collisions, 0);
    canvas_put(&c, 5, 0, 'X');
    CHECK_EQ(c.ornament_collisions, 1);
    CHECK_EQ(c.glyphs[0][5], 'X');

    /* A space is padding, not ornament, and does not count. */
    canvas_put(&c, 6, 0, ' ');
    CHECK_EQ(c.ornament_collisions, 1);

    TEST_CASE("a canvas larger than a carving may be is refused");

    CHECK_EQ(canvas_init(&c, CANVAS_MAX_WIDTH + 1u, 4, ALPHABET_CARVED), 0);
    CHECK_EQ(canvas_init(&c, 4, 0, ALPHABET_CARVED), 0);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_the_canvas_joins_its_lines();
    test_every_creature_holds_every_cell();
    test_no_ornament_touches_a_wall();
    test_the_round_trip();
    test_the_same_record_gives_the_same_bytes();
    test_a_hand_edit_is_refused();
    test_a_picture_is_not_a_record();
    test_a_value_too_wide_is_refused();

    return vtt_test_finish("098-test-engraving");
}
/* }}} */
