/* graph-test.c — proves the dispatch with a self-checking mouse round-trip.
 *
 * The graph:  heartbeat --tick--> mouse --deltas--> pose
 *   heartbeat : a source box; fires N times, each pushing one tick.
 *   mouse     : per tick, generates K mouse differentials and pushes them.
 *   pose      : drain-and-sums every differential into an accumulated position.
 *
 * The differentials are generated deterministically from the tick number, so an
 * INDEPENDENT authoritative sum can be computed after the run: sum over every
 * tick of every differential. If the pipeline lost, duplicated, or torn even one
 * value, pose's position and the authoritative sum diverge. They can only agree
 * if the whole trigger-on-ready + drain-and-sum path conserved every value,
 * however the threads happened to interleave. Temporary prover.
 */
#include "graph.h"

#include <stdio.h>
#include <stdint.h>

static int failures = 0;
static void check(const char *name, int cond)
{
    if (cond) printf("  ok  %s\n", name);
    else    { printf("  FAIL %s\n", name); failures++; }
}

/* {{{ lcg_delta() — the authoritative differential for (tick, i) */
/* One deterministic pseudo-random differential in [-10, 10], a pure function of
 * the tick number and the index within that tick. Being a pure function is what
 * lets the checker recompute the ground truth independently of the pipeline. */
static int32_t lcg_delta(uint32_t tick, int i)
{
    uint32_t x = tick * 2654435761u + (uint32_t)i * 40503u + 12345u;
    x ^= x >> 15; x *= 2246822519u; x ^= x >> 13;
    return (int32_t)(x % 21u) - 10;
}
/* }}} */

#define N_TICKS 5000
#define K_PER   4

/* {{{ box user state */
typedef struct { slot_id_t tick_out; int count; } hb_user;
typedef struct { slot_id_t delta_out; } mouse_user;
typedef struct { long position; } pose_user;
/* }}} */

/* {{{ hb_fn() — the heartbeat: push one tick, re-arm until N */
static int hb_fn(box_t *b)
{
    hb_user *u = b->user;
    int32_t tick = ++u->count;               /* ticks are 1..N */
    while (slot_push(b->slots, u->tick_out, &tick) == -1) { /* tiny queue: retry */ }
    return u->count < N_TICKS;               /* 1 = re-arm, 0 = stop */
}
/* }}} */

/* {{{ mouse_fn() — per tick, emit K differentials */
static int mouse_fn(box_t *b)
{
    mouse_user *u = b->user;
    int32_t tick;
    if (!slot_pop(b->slots, b->in[0], &tick)) return 0;   /* consume one tick */
    for (int i = 0; i < K_PER; i++) {
        int32_t d = lcg_delta((uint32_t)tick, i);
        while (slot_push(b->slots, u->delta_out, &d) == -1) { /* retry on full */ }
    }
    return 0;
}
/* }}} */

/* {{{ pose_fn() — drain-and-sum every differential into position */
static int pose_fn(box_t *b)
{
    pose_user *u = b->user;
    int32_t buf[64];
    int32_t got;
    do {
        got = slot_drain(b->slots, b->in[0], buf, 64);
        for (int32_t i = 0; i < got; i++) u->position += buf[i];
    } while (got == 64);          /* filled the buffer? there may be more */
    return 0;
}
/* }}} */

/* {{{ main() */
int main(void)
{
    printf("mouse round-trip:\n");
    pool_t *pool = pool_create(0);
    slot_store_t *slots = slot_store_create();

    /* Wires are shared slots. tick_slot feeds mouse; delta_slot feeds pose. */
    slot_id_t tick_slot  = slot_alloc(slots, SLOT_QUEUE, sizeof(int32_t), 64);
    slot_id_t delta_slot = slot_alloc(slots, SLOT_QUEUE, sizeof(int32_t), 64);

    pose_user  pu = { 0 };
    mouse_user mu = { delta_slot };
    hb_user    hu = { tick_slot, 0 };

    box_t pose  = { "pose",  pose_fn,  slots, pool, { delta_slot }, 1, { 0 }, 0, 0, &pu };
    box_t mouse = { "mouse", mouse_fn, slots, pool, { tick_slot },  1, { &pose }, 1, 0, &mu };
    box_t hb    = { "heartbeat", hb_fn, slots, pool, { 0 }, 0, { &mouse }, 1, 0, &hu };

    box_kick(&hb);                 /* start the graph */
    pool_wait_quiescent(pool);     /* run until it drains */

    /* Authoritative sum: independent of the pipeline. */
    long authoritative = 0;
    for (uint32_t t = 1; t <= N_TICKS; t++)
        for (int i = 0; i < K_PER; i++)
            authoritative += lcg_delta(t, i);

    printf("  (ticks=%d, K=%d, differentials=%d)\n", N_TICKS, K_PER, N_TICKS * K_PER);
    check("pose position == authoritative differential sum", pu.position == authoritative);
    check("heartbeat fired exactly N times", hu.count == N_TICKS);

    slot_store_destroy(slots);
    pool_destroy(pool);
    printf(failures ? "\n%d FAILURE(S)\n" : "\nall checks passed\n", failures);
    return failures ? 1 : 0;
}
/* }}} */
