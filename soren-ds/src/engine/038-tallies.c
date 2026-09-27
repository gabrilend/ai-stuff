/*
 * 038-tallies.c — the tallies sink boxes write to.
 *
 * General description: two tables of (count, sum) pairs, one line each so
 * two stations' tallies never share a cache line, updated with atomic adds
 * from whichever core ran the sink.
 */
#include "027-primitives.h"
#include "038-tallies.h"

#define TALLY_SLOTS 4096

struct tally {
    uint64_t count;
    int64_t  sum;
} LINE_ALIGNED;

static struct tally received[TALLY_SLOTS];
static struct tally refused[TALLY_SLOTS];

/* {{{ tally_add */
void tally_add(int32_t station, int64_t value)
{
    struct tally *t = &received[(uint32_t)station % TALLY_SLOTS];
    atomic_add(&t->count, 1);
    atomic_add(&t->sum, value);
}
/* }}} */

/* {{{ tally_refusal */
void tally_refusal(int32_t station, int64_t value)
{
    struct tally *t = &refused[(uint32_t)station % TALLY_SLOTS];
    atomic_add(&t->count, 1);
    atomic_add(&t->sum, value);
}
/* }}} */

/* {{{ tally_read */
void tally_read(int32_t station, uint64_t *count, int64_t *sum)
{
    struct tally *t = &received[(uint32_t)station % TALLY_SLOTS];
    *count = atomic_load_acquire(&t->count);
    *sum   = atomic_load_acquire(&t->sum);
}
/* }}} */

/* {{{ tally_refusals */
void tally_refusals(int32_t station, uint64_t *count, int64_t *sum)
{
    struct tally *t = &refused[(uint32_t)station % TALLY_SLOTS];
    *count = atomic_load_acquire(&t->count);
    *sum   = atomic_load_acquire(&t->sum);
}
/* }}} */

/* {{{ tally_reset */
void tally_reset(void)
{
    bytes_zero(received, sizeof received);
    bytes_zero(refused, sizeof refused);
}
/* }}} */
