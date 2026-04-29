// 040-game-pool.c — Process-wide task pool implementation.
//
// File-static singleton. The pool itself is owned by libs/
// 900-task-pool; this file exists only so the rest of the project
// can use the pool without each caller having to know the worker
// count or lifecycle.
//
// game_pool_init is idempotent: a second call with the pool already
// alive is a no-op (rather than leaking the existing pool or
// destroying it mid-use). game_pool_shutdown is also idempotent.
// Both choices keep startup/shutdown sequences forgiving when the
// engine is being restructured.

#include "040-game-pool.h"

#include <stddef.h>

static task_pool_t *g_pool = NULL;

// {{{ void game_pool_init()
void game_pool_init(int n_workers)
{
	if (g_pool != NULL) return;
	g_pool = pool_create(n_workers);
}
// }}}

// {{{ void game_pool_shutdown()
void game_pool_shutdown(void)
{
	if (g_pool == NULL) return;
	pool_destroy(g_pool);
	g_pool = NULL;
}
// }}}

// {{{ task_pool_t *game_pool()
task_pool_t *game_pool(void)
{
	return g_pool;
}
// }}}
