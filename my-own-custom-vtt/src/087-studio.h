/*
 * 087-studio.h -- watching the watcher, and quoting the price before the sale.
 *
 * The pool stores opinions. This is what is done with them, and all of it is one
 * idea: a system improved by a grader that is itself being tuned is A LOOP WITH
 * NO ANCHOR.
 *
 * Let a person's ratings become rare relative to the machine's, and the whole
 * apparatus converges smoothly on the GRADER'S taste rather than yours. No error
 * is raised anywhere. Nothing fails. You find out months later by not liking the
 * output, at which point every rating in the pool is suspect and there is no way
 * to tell which ones.
 *
 * So three things happen here, and none of them is optional:
 *
 *   THE AGREEMENT RATE is computed from the pool rather than measured in a
 *     separate exercise. Every entry carrying both a machine tier and a person's
 *     is one free observation of how often the machine is right. A grader nobody
 *     has measured is not a grader, it is a rumour.
 *
 *   AN AGREEMENT COMPUTED FROM NOTHING IS NOT AGREEMENT. A pool with no human
 *     ratings reports UNMEASURABLE, never a hundred per cent. Zero out of zero
 *     is not perfect; it is silence, and reporting silence as consensus is the
 *     single most dangerous number this project could print.
 *
 *   THE HUMAN-RATED FRACTION is reported beside it, with a floor, and the studio
 *     says plainly when it is below. That fraction is what makes the agreement
 *     rate mean anything at all.
 *
 * And one more idea, which is the quality dial: RAISING QUALITY SPENDS VARIETY,
 * AND THE PRICE IS QUOTED BEFORE THE SALE. Raising a category's floor from three
 * to four leaves thirty-one sprites to draw from instead of two hundred and
 * fourteen, and they will start to resemble each other. That trade must be
 * visible at the moment of choosing, not discovered afterwards in the output.
 *
 * It is the same axis that decides whether a trained system memorises or wanders,
 * pulled out of the internals and put where a person can reach it.
 *
 * See docs/017-the-sprite-studio.md and issues 906 and 907.
 */

#ifndef VTT_STUDIO_H
#define VTT_STUDIO_H

#include <stdint.h>
#include <stdio.h>

#include "085-sprite-pool.h"

/*
 * Passed where a category is wanted and every category is meant. A named
 * constant rather than a bare empty string, because "" appearing in a call is a
 * mistake and EVERY_CATEGORY is a decision.
 */
#define EVERY_CATEGORY ""

/* How much of the pool a person is expected to have looked at. */
#define ANCHOR_FLOOR_PER_THOUSAND 50u    /* five per cent */

/*
 * Below this many pairs the agreement rate is arithmetic rather than evidence.
 * Two people agreeing twice is not a measurement, and a percentage computed from
 * three observations will swing thirty points on the fourth.
 */
#define AGREEMENT_ENOUGH_PAIRS 20u

/* How much is known about whether the machine and a person agree. */
#define AGREEMENT_UNMEASURABLE 0u   /* no entry carries both opinions */
#define AGREEMENT_THIN         1u   /* some do, too few to lean on */
#define AGREEMENT_MEASURED     2u

struct agreement {
    uint8_t  standing;          /* one of the three above */

    uint32_t pairs;             /* entries carrying both opinions */
    uint32_t exact;             /* the two said the same tier */
    uint32_t within_one;        /* they were within one tier of each other */

    /*
     * Where the two rates would be, in parts per thousand. Both are zero when
     * there are no pairs -- read `standing` first, always. A caller that prints
     * this without looking at `standing` prints "0.0% agreement" for a pool
     * nobody has rated, which is a different falsehood from the one this file
     * exists to prevent and no better.
     */
    uint32_t exact_per_thousand;
    uint32_t within_one_per_thousand;

    /*
     * The machine's tier minus the person's, summed over the pairs, in tenths of
     * a tier. Positive means the machine is the more generous of the two.
     *
     * Worth having separately from the agreement rate because they answer
     * different questions: the rate says how often the machine is wrong, and
     * this says WHICH WAY, and a grader that is consistently one tier generous
     * is a grader that can be corrected rather than replaced.
     */
    int32_t  machine_bias_in_tenths;
};

struct anchor {
    uint32_t entries;
    uint32_t rated_by_a_person;

    uint32_t fraction_per_thousand;
    uint32_t floor_per_thousand;

    int      below_the_floor;
};

struct dial_report {
    char     category[SPRITE_NAME_MAX + 1];

    uint8_t  from_floor;
    uint8_t  to_floor;
    uint8_t  trust;

    uint32_t in_category;
    uint32_t survivors_before;
    uint32_t survivors_after;
};

/*
 * Whether a person has been asked lately whether they would like to rate some
 * things, and said no.
 *
 * A STUDIO THAT NAGS IS A STUDIO NOBODY OPENS. Declining must cost nothing and
 * must not be asked again in the same breath, so the refusal is remembered --
 * which is the only reason this struct exists at all.
 */
#define STUDIO_MAX_DECLINED 32

struct studio {
    char     declined[STUDIO_MAX_DECLINED][SPRITE_NAME_MAX + 1];
    uint32_t declined_count;
};

void studio_init(struct studio *s);

/*
 * Measure how often the machine and a person said the same thing.
 *
 * Pass EVERY_CATEGORY for the whole pool. Reads `standing` first is not advice,
 * it is the contract.
 */
void studio_agreement(const struct sprite_pool *p, const char *category,
                      struct agreement *into);

/* The same as a sentence somebody can read. Returns `into`. */
const char *studio_agreement_sentence(const struct agreement *a,
                                      char *into, uint32_t capacity);

/* How much of the pool a person has actually looked at, against the floor. */
void studio_anchor(const struct sprite_pool *p, const char *category,
                   struct anchor *into);

const char *studio_anchor_sentence(const struct anchor *a,
                                   char *into, uint32_t capacity);

/*
 * What raising a floor would cost, computed before anything is applied.
 *
 * Nothing here changes the pool. The whole point is that the answer arrives
 * while the question is still open.
 */
void studio_dial_report(const struct sprite_pool *p, const char *category,
                        uint8_t from_floor, uint8_t to_floor, uint8_t trust,
                        struct dial_report *into);

const char *studio_dial_sentence(const struct dial_report *r,
                                 char *into, uint32_t capacity);

/*
 * May the studio offer to let somebody rate some sprites in this category?
 *
 * False once they have declined for that category. Declining is free and stays
 * free.
 */
int studio_may_offer(const struct studio *s, const char *category);

/*
 * Record a refusal. Changes nothing about the pool -- no tier, no entry, no
 * ordering. "Not now" costs nothing.
 */
void studio_decline(struct studio *s, const char *category);

/*
 * The offer itself, carrying its own cost so the answer can be informed: how
 * many are unrated by a person, and what rating them could do to the floor.
 */
const char *studio_offer_sentence(const struct sprite_pool *p,
                                  const char *category,
                                  char *into, uint32_t capacity);

/*
 * Everything above, printed together.
 *
 * The agreement rate and the human-rated fraction are reported WHEREVER THE POOL
 * IS SUMMARISED rather than computed and filed. A number nobody sees is not a
 * measurement, it is a log entry.
 */
void studio_summarise(const struct sprite_pool *p, const char *category,
                      FILE *out);

#endif
