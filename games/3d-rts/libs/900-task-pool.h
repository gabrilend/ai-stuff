// 900-task-pool.h
//
// Action-array task pool. Workers run "tasks", where each task is a
// flat array of small atomic action functions executed in sequence.
// Actions can advance, jump, block, or finish the task. Each task
// has a parallel `result_slots[]` array (write-once per slot by the
// owning action) plus a parallel `result_filled[]` bool array that
// distinguishes "action k hasn't run yet" from "action k ran and
// chose to write NULL." Tasks have priorities (1 = highest, 10 =
// lowest) scheduled via the cycler pattern (1; 1,2; 1,2,3; ...;
// 1..10; 1,2; ...) so high priority dominates without starving low.
//
// See issues/114-coroutine-pool-library.md for the full design
// rationale, including the four-iteration history (coroutines →
// continuation-passing → action-array → demote-on-block) that led
// to the current shape.
//
// Quick mental model:
//
//     pool          — N worker pthreads sharing a registry, ten
//                     priority queues (arrays-of-pointers), and a
//                     refcounted task table.
//     task          — a row in the registry, identified by a 64-bit
//                     GUID, containing actions[], action_args[],
//                     result_slots[], result_filled[], and a
//                     mutable priority field.
//     action        — a function `action_result_t f(task_ctx_t *)`.
//                     Reads ctx->args, may write to its own result
//                     slot, returns one of ACT_ADVANCE, ACT_JUMP,
//                     ACT_BLOCK, ACT_DONE.
//     ACT_BLOCK     — "I can't progress right now." The library
//                     parks the task on the blocker's waiters[]
//                     list (zero CPU until woken), and promotes
//                     the blocker by one level if it's in the
//                     ready queue. When the blocker reaches DONE,
//                     it walks its waiters[] and pushes each onto
//                     the ready queue, where workers pick them up
//                     and re-run the blocking action. ctx->block_on
//                     MUST be a valid id of a non-self task; the
//                     library aborts otherwise.
//
// Cross-task waits are expressed by reading another task's result
// slot via pool_result_slot inside an action. If the slot is
// SLOT_PENDING, the action sets ctx->block_on to the producer's id
// and returns ACT_BLOCK.
//
// Wait cycles (A parks on B, B parks on A) are not detected. Both
// park forever. Callers must avoid them.

#ifndef TASK_POOL_H
#define TASK_POOL_H

#include <stddef.h>
#include <stdint.h>

// Opaque pool handle.
typedef struct task_pool task_pool_t;

// Task identifier. 0 is the "no task" sentinel; real GUIDs start at 1.
typedef uint64_t task_id_t;
#define TASK_ID_NONE ((task_id_t)0)

// What an action wants to happen next. Returned from every action;
// the worker dispatches on this value to decide whether to run the
// next action, jump, suspend, or end the task.
typedef enum {
    ACT_ADVANCE,  // run actions[current_index + 1] next.
    ACT_JUMP,     // run actions[ctx->jump_to] next. Must set jump_to.
    ACT_BLOCK,    // park self on block_on's waiters[]; promote block_on
                  // if in ready queue. When block_on reaches DONE, this
                  // task is pushed back onto the ready queue and the same
                  // action runs again. ctx->block_on must be valid.
    ACT_DONE,     // task is finished. Skip remaining actions.
} action_result_t;

// Result of a pool_result_slot read. Distinguishes "not yet
// written" from "written, and the value happens to be NULL" — both
// would collapse to NULL under a pointer-only return.
typedef enum {
    SLOT_FILLED,         // action k completed; *out is its (possibly NULL) value.
    SLOT_PENDING,        // action k has not yet completed.
    SLOT_OUT_OF_RANGE,   // slot < 0 or slot >= n_actions.
    SLOT_UNKNOWN_ID,     // id not in the registry.
} slot_status_t;

// Forward declaration so task_ctx_t can hold a pool pointer.
struct task_pool;

// Per-call context passed to every action. Fields are grouped:
// identity, inputs, outputs, and a back-pointer to the pool so
// actions can call pool_result_slot without args plumbing.
typedef struct task_ctx {
    // ─── identity ────────────────────────────────────────
    task_id_t           self_id;
    int                 current_index;

    // ─── inputs ──────────────────────────────────────────
    void               *args;           // = action_args[current_index].
    void              **result_slots;   // = task->result_slots; result_slots[k]
                                        // is action k's output (NULL or value).
    int                 n_slots;        // = task's n_actions; bound for result_slots.
    struct task_pool   *pool;           // for pool_result_slot etc.
    int                 priority;       // task's current priority (1=high, 10=low).
                                        // May differ from spawn-time priority due
                                        // to demote-on-block accumulation. Action
                                        // can use this to know whether it's running
                                        // degraded.

    // ─── outputs ─────────────────────────────────────────
    int                 jump_to;        // valid ONLY when returning ACT_JUMP.
    task_id_t           block_on;       // REQUIRED when returning ACT_BLOCK.
                                        //   Must be a valid id of a non-self
                                        //   task. The library parks self on
                                        //   that task's waiters list. An
                                        //   invalid block_on (NONE, self, or
                                        //   missing-from-registry) is a
                                        //   programming bug — the library
                                        //   aborts with a diagnostic.
} task_ctx_t;

typedef action_result_t (*action_fn_t)(task_ctx_t *ctx);

// ─── pool lifecycle ──────────────────────────────────────────────

// Create a pool of n_workers pthreads. n_workers must be >= 1.
// Returns NULL on bad arg / allocation failure.
task_pool_t *pool_create(int n_workers);

// Signal shutdown, join all workers, free the pool. Tasks remaining
// at destroy time are leaked — caller is expected to have spun the
// pool down to quiescence first.
void pool_destroy(task_pool_t *pool);

// ─── spawning ────────────────────────────────────────────────────

// Spawn a task with the given actions array and parallel per-action
// args array (both of length n_actions, both copied internally).
//
// `priority` is clamped to [1, 10]. 1 is highest, 10 is lowest.
//
// As of iter4: there is no `deps` parameter. Cross-task waits are
// expressed by reading another task's result slot via
// `pool_result_slot` inside an action and returning ACT_BLOCK
// (with `block_on` set to the producer's id) if the slot is pending.
//
// Returns the task's GUID, or TASK_ID_NONE on error.
task_id_t pool_spawn(task_pool_t *pool,
                     const action_fn_t *actions,
                     void *const      *action_args,
                     int               n_actions,
                     int               priority);

// ─── refcount ────────────────────────────────────────────────────

// Bump the refcount on a task. Use when storing a GUID somewhere
// that must outlive the task's natural lifecycle (e.g., to read
// results from outside).
void pool_ref(task_pool_t *pool, task_id_t id);

// Drop a refcount. Last drop frees the task and removes it from the
// registry.
void pool_unref(task_pool_t *pool, task_id_t id);

// ─── queries ─────────────────────────────────────────────────────

// Read action `slot`'s output. Writes the value to *out (which may
// be NULL if action k chose to write NULL) and returns SLOT_FILLED.
// Returns SLOT_PENDING if action k has not yet completed,
// SLOT_OUT_OF_RANGE if slot is outside [0, n_actions), or
// SLOT_UNKNOWN_ID if `id` is not in the registry.
//
// Does NOT change refcount. Caller must ensure the task is still
// alive (via pool_ref, or by the pool's reference not yet having
// been dropped).
slot_status_t pool_result_slot(task_pool_t *pool,
                                task_id_t id,
                                int slot,
                                void **out);

// Returns 1 if the task has completed, 0 if still alive in some
// queue, -1 if id is unknown to the registry.
int pool_is_done(task_pool_t *pool, task_id_t id);

#endif
