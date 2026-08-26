/*
 * 088-test-studio.c -- does a number computed from nothing read as agreement?
 *
 * That single question is why this file exists. Every other check here is
 * ordinary arithmetic that would announce itself the moment somebody looked at
 * the output. The dangerous one is silent: a ratio over zero observations that
 * returns a hundred per cent because nothing disagreed.
 *
 * Nothing agreed either, and a studio reporting perfect agreement with a person
 * who has never rated anything is a studio that will let the machine's taste
 * replace theirs without a single error being raised.
 */

#include "020-test-harness.h"
#include "087-studio.h"

#include <stdio.h>
#include <string.h>

#define WHEN 1000u

/* {{{ static void fill_with */
static void fill_with(struct sprite_pool *p, const char *category,
                      uint64_t first, uint64_t last)
{
    uint64_t seed;

    for (seed = first; seed <= last; seed++) {
        pool_add(p, category, seed, WHEN);
    }
}
/* }}} */

/*
 * The centre of this file.
 */
/* {{{ static void test_agreement_from_nothing */
static void test_agreement_from_nothing(void)
{
    struct sprite_pool p;
    struct agreement a;
    char sentence[512];

    TEST_CASE("a pool nobody has rated reports unmeasurable, not perfect");

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);
    fill_with(&p, "goblin", 1, 300);

    studio_agreement(&p, EVERY_CATEGORY, &a);

    CHECK_EQ(a.standing, AGREEMENT_UNMEASURABLE);
    CHECK_EQ(a.pairs, 0);
    CHECK_EQ(a.exact, 0);
    CHECK_EQ(a.exact_per_thousand, 0);
    CHECK_EQ(a.within_one_per_thousand, 0);

    /* And it says so in words, because a caller printing the number without
     * reading the standing would print "0.0% agreement" for a pool nobody has
     * touched, which is a different falsehood and no better. */
    studio_agreement_sentence(&a, sentence, sizeof(sentence));
    CHECK(strstr(sentence, "UNMEASURABLE") != NULL);
    CHECK(strstr(sentence, "This is not agreement") != NULL);
    CHECK(strstr(sentence, "100") == NULL);

    /* An entirely empty pool, likewise. */
    pool_release(&p);
    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);
    studio_agreement(&p, EVERY_CATEGORY, &a);
    CHECK_EQ(a.standing, AGREEMENT_UNMEASURABLE);

    /* And a pool where a person has rated everything and the machine nothing --
     * algorithm B's shape -- also has nothing to compare. */
    pool_release(&p);
    CHECK_EQ(pool_init(&p, POOL_JUDGE_THEN_CURATE), 1);
    fill_with(&p, "goblin", 1, 50);
    {
        uint32_t i;

        for (i = 1; i <= 50; i++) {
            CHECK_EQ(pool_rate_by_person(&p, i, 3, "ritz", WHEN), 1);
        }
    }
    studio_agreement(&p, EVERY_CATEGORY, &a);
    CHECK_EQ(a.standing, AGREEMENT_UNMEASURABLE);

    pool_release(&p);
}
/* }}} */

/* {{{ static void test_a_handful_of_pairs_is_thin */
static void test_a_handful_of_pairs_is_thin(void)
{
    struct sprite_pool p;
    struct agreement a;
    char sentence[512];
    uint32_t i;

    TEST_CASE("a few pairs is arithmetic, not evidence, and says so");

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);
    fill_with(&p, "goblin", 1, 300);

    for (i = 1; i <= 3; i++) {
        CHECK_EQ(pool_rate_by_person(&p, i, pool_at(&p, i)->machine_tier,
                                     "ritz", WHEN), 1);
    }

    studio_agreement(&p, EVERY_CATEGORY, &a);

    CHECK_EQ(a.standing, AGREEMENT_THIN);
    CHECK_EQ(a.pairs, 3);
    CHECK_EQ(a.exact, 3);

    /* Three out of three is a hundred per cent and it must not be quoted as
     * one -- a percentage from three observations swings thirty points on the
     * fourth. */
    studio_agreement_sentence(&a, sentence, sizeof(sentence));
    CHECK(strstr(sentence, "THIN") != NULL);
    CHECK(strstr(sentence, "100") == NULL);

    /* One more than enough, and it becomes a measurement. */
    for (i = 4; i <= AGREEMENT_ENOUGH_PAIRS; i++) {
        CHECK_EQ(pool_rate_by_person(&p, i, pool_at(&p, i)->machine_tier,
                                     "ritz", WHEN), 1);
    }

    studio_agreement(&p, EVERY_CATEGORY, &a);
    CHECK_EQ(a.standing, AGREEMENT_MEASURED);
    CHECK_EQ(a.pairs, AGREEMENT_ENOUGH_PAIRS);

    pool_release(&p);
}
/* }}} */

/*
 * When there are pairs, the arithmetic is the arithmetic. Built by hand so each
 * number is known in advance rather than being whatever the grader happened to
 * produce.
 */
/* {{{ static void test_the_agreement_arithmetic */
static void test_the_agreement_arithmetic(void)
{
    struct sprite_pool p;
    struct agreement a;
    uint32_t i;

    TEST_CASE("half agreeing exactly reads as half");

    CHECK_EQ(pool_init(&p, POOL_JUDGE_THEN_CURATE), 1);
    fill_with(&p, "goblin", 1, 40);

    /* The machine says 3 to every one of them. */
    for (i = 1; i <= 40; i++) {
        struct pool_entry *e = (struct pool_entry *)pool_at(&p, i);

        e->machine_tier = 3;
        e->machine_when = WHEN;
    }

    /* A person agrees with twenty, is one off on ten, and is two off on ten. */
    for (i = 1; i <= 20; i++) {
        CHECK_EQ(pool_rate_by_person(&p, i, 3, "ritz", WHEN), 1);
    }
    for (i = 21; i <= 30; i++) {
        CHECK_EQ(pool_rate_by_person(&p, i, 4, "ritz", WHEN), 1);
    }
    for (i = 31; i <= 40; i++) {
        CHECK_EQ(pool_rate_by_person(&p, i, 5, "ritz", WHEN), 1);
    }

    studio_agreement(&p, EVERY_CATEGORY, &a);

    CHECK_EQ(a.standing, AGREEMENT_MEASURED);
    CHECK_EQ(a.pairs, 40);
    CHECK_EQ(a.exact, 20);
    CHECK_EQ(a.within_one, 30);
    CHECK_EQ(a.exact_per_thousand, 500);
    CHECK_EQ(a.within_one_per_thousand, 750);

    /*
     * The machine said 3 where the person said 3, 4, and 5, so it is the harsher
     * of the two -- and the sign of the bias is the point, because a grader that
     * is consistently one tier out can be corrected rather than replaced.
     *
     * Sum of (machine - person) = (0 * 20) + (-1 * 10) + (-2 * 10) = -30,
     * over 40 pairs, in tenths: (-30 * 10) / 40 = -7.
     */
    CHECK_EQ(a.machine_bias_in_tenths, -7);

    pool_release(&p);
}
/* }}} */

/* {{{ static void test_the_anchor */
static void test_the_anchor(void)
{
    struct sprite_pool p;
    struct anchor a;
    char sentence[512];
    uint32_t i;

    TEST_CASE("the studio says plainly when nobody is holding the anchor");

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);
    fill_with(&p, "goblin", 1, 1000);

    studio_anchor(&p, EVERY_CATEGORY, &a);
    CHECK_EQ(a.entries, 1000);
    CHECK_EQ(a.rated_by_a_person, 0);
    CHECK_EQ(a.fraction_per_thousand, 0);
    CHECK_EQ(a.below_the_floor, 1);

    studio_anchor_sentence(&a, sentence, sizeof(sentence));
    CHECK(strstr(sentence, "BELOW") != NULL);
    CHECK(strstr(sentence, "drifting") != NULL);

    /* One below the floor. */
    for (i = 1; i <= 49; i++) {
        CHECK_EQ(pool_rate_by_person(&p, i, 3, "ritz", WHEN), 1);
    }
    studio_anchor(&p, EVERY_CATEGORY, &a);
    CHECK_EQ(a.fraction_per_thousand, 49);
    CHECK_EQ(a.below_the_floor, 1);

    /* Exactly at it, which counts as holding it. */
    CHECK_EQ(pool_rate_by_person(&p, 50, 3, "ritz", WHEN), 1);
    studio_anchor(&p, EVERY_CATEGORY, &a);
    CHECK_EQ(a.rated_by_a_person, 50);
    CHECK_EQ(a.fraction_per_thousand, ANCHOR_FLOOR_PER_THOUSAND);
    CHECK_EQ(a.below_the_floor, 0);

    studio_anchor_sentence(&a, sentence, sizeof(sentence));
    CHECK(strstr(sentence, "BELOW") == NULL);

    /* An empty pool is not below the floor. There is nothing to have looked at,
     * and complaining at somebody who has not started yet is the studio
     * nagging. */
    pool_release(&p);
    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);
    studio_anchor(&p, EVERY_CATEGORY, &a);
    CHECK_EQ(a.below_the_floor, 0);

    pool_release(&p);
}
/* }}} */

/*
 * Algorithm B has no drift failure, and the numbers show it rather than the
 * comment claiming it: every rating is a person's, so the human-rated fraction
 * is everything and there is no agreement rate at all.
 */
/* {{{ static void test_algorithm_b_cannot_drift */
static void test_algorithm_b_cannot_drift(void)
{
    struct sprite_pool p;
    struct anchor anchored;
    struct agreement a;
    uint32_t i;

    TEST_CASE("judge then curate has nothing to drift from");

    CHECK_EQ(pool_init(&p, POOL_JUDGE_THEN_CURATE), 1);
    fill_with(&p, "goblin", 1, 40);

    for (i = 1; i <= 40; i++) {
        CHECK_EQ(pool_rate_by_person(&p, i, (uint8_t)(1u + (i % 5u)),
                                     "ritz", WHEN), 1);
    }

    studio_anchor(&p, EVERY_CATEGORY, &anchored);
    CHECK_EQ(anchored.fraction_per_thousand, 1000);
    CHECK_EQ(anchored.below_the_floor, 0);

    studio_agreement(&p, EVERY_CATEGORY, &a);
    CHECK_EQ(a.standing, AGREEMENT_UNMEASURABLE);

    pool_release(&p);
}
/* }}} */

/* {{{ static void test_the_dial_quotes_its_price */
static void test_the_dial_quotes_its_price(void)
{
    struct sprite_pool p;
    struct dial_report r;
    char sentence[512];
    uint8_t before_tiers[64];
    uint32_t i;

    TEST_CASE("raising a floor reports its cost and changes nothing");

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);
    fill_with(&p, "goblin", 1, 400);
    fill_with(&p, "wolf", 1, 60);

    for (i = 1; i < 64; i++) {
        before_tiers[i] = pool_tier(&p, i);
    }

    studio_dial_report(&p, "goblin", 3, 4, TRUST_ANYBODY, &r);

    CHECK(strcmp(r.category, "goblin") == 0);
    CHECK_EQ(r.from_floor, 3);
    CHECK_EQ(r.to_floor, 4);
    CHECK_EQ(r.in_category, 400);
    CHECK(r.survivors_after <= r.survivors_before);
    CHECK(r.survivors_before <= r.in_category);

    /* The pool is untouched. A measurement that alters what it measures is not
     * a measurement. */
    CHECK_EQ(pool_count(&p), 460);
    for (i = 1; i < 64; i++) {
        CHECK_EQ(pool_tier(&p, i), before_tiers[i]);
    }

    /* The sentence carries both numbers and a consequence, because a trade with
     * only one side quoted is not a trade anybody can weigh. */
    studio_dial_sentence(&r, sentence, sizeof(sentence));
    CHECK(strstr(sentence, "goblin") != NULL);
    CHECK(strstr(sentence, "instead of") != NULL);

    /* Lowering it says the opposite thing rather than announcing a cost. */
    studio_dial_report(&p, "goblin", 4, 2, TRUST_ANYBODY, &r);
    CHECK(r.survivors_after >= r.survivors_before);
    studio_dial_sentence(&r, sentence, sizeof(sentence));
    CHECK(strstr(sentence, "raising") == NULL);
    CHECK(strstr(sentence, "moving") != NULL);

    /* Restricting to a person's judgment, in a pool nobody has judged, leaves
     * nothing -- which is the honest answer and not an empty category. */
    studio_dial_report(&p, "goblin", 4, 5, TRUST_A_PERSON, &r);
    CHECK_EQ(r.survivors_before, 0);
    CHECK_EQ(r.survivors_after, 0);
    studio_dial_sentence(&r, sentence, sizeof(sentence));
    CHECK(strstr(sentence, "as judged by a person") != NULL);

    pool_release(&p);
}
/* }}} */

/* {{{ static void test_declining_is_free */
static void test_declining_is_free(void)
{
    struct sprite_pool p;
    struct studio s;
    char sentence[512];
    uint32_t count_before;
    uint8_t tier_before;

    TEST_CASE("not now costs nothing and is not asked again");

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);
    studio_init(&s);
    fill_with(&p, "goblin", 1, 100);
    fill_with(&p, "wolf", 1, 20);

    CHECK_EQ(studio_may_offer(&s, "goblin"), 1);

    /* The offer carries its own cost, so the answer can be informed. */
    studio_offer_sentence(&p, "goblin", sentence, sizeof(sentence));
    CHECK(strstr(sentence, "100") != NULL);
    CHECK(strstr(sentence, "Not now") != NULL);

    count_before = pool_count(&p);
    tier_before = pool_tier(&p, 1);

    studio_decline(&s, "goblin");

    CHECK_EQ(studio_may_offer(&s, "goblin"), 0);

    /* Declining changed nothing whatsoever about the library. */
    CHECK_EQ(pool_count(&p), count_before);
    CHECK_EQ(pool_tier(&p, 1), tier_before);

    /* And it is per category -- turning down the goblins is not turning down
     * everything. */
    CHECK_EQ(studio_may_offer(&s, "wolf"), 1);

    /* Declining twice is not two refusals. */
    studio_decline(&s, "goblin");
    CHECK_EQ(s.declined_count, 1);

    /* When everything in a category has been looked at, the offer says so
     * instead of asking for nothing. */
    {
        uint32_t i;

        for (i = 1; i <= 20; i++) {
            uint32_t entry = pool_find(&p, "wolf", i);

            CHECK(entry != POOL_NOTHING);
            CHECK_EQ(pool_rate_by_person(&p, entry, 3, "ritz", WHEN), 1);
        }
    }

    studio_offer_sentence(&p, "wolf", sentence, sizeof(sentence));
    CHECK(strstr(sentence, "all 20") != NULL);

    pool_release(&p);
}
/* }}} */

/*
 * Quality is discussed per category and never globally. Nobody says the sprites
 * are bad; they say the goblins are bad.
 */
/* {{{ static void test_measurements_stay_in_their_category */
static void test_measurements_stay_in_their_category(void)
{
    struct sprite_pool p;
    struct agreement a;
    struct anchor anchored;
    uint32_t i;

    TEST_CASE("a category's numbers are that category's");

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);
    fill_with(&p, "goblin", 1, 100);
    fill_with(&p, "wolf", 1, 100);

    /* Every goblin gets a person's opinion; no wolf does. */
    for (i = 1; i <= 100; i++) {
        uint32_t entry = pool_find(&p, "goblin", i);

        CHECK_EQ(pool_rate_by_person(&p, entry, 3, "ritz", WHEN), 1);
    }

    studio_anchor(&p, "goblin", &anchored);
    CHECK_EQ(anchored.entries, 100);
    CHECK_EQ(anchored.fraction_per_thousand, 1000);
    CHECK_EQ(anchored.below_the_floor, 0);

    studio_anchor(&p, "wolf", &anchored);
    CHECK_EQ(anchored.entries, 100);
    CHECK_EQ(anchored.rated_by_a_person, 0);
    CHECK_EQ(anchored.below_the_floor, 1);

    /* Across everything it is half, which is exactly the global number that
     * would have hidden the wolves. */
    studio_anchor(&p, EVERY_CATEGORY, &anchored);
    CHECK_EQ(anchored.entries, 200);
    CHECK_EQ(anchored.fraction_per_thousand, 500);

    studio_agreement(&p, "wolf", &a);
    CHECK_EQ(a.standing, AGREEMENT_UNMEASURABLE);

    studio_agreement(&p, "goblin", &a);
    CHECK_EQ(a.standing, AGREEMENT_MEASURED);
    CHECK_EQ(a.pairs, 100);

    pool_release(&p);
}
/* }}} */

/*
 * The summary prints the honesty every time, not in a footnote somewhere.
 */
/* {{{ static void test_the_summary_says_it_is_a_heuristic */
static void test_the_summary_says_it_is_a_heuristic(void)
{
    struct sprite_pool p;
    FILE *out;
    char buffer[8192];
    size_t length;
    const char *path = "/dev/shm/my-own-custom-vtt/test-studio-summary";

    TEST_CASE("every summary says the machine's tiers are a heuristic");

    CHECK_EQ(pool_init(&p, POOL_RATE_ON_ARRIVAL), 1);
    fill_with(&p, "goblin", 1, 50);

    out = fopen(path, "w");
    CHECK(out != NULL);
    if (out == NULL) {
        pool_release(&p);
        return;
    }

    studio_summarise(&p, EVERY_CATEGORY, out);
    fclose(out);

    out = fopen(path, "r");
    CHECK(out != NULL);
    if (out == NULL) {
        pool_release(&p);
        return;
    }

    length = fread(buffer, 1, sizeof(buffer) - 1, out);
    buffer[length] = '\0';
    fclose(out);

    CHECK(strstr(buffer, "HEURISTIC") != NULL);
    CHECK(strstr(buffer, "proxy for taste") != NULL);
    CHECK(strstr(buffer, "UNMEASURABLE") != NULL);
    CHECK(strstr(buffer, "BELOW") != NULL);

    pool_release(&p);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_agreement_from_nothing();
    test_a_handful_of_pairs_is_thin();
    test_the_agreement_arithmetic();
    test_the_anchor();
    test_algorithm_b_cannot_drift();
    test_the_dial_quotes_its_price();
    test_declining_is_free();
    test_measurements_stay_in_their_category();
    test_the_summary_says_it_is_a_heuristic();

    return vtt_test_finish("088-test-studio");
}
/* }}} */
