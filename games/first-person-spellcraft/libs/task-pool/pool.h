/* pool.h — the lean worker pool: the engine's only threads. Public C API.
 *
 * What it is, in a sentence: N worker threads pulling tasks off one
 * mutex-protected FIFO queue — this is where every SoraMech box actually runs.
 *
 * A "task" is one C function plus a void* argument. A box firing is a task; the
 * frame-clock re-arming is a task spawning itself; an iterator looping is a task
 * re-spawning while its input slot still drains. Tasks may spawn more tasks
 * (including themselves) from inside an action — that is how the graph keeps
 * turning without any central loop.
 *
 * Modelled on SoraMech's `libs/task-pool/pool.c`, kept lean for this engine:
 * no per-worker language-spec init/teardown callbacks (our boxes are plain C,
 * nothing per-worker to set up), no priority queue (plain FIFO), and tuned for a
 * game that NEVER quiesces — the frame-clock keeps re-arming, so the pool stays
 * live until the program tears it down, not until the queue drains.
 *
 * The one thread NOT in this pool is the renderer: raylib's GL context is bound
 * to a single thread, so the draw runs on its own dedicated always-unblocked
 * thread (see docs/soramech-notes.md pattern 7), reading renderables from a slot.
 */
#ifndef FPS_POOL_H
#define FPS_POOL_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct pool pool_t;

/* A task: one function, one argument, no return. Errors are the task's own
 * business — the pool only dispatches. */
typedef void (*pool_task_t)(void *arg);

#define POOL_MAX_WORKERS 16

/* {{{ Lifecycle */
/* Create a pool and start its workers pulling immediately. n_workers <= 0
 * defaults to the online CPU count, capped at POOL_MAX_WORKERS. Returns NULL on
 * allocation / pthread failure. (No init barrier: with plain-C boxes there is no
 * per-worker setup to synchronize, so workers are live the moment they spawn.) */
pool_t *pool_create(int n_workers);

/* Stop accepting work, wake every worker, drain the queue, join all workers,
 * free. Safe on NULL. */
void    pool_destroy(pool_t *p);

int     pool_n_workers(const pool_t *p);
/* }}} */

/* {{{ Submission and wait */
/* Submit a task. Safe from any thread, including from inside another task (a box
 * re-arming itself, an iterator re-spawning). */
void    pool_spawn(pool_t *p, pool_task_t fn, void *arg);

/* Block until the in-flight-task count reaches zero. Useful for a one-shot
 * setup/teardown phase or a test; a running game with a live frame-clock never
 * reaches zero, so the game loop does NOT call this — it runs until a quit
 * signal tears the pool down. */
void    pool_wait_quiescent(pool_t *p);
/* }}} */

#ifdef __cplusplus
}
#endif

#endif /* FPS_POOL_H */
