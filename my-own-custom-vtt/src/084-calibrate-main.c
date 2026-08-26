/*
 * 084-calibrate-main.c -- are the machine grader's tiers still five tiers?
 *
 * WHAT THIS IS, for somebody who has never opened it: the program that draws
 * sprites judges each one and files it under a tier from one to five. The lines
 * between the tiers are four fixed numbers. This program makes a great many
 * sprites, counts what tier each one lands in, and reports whether the five
 * tiers are being used or whether four fifths of everything is piling into two
 * of them.
 *
 * WHY IT SHIPS RATHER THAN BEING A SCRIPT SOMEBODY RAN ONCE: the four numbers
 * are frozen and the thing they measure is not. Add a shape to the paintbrush,
 * change how big a body is drawn, weight the grader differently -- and the
 * distribution moves underneath the lines, so tier five quietly comes to mean
 * "the best third" instead of "the best tenth", and nothing anywhere complains.
 * The only defence is being able to re-measure, cheaply, whenever the generator
 * changes.
 *
 * It reports rather than fixes. The four numbers stay in the source where they
 * can be read and argued with; this says whether they are still true.
 *
 * Usage:
 *   084-calibrate                  -- the default sweep
 *   084-calibrate 40000            -- that many seeds per category
 *   084-calibrate 4000 --histogram -- also print every score and its count
 */

#include "082-sprite.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * The categories swept. Deliberately several, because the category is folded
 * into the stream name -- a calibration against one word would be a calibration
 * against one corner of the space, and would look perfectly convincing.
 */
static const char *const categories[] = {
    "goblin", "torch", "chest", "wolf", "innkeeper", "barrel", "rat", "door"
};
#define CATEGORY_COUNT ((uint32_t)(sizeof(categories) / sizeof(categories[0])))

#define SCORE_MAX 100

/*
 * How far a measured percentage may sit from its intended one before the lines
 * are called stale. Six points of slack, because the sweep is a sample and a
 * tier that wanted twenty per cent and got twenty-two has not gone wrong.
 */
#define DRIFT_ALLOWED 6

/* What each tier is meant to hold, in percent. Ten, twenty, forty, twenty, ten. */
static const uint32_t intended_share[6] = { 0u, 10u, 20u, 40u, 20u, 10u };

/* {{{ static uint32_t percentile_of */
static uint32_t percentile_of(const uint32_t *histogram, uint32_t total, uint32_t wanted)
{
    uint32_t running = 0;
    uint32_t score;

    /*
     * The lowest score at or below which the wanted fraction of the pool sits.
     * Walking upwards rather than interpolating, because the scores are whole
     * numbers and a cut line has to be a whole number too.
     */
    for (score = 0; score <= SCORE_MAX; score++) {
        running += histogram[score];

        if (running * 100u >= total * wanted) {
            return score;
        }
    }

    return SCORE_MAX;
}
/* }}} */

/* {{{ int main */
int main(int argc, char **argv)
{
    uint32_t histogram[SCORE_MAX + 1];
    uint32_t by_tier[6];
    uint32_t seeds = 4000;
    int show_histogram = 0;
    uint32_t total = 0;
    uint32_t lowest = SCORE_MAX;
    uint32_t highest = 0;
    uint64_t seed;
    uint32_t which;
    uint32_t score;
    uint8_t tier;
    int stale = 0;

    /* Line-buffered, so a long sweep shows progress rather than looking hung. */
    setvbuf(stdout, NULL, _IOLBF, 0);

    {
        int argument;

        for (argument = 1; argument < argc; argument++) {
            if (strcmp(argv[argument], "--histogram") == 0) {
                show_histogram = 1;
            } else {
                long given = strtol(argv[argument], NULL, 10);

                if (given < 1) {
                    printf("084-calibrate: '%s' is not a number of seeds.\n",
                           argv[argument]);
                    return 1;
                }
                seeds = (uint32_t)given;
            }
        }
    }

    memset(histogram, 0, sizeof(histogram));
    memset(by_tier, 0, sizeof(by_tier));

    printf("The machine grader's calibration\n");
    printf("================================\n\n");
    printf("  %u seeds across %u categories = %u sprites\n\n",
           (unsigned)seeds, (unsigned)CATEGORY_COUNT,
           (unsigned)(seeds * CATEGORY_COUNT));

    for (seed = 1; seed <= seeds; seed++) {
        for (which = 0; which < CATEGORY_COUNT; which++) {
            struct sprite s;

            sprite_make(&s, categories[which], seed);

            score = sprite_machine_score(&s);
            if (score > SCORE_MAX) {
                score = SCORE_MAX;
            }

            histogram[score]++;
            by_tier[sprite_machine_tier(&s)]++;
            total++;

            if (score < lowest) {
                lowest = score;
            }
            if (score > highest) {
                highest = score;
            }
        }
    }

    printf("  scores run from %u to %u out of 100\n\n",
           (unsigned)lowest, (unsigned)highest);

    if (show_histogram) {
        printf("  score  count   share\n");
        printf("  -----  ------  -----\n");

        for (score = 0; score <= SCORE_MAX; score++) {
            uint32_t bar;

            if (histogram[score] == 0) {
                continue;
            }

            printf("  %5u  %6u  ", (unsigned)score, (unsigned)histogram[score]);

            /* One block per quarter of a percent, so the shape of the
             * distribution is visible rather than merely listed. */
            for (bar = 0; bar < (histogram[score] * 400u) / total; bar++) {
                printf("#");
            }
            printf("\n");
        }
        printf("\n");
    }

    printf("  tier  cut  holds     wanted  \n");
    printf("  ----  ---  --------  --------\n");

    for (tier = 1; tier <= 5; tier++) {
        uint32_t share = (by_tier[tier] * 1000u) / total;
        uint32_t wanted = intended_share[tier];
        int32_t drift = (int32_t)(share / 10u) - (int32_t)wanted;

        printf("  %4u  %3u  %5u.%01u%%  %5u%%   %s\n",
               (unsigned)tier,
               (unsigned)sprite_machine_cut(tier),
               (unsigned)(share / 10u), (unsigned)(share % 10u),
               (unsigned)wanted,
               (drift > DRIFT_ALLOWED || drift < -DRIFT_ALLOWED) ? "<-- adrift" : "");

        if (drift > DRIFT_ALLOWED || drift < -DRIFT_ALLOWED) {
            stale = 1;
        }

        /*
         * An empty tier is always stale, however small its intended share. A
         * number nothing ever lands on is not a lenient grade, it is a grade
         * that does not exist while looking like one.
         */
        if (by_tier[tier] == 0) {
            stale = 1;
        }
    }

    printf("\n  where the lines would go if measured today:\n");
    printf("    tier 2 at %u   (currently %u)\n",
           (unsigned)percentile_of(histogram, total, 10u),
           (unsigned)sprite_machine_cut(2));
    printf("    tier 3 at %u   (currently %u)\n",
           (unsigned)percentile_of(histogram, total, 30u),
           (unsigned)sprite_machine_cut(3));
    printf("    tier 4 at %u   (currently %u)\n",
           (unsigned)percentile_of(histogram, total, 70u),
           (unsigned)sprite_machine_cut(4));
    printf("    tier 5 at %u   (currently %u)\n",
           (unsigned)percentile_of(histogram, total, 90u),
           (unsigned)sprite_machine_cut(5));

    printf("\n");

    if (stale) {
        printf("  STALE. The generator has moved and the cut lines have not.\n");
        printf("  A tier now means something other than what it meant when the\n");
        printf("  numbers were measured, and every rating recorded against a\n");
        printf("  tier is quietly describing a different pool than it did.\n");
        printf("  The four numbers live in sprite_machine_cut, in 082-sprite.c.\n");
        return 1;
    }

    printf("  The five tiers are still five tiers.\n");
    return 0;
}
/* }}} */
