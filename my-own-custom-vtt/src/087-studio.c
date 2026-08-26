/*
 * 087-studio.c -- the numbers that keep the loop honest.
 *
 * Nothing in this file changes the pool. Every function here reads and reports,
 * which is the correct shape for a set of measurements: a measurement that can
 * alter what it measures is not a measurement.
 *
 * See 087-studio.h for why each of these exists.
 */

#include "087-studio.h"

#include <string.h>

/* {{{ void studio_init */
void studio_init(struct studio *s)
{
    memset(s, 0, sizeof(*s));
}
/* }}} */

/* {{{ static int in_scope */
static int in_scope(const struct pool_entry *e, const char *category)
{
    /* EVERY_CATEGORY is the empty string, and no sound category is empty, so
     * this cannot collide with a real one. */
    if (category[0] == '\0') {
        return 1;
    }
    return strcmp(e->category, category) == 0;
}
/* }}} */

/* {{{ void studio_agreement */
void studio_agreement(const struct sprite_pool *p, const char *category,
                      struct agreement *into)
{
    int32_t bias_sum = 0;
    uint32_t i;

    memset(into, 0, sizeof(*into));

    for (i = 1; i <= pool_count(p); i++) {
        const struct pool_entry *e = pool_at(p, i);
        int32_t difference;

        if (!in_scope(e, category)) {
            continue;
        }

        /*
         * Both opinions or it is not a pair. An entry the machine rated and
         * nobody has looked at says nothing about whether they would have
         * agreed, and counting it either way would be inventing an observation.
         */
        if (e->machine_tier == TIER_UNRATED || e->person_tier == TIER_UNRATED) {
            continue;
        }

        into->pairs++;

        if (e->machine_tier == e->person_tier) {
            into->exact++;
        }

        difference = (int32_t)e->machine_tier - (int32_t)e->person_tier;

        if (difference >= -1 && difference <= 1) {
            into->within_one++;
        }

        bias_sum += difference;
    }

    /*
     * ZERO OUT OF ZERO IS NOT PERFECT.
     *
     * This is the branch the whole file is built around. A pool nobody has rated
     * has nothing to say about whether the machine is right, and the temptation
     * -- which every ratio in every codebase eventually yields to -- is to
     * return 100% because nothing disagreed. Nothing agreed either.
     */
    if (into->pairs == 0) {
        into->standing = AGREEMENT_UNMEASURABLE;
        return;
    }

    into->exact_per_thousand      = (into->exact * 1000u) / into->pairs;
    into->within_one_per_thousand = (into->within_one * 1000u) / into->pairs;
    into->machine_bias_in_tenths  = (bias_sum * 10) / (int32_t)into->pairs;

    /*
     * And a handful of pairs is arithmetic rather than evidence. Saying THIN
     * rather than quoting a percentage is the difference between a number that
     * invites a decision and one that invites another look.
     */
    if (into->pairs < AGREEMENT_ENOUGH_PAIRS) {
        into->standing = AGREEMENT_THIN;
        return;
    }

    into->standing = AGREEMENT_MEASURED;
}
/* }}} */

/* {{{ const char *studio_agreement_sentence */
const char *studio_agreement_sentence(const struct agreement *a,
                                      char *into, uint32_t capacity)
{
    const char *leaning;

    if (a->standing == AGREEMENT_UNMEASURABLE) {
        snprintf(into, capacity,
                 "agreement with the machine: UNMEASURABLE -- no sprite carries"
                 " both a machine tier and a person's, so there is nothing to"
                 " compare. This is not agreement.");
        return into;
    }

    /* Which way it leans, from a table rather than a chain of comparisons. */
    if (a->machine_bias_in_tenths >= 5) {
        leaning = "the machine is the more generous of the two";
    } else if (a->machine_bias_in_tenths <= -5) {
        leaning = "the machine is the harsher of the two";
    } else {
        leaning = "neither leans much";
    }

    if (a->standing == AGREEMENT_THIN) {
        snprintf(into, capacity,
                 "agreement with the machine: THIN -- only %u pairs, where %u"
                 " would be enough to lean on. It matched exactly %u times and"
                 " came within one tier %u times.",
                 (unsigned)a->pairs, (unsigned)AGREEMENT_ENOUGH_PAIRS,
                 (unsigned)a->exact, (unsigned)a->within_one);
        return into;
    }

    snprintf(into, capacity,
             "agreement with the machine: exact on %u.%u%% and within one tier"
             " on %u.%u%% of %u pairs; %s (%s%u.%u tiers).",
             (unsigned)(a->exact_per_thousand / 10u),
             (unsigned)(a->exact_per_thousand % 10u),
             (unsigned)(a->within_one_per_thousand / 10u),
             (unsigned)(a->within_one_per_thousand % 10u),
             (unsigned)a->pairs,
             leaning,
             a->machine_bias_in_tenths < 0 ? "-" : "+",
             (unsigned)((a->machine_bias_in_tenths < 0
                         ? -a->machine_bias_in_tenths
                         : a->machine_bias_in_tenths) / 10),
             (unsigned)((a->machine_bias_in_tenths < 0
                         ? -a->machine_bias_in_tenths
                         : a->machine_bias_in_tenths) % 10));

    return into;
}
/* }}} */

/* {{{ void studio_anchor */
void studio_anchor(const struct sprite_pool *p, const char *category,
                   struct anchor *into)
{
    uint32_t i;

    memset(into, 0, sizeof(*into));
    into->floor_per_thousand = ANCHOR_FLOOR_PER_THOUSAND;

    for (i = 1; i <= pool_count(p); i++) {
        const struct pool_entry *e = pool_at(p, i);

        if (!in_scope(e, category)) {
            continue;
        }

        into->entries++;

        if (e->person_tier != TIER_UNRATED) {
            into->rated_by_a_person++;
        }
    }

    if (into->entries == 0) {
        /* An empty pool is not below the floor. There is nothing to have looked
         * at, and calling that a failure would have the studio complaining at
         * somebody who has not started yet. */
        into->below_the_floor = 0;
        return;
    }

    into->fraction_per_thousand = (into->rated_by_a_person * 1000u) / into->entries;
    into->below_the_floor =
        (into->fraction_per_thousand < into->floor_per_thousand) ? 1 : 0;
}
/* }}} */

/* {{{ const char *studio_anchor_sentence */
const char *studio_anchor_sentence(const struct anchor *a,
                                   char *into, uint32_t capacity)
{
    if (a->entries == 0) {
        snprintf(into, capacity, "the pool is empty.");
        return into;
    }

    if (a->below_the_floor) {
        snprintf(into, capacity,
                 "a person has rated %u of %u (%u.%u%%), which is BELOW the"
                 " %u.%u%% anchor. The machine's taste is drifting away from"
                 " yours with nothing pulling it back, and no error will ever"
                 " be raised about it.",
                 (unsigned)a->rated_by_a_person, (unsigned)a->entries,
                 (unsigned)(a->fraction_per_thousand / 10u),
                 (unsigned)(a->fraction_per_thousand % 10u),
                 (unsigned)(a->floor_per_thousand / 10u),
                 (unsigned)(a->floor_per_thousand % 10u));
        return into;
    }

    snprintf(into, capacity,
             "a person has rated %u of %u (%u.%u%%), at or above the %u.%u%%"
             " anchor.",
             (unsigned)a->rated_by_a_person, (unsigned)a->entries,
             (unsigned)(a->fraction_per_thousand / 10u),
             (unsigned)(a->fraction_per_thousand % 10u),
             (unsigned)(a->floor_per_thousand / 10u),
             (unsigned)(a->floor_per_thousand % 10u));

    return into;
}
/* }}} */

/* {{{ void studio_dial_report */
void studio_dial_report(const struct sprite_pool *p, const char *category,
                        uint8_t from_floor, uint8_t to_floor, uint8_t trust,
                        struct dial_report *into)
{
    memset(into, 0, sizeof(*into));

    snprintf(into->category, sizeof(into->category), "%.31s", category);
    into->from_floor = from_floor;
    into->to_floor   = to_floor;
    into->trust      = trust;

    into->in_category      = pool_in_category(p, category);
    into->survivors_before = pool_survivors(p, category, from_floor, trust, NULL, 0);
    into->survivors_after  = pool_survivors(p, category, to_floor, trust, NULL, 0);

    /* Nothing was applied. The whole point of this function is that the answer
     * arrives while the question is still open. */
}
/* }}} */

/*
 * What losing that much variety feels like, in words.
 *
 * A dispatch table over how much of the pool survives, rather than a chain of
 * comparisons -- the thresholds are the interesting part and a table puts them
 * where they can be read together and argued with.
 */
static const struct {
    uint32_t at_least_per_thousand;   /* of what survived before */
    const char *consequence;
} variety_cost[] = {
    { 800u, "barely any variety is lost"                                   },
    { 500u, "expect some repetition"                                       },
    { 250u, "expect them to start resembling each other"                   },
    {  80u, "expect to see the same few over and over"                     },
    {   0u, "there will be almost nothing to choose from"                  }
};

/* {{{ static const char *cost_of */
static const char *cost_of(uint32_t before, uint32_t after)
{
    uint32_t remaining;
    uint32_t i;

    if (after == 0) {
        return "nothing survives it at all";
    }

    if (before == 0) {
        return "nothing survived the old floor either";
    }

    remaining = (after * 1000u) / before;

    for (i = 0; i < sizeof(variety_cost) / sizeof(variety_cost[0]); i++) {
        if (remaining >= variety_cost[i].at_least_per_thousand) {
            return variety_cost[i].consequence;
        }
    }

    return variety_cost[sizeof(variety_cost) / sizeof(variety_cost[0]) - 1].consequence;
}
/* }}} */

/* {{{ const char *studio_dial_sentence */
const char *studio_dial_sentence(const struct dial_report *r,
                                 char *into, uint32_t capacity)
{
    const char *whose = (r->trust == TRUST_A_PERSON)
                        ? " as judged by a person" : "";

    if (r->to_floor <= r->from_floor) {
        /* Lowering it, or not moving it. Variety is bought back rather than
         * spent, so the sentence says the opposite thing. */
        snprintf(into, capacity,
                 "%s: moving the floor from %u to %u%s leaves %u to draw from"
                 " instead of %u, out of %u in the category.",
                 r->category, (unsigned)r->from_floor, (unsigned)r->to_floor,
                 whose,
                 (unsigned)r->survivors_after, (unsigned)r->survivors_before,
                 (unsigned)r->in_category);
        return into;
    }

    snprintf(into, capacity,
             "%s: raising the floor from %u to %u%s leaves %u to draw from"
             " instead of %u, out of %u in the category -- %s.",
             r->category, (unsigned)r->from_floor, (unsigned)r->to_floor,
             whose,
             (unsigned)r->survivors_after, (unsigned)r->survivors_before,
             (unsigned)r->in_category,
             cost_of(r->survivors_before, r->survivors_after));

    return into;
}
/* }}} */

/* {{{ int studio_may_offer */
int studio_may_offer(const struct studio *s, const char *category)
{
    uint32_t i;

    for (i = 0; i < s->declined_count; i++) {
        if (strcmp(s->declined[i], category) == 0) {
            return 0;
        }
    }

    return 1;
}
/* }}} */

/* {{{ void studio_decline */
void studio_decline(struct studio *s, const char *category)
{
    if (!studio_may_offer(s, category)) {
        return;
    }

    if (s->declined_count >= STUDIO_MAX_DECLINED) {
        /*
         * More categories declined than the studio can remember. The oldest
         * refusal is forgotten, which means somebody eventually gets asked
         * again about a category they turned down long ago -- which is the mild
         * failure. The alternative, refusing to record the refusal, would mean
         * asking again immediately, which is the studio nagging.
         */
        uint32_t i;

        for (i = 1; i < STUDIO_MAX_DECLINED; i++) {
            memcpy(s->declined[i - 1], s->declined[i], sizeof(s->declined[0]));
        }
        s->declined_count = STUDIO_MAX_DECLINED - 1u;
    }

    snprintf(s->declined[s->declined_count], sizeof(s->declined[0]),
             "%.31s", category);
    s->declined_count++;

    /* And nothing about the pool was touched. "Not now" costs nothing. */
}
/* }}} */

/* {{{ const char *studio_offer_sentence */
const char *studio_offer_sentence(const struct sprite_pool *p,
                                  const char *category,
                                  char *into, uint32_t capacity)
{
    uint32_t total = pool_in_category(p, category);
    uint32_t unrated = 0;
    uint32_t i;

    for (i = 1; i <= pool_count(p); i++) {
        const struct pool_entry *e = pool_at(p, i);

        if (!in_scope(e, category)) {
            continue;
        }
        if (e->person_tier == TIER_UNRATED) {
            unrated++;
        }
    }

    if (unrated == 0) {
        snprintf(into, capacity,
                 "%s: you have looked at all %u of them.",
                 category, (unsigned)total);
        return into;
    }

    /*
     * The offer carries its own cost so the answer can be informed. It says how
     * many, and what it would buy -- not "would you like to improve quality",
     * which is a question with no price on it and therefore no honest answer.
     */
    snprintf(into, capacity,
             "%s: %u of %u have no rating from a person. Looking through them"
             " would let a floor be set on what you actually think rather than"
             " on what the heuristic guessed. Not now is a fine answer and will"
             " not be asked again.",
             category, (unsigned)unrated, (unsigned)total);

    return into;
}
/* }}} */

/* {{{ void studio_summarise */
void studio_summarise(const struct sprite_pool *p, const char *category,
                      FILE *out)
{
    struct agreement a;
    struct anchor anchored;
    char sentence[512];
    uint32_t stale;
    uint8_t tier;
    uint32_t by_tier[6];
    uint32_t by_person = 0;
    uint32_t by_machine = 0;
    uint32_t by_nobody = 0;
    uint32_t i;

    memset(by_tier, 0, sizeof(by_tier));

    for (i = 1; i <= pool_count(p); i++) {
        const struct pool_entry *e = pool_at(p, i);
        uint8_t provenance;

        if (!in_scope(e, category)) {
            continue;
        }

        by_tier[pool_tier(p, i)]++;

        provenance = pool_tier_provenance(p, i);
        if (provenance == RATED_BY_PERSON) {
            by_person++;
        } else if (provenance == RATED_BY_MACHINE) {
            by_machine++;
        } else {
            by_nobody++;
        }
    }

    fprintf(out, "  the pool%s%s\n",
            category[0] == '\0' ? "" : ", ",
            category[0] == '\0' ? "" : category);
    fprintf(out, "  ----------------------------------------------------\n");
    fprintf(out, "    tier  held by\n");

    for (tier = 5; tier >= 1; tier--) {
        fprintf(out, "    %4u  %u\n", (unsigned)tier, (unsigned)by_tier[tier]);
    }
    fprintf(out, "    none  %u\n", (unsigned)by_tier[TIER_UNRATED]);

    fprintf(out, "\n    rated by a person: %u    by the machine: %u"
                 "    by nobody: %u\n",
            (unsigned)by_person, (unsigned)by_machine, (unsigned)by_nobody);

    /*
     * THE HONESTY, printed every time rather than kept for a footnote. The tier
     * numbers above look like measurements and most of them are a heuristic's
     * guess, and a reader who does not know that is reading the wrong thing.
     */
    fprintf(out, "\n    the machine's tiers are a HEURISTIC: layer count,"
                 " whether it moves,\n"
                 "    palette coherence, how much of its box it fills, and how"
                 " balanced\n"
                 "    the detail is. That is a proxy for taste, and a crude"
                 " one.\n");

    studio_agreement(p, category, &a);
    fprintf(out, "\n    %s\n", studio_agreement_sentence(&a, sentence,
                                                         sizeof(sentence)));

    studio_anchor(p, category, &anchored);
    fprintf(out, "    %s\n", studio_anchor_sentence(&anchored, sentence,
                                                    sizeof(sentence)));

    stale = pool_from_another_paintbrush(p);
    if (stale > 0) {
        fprintf(out, "\n    %u entries were drawn by a different paintbrush"
                     " than the one in use\n"
                     "    now, so their ratings describe pictures that no"
                     " longer exist.\n",
                (unsigned)stale);
    }
}
/* }}} */
