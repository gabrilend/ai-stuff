/* graph.h — the dataflow dispatch: boxes, wires, and the trigger-on-ready rule
 * that makes the graph turn. Public C API.
 *
 * A box is one unit of work: a function plus its input ports. A wire is just a
 * shared slot — a producer box writes into a slot that is a consumer box's input
 * port, so "A feeds B" means A and B name the same slot id. The dispatch fires a
 * box when all its input ports hold a value, runs it on the pool, then checks
 * every downstream box and fires the ones that just became ready. Source boxes
 * (no inputs) re-arm themselves — that is the frame-clock heartbeat and the
 * iterator loop, the thing that keeps a long-running map turning.
 *
 * Two invariants keep it correct under real threads:
 *   single-spawn — a box in flight is never spawned again concurrently (an
 *                  atomic gate); its own completion re-checks for pending input.
 *   clear-then-recheck — on finishing, a box clears its gate BEFORE re-checking
 *                  its inputs, closing the race where input arrives in the gap.
 */
#ifndef FPS_GRAPH_H
#define FPS_GRAPH_H

#include "slot.h"
#include "../task-pool/pool.h"

#include <stdatomic.h>

#define BOX_MAX_IN   8
#define BOX_MAX_DOWN 8

typedef struct box box_t;

/* A box body: read inputs from the box's input slots, compute, push outputs into
 * the (shared) downstream slots. Returns 1 to keep re-arming (meaningful only
 * for a source box with no inputs — the heartbeat), 0 otherwise. */
typedef int (*box_fn_t)(box_t *self);

struct box {
    const char   *name;
    box_fn_t      fn;
    slot_store_t *slots;         /* the shared store all boxes read/write */
    pool_t       *pool;          /* the pool this box runs on */
    slot_id_t     in[BOX_MAX_IN];/* this box's input port slots */
    int           n_in;
    box_t        *down[BOX_MAX_DOWN]; /* boxes to re-check for readiness after we run */
    int           n_down;
    _Atomic int   in_flight;     /* single-spawn gate */
    void         *user;          /* box-specific state (output slot ids, counters) */
};

/* Spawn a box onto its pool iff it isn't already in flight (the single-spawn
 * gate). Used to kick source boxes to start the graph, and internally to fire
 * downstream boxes that just became ready. */
void box_kick(box_t *b);

#endif /* FPS_GRAPH_H */
