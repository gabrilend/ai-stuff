// 040-game-pool.h — Process-wide task pool for parallel sim work.
//
// Owned by main(). Other modules read it via `game_pool()` —
// they never create their own. Lifecycle: `game_pool_init(N)`
// once after the world modules are ready, `game_pool_shutdown()`
// once before the window closes.
//
// Wrapping the raw pool API is intentional: the pool's lifecycle
// is bound to the rest of the engine's startup/shutdown, and a
// thin singleton means no code path has to thread a `task_pool_t *`
// through every function. See issue 122 for the rationale.

#ifndef GAME_POOL_H_
#define GAME_POOL_H_

#include "900-task-pool.h"

void         game_pool_init(int n_workers);
void         game_pool_shutdown(void);

// Returns the process-wide pool, or NULL if init has not yet run
// or shutdown has already run. Callers can treat NULL as "fall
// back to serial execution"; it is the legitimate state during
// very early startup or after shutdown.
task_pool_t *game_pool(void);

#endif
