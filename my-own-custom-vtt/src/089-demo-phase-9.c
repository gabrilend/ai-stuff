/*
 * 089-demo-phase-9.c -- the appearance layer is a studio, not a folder.
 *
 * Phase nine's claim is that generated art needs a place to live, a way to be
 * judged, and something watching whether the judging still means anything. This
 * shows all three, and it shows the two failure modes the design exists to
 * prevent, happening.
 *
 * Seven parts:
 *
 *   THE PAINTBRUSH      twelve words, and what a thirteenth gets.
 *   A BATCH             pictures made, written out, and openable.
 *   BOTH ALGORITHMS     the same batch under each, side by side.
 *   THE DIAL            a floor raised, its price quoted before it moves.
 *   THE ANCHOR          how far the machine's taste has drifted from a person's.
 *   THE TABLE           a sprite re-tiered mid-fight, without stopping play.
 *   THE HONESTY         what the grader actually is, and what is still open.
 *
 * Run through ./run-phase-demo 9.
 */

#include "087-studio.h"
#include "053-session.h"
#include "037-fixture.h"
#include "035-worldfile.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

#define M(n) ((wcoord)((n) * WC_ONE))

#define SCRATCH "/dev/shm/my-own-custom-vtt"

/* The categories this demo furnishes a library with. */
static const char *const categories[] = { "goblin", "torch", "chest", "wolf" };
#define CATEGORY_COUNT ((uint32_t)(sizeof(categories) / sizeof(categories[0])))

/* {{{ static void rule */
static void rule(const char *title)
{
    size_t i;
    size_t width = strlen(title);

    printf("\n  %s\n  ", title);
    for (i = 0; i < width; i++) {
        printf("-");
    }
    printf("\n\n");
}
/* }}} */

/*
 * A person's opinions, standing in for a person.
 *
 * DELIBERATELY NOT THE MACHINE'S. This person likes movement more than the
 * grader does and cares less about how many layers there are, which is what
 * makes the agreement rate a number rather than a formality -- a stand-in that
 * simply echoed the heuristic would produce perfect agreement and prove nothing
 * whatsoever about the measurement.
 */
/* {{{ static uint8_t what_a_person_thinks */
static uint8_t what_a_person_thinks(const struct sprite *s)
{
    uint32_t score = 0;

    if (s->motion != MOTION_STILL) {
        score += 45;
    }
    if (s->layer_count >= 3) {
        score += 20;
    }

    /* They like a body that fills its space and they do not much mind clutter. */
    if (s->layers[0].radius >= 30) {
        score += 25;
    } else if (s->layers[0].radius >= 26) {
        score += 12;
    }

    /* And they like it when the detail is mirrored, which the grader only
     * notices sideways, through its balance component. */
    if (s->layer_count >= 3 &&
        s->layers[1].offset_x == -s->layers[2].offset_x &&
        s->layers[1].offset_x != 0) {
        score += 20;
    }

    if (score >= 85) {
        return 5;
    }
    if (score >= 65) {
        return 4;
    }
    if (score >= 45) {
        return 3;
    }
    if (score >= 25) {
        return 2;
    }
    return 1;
}
/* }}} */

/* {{{ static void fill */
static void fill(struct sprite_pool *p, uint32_t per_category, uint64_t when)
{
    uint32_t which;
    uint64_t seed;

    for (which = 0; which < CATEGORY_COUNT; which++) {
        for (seed = 1; seed <= per_category; seed++) {
            pool_add(p, categories[which], seed, when);
        }
    }
}
/* }}} */

/* {{{ static void show_the_paintbrush */
static void show_the_paintbrush(void)
{
    uint32_t count = 0;
    uint32_t i;

    sprite_vocabulary(&count);

    rule("The paintbrush is twelve words");

    printf("    shapes   ");
    for (i = 0; i < SHAPE_COUNT; i++) {
        printf("%s ", shape_name((uint8_t)i));
    }
    printf("\n    slots    ");
    for (i = 0; i < SLOT_COUNT; i++) {
        printf("%s ", slot_name((uint8_t)i));
    }
    printf("\n    motions  ");
    for (i = 0; i < MOTION_COUNT; i++) {
        printf("%s ", motion_name((uint8_t)i));
    }
    printf("\n\n    %u words in total, and nothing else is a word.\n", (unsigned)count);

    printf("\n    A paintbrush is defined by what it refuses. Handed a long\n");
    printf("    reference, anything generating descriptions invents plausible\n");
    printf("    neighbours -- confidently, and in good style:\n\n");

    {
        static const char *const invented[] = {
            "ellipse", "hexagon", "tertiary", "idle", "circel", "flikcer"
        };
        uint32_t n;

        for (n = 0; n < 6; n++) {
            const char *nearest = sprite_nearest_word(invented[n]);

            printf("      \"%-9s\"  refused", invented[n]);

            if (nearest != NULL) {
                printf("  -- did you mean \"%s\"?", nearest);
            }
            printf("\n");
        }
    }

    printf("\n    The vocabulary being twelve words long is what makes the\n");
    printf("    suggestion worth making. Across a thousand words the nearest\n");
    printf("    one is noise.\n");
}
/* }}} */

/*
 * A page you can open, showing the whole library moving.
 *
 * THE DELIVERABLE IS THE PICTURE, and a demo that only prints numbers about a
 * picture has hidden it. The format was chosen so that a file animates on its
 * own in a browser; this is where somebody actually sees that happen, several
 * hundred at a time, sorted by what anybody thought of them.
 *
 * The sprites are referenced rather than embedded, because they are already on
 * disk beside this file and a page that inlined them would be a second copy that
 * could disagree with the first.
 */
/* {{{ static int write_contact_sheet */
static int write_contact_sheet(const struct sprite_pool *library,
                               const char *directory, uint32_t most_per_tier)
{
    char path[512];
    FILE *page;
    uint32_t which;

    snprintf(path, sizeof(path), "%.400s/contact-sheet.html", directory);

    page = fopen(path, "w");
    if (page == NULL) {
        return 0;
    }

    fprintf(page,
        "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\">\n"
        "<title>the library</title>\n<style>\n"
        "  body { background:#15171c; color:#c8ccd4;"
                " font:14px/1.5 ui-monospace,monospace; margin:0; padding:24px; }\n"
        "  h1 { font-size:18px; font-weight:600; margin:0 0 4px; color:#e8ecf4; }\n"
        "  h2 { font-size:15px; margin:28px 0 2px; color:#e8ecf4; }\n"
        "  h3 { font-size:13px; font-weight:400; margin:16px 0 6px; color:#8b93a1;"
                " border-top:1px solid #262a33; padding-top:8px; }\n"
        "  p  { max-width:62ch; color:#8b93a1; margin:4px 0 0; }\n"
        "  .shelf { display:flex; flex-wrap:wrap; gap:10px; }\n"
        "  figure { margin:0; width:76px; text-align:center; }\n"
        "  img { width:72px; height:72px; background:#1d2027;"
               " border:1px solid #262a33; border-radius:6px; display:block; }\n"
        "  figcaption { font-size:10px; color:#6b7280; margin-top:3px;"
                      " white-space:nowrap; overflow:hidden; }\n"
        "  .byperson { color:#7fb069; }\n"
        "</style></head><body>\n");

    fprintf(page, "<h1>the library</h1>\n");
    fprintf(page,
        "<p>%u sprites, paintbrush %016llX, canvas %u by %u. Every one of these"
        " is a file on disk beside this page, and every one is moving. A rater"
        " shown a still frame of a walk cycle is rating an illustration.</p>\n",
        (unsigned)pool_count(library),
        (unsigned long long)sprite_paintbrush_fingerprint(),
        (unsigned)SPRITE_CANVAS, (unsigned)SPRITE_CANVAS);

    fprintf(page,
        "<p>Tiers in <span class=\"byperson\">green</span> were set by a"
        " person. The rest are a HEURISTIC -- layer count, whether it moves,"
        " palette coherence, how much of its box it fills, and whether it stands"
        " upright rather than leaning. That is a proxy for taste, and a crude"
        " one.</p>\n");

    for (which = 0; which < CATEGORY_COUNT; which++) {
        uint8_t tier;

        fprintf(page, "<h2>%s &mdash; %u</h2>\n", categories[which],
                (unsigned)pool_in_category(library, categories[which]));

        for (tier = 5; tier >= 1; tier--) {
            uint32_t shown = 0;
            uint32_t held = 0;
            uint32_t i;

            for (i = 1; i <= pool_count(library); i++) {
                if (strcmp(pool_at(library, i)->category,
                           categories[which]) == 0
                    && pool_tier(library, i) == tier) {
                    held++;
                }
            }

            if (held == 0) {
                continue;
            }

            fprintf(page, "<h3>tier %u &mdash; %u</h3>\n<div class=\"shelf\">\n",
                    (unsigned)tier, (unsigned)held);

            for (i = 1; i <= pool_count(library) && shown < most_per_tier; i++) {
                const struct pool_entry *e = pool_at(library, i);
                int by_person;

                if (strcmp(e->category, categories[which]) != 0
                    || pool_tier(library, i) != tier) {
                    continue;
                }

                by_person = (pool_tier_provenance(library, i) == RATED_BY_PERSON);

                fprintf(page,
                    "<figure><img src=\"%s-%llu.svg\" alt=\"%s %llu\">"
                    "<figcaption%s>%llu %s</figcaption></figure>\n",
                    e->category, (unsigned long long)e->seed,
                    e->category, (unsigned long long)e->seed,
                    by_person ? " class=\"byperson\"" : "",
                    (unsigned long long)e->seed,
                    by_person ? e->person_name : "machine");

                shown++;
            }

            fprintf(page, "</div>\n");

            /*
             * NO SILENT CAPS. A page that quietly showed the first forty would
             * read as "here is the tier" when it is a sample of one, and every
             * impression a reader formed from it would be of a pool they had not
             * seen.
             */
            if (shown < held) {
                fprintf(page, "<p>showing %u of %u; the rest are on disk.</p>\n",
                        (unsigned)shown, (unsigned)held);
            }
        }
    }

    fprintf(page, "</body></html>\n");
    fclose(page);
    return 1;
}
/* }}} */

/* {{{ static void show_a_batch */
static void show_a_batch(const struct sprite_pool *library)
{
    const char *why = "";
    const char *directory = SCRATCH "/phase-9-pool";
    uint32_t which;

    rule("A batch, made and written where you can open it");

    printf("    paintbrush fingerprint  %016llX\n",
           (unsigned long long)sprite_paintbrush_fingerprint());
    printf("    canvas                  %u by %u\n\n",
           (unsigned)SPRITE_CANVAS, (unsigned)SPRITE_CANVAS);

    for (which = 0; which < CATEGORY_COUNT; which++) {
        printf("    %-8s %u\n", categories[which],
               (unsigned)pool_in_category(library, categories[which]));
    }

    printf("\n    %u in the library.\n", (unsigned)pool_count(library));

    /* The RAM tier and the pool's own directory, ensured rather than assumed --
     * a demo that fails at its last step because a directory was missing has
     * wasted everything it did before that. */
    mkdir(SCRATCH, 0755);
    mkdir(directory, 0755);

    if (!pool_write(library, directory, &why)) {
        printf("\n    The library could not be written: %s\n", why);
        return;
    }

    printf("\n    Written to %s\n", directory);
    printf("    One SVG per sprite, plus a text index you can read and diff.\n");
    printf("\n    Open any of these in a browser and the creature moves. That is\n");
    printf("    the whole reason the format is what it is: somebody shown one\n");
    printf("    frozen frame of a walk cycle is judging an illustration.\n\n");

    if (write_contact_sheet(library, directory, 48)) {
        printf("      %s/contact-sheet.html   <-- OPEN THIS ONE\n",
               directory);
        printf("        every sprite in the library, sorted by tier, all moving\n\n");
    }

    for (which = 0; which < CATEGORY_COUNT; which++) {
        printf("      %s/%s-%u.svg\n", directory, categories[which], 3u);
    }

    /* And what one of them actually is, in words, so that reading the file is
     * not the only way to know what is in it. */
    {
        struct sprite s;
        char reasoning[256];
        uint32_t layer;

        sprite_make(&s, "goblin", 3);

        printf("\n    goblin, seed 3:\n");
        printf("      motion   %s\n", motion_name(s.motion));
        printf("      palette  #%06X  #%06X  #%06X\n",
               (unsigned)s.palette[SLOT_PRIMARY],
               (unsigned)s.palette[SLOT_SECONDARY],
               (unsigned)s.palette[SLOT_ACCENT]);

        for (layer = 0; layer < s.layer_count; layer++) {
            printf("      layer %u  %-8s %-9s at %+3d,%+3d radius %u\n",
                   (unsigned)layer,
                   shape_name(s.layers[layer].shape),
                   slot_name(s.layers[layer].slot),
                   (int)s.layers[layer].offset_x,
                   (int)s.layers[layer].offset_y,
                   (unsigned)s.layers[layer].radius);
        }

        printf("      graded   %s\n",
               sprite_machine_reasoning(&s, reasoning, sizeof(reasoning)));
    }
}
/* }}} */

/* {{{ static void show_both_algorithms */
static void show_both_algorithms(uint32_t per_category)
{
    struct sprite_pool a;
    struct sprite_pool b;
    uint32_t i;

    rule("Both algorithms, on the same batch");

    pool_init(&a, POOL_RATE_ON_ARRIVAL);
    pool_init(&b, POOL_JUDGE_THEN_CURATE);

    fill(&a, per_category, 1);
    fill(&b, per_category, 1);

    /*
     * Under A the machine has already spoken for everything, and a person
     * wanders past a handful. Under B nobody has spoken at all until a person
     * makes the opening pass over the whole library.
     */
    for (i = 1; i <= pool_count(&a); i++) {
        struct sprite s;

        /* One in eight gets looked at. That is what "a person rates a little,
         * whenever they feel like it" looks like as a number. */
        if (i % 8 != 0) {
            continue;
        }

        pool_sprite(&a, i, &s);
        pool_rate_by_person(&a, i, what_a_person_thinks(&s), "ritz", 2);
    }

    for (i = 1; i <= pool_count(&b); i++) {
        struct sprite s;

        pool_sprite(&b, i, &s);
        pool_rate_by_person(&b, i, what_a_person_thinks(&s), "ritz", 2);
    }

    printf("    rate-on-arrival: the machine judges everything as it lands, a\n");
    printf("    person judges a little whenever they like.\n");

    studio_summarise(&a, EVERY_CATEGORY, stdout);

    printf("\n\n    judge-then-curate: nothing is rated until a person looks, and\n");
    printf("    then the rating happens during play.\n");

    studio_summarise(&b, EVERY_CATEGORY, stdout);

    printf("\n    Neither is the better one. The first is for ten thousand\n");
    printf("    generated dandelions and gives a free, continuous measurement of\n");
    printf("    how far the machine's taste has drifted from yours. The second is\n");
    printf("    for the forty things that actually appear in your campaign, has\n");
    printf("    no drift failure at all because every rating is a person's, and\n");
    printf("    pays for that by being the size of one person's patience.\n");

    pool_release(&a);
    pool_release(&b);
}
/* }}} */

/* {{{ static void show_the_dial */
static void show_the_dial(struct sprite_pool *library, struct studio *studio)
{
    struct dial_report report;
    char sentence[512];
    uint8_t floor;

    rule("The dial, and what it costs to turn it");

    printf("    \"The goblin sprites are looking pretty bad -- can we increase\n");
    printf("     their quality?\"\n\n");

    printf("    Here is what each floor leaves to draw from:\n\n");
    printf("      floor   anybody   a person\n");
    printf("      -----   -------   --------\n");

    for (floor = 1; floor <= 5; floor++) {
        printf("      %5u   %7u   %8u\n", (unsigned)floor,
               (unsigned)pool_survivors(library, "goblin", floor,
                                        TRUST_ANYBODY, NULL, 0),
               (unsigned)pool_survivors(library, "goblin", floor,
                                        TRUST_A_PERSON, NULL, 0));
    }

    printf("\n    Two columns, because \"tier 4 or better\" and \"tier 4 or better\n");
    printf("    AS JUDGED BY A PERSON\" are different requests. The second is\n");
    printf("    smaller and more trustworthy. Confidence and quality are not the\n");
    printf("    same axis, and collapsing them loses the distinction exactly when\n");
    printf("    it matters.\n\n");

    studio_dial_report(library, "goblin", 3, 4, TRUST_ANYBODY, &report);
    printf("    %s\n", studio_dial_sentence(&report, sentence, sizeof(sentence)));

    printf("\n    Nothing has been applied. The price is quoted while the question\n");
    printf("    is still open, which is the entire point -- a trade discovered\n");
    printf("    afterwards, in the output, is not a trade anybody made.\n");

    studio_dial_report(library, "goblin", 3, 5, TRUST_ANYBODY, &report);
    printf("\n    And if that is not enough:\n\n");
    printf("    %s\n", studio_dial_sentence(&report, sentence, sizeof(sentence)));

    printf("\n    \"That's okay.\"\n");

    /* The offer, made once, declined, and never made again. */
    printf("\n    %s\n", studio_offer_sentence(library, "goblin",
                                               sentence, sizeof(sentence)));
    printf("\n    \"No, not now, thanks.\"\n\n");

    studio_decline(studio, "goblin");

    printf("    may the studio ask about goblins again?  %s\n",
           studio_may_offer(studio, "goblin") ? "yes" : "no");
    printf("    may it ask about wolves?                 %s\n",
           studio_may_offer(studio, "wolf") ? "yes" : "no");

    printf("\n    Declining changed nothing about the library -- not a tier, not\n");
    printf("    an entry, not an ordering. A studio that nags is a studio nobody\n");
    printf("    opens.\n");
}
/* }}} */

/* {{{ static void show_the_anchor */
static void show_the_anchor(struct sprite_pool *library)
{
    struct agreement measured;
    struct anchor anchored;
    char sentence[512];

    rule("The anchor, and the number that must never lie");

    /* First, a library nobody has rated -- the state every library starts in. */
    {
        struct sprite_pool untouched;
        struct agreement nothing;

        pool_init(&untouched, POOL_RATE_ON_ARRIVAL);
        fill(&untouched, 20, 1);

        studio_agreement(&untouched, EVERY_CATEGORY, &nothing);

        printf("    A library the machine has rated and nobody has looked at:\n\n");
        printf("      %s\n", studio_agreement_sentence(&nothing, sentence,
                                                       sizeof(sentence)));

        printf("\n    Not one hundred per cent. Nothing disagreed, and nothing\n");
        printf("    agreed either. Zero out of zero is silence, and reporting\n");
        printf("    silence as consensus is the single most dangerous number this\n");
        printf("    project could print -- it is exactly the reading that would\n");
        printf("    let the machine's taste replace yours with no error raised\n");
        printf("    anywhere.\n");

        pool_release(&untouched);
    }

    studio_agreement(library, "goblin", &measured);
    studio_anchor(library, "goblin", &anchored);

    printf("\n    And the goblins, where a person has actually been:\n\n");
    printf("      %s\n", studio_agreement_sentence(&measured, sentence,
                                                   sizeof(sentence)));
    printf("      %s\n", studio_anchor_sentence(&anchored, sentence,
                                                sizeof(sentence)));

    printf("\n    Which way it leans is kept separate from how often it is wrong,\n");
    printf("    because they answer different questions -- a grader that is\n");
    printf("    reliably one tier generous can be corrected, and one that is\n");
    printf("    randomly wrong has to be replaced.\n");
}
/* }}} */

/*
 * A fight, and somebody looking at a goblin in the middle of it.
 */
/* {{{ static void show_the_table */
static void show_the_table(struct sprite_pool *library)
{
    struct world w;
    struct pool *threads = pool_start(2);
    struct session s;
    uint32_t goblin;
    uint64_t hash_before;
    uint32_t entry;
    uint16_t answer;
    int beat;

    rule("A sprite re-tiered from the table, mid-fight");

    fixture_make_two_rooms(&w);

    goblin = world_add_thing(&w);
    {
        struct thing *t = world_thing(&w, goblin);

        t->x = M(3);
        t->y = M(3);
        t->radius = (uint16_t)(WC_ONE / 2);
        t->region = 1;
        t->kind = 5;
        t->sprite_category = string_pool_add(&w.strings, "goblin", 6);
        t->sprite_seed = 3;
    }

    session_start(&s, &w, threads, 12345, 8, 10);
    session_attach_sprites(&s, library);

    printf("    A goblin is standing in the tavern, wearing goblin seed 3.\n");
    printf("    Play is running: three beats go by.\n\n");

    for (beat = 0; beat < 3; beat++) {
        session_tick(&s);
    }

    hash_before = world_hash(&w);
    entry = pool_find(library, "goblin", 3);

    printf("      tick                %llu\n", (unsigned long long)s.sim.tick);
    printf("      world checksum      %016llX\n", (unsigned long long)hash_before);
    printf("      that goblin's tier  %u, set by %s\n",
           (unsigned)pool_tier(library, entry),
           pool_tier_provenance(library, entry) == RATED_BY_PERSON
               ? "a person" : "the machine");

    printf("\n    Somebody looks at it and thinks: that one is wrong.\n\n");

    answer = session_command(&s, VERB_RETIER, goblin, 2, 0);

    printf("      the command         %s\n", refusal_sentence(answer));
    printf("      tick                %llu\n", (unsigned long long)s.sim.tick);
    printf("      world checksum      %016llX  %s\n",
           (unsigned long long)world_hash(&w),
           world_hash(&w) == hash_before ? "(unchanged)" : "(MOVED -- wrong)");
    printf("      that goblin's tier  %u, set by %s, %s\n",
           (unsigned)pool_tier(library, entry),
           pool_tier_provenance(library, entry) == RATED_BY_PERSON
               ? "a person" : "the machine",
           pool_at(library, entry)->person_name);

    printf("\n    The world did not move. Not a position, not a beat, not the\n");
    printf("    checksum -- which is exactly what makes this safe to accept while\n");
    printf("    the fight is still going, and why it does not have to be rolled\n");
    printf("    back or replayed with everything else.\n");

    printf("\n    And what the machine thought is still there, underneath:\n\n");
    printf("      the machine said    %u\n",
           (unsigned)pool_at(library, entry)->machine_tier);
    printf("      the person said     %u\n",
           (unsigned)pool_at(library, entry)->person_tier);
    printf("\n    One field would have lost the first of those, and with it the\n");
    printf("    only evidence anybody has about whether the machine is any good.\n");

    printf("\n    Who said it is recorded as a SEAT, not a display name. A name is\n");
    printf("    display-only everywhere in this project, and a judgement that\n");
    printf("    outlives the evening must not be filed under something somebody\n");
    printf("    can change between one evening and the next.\n");

    printf("\n    Play carries on:\n\n");
    for (beat = 0; beat < 3; beat++) {
        session_tick(&s);
    }
    printf("      tick                %llu\n", (unsigned long long)s.sim.tick);

    printf("\n    A judgement made here is a different act from one made in a\n");
    printf("    gallery. In a gallery you are asked whether it is a good picture.\n");
    printf("    Here you are asked whether it read as a goblin at the moment you\n");
    printf("    needed it to, at that size, next to those other things.\n");

    session_release(&s);
    world_release(&w);
    pool_stop(threads);
}
/* }}} */

/* {{{ static void show_the_honesty */
static void show_the_honesty(struct sprite_pool *library)
{
    struct anchor anchored;
    char sentence[512];

    rule("What the grader is, and what is still open");

    printf("    The machine's tier is a HEURISTIC. It weighs five things:\n\n");
    printf("      layers      out of 24   -- four is best; one is a blob, six a pile\n");
    printf("      motion      out of 20   -- anything but still; the project's opinion\n");
    printf("      palette     out of 30   -- secondary near the primary, accent far\n");
    printf("      size        out of 14   -- a body filling about a third of the box\n");
    printf("      upright     out of 12   -- standing straight, not leaning to one side\n");

    printf("\n    That is a proxy for taste, and a crude one. Saying so matters,\n");
    printf("    because everything above exists to measure how far it has drifted\n");
    printf("    from a person's -- and a grader that is secretly a complexity\n");
    printf("    metric will drift somewhere nobody predicted.\n");

    printf("\n    The five tiers are separated by four numbers, and those numbers\n");
    printf("    were MEASURED rather than chosen:\n\n");

    {
        uint8_t tier;

        for (tier = 2; tier <= 5; tier++) {
            printf("      tier %u begins at %u of 100\n",
                   (unsigned)tier, (unsigned)sprite_machine_cut(tier));
        }
    }

    printf("\n    The first four were round numbers that looked reasonable.\n");
    printf("    Against real output they left tier one entirely empty and put\n");
    printf("    ninety per cent of everything into two tiers -- a five-point\n");
    printf("    scale that was really a three-point scale, which is worse than a\n");
    printf("    three-point scale because the two dead numbers look like\n");
    printf("    information.\n");

    printf("\n    Run 084-calibrate to check them against today's generator.\n");
    printf("    It has caught two drifts already. Mirroring the detail layers\n");
    printf("    moved all four numbers by two points. Correcting the balance\n");
    printf("    component to measure sideways lean only was worse -- it threw\n");
    printf("    three of the five tiers outside their intended share and the\n");
    printf("    tool refused outright. Nothing else in the project would have\n");
    printf("    said a word about either.\n");

    studio_anchor(library, EVERY_CATEGORY, &anchored);
    printf("\n    %s\n", studio_anchor_sentence(&anchored, sentence,
                                                sizeof(sentence)));

    printf("\n    Still open, and written down rather than left to be discovered:\n\n");
    printf("      A tier is a RANKING, not a verdict. Because the cut lines are\n");
    printf("      percentiles, tier five means \"in the best tenth of what this\n");
    printf("      paintbrush makes\". Improve the generator and the same tenth is\n");
    printf("      still tier five. The scale measures spread, not quality.\n");
    printf("      (open question 15.2)\n\n");
    printf("      Who runs the calibration, and when? The tool exits non-zero\n");
    printf("      when the tiers go adrift, so finding out is solved. Remembering\n");
    printf("      to look is not. (open question 15.1)\n\n");
    printf("      Which algorithm should a table run by default? Both are built\n");
    printf("      and they fail in opposite directions. (open question 10.1)\n\n");
    printf("      Who may re-tier during play? For now, whoever may edit the\n");
    printf("      world -- the narrow answer. Widening it later breaks nothing;\n");
    printf("      narrowing it later would. (open question 10.2)\n\n");
    printf("      Is the pool per-table or per-project? A campaign's curated\n");
    printf("      library and a shipped one are different social objects.\n");
    printf("      (open question 10.3)\n");
}
/* }}} */

/* {{{ int main */
int main(void)
{
    struct sprite_pool library;
    struct studio studio;
    const uint32_t per_category = 120;
    uint32_t i;

    /* Line-buffered, so a redirected run shows progress rather than looking
     * hung -- the same lesson as phase four's two programs. */
    setvbuf(stdout, NULL, _IOLBF, 0);

    printf("\n");
    printf("  ===============================================================\n");
    printf("   PHASE NINE -- the appearance layer is a studio, not a folder\n");
    printf("  ===============================================================\n");

    show_the_paintbrush();

    pool_init(&library, POOL_RATE_ON_ARRIVAL);
    studio_init(&studio);

    fill(&library, per_category, 1);

    /*
     * A person has been through some of them. Enough of the goblins to make the
     * agreement rate a measurement rather than an anecdote, and fewer of the
     * rest -- which is what a real library looks like and is why the anchor
     * reports per category rather than globally.
     */
    for (i = 1; i <= pool_count(&library); i++) {
        struct sprite s;

        if (strcmp(pool_at(&library, i)->category, "goblin") != 0) {
            if (i % 20 != 0) {
                continue;
            }
        } else if (i % 3 != 0) {
            continue;
        }

        pool_sprite(&library, i, &s);
        pool_rate_by_person(&library, i, what_a_person_thinks(&s), "ritz", 2);
    }

    show_a_batch(&library);
    show_both_algorithms(per_category);
    show_the_dial(&library, &studio);
    show_the_anchor(&library);
    show_the_table(&library);
    show_the_honesty(&library);

    printf("\n  ===============================================================\n");
    printf("   Nothing was deleted. There is no function that deletes.\n");
    printf("  ===============================================================\n\n");

    pool_release(&library);
    return 0;
}
/* }}} */
