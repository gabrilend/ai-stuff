// 050-units.h — Unit pool and rendering.
//
// Phase 1 has a single fixed pool of UNITS_MAX entries. Allocation
// is done up front; spawning reuses dead slots so the array index is
// also a stable id for the unit's lifetime.
//
// Until issue 102 lands the snapshot-mediated render path, the
// renderer reads this pool directly. The intended path
// (`docs/004-architecture.md` §"Snapshot") routes reads through a
// published front buffer; swapping is a one-line change at the
// renderer call site, not a redesign of this module.

#ifndef UNITS_H_
#define UNITS_H_

#include <raylib.h>
#include <stdbool.h>
#include <stdint.h>

#define UNITS_MAX 256

typedef struct Unit {
	int     id;          // pool index, stable for the unit's lifetime
	bool    alive;
	uint8_t team;
	Vector3 position;    // x,y world; z is terrain_height_at(x,y), kept in sync
	float   yaw;         // facing direction in radians
	bool    has_target;
	Vector2 target_xy;   // when has_target, walk toward this point
} Unit;

void units_init(void);
void units_tick(float dt);
void units_render(void);

// Returns the new unit's id on success, -1 if the pool is full.
// Z is set from terrain_height_at(x, y) at spawn time.
int  units_spawn(uint8_t team, float x, float y, float yaw);

// Assigns a movement target. The unit walks toward (target.x, target.y)
// at UNIT_SPEED until within UNIT_REACH_RADIUS, at which point the
// target is cleared. No-op for invalid id or dead units.
void units_set_target(int id, Vector2 target);

// Read-only access for queries (LoS, combat targeting, selection,
// etc.). Pointer into the pool, valid for the lifetime of the
// program. Returns NULL on out-of-range id.
const Unit *units_get(int id);

// Iteration: pool() returns a pointer to slot 0; count() returns the
// highest occupied slot index + 1. Iterate `[0, count)` and skip
// `!alive` entries — the pool is sparse, not compact.
const Unit *units_pool(void);
int         units_count(void);

#endif
