/*
 * 047-streams.c -- splitmix, a frozen name hash, and no modulo bias.
 *
 * Interface and reasoning are in 047-streams.h.
 *
 * The generator is splitmix64: a counter, then three rounds of shift-xor-multiply
 * to scramble it. Chosen because it is a dozen lines with no dependency and no
 * version of its own.
 *
 * That last part is the real argument. A generator taken from a library can
 * change between releases, and when it does it takes the meaning of every seed
 * anybody wrote down with it -- silently, because the new one produces perfectly
 * good random numbers, just different ones.
 */

#include "047-streams.h"

#include <string.h>

/*
 * The golden-ratio increment and the two mixing constants, from splitmix64.
 * FROZEN. Changing any of them retires every seed in existence.
 */
#define SPLITMIX_GAMMA 0x9E3779B97F4A7C15ull
#define SPLITMIX_MIX_A 0xBF58476D1CE4E5B9ull
#define SPLITMIX_MIX_B 0x94D049BB133111EBull

/* FNV-1a, also frozen, for the same reason. */
#define FNV_OFFSET 1469598103934665603ull
#define FNV_PRIME  1099511628211ull

/* {{{ static uint64_t splitmix */
static uint64_t splitmix(uint64_t *state)
{
    uint64_t z;

    *state += SPLITMIX_GAMMA;

    z = *state;
    z = (z ^ (z >> 30)) * SPLITMIX_MIX_A;
    z = (z ^ (z >> 27)) * SPLITMIX_MIX_B;

    return z ^ (z >> 31);
}
/* }}} */

/* {{{ static uint64_t hash_name */
static uint64_t hash_name(const char *name)
{
    uint64_t h = FNV_OFFSET;
    uint32_t i;

    for (i = 0; name[i] != '\0' && i <= STREAM_NAME_MAX; i++) {
        h ^= (uint64_t)(uint8_t)name[i];
        h *= FNV_PRIME;
    }

    return h;
}
/* }}} */

/* {{{ void streams_init */
void streams_init(struct stream_registry *r, uint64_t seed)
{
    memset(r, 0, sizeof(struct stream_registry));
    r->seed = seed;
}
/* }}} */

/* {{{ uint32_t stream_named */
uint32_t stream_named(struct stream_registry *r, const char *name)
{
    uint64_t h;
    uint32_t i;

    if (name == NULL || name[0] == '\0') {
        return STREAMS_MAX;
    }

    /*
     * Too long is refused rather than truncated. Two names that differ only past
     * the cut would silently become one stream, and the two things drawing from
     * them would start interfering in a way nothing reports.
     */
    for (i = 0; name[i] != '\0'; i++) {
        if (i > STREAM_NAME_MAX) {
            return STREAMS_MAX;
        }
    }

    h = hash_name(name);

    for (i = 0; i < r->count; i++) {
        if (r->name_hash[i] == h) {
            return i;
        }
    }

    /*
     * Full. Refused, so that a session which wants more streams than the table
     * holds says so, rather than silently reusing one and making two unrelated
     * things interfere.
     */
    if (r->count >= STREAMS_MAX) {
        return STREAMS_MAX;
    }

    i = r->count;
    r->name_hash[i] = h;

    /*
     * The starting position is the session seed and the name hash mixed
     * together, so two sessions with different seeds disagree everywhere, and
     * two streams within one session are independent.
     */
    {
        uint64_t mixed = r->seed ^ h;
        r->state[i] = splitmix(&mixed);
    }

    r->count++;

    return i;
}
/* }}} */

/* {{{ uint64_t stream_next */
uint64_t stream_next(struct stream_registry *r, uint32_t stream)
{
    /*
     * An unknown stream index returns zero rather than reading past the table.
     * Callers get their index from stream_named, which reports failure by
     * returning STREAMS_MAX -- so reaching here with a bad index means the caller
     * ignored that, and a constant zero is a far more visible symptom than a
     * plausible random number would be.
     */
    if (stream >= r->count) {
        return 0;
    }

    return splitmix(&r->state[stream]);
}
/* }}} */

/* {{{ uint64_t stream_below */
uint64_t stream_below(struct stream_registry *r, uint32_t stream, uint64_t bound)
{
    uint64_t threshold;

    if (bound == 0) {
        return 0;
    }

    /*
     * Rejection sampling. Taking a raw draw modulo the bound makes the low values
     * very slightly more likely, because the generator's range does not divide
     * evenly by the bound -- invisible in one roll, and a loaded die across ten
     * thousand generated dungeons.
     *
     * The threshold is 2^64 mod bound, computed as (-bound) mod bound because
     * 2^64 does not fit in the type. Draws below it are discarded.
     */
    threshold = (0u - bound) % bound;

    for (;;) {
        uint64_t value = stream_next(r, stream);

        if (value >= threshold) {
            return value % bound;
        }
    }
}
/* }}} */

/* {{{ int64_t stream_between */
int64_t stream_between(struct stream_registry *r, uint32_t stream,
                       int64_t low, int64_t high)
{
    uint64_t span;

    /* An empty or backwards range gives its low end rather than nothing. */
    if (high <= low) {
        return low;
    }

    /*
     * Inclusive at both ends, which is what a die is: a d6 rolls 1 through 6, not
     * 1 through 5. Computed in unsigned so that a range spanning zero does not
     * overflow on the subtraction.
     */
    span = (uint64_t)(high - low) + 1u;

    return low + (int64_t)stream_below(r, stream, span);
}
/* }}} */

/* {{{ void streams_copy */
void streams_copy(struct stream_registry *destination,
                  const struct stream_registry *source)
{
    /*
     * A whole-registry copy, taken at the head of every turn along with the
     * world and the fog. Restoring the world without this makes a retconned turn
     * roll different dice for a reason nobody can see -- which looks exactly like
     * the retcon having worked, and is the hardest kind of wrong to notice.
     */
    memcpy(destination, source, sizeof(struct stream_registry));
}
/* }}} */

/* {{{ uint64_t streams_hash */
uint64_t streams_hash(const struct stream_registry *r)
{
    uint64_t h = FNV_OFFSET;
    uint32_t i;
    uint32_t byte;

    /*
     * Folded into the world hash, so that two worlds which look identical but
     * will roll differently are correctly reported as different worlds. Fed a
     * byte at a time in a fixed order so the answer does not depend on the
     * machine's byte order.
     */
    for (i = 0; i < r->count; i++) {
        for (byte = 0; byte < 8; byte++) {
            h ^= (r->name_hash[i] >> (byte * 8)) & 0xFFu;
            h *= FNV_PRIME;
        }
        for (byte = 0; byte < 8; byte++) {
            h ^= (r->state[i] >> (byte * 8)) & 0xFFu;
            h *= FNV_PRIME;
        }
    }

    return h;
}
/* }}} */

/* {{{ uint32_t streams_count */
uint32_t streams_count(const struct stream_registry *r)
{
    return r->count;
}
/* }}} */

/* {{{ uint64_t stream_name_hash */
uint64_t stream_name_hash(const struct stream_registry *r, uint32_t stream)
{
    if (stream >= r->count) {
        return 0;
    }

    return r->name_hash[stream];
}
/* }}} */
