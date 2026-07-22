/* graph.c — the trigger-on-ready dispatch.
 *
 * How it works, for a general reader: every box, when it runs, does three things
 * in order — its own work, then a look at each box it feeds to wake the ones now
 * ready, then a check on itself in case fresh input arrived while it was busy.
 * A one-bit "in flight" gate makes sure no box is ever running in two places at
 * once. That is the whole engine: no central loop, just boxes waking boxes.
 */
#include "graph.h"

/* {{{ local box_inputs_ready() */
/* True iff every one of the box's input ports currently holds a value. A source
 * box (no inputs) is trivially "ready" — but sources are driven by their own
 * re-arm, not by this check, so this is only ever asked of input-driven boxes. */
static int box_inputs_ready(box_t *b)
{
    for (int i = 0; i < b->n_in; i++)
        if (!slot_has_value(b->slots, b->in[i])) return 0;
    return 1;
}
/* }}} */

/* {{{ local box_dispatch() — the pool task run per box firing */
static void box_dispatch(void *arg);

/* {{{ box_kick() */
void box_kick(box_t *b)
{
    /* CAS the gate 0 -> 1. Only the thread that wins the flip gets to spawn, so
     * a box made ready by two producers at once is still scheduled exactly once. */
    int expected = 0;
    if (atomic_compare_exchange_strong(&b->in_flight, &expected, 1))
        pool_spawn(b->pool, box_dispatch, b);
}
/* }}} */

static void box_dispatch(void *arg)
{
    box_t *b = arg;
    int keep = b->fn(b);   /* the box's real work: read inputs, push outputs */

    /* Wake every downstream box that just became ready. box_kick's CAS gate
     * means a box already running (or already queued) is not double-spawned. */
    for (int i = 0; i < b->n_down; i++)
        if (box_inputs_ready(b->down[i])) box_kick(b->down[i]);

    if (b->n_in == 0) {
        /* Source box (the heartbeat). Two paths:
         *   keep -> re-arm: spawn ourselves again. The gate stays 1, so the
         *           source is a single serial chain, never overlapping itself.
         *   done -> release the gate; the source stops and the graph can drain. */
        if (keep) pool_spawn(b->pool, box_dispatch, b);
        else      atomic_store(&b->in_flight, 0);
    } else {
        /* Input-driven box. Clear the gate FIRST, then re-check our own inputs:
         * if a value landed while we were running, we (or a racing producer's
         * box_kick) re-fire it. Clearing before checking is what closes the
         * missed-wakeup race — a producer that pushed in the gap will win the
         * CAS if we don't. */
        atomic_store(&b->in_flight, 0);
        if (box_inputs_ready(b)) box_kick(b);
    }
}
/* }}} */
