/*
 * 086-test-sprite-pool.c -- does the library keep what it was given, and does a
 * correction destroy what it corrected?
 *
 * The second question is the one worth writing tests for. A store that loses an
 * entry announces itself the first time somebody looks. A store that quietly
 * overwrites the machine's opinion every time a person disagrees keeps working
 * perfectly, and the only symptom is that the agreement rate -- the number the
 * whole studio is built to watch -- reads as one hundred per cent forever.
 *
 * Both rating algorithms are exercised here. A mode that is not tested is a mode
 * that is broken; it just has not been asked yet.
 */

#include "020-test-harness.h"
#include "085-sprite-pool.h"

#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

/* Ephemeral, so it goes to the RAM tier rather than into somebody's checkout. */
#define SCRATCH_DIR "/dev/shm/my-own-custom-vtt"

/*
 * Times are supplied rather than read from a clock, so these are just numbers
 * that are easy to recognise in a failure message.
 */
#define WHEN_MADE   1000u
#define WHEN_RATED  2000u
#define WHEN_LATER  3000u

/* {{{ static void fill_with */
static void fill_with(struct sprite_pool *p, const char *category,
                      uint64_t first, uint64_t last)
{
    uint64_t seed;

    for (seed = first; seed <= last; seed++) {
        pool_add(p, category, seed, WHEN_MADE);
    }
}
/* }}} */

/*
 * Under rate-on-arrival everything is judged the moment it lands, because a pool
 * that keeps everything and is looked at rarely is overwhelmingly unrated -- and
 * a floor of "tier four or better" against an unrated library excludes the
 * library.
 */
/* {{{ static void test_rate_on_arrival */
static void test_rate_on_arrival(void)
{
    struct sprite_pool p;
    uint32_t i;
    uint32_t unrated = 0;

    TEST_CASE("rate on arrival: the machine speaks for everything at once");

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);

    fill_with(&p, "goblin", 1, 60);
    CHECK_EQ(pool_count(&p), 60);

    for (i = 1; i <= pool_count(&p); i++) {
        CHECK_EQ(pool_tier_provenance(&p, i), RATED_BY_MACHINE);
        CHECK(pool_tier(&p, i) >= 1 && pool_tier(&p, i) <= 5);

        if (pool_tier(&p, i) == TIER_UNRATED) {
            unrated++;
        }
    }

    CHECK_EQ(unrated, 0);

    pool_release(&p);
}
/* }}} */

/*
 * Under judge-then-curate nothing is rated until a person looks, and that is the
 * point rather than an oversight. The pool is bounded by patience, and
 * everything in it has been looked at.
 */
/* {{{ static void test_judge_then_curate */
static void test_judge_then_curate(void)
{
    struct sprite_pool p;
    uint32_t i;

    TEST_CASE("judge then curate: nothing is rated until somebody looks");

    CHECK_EQ(pool_init(&p, POOL_JUDGE_THEN_CURATE), 1);

    fill_with(&p, "goblin", 1, 40);
    CHECK_EQ(pool_count(&p), 40);

    for (i = 1; i <= pool_count(&p); i++) {
        CHECK_EQ(pool_tier_provenance(&p, i), RATED_BY_NOBODY);
        CHECK_EQ(pool_tier(&p, i), TIER_UNRATED);
    }

    /* The opening pass. */
    for (i = 1; i <= pool_count(&p); i++) {
        CHECK_EQ(pool_rate_by_person(&p, i, (uint8_t)(1u + (i % 5u)), "ritz",
                                     WHEN_RATED), 1);
    }

    for (i = 1; i <= pool_count(&p); i++) {
        CHECK_EQ(pool_tier_provenance(&p, i), RATED_BY_PERSON);
        CHECK_EQ(pool_tier(&p, i), 1u + (i % 5u));

        /* And no machine opinion was ever formed, so there is nothing to
         * compare against -- which is exactly why this algorithm has no drift
         * failure and no agreement rate either. */
        CHECK_EQ(pool_at(&p, i)->machine_tier, TIER_UNRATED);
    }

    pool_release(&p);
}
/* }}} */

/*
 * The centre of this file. A person disagreeing with the machine must not erase
 * the machine's opinion, because that opinion is one half of every pair the
 * agreement rate is computed from.
 */
/* {{{ static void test_a_correction_keeps_what_it_corrected */
static void test_a_correction_keeps_what_it_corrected(void)
{
    struct sprite_pool p;
    uint32_t entry;
    uint8_t what_the_machine_said;

    TEST_CASE("a person's rating does not destroy the machine's");

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);

    entry = pool_add(&p, "goblin", 7, WHEN_MADE);
    CHECK(entry != POOL_NOTHING);

    what_the_machine_said = pool_at(&p, entry)->machine_tier;
    CHECK(what_the_machine_said >= 1 && what_the_machine_said <= 5);

    /* A person disagrees, deliberately by a lot. */
    CHECK_EQ(pool_rate_by_person(&p, entry, 1, "ritz", WHEN_RATED), 1);

    CHECK_EQ(pool_tier(&p, entry), 1);
    CHECK_EQ(pool_tier_provenance(&p, entry), RATED_BY_PERSON);
    CHECK_EQ(pool_at(&p, entry)->machine_tier, what_the_machine_said);
    CHECK_EQ(pool_at(&p, entry)->machine_when, WHEN_MADE);
    CHECK(strcmp(pool_at(&p, entry)->person_name, "ritz") == 0);

    /* And a second correction, by somebody else, still leaves the machine's. */
    CHECK_EQ(pool_rate_by_person(&p, entry, 5, "somebody-else", WHEN_LATER), 1);

    CHECK_EQ(pool_tier(&p, entry), 5);
    CHECK_EQ(pool_at(&p, entry)->machine_tier, what_the_machine_said);
    CHECK_EQ(pool_at(&p, entry)->person_when, WHEN_LATER);
    CHECK(strcmp(pool_at(&p, entry)->person_name, "somebody-else") == 0);

    /* The machine may speak again without touching the person's answer. */
    CHECK_EQ(pool_rate_by_machine(&p, entry, WHEN_LATER), 1);
    CHECK_EQ(pool_tier(&p, entry), 5);
    CHECK_EQ(pool_at(&p, entry)->person_tier, 5);

    pool_release(&p);
}
/* }}} */

/* {{{ static void test_a_rating_that_could_not_be_recorded */
static void test_a_rating_that_could_not_be_recorded(void)
{
    struct sprite_pool p;
    uint32_t entry;

    TEST_CASE("a refused rating does not look like one that was recorded");

    CHECK_EQ(pool_init(&p, POOL_JUDGE_THEN_CURATE), 1);
    entry = pool_add(&p, "goblin", 7, WHEN_MADE);

    /* Zero is unrated, not a rating somebody can give. */
    CHECK_EQ(pool_rate_by_person(&p, entry, 0, "ritz", WHEN_RATED), 0);

    /* Six is a caller with a different scale in mind. Clamping it to five would
     * record an opinion nobody held. */
    CHECK_EQ(pool_rate_by_person(&p, entry, 6, "ritz", WHEN_RATED), 0);

    /* Nobody is not a rater. */
    CHECK_EQ(pool_rate_by_person(&p, entry, 3, "", WHEN_RATED), 0);

    /* A name with a space would split a line of the index into more fields than
     * the reader expects, and every entry after it would mis-parse. */
    CHECK_EQ(pool_rate_by_person(&p, entry, 3, "two words", WHEN_RATED), 0);

    /* An entry that does not exist. */
    CHECK_EQ(pool_rate_by_person(&p, 9999, 3, "ritz", WHEN_RATED), 0);
    CHECK_EQ(pool_rate_by_person(&p, POOL_NOTHING, 3, "ritz", WHEN_RATED), 0);

    /* After all of that, still unrated. */
    CHECK_EQ(pool_tier(&p, entry), TIER_UNRATED);
    CHECK_EQ(pool_tier_provenance(&p, entry), RATED_BY_NOBODY);

    pool_release(&p);
}
/* }}} */

/* {{{ static void test_the_category_wall */
static void test_the_category_wall(void)
{
    struct sprite_pool p;

    TEST_CASE("a category that would name a file elsewhere is refused");

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);

    CHECK_EQ(pool_category_is_sound("goblin"), 1);
    CHECK_EQ(pool_category_is_sound("dire-wolf"), 1);
    CHECK_EQ(pool_category_is_sound("goblin2"), 1);

    CHECK_EQ(pool_category_is_sound(""), 0);
    CHECK_EQ(pool_category_is_sound("../etc/passwd"), 0);
    CHECK_EQ(pool_category_is_sound("gob lin"), 0);
    CHECK_EQ(pool_category_is_sound("Goblin"), 0);
    CHECK_EQ(pool_category_is_sound("goblin/wolf"), 0);
    CHECK_EQ(pool_category_is_sound("goblin\n"), 0);

    /* And the pool refuses to hold one rather than sanitising it, because a
     * sanitised category is a category somebody cannot find again. */
    CHECK_EQ(pool_add(&p, "../etc/passwd", 1, WHEN_MADE), POOL_NOTHING);
    CHECK_EQ(pool_count(&p), 0);

    pool_release(&p);
}
/* }}} */

/*
 * The same description is the same picture, so it is the same entry. Otherwise a
 * person rates a goblin, the generator offers that goblin again, and the pool
 * holds one rated and one unrated copy of one thing.
 */
/* {{{ static void test_the_same_description_twice */
static void test_the_same_description_twice(void)
{
    struct sprite_pool p;
    uint32_t first;
    uint32_t again;

    TEST_CASE("adding the same description twice is one entry");

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);

    first = pool_add(&p, "goblin", 7, WHEN_MADE);
    CHECK_EQ(pool_rate_by_person(&p, first, 5, "ritz", WHEN_RATED), 1);

    again = pool_add(&p, "goblin", 7, WHEN_LATER);

    CHECK_EQ(again, first);
    CHECK_EQ(pool_count(&p), 1);

    /* And the rating came back with it. */
    CHECK_EQ(pool_tier(&p, again), 5);

    /* A different seed is a different picture. */
    CHECK(pool_add(&p, "goblin", 8, WHEN_MADE) != first);
    CHECK_EQ(pool_count(&p), 2);

    /* And so is the same seed in a different category. */
    CHECK(pool_add(&p, "wolf", 7, WHEN_MADE) != first);
    CHECK_EQ(pool_count(&p), 3);

    pool_release(&p);
}
/* }}} */

/*
 * Raising the floor spends variety. The test is the direction of the trade, not
 * a particular number -- the numbers move whenever the grader is recalibrated
 * and the direction never does.
 */
/* {{{ static void test_raising_the_floor_never_gains */
static void test_raising_the_floor_never_gains(void)
{
    struct sprite_pool p;
    uint32_t at_floor[6];
    uint8_t floor;

    TEST_CASE("raising a floor never increases what survives it");

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);
    fill_with(&p, "goblin", 1, 400);
    fill_with(&p, "wolf", 1, 100);

    for (floor = 1; floor <= 5; floor++) {
        at_floor[floor] = pool_survivors(&p, "goblin", floor, TRUST_ANYBODY,
                                         NULL, 0);
    }

    for (floor = 2; floor <= 5; floor++) {
        CHECK(at_floor[floor] <= at_floor[floor - 1]);
    }

    /* At the bottom, everything rated survives -- which under this algorithm is
     * everything in the category. */
    CHECK_EQ(at_floor[1], pool_in_category(&p, "goblin"));
    CHECK_EQ(at_floor[1], 400);

    /* And the other category is not swept up in it. */
    CHECK_EQ(pool_in_category(&p, "wolf"), 100);
    CHECK(pool_survivors(&p, "wolf", 1, TRUST_ANYBODY, NULL, 0) == 100);

    /* Quality is never discussed globally. A category nobody has filled has no
     * survivors rather than borrowing another category's. */
    CHECK_EQ(pool_survivors(&p, "barrel", 1, TRUST_ANYBODY, NULL, 0), 0);

    pool_release(&p);
}
/* }}} */

/*
 * "Tier four or better" and "tier four or better as judged by a person" are
 * different requests. The second is always smaller, and it is the more
 * trustworthy one.
 */
/* {{{ static void test_the_provenance_dial */
static void test_the_provenance_dial(void)
{
    struct sprite_pool p;
    uint32_t i;
    uint32_t anybody;
    uint32_t a_person;
    uint32_t chosen[16];
    uint32_t how_many;

    TEST_CASE("trusting only a person gives a smaller and surer answer");

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);
    fill_with(&p, "goblin", 1, 200);

    /* A person has looked at a handful and liked them. */
    for (i = 1; i <= 10; i++) {
        CHECK_EQ(pool_rate_by_person(&p, i, 5, "ritz", WHEN_RATED), 1);
    }

    anybody  = pool_survivors(&p, "goblin", 4, TRUST_ANYBODY, NULL, 0);
    a_person = pool_survivors(&p, "goblin", 4, TRUST_A_PERSON, NULL, 0);

    CHECK_EQ(a_person, 10);
    CHECK(a_person <= anybody);
    CHECK(anybody > a_person);

    /* Every entry the strict question returns was rated by a person. */
    how_many = pool_survivors(&p, "goblin", 4, TRUST_A_PERSON, chosen, 16);
    CHECK_EQ(how_many, 10);

    for (i = 0; i < 10; i++) {
        CHECK_EQ(pool_tier_provenance(&p, chosen[i]), RATED_BY_PERSON);
    }

    /*
     * The count is the true count even when the array could not hold it. A
     * caller comparing two floors with a small array still learns the real
     * trade; a count that stopped at the array's end would report raising a
     * floor as free.
     */
    how_many = pool_survivors(&p, "goblin", 1, TRUST_ANYBODY, chosen, 16);
    CHECK_EQ(how_many, 200);

    pool_release(&p);
}
/* }}} */

/*
 * Everything survives a round trip through a file: both tiers, both times, the
 * rater's name, and which paintbrush made each entry.
 */
/* {{{ static void test_the_pool_survives_a_reload */
static void test_the_pool_survives_a_reload(void)
{
    struct sprite_pool written;
    struct sprite_pool loaded;
    const char *why = "";
    const char *directory = SCRATCH_DIR "/test-pool";
    uint32_t i;

    TEST_CASE("an entry survives being written and read back");

    mkdir(SCRATCH_DIR, 0755);
    mkdir(directory, 0755);

    CHECK_EQ(pool_init(&written, POOL_RATE_ON_ARRIVAL), 1);
    fill_with(&written, "goblin", 1, 25);
    fill_with(&written, "torch", 1, 5);

    CHECK_EQ(pool_rate_by_person(&written, 3, 1, "ritz", WHEN_RATED), 1);
    CHECK_EQ(pool_rate_by_person(&written, 7, 5, "somebody-else", WHEN_LATER), 1);

    if (!pool_write(&written, directory, &why)) {
        fprintf(stderr, "    could not write the pool: %s\n", why);
        CHECK(0);
    }

    CHECK_EQ(pool_init(&loaded, POOL_JUDGE_THEN_CURATE), 1);

    if (!pool_read(&loaded, directory, &why)) {
        fprintf(stderr, "    could not read the pool: %s\n", why);
        CHECK(0);
    }

    CHECK_EQ(pool_count(&loaded), pool_count(&written));

    /* The algorithm came back with the file, over the one this pool was made
     * with -- the setting belongs to the library, not to the program that
     * happened to open it. */
    CHECK_EQ(loaded.algorithm, POOL_RATE_ON_ARRIVAL);

    for (i = 1; i <= pool_count(&written); i++) {
        const struct pool_entry *a = pool_at(&written, i);
        const struct pool_entry *b = pool_at(&loaded, i);

        CHECK(strcmp(a->category, b->category) == 0);
        CHECK_EQ(a->seed, b->seed);
        CHECK_EQ(a->paintbrush, b->paintbrush);
        CHECK_EQ(a->canvas, b->canvas);
        CHECK_EQ(a->machine_tier, b->machine_tier);
        CHECK_EQ(a->machine_when, b->machine_when);
        CHECK_EQ(a->person_tier, b->person_tier);
        CHECK_EQ(a->person_when, b->person_when);
        CHECK(strcmp(a->person_name, b->person_name) == 0);
    }

    /* And the pictures are on disk where somebody can open them. */
    {
        char path[512];
        FILE *f;

        snprintf(path, sizeof(path), "%s/goblin-3.svg", directory);
        f = fopen(path, "r");
        CHECK(f != NULL);

        if (f != NULL) {
            char first[8];

            CHECK(fgets(first, sizeof(first), f) != NULL);
            CHECK(strncmp(first, "<svg", 4) == 0);
            fclose(f);
        }
    }

    pool_release(&written);
    pool_release(&loaded);
}
/* }}} */

/*
 * A line the reader cannot understand stops the read and says which line.
 *
 * A reader that skipped it would be a pool quietly deleting an entry, silently,
 * at load, months after whatever damaged the line -- which is the one thing this
 * whole module exists to prevent.
 */
/* {{{ static void test_a_line_that_cannot_be_read */
static void test_a_line_that_cannot_be_read(void)
{
    struct sprite_pool p;
    const char *why = "";
    const char *directory = SCRATCH_DIR "/test-pool-damaged";
    char path[512];
    FILE *f;

    TEST_CASE("a damaged index stops the read rather than losing an entry");

    mkdir(SCRATCH_DIR, 0755);
    mkdir(directory, 0755);

    snprintf(path, sizeof(path), "%s/index", directory);

    f = fopen(path, "w");
    CHECK(f != NULL);
    if (f == NULL) {
        return;
    }

    fprintf(f, "vtt-sprite-pool 1\n");
    fprintf(f, "algorithm rate-on-arrival\n");
    fprintf(f, "goblin 1 ABCDEF0123456789 100 4 1000 0 0 -\n");
    fprintf(f, "goblin 2 ABCDEF0123456789 100\n");          /* short */
    fprintf(f, "goblin 3 ABCDEF0123456789 100 3 1000 0 0 -\n");
    fclose(f);

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);
    CHECK_EQ(pool_read(&p, directory, &why), 0);
    CHECK(strstr(why, "line 4") != NULL);
    CHECK(strstr(why, "9") != NULL);
    pool_release(&p);

    /* A category that would name a file elsewhere is refused at load too, not
     * only when it is added. */
    f = fopen(path, "w");
    if (f != NULL) {
        fprintf(f, "vtt-sprite-pool 1\n");
        fprintf(f, "../etc/passwd 1 ABCDEF0123456789 100 4 1000 0 0 -\n");
        fclose(f);
    }

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);
    CHECK_EQ(pool_read(&p, directory, &why), 0);
    CHECK(strstr(why, "category") != NULL);
    pool_release(&p);

    /* A tier off the scale. */
    f = fopen(path, "w");
    if (f != NULL) {
        fprintf(f, "vtt-sprite-pool 1\n");
        fprintf(f, "goblin 1 ABCDEF0123456789 100 9 1000 0 0 -\n");
        fclose(f);
    }

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);
    CHECK_EQ(pool_read(&p, directory, &why), 0);
    CHECK(strstr(why, "tier") != NULL);
    pool_release(&p);

    /* And something that is not a pool index at all. */
    f = fopen(path, "w");
    if (f != NULL) {
        fprintf(f, "this is somebody's shopping list\n");
        fclose(f);
    }

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);
    CHECK_EQ(pool_read(&p, directory, &why), 0);
    CHECK(strstr(why, "pool index") != NULL);
    pool_release(&p);
}
/* }}} */

/*
 * A rating is an opinion about a specific picture, and the entry records which
 * paintbrush drew it. Change the paintbrush and the pool can say how many of its
 * ratings are describing something that no longer exists.
 */
/* {{{ static void test_which_paintbrush_drew_it */
static void test_which_paintbrush_drew_it(void)
{
    struct sprite_pool p;
    uint32_t entry;

    TEST_CASE("every entry records the paintbrush that drew it");

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);

    entry = pool_add(&p, "goblin", 7, WHEN_MADE);
    CHECK_EQ(pool_at(&p, entry)->paintbrush, sprite_paintbrush_fingerprint());
    CHECK_EQ(pool_at(&p, entry)->canvas, SPRITE_CANVAS);
    CHECK_EQ(pool_from_another_paintbrush(&p), 0);

    /* The fingerprint is stable across calls -- it is computed from fixed
     * witnesses, not from anything that moves. */
    CHECK_EQ(sprite_paintbrush_fingerprint(), sprite_paintbrush_fingerprint());

    /* Pretend the paintbrush moved on. Every entry made before it is now a
     * rating of a picture that no longer exists, and the pool says how many. */
    p.paintbrush_now = sprite_paintbrush_fingerprint() ^ 1u;
    CHECK_EQ(pool_from_another_paintbrush(&p), 1);

    pool_release(&p);
}
/* }}} */

/* {{{ static void test_the_picture_comes_back */
static void test_the_picture_comes_back(void)
{
    struct sprite_pool p;
    uint32_t entry;
    struct sprite from_pool;
    struct sprite made_directly;

    TEST_CASE("forty bytes of description regenerate the picture exactly");

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);

    entry = pool_add(&p, "goblin", 4242, WHEN_MADE);
    CHECK_EQ(pool_sprite(&p, entry, &from_pool), 1);

    sprite_make(&made_directly, "goblin", 4242);

    CHECK_EQ(memcmp(&from_pool, &made_directly, sizeof(struct sprite)), 0);

    /* An entry that is not there gives nothing rather than a default sprite. */
    CHECK_EQ(pool_sprite(&p, POOL_NOTHING, &from_pool), 0);
    CHECK_EQ(pool_sprite(&p, 9999, &from_pool), 0);

    pool_release(&p);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_rate_on_arrival();
    test_judge_then_curate();
    test_a_correction_keeps_what_it_corrected();
    test_a_rating_that_could_not_be_recorded();
    test_the_category_wall();
    test_the_same_description_twice();
    test_raising_the_floor_never_gains();
    test_the_provenance_dial();
    test_the_pool_survives_a_reload();
    test_a_line_that_cannot_be_read();
    test_which_paintbrush_drew_it();
    test_the_picture_comes_back();

    return vtt_test_finish("086-test-sprite-pool");
}
/* }}} */
