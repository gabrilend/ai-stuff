/*
 * 085-sprite-pool.h -- every sprite ever made, kept, and what anybody thought
 * of it.
 *
 * NOTHING IS EVER DELETED. Not the bad ones. There is no function here that
 * removes an entry, and that is a design decision rather than an omission.
 *
 *   A low tier is information. It records what missed and by how much, which is
 *     the only evidence anybody has for whether the generator is getting better.
 *   Re-rating later can promote something scored in a hurry, and a pruned pool
 *     has thrown away the thing it would have promoted.
 *   A pool you prune is a pool whose history cannot be reconstructed, which
 *     makes every later question about why the output drifted unanswerable.
 *
 * Storage is cheap. Judgment is expensive. Never throw away the expensive thing
 * to save the cheap one.
 *
 * TWO TIERS ARE STORED, ONE IS EFFECTIVE. The machine's opinion and a person's
 * live in separate fields and neither ever overwrites the other; the effective
 * tier is the person's where there is one and the machine's otherwise.
 *
 * That is a deliberate departure from "both write the same field, the person's
 * wins". One field would work perfectly and would destroy, on every correction,
 * exactly the data the agreement rate is computed from -- and the agreement rate
 * is the whole reason for rating by machine at all. A grader nobody has measured
 * is not a grader, it is a rumour.
 *
 * WHAT THE POOL NEVER DOES: read a clock. Every rating's time is supplied by the
 * caller, because a session's time is its beat number and a person at a terminal
 * has a wall clock, and a store that reached for one of them would make the other
 * one lie. It also makes every test in 086 exactly reproducible.
 *
 * See docs/017-the-sprite-studio.md and issues 903, 904, 906, 907.
 */

#ifndef VTT_SPRITE_POOL_H
#define VTT_SPRITE_POOL_H

#include <stdint.h>

#include "023-blocks.h"
#include "082-sprite.h"

/* No entry. Index 0 of the block, same convention as everything else. */
#define POOL_NOTHING 0u

/* A tier of zero means nobody has said anything, which is not a low opinion. */
#define TIER_UNRATED 0u

/* Who set the effective tier. */
#define RATED_BY_NOBODY  0u
#define RATED_BY_MACHINE 1u
#define RATED_BY_PERSON  2u

/* How long a rater's name may be. Longer is refused rather than truncated. */
#define RATER_NAME_MAX 31

/*
 * The two rating algorithms. Both are built, both are tested, and neither is the
 * better one -- which one a table runs is a setting.
 *
 * RATE_ON_ARRIVAL is for ten thousand generated dandelions. The machine rates
 *   everything the moment it is made; a person rates a little whenever they feel
 *   like it. Large pool, thin judgment, and a free continuous measurement of how
 *   often the machine agrees with you.
 *
 * JUDGE_THEN_CURATE is for the forty things that actually appear in your
 *   campaign. Nothing is rated on arrival. A person passes over the library once,
 *   and after that the rating happens during play -- the moment somebody looks at
 *   a goblin mid-session and thinks that one is wrong. Small pool, complete
 *   judgment, and the judgment happens in context, which is a better question
 *   than a gallery can ask: did that read as a goblin at the moment I needed it
 *   to, at that size, next to those other things.
 *
 * It has no drift failure, because every rating is a person's and there is
 * nothing to drift from. It pays for that with a pool the size of one person's
 * patience. That asymmetry is the real difference between the two and it is not
 * the one people notice first.
 */
#define POOL_RATE_ON_ARRIVAL    0u
#define POOL_JUDGE_THEN_CURATE  1u

/*
 * Which ratings a query will accept.
 *
 * "Tier 4 or better" and "tier 4 or better as judged by a person" are different
 * requests, and the second is smaller and more trustworthy. Confidence and
 * quality are not the same axis, and collapsing them loses the distinction
 * exactly when it matters.
 */
#define TRUST_ANYBODY  0u
#define TRUST_A_PERSON 1u

struct pool_entry {
    /*
     * The description. With the seed this regenerates the sprite exactly, which
     * is why the pool does not store the sprite itself: a picture is a hundred
     * bytes of derived data and its description is forty.
     */
    char     category[SPRITE_NAME_MAX + 1];
    uint64_t seed;

    /*
     * The paintbrush and the canvas it came from.
     *
     * Without these a rating means nothing later. You cannot tell whether a bad
     * score was bad work or an impossible brief, and you cannot tell a rating of
     * this paintbrush from a rating of the one it replaced -- which is the
     * difference between "this goblin was badly drawn" and "this goblin was
     * drawn by a tool that no longer exists".
     */
    uint64_t paintbrush;
    uint32_t canvas;

    /* Neither of these ever overwrites the other. */
    uint8_t  machine_tier;
    uint64_t machine_when;

    uint8_t  person_tier;
    uint64_t person_when;
    char     person_name[RATER_NAME_MAX + 1];
};

struct sprite_pool {
    struct block entries;

    uint8_t  algorithm;

    /*
     * The fingerprint of the paintbrush this pool is being used with now, taken
     * once when it is opened. An entry whose own fingerprint differs was rated
     * against a different paintbrush, and the pool can say how many.
     */
    uint64_t paintbrush_now;
};

/*
 * Prepare a pool running one of the two algorithms. Returns 1, or 0 if memory
 * could not be found -- which a caller must treat as fatal rather than carrying
 * on with a library it could not build.
 */
int pool_init(struct sprite_pool *p, uint8_t algorithm);

void pool_release(struct sprite_pool *p);

/*
 * Put a sprite in the pool and return its entry.
 *
 * Under RATE_ON_ARRIVAL the machine rates it here and now, using the time given.
 * Under JUDGE_THEN_CURATE it arrives unrated and stays that way until a person
 * looks at it.
 *
 * Returns POOL_NOTHING when the category is not one a pool can hold -- see
 * pool_category_is_sound. A category is part of a filename, so this is a wall
 * rather than a preference.
 */
uint32_t pool_add(struct sprite_pool *p, const char *category, uint64_t seed,
                  uint64_t when);

/*
 * A category may be lowercase letters, digits, and dashes, and must not be
 * empty. Returns 1 when sound.
 *
 * It becomes a filename, and a category with a slash in it names a file
 * somewhere else entirely. Refusing here is refusing once; the alternative is
 * escaping it correctly at every place that ever writes it.
 */
int pool_category_is_sound(const char *category);

/*
 * Record what the machine thinks. Overwrites only the machine's own field, so a
 * person's rating is never touched by it.
 */
int pool_rate_by_machine(struct sprite_pool *p, uint32_t entry, uint64_t when);

/*
 * Record what a person thinks. Overwrites only the person's field, so the
 * machine's opinion survives every correction -- which is what makes the
 * agreement rate computable at all.
 *
 * Returns 0 when the tier is not 1 to 5, when the name is too long, or when the
 * entry does not exist. A rating that could not be recorded must not look like
 * one that was.
 */
int pool_rate_by_person(struct sprite_pool *p, uint32_t entry, uint8_t tier,
                        const char *who, uint64_t when);

/* The effective tier: the person's where there is one, the machine's otherwise. */
uint8_t pool_tier(const struct sprite_pool *p, uint32_t entry);

/* Who set the effective tier. */
uint8_t pool_tier_provenance(const struct sprite_pool *p, uint32_t entry);

/* How many entries, not counting the sentinel. */
uint32_t pool_count(const struct sprite_pool *p);

/* An entry, to read. Entry POOL_NOTHING gives the zeroed sentinel. */
const struct pool_entry *pool_at(const struct sprite_pool *p, uint32_t entry);

/* The entry for a description, or POOL_NOTHING. */
uint32_t pool_find(const struct sprite_pool *p, const char *category, uint64_t seed);

/*
 * Rebuild the picture from its description. This is why the pool stores a
 * description rather than a sprite: forty bytes regenerate a hundred, exactly,
 * for as long as the paintbrush has not changed -- and the entry records which
 * paintbrush it was, so "has not changed" is a question that can be asked.
 */
int pool_sprite(const struct sprite_pool *p, uint32_t entry, struct sprite *into);

/*
 * How many entries would survive a floor, and which.
 *
 * `into` may be a caller's array to fill with entry indices, or the count alone
 * is wanted and `capacity` is zero. The returned count is the true number that
 * survive, which may be larger than what fitted -- so a caller comparing two
 * floors gets the real answer even with a small array.
 */
uint32_t pool_survivors(const struct sprite_pool *p, const char *category,
                        uint8_t floor, uint8_t trust,
                        uint32_t *into, uint32_t capacity);

/* How many entries are in a category at all, rated or not. */
uint32_t pool_in_category(const struct sprite_pool *p, const char *category);

/* How many entries were made by a paintbrush other than the one in use now. */
uint32_t pool_from_another_paintbrush(const struct sprite_pool *p);

/*
 * Write the pool to a directory: one text index, and one SVG per entry.
 *
 * The index is text so it diffs and a person can read it. Returns 1, or 0 with
 * the reason written into `why` -- which is a sentence naming the file, not a
 * code.
 */
int pool_write(const struct sprite_pool *p, const char *directory,
               const char **why);

/*
 * Read a pool back. Everything survives: both tiers, both times, the rater's
 * name, and the paintbrush each entry was made by.
 *
 * A line the reader cannot understand stops the read and is named. A pool that
 * silently skipped a line it did not like would be a pool quietly deleting
 * entries, which is the one thing this file exists to prevent.
 */
int pool_read(struct sprite_pool *p, const char *directory, const char **why);

#endif
