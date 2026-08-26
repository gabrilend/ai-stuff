/*
 * 047-streams.h -- randomness that comes from somewhere you named.
 *
 * Nothing in this project calls a global random function. A caller asks for a
 * stream BY NAME -- "attack", "wandering-monsters", "dungeon-layout" -- and gets
 * a generator seeded from the session seed combined with that name.
 *
 * WHY NAMES, AND NOT ONE STREAM
 *
 * One generator couples every use of randomness to every other use. Add a roll
 * anywhere and every subsequent roll everywhere shifts: a ruleset that starts
 * checking one extra condition changes what monsters wander, what the dungeon
 * looked like, and every attack for the rest of the session.
 *
 * That makes a seed useless in practice. You could reproduce a session only if
 * you never changed any code -- which is exactly when you least need to.
 *
 * Named streams are independent. Adding a draw to "attack" leaves
 * "wandering-monsters" byte-identical, so a seed keeps meaning something across
 * changes to the program. That is the whole point of having one.
 *
 * See docs/011-the-rules-layer.md and issues/305-randomness-comes-from-named-streams.md.
 */

#ifndef VTT_STREAMS_H
#define VTT_STREAMS_H

#include <stdint.h>

/*
 * How many distinct names a session may use. Streams are named at build time by
 * the code that draws from them, plus whatever a ruleset registers at load, so
 * the number is known before anybody connects and the table never grows.
 */
#define STREAMS_MAX 64

/* A name longer than this is refused rather than truncated. */
#define STREAM_NAME_MAX 63

struct stream_registry {
    uint64_t seed;

    uint64_t name_hash[STREAMS_MAX];
    uint64_t state[STREAMS_MAX];
    uint32_t count;
};

/*
 * Prepare a registry for a session seed. No streams exist until they are asked
 * for by name.
 */
void streams_init(struct stream_registry *r, uint64_t seed);

/*
 * The index of the stream with this name, creating it if it is new.
 *
 * Returns STREAMS_MAX if the table is full or the name is too long, which a
 * caller must treat as an error naming what could not fit -- not as a stream it
 * can quietly draw from.
 *
 * The same name always gives the same stream for a given seed, forever. That is
 * why the name hash is frozen once chosen: changing it would silently retire
 * every seed anybody has written down.
 */
uint32_t stream_named(struct stream_registry *r, const char *name);

/* The next value from a stream. */
uint64_t stream_next(struct stream_registry *r, uint32_t stream);

/*
 * A value in [0, bound). Free of modulo bias -- taking a raw draw modulo a bound
 * makes the low values very slightly more likely, which is invisible in play and
 * shows up as a loaded die across ten thousand generated dungeons.
 *
 * A bound of 0 returns 0.
 */
uint64_t stream_below(struct stream_registry *r, uint32_t stream, uint64_t bound);

/*
 * A value in [low, high], inclusive at both ends, which is what a die is.
 * A high below a low returns low.
 */
int64_t stream_between(struct stream_registry *r, uint32_t stream,
                       int64_t low, int64_t high);

/*
 * ROLLBACK AND REPLAY DEPEND ON THESE. A stream's position must be part of every
 * snapshot: restore the world without restoring the dice and a retconned turn
 * draws different numbers for a reason nobody can see, which is the worst kind of
 * wrong because it looks like the retcon worked.
 */
void streams_copy(struct stream_registry *destination,
                  const struct stream_registry *source);

/* One number standing for every stream's position. Folded into the world hash. */
uint64_t streams_hash(const struct stream_registry *r);

/* How many streams have been named. What a demo reports. */
uint32_t streams_count(const struct stream_registry *r);

/* The name hash of a stream, for a demo that wants to show the table. */
uint64_t stream_name_hash(const struct stream_registry *r, uint32_t stream);

#endif
