// 050-units.c — Unit pool implementation.
//
// Static pool, allocated up front, indexed-as-id. Spawn finds the
// first dead slot (or the next never-used slot) and returns its
// index. The pool is sparse: the count is the highest occupied
// index + 1, *not* the number of alive units. Iterators must skip
// dead entries.
//
// Two teams in Phase 1 are scaffolding for testing combat (issues
// 111 / 113); the vision does not call for opposing players. The
// initial spawn places three of each team on opposite sides of the
// origin so combat work has something to look at when it lands.
//
// Z position is kept in sync with the terrain at the unit's X/Y.
// The renderer treats `position.z` as the *surface* and lifts the
// cube center by half its height when drawing — so the base sits
// flat on the ground per the mechanics doc.
//
// All cross-thread reads (sim → render in the eventual 102 world)
// go through the snapshot, not directly into this pool. Until that
// snapshot exists, the renderer reads the pool directly; the
// boundary is documented in the header.

#include "050-units.h"

#include <math.h>
#include <pthread.h>
#include <stddef.h>
#include <stdint.h>

#include <rlgl.h>

#include "020-terrain.h"
#include "040-game-pool.h"

// Local conversion to avoid including all of raymath.h just for one
// macro. atan2f produces radians, raylib's rlRotatef expects degrees.
#define UNITS_RAD2DEG 57.29577951f

// Unit dimensions. Height is taller than X/Y so the boxes read as
// "people-shaped" rather than "stone-shaped" against the 1-unit
// terrain tiles. Felt-quality numbers; revisit only if combat
// distances start to feel off.
#define UNIT_SIZE_X 0.8f
#define UNIT_SIZE_Y 0.8f
#define UNIT_SIZE_Z 1.5f

// Movement tunables. UNIT_SPEED is world units per second — at 5,
// crossing the 64-tile map takes ~13 s, which feels like a brisk
// march. UNIT_REACH_RADIUS keeps units from oscillating around
// their target; squared form precomputed so tick() avoids a sqrt.
static const float UNIT_SPEED              = 5.0f;
static const float UNIT_REACH_RADIUS       = 0.3f;
static const float UNIT_REACH_RADIUS_SQ    = UNIT_REACH_RADIUS * UNIT_REACH_RADIUS;

// Turn rate in radians per second. 1.5 rad/s ≈ 86°/s — slow enough
// that the rotate-then-walk sequence is visible, fast enough that
// units don't feel sluggish. Combined with the squared-cosine
// alignment falloff below, units "can't move well" until they're
// nearly facing their target. See docs/balance-updates.md for the
// felt-quality reasoning.
static const float UNIT_TURN_RATE          = 1.5f;
static const float UNITS_PI                = 3.14159265358979323846f;

// Team palette. Index = team id. Phase 1 uses two; raising this
// requires no code changes elsewhere as long as the spawn caller
// passes a team id within bounds.
static const Color TEAM_COLORS[] = {
	{  60, 110, 200, 255 },  // team 0 — blue
	{ 200,  70,  60, 255 },  // team 1 — red
};
#define TEAM_COUNT ((int)(sizeof(TEAM_COLORS) / sizeof(TEAM_COLORS[0])))

static struct {
	Unit pool[UNITS_MAX];
	int  count;
} g_units;

// Serializes the read-decide-spawn sequence around movement task
// lifecycle. Without it there is a race between `units_set_target`
// (main thread) and the movement task's reschedule action (worker
// thread) for the `movement_task_id` and `has_target` fields:
//
//   - Main: sees movement_task_id != NONE, skips spawn, sets has_target=true.
//   - Task: was about to clear movement_task_id (saw has_target=false
//     a moment ago), then clears it. Unit ends up has_target=true with
//     movement_task_id = NONE → stalled.
//
// One process-wide mutex is fine at Phase 1's unit count. Per-unit
// mutexes are an obvious upgrade if it ever shows up in a profile.
static pthread_mutex_t g_movement_mu = PTHREAD_MUTEX_INITIALIZER;

// {{{ static int alloc_slot()
// First dead slot scan. Linear because UNITS_MAX is small (256) and
// the pool is sparse but rarely full; a free-list would be premature
// at this size.
static int alloc_slot(void)
{
	for (int i = 0; i < UNITS_MAX; i++) {
		if (!g_units.pool[i].alive) return i;
	}
	return -1;
}
// }}}

// {{{ void units_init()
void units_init(void)
{
	for (int i = 0; i < UNITS_MAX; i++) {
		g_units.pool[i].id    = i;
		g_units.pool[i].alive = false;
	}
	g_units.count = 0;

	// Initial test spawn: three units per team in opposing clumps.
	// Positions are hand-picked rather than randomized so the world
	// is reproducible. Combat work (issue 113) gets a deterministic
	// starting state to debug against.
	units_spawn(0, -10.0f, -10.0f, 0.0f);
	units_spawn(0,  -8.0f, -12.0f, 0.0f);
	units_spawn(0, -12.0f,  -8.0f, 0.0f);
	units_spawn(1,  10.0f,  10.0f, 3.14159f);
	units_spawn(1,  12.0f,   8.0f, 3.14159f);
	units_spawn(1,   8.0f,  12.0f, 3.14159f);
}
// }}}

// {{{ int units_spawn()
int units_spawn(uint8_t team, float x, float y, float yaw)
{
	int slot = alloc_slot();
	if (slot < 0) return -1;
	Unit *u = &g_units.pool[slot];
	u->id               = slot;
	u->alive            = true;
	u->team             = team;
	u->position.x       = x;
	u->position.y       = y;
	u->position.z       = terrain_height_at(x, y);
	u->yaw              = yaw;
	u->has_target       = false;
	u->last_update_t    = 0.0;
	u->movement_task_id = TASK_ID_NONE;
	if (slot >= g_units.count) g_units.count = slot + 1;
	return slot;
}
// }}}

// ─── movement task (Shape B: per-unit self-rescheduling) ────────────
//
// Each moving unit owns a movement task that runs the chain
// [move_advance, move_reschedule]. The advance action does one
// timestamp-based step of motion; the reschedule action either
// spawns the next iteration (if the unit still has a target) or
// clears `movement_task_id` (if it doesn't).
//
// Args plumbing: each action's `args` is the unit id stuffed into a
// void* via intptr_t, so there is no per-task heap allocation.
//
// Concurrency: g_movement_mu protects movement_task_id + has_target
// transitions in `units_set_target` and `move_reschedule`. Position
// reads from the renderer are racy but visually tolerable; the
// snapshot pattern in 102 will make them not-racy later.

// Forward decl so move_reschedule can spawn another iteration whose
// actions[] points at these names.
static action_result_t move_advance   (task_ctx_t *ctx);
static action_result_t move_reschedule(task_ctx_t *ctx);

// {{{ static void spawn_movement_task()
// Spawn a fresh movement task for unit `id`. Caller holds
// g_movement_mu. Updates u->movement_task_id with the new GUID
// (or TASK_ID_NONE on failure — pool unavailable, registry full).
static void spawn_movement_task(int id, task_pool_t *pool)
{
	static action_fn_t acts[2] = { move_advance, move_reschedule };
	void *args[2] = { (void *)(intptr_t)id, (void *)(intptr_t)id };
	g_units.pool[id].movement_task_id = pool_spawn(pool, acts, args, 2,
	                                                /*priority=*/2);
}
// }}}

// {{{ static action_result_t move_advance()
// One timestamp-based step. Reads now → elapsed since
// last_update_t → advances yaw + position by speed*elapsed*cos²(err).
// Always returns ACT_ADVANCE so move_reschedule runs and handles
// movement_task_id bookkeeping; an arrival just sets has_target=false
// and lets reschedule do the cleanup.
static action_result_t move_advance(task_ctx_t *ctx)
{
	int id = (int)(intptr_t)ctx->args;
	if (id < 0 || id >= UNITS_MAX) return ACT_ADVANCE;
	Unit *u = &g_units.pool[id];
	if (!u->alive)      return ACT_ADVANCE;
	if (!u->has_target) return ACT_ADVANCE;

	double now = GetTime();
	float  dt  = (float)(now - u->last_update_t);
	if (dt < 0.0f) dt = 0.0f;
	u->last_update_t = now;

	float dx = u->target_xy.x - u->position.x;
	float dy = u->target_xy.y - u->position.y;
	float dist_sq = dx * dx + dy * dy;

	if (dist_sq <= UNIT_REACH_RADIUS_SQ) {
		u->has_target = false;
		return ACT_ADVANCE;
	}

	float desired_yaw = atan2f(dy, dx);
	float ang_err     = desired_yaw - u->yaw;
	if (ang_err >  UNITS_PI) ang_err -= 2.0f * UNITS_PI;
	if (ang_err < -UNITS_PI) ang_err += 2.0f * UNITS_PI;

	float max_yaw_step = UNIT_TURN_RATE * dt;
	float yaw_step     = ang_err;
	if (yaw_step >  max_yaw_step) yaw_step =  max_yaw_step;
	if (yaw_step < -max_yaw_step) yaw_step = -max_yaw_step;
	u->yaw += yaw_step;
	if (u->yaw >  UNITS_PI) u->yaw -= 2.0f * UNITS_PI;
	if (u->yaw < -UNITS_PI) u->yaw += 2.0f * UNITS_PI;

	// Squared-cosine alignment falloff for the "tanks/people" feel
	// (kept identical to the as-shipped serial version; tuning log
	// is in docs/balance-updates.md).
	float align = cosf(ang_err);
	if (align < 0.0f) align = 0.0f;
	align = align * align;
	float dist = sqrtf(dist_sq);
	float step = UNIT_SPEED * dt * align;
	if (step > dist) step = dist;

	float fx = cosf(u->yaw);
	float fy = sinf(u->yaw);
	u->position.x += fx * step;
	u->position.y += fy * step;
	u->position.z  = terrain_height_at(u->position.x, u->position.y);

	return ACT_ADVANCE;
}
// }}}

// {{{ static action_result_t move_reschedule()
// Decide whether to spawn the next iteration or terminate the
// movement chain. Holds g_movement_mu so the
// "check has_target then spawn-or-clear movement_task_id" sequence
// is atomic against units_set_target on the main thread.
static action_result_t move_reschedule(task_ctx_t *ctx)
{
	int id = (int)(intptr_t)ctx->args;
	if (id < 0 || id >= UNITS_MAX) return ACT_DONE;
	Unit *u = &g_units.pool[id];

	pthread_mutex_lock(&g_movement_mu);
	if (u->alive && u->has_target) {
		spawn_movement_task(id, ctx->pool);
	} else {
		u->movement_task_id = TASK_ID_NONE;
	}
	pthread_mutex_unlock(&g_movement_mu);
	return ACT_DONE;
}
// }}}

// {{{ void units_set_target()
// Set or update a unit's movement target. Idempotent w.r.t. the
// movement task — if a task is already alive for this unit, just
// updating target_xy is enough; the running task's next move_advance
// reads target_xy fresh and redirects smoothly.
void units_set_target(int id, Vector2 target)
{
	if (id < 0 || id >= UNITS_MAX) return;
	Unit *u = &g_units.pool[id];
	if (!u->alive) return;

	pthread_mutex_lock(&g_movement_mu);
	u->target_xy     = target;
	u->has_target    = true;
	// Reset the timestamp so the first step under the new target
	// isn't "all the time since the last walk." Without this, a unit
	// idle for ten seconds and then given a target would teleport
	// half its first step.
	u->last_update_t = GetTime();
	if (u->movement_task_id == TASK_ID_NONE) {
		task_pool_t *pool = game_pool();
		if (pool) spawn_movement_task(id, pool);
	}
	pthread_mutex_unlock(&g_movement_mu);
}
// }}}

// {{{ const Unit *units_get()
const Unit *units_get(int id)
{
	if (id < 0 || id >= UNITS_MAX) return NULL;
	return &g_units.pool[id];
}
// }}}

// {{{ const Unit *units_pool()
const Unit *units_pool(void)
{
	return g_units.pool;
}
// }}}

// {{{ int units_count()
int units_count(void)
{
	return g_units.count;
}
// }}}

// {{{ static Color team_color()
static Color team_color(uint8_t team)
{
	if (team >= TEAM_COUNT) return WHITE;
	return TEAM_COLORS[team];
}
// }}}

// {{{ static void draw_unit()
// One unit as a solid colored cube plus a black wire outline (so
// silhouettes read against busy terrain) plus a small "nose" cube
// stuck to the +X face of the body. The nose is what makes rotation
// visible — a square is rotation-symmetric in silhouette, so without
// an asymmetric feature the yaw update would be invisible.
//
// The whole render is wrapped in a translation + Z-axis rotation so
// the local +X axis after rlRotatef corresponds to the unit's
// "forward" direction. raylib's `DrawCube*V` always draw axis-aligned
// in their *local* (post-transform) space, so the cube primitives
// themselves don't need to know about yaw — the matrix carries the
// rotation for them.
static void draw_unit(const Unit *u)
{
	Vector3 body_size = { UNIT_SIZE_X, UNIT_SIZE_Y, UNIT_SIZE_Z };
	Color   body      = team_color(u->team);

	// "Nose" placed half-in-half-out of the +X face. Small enough
	// not to hide the body color, dark enough to be readable from
	// any camera angle.
	Vector3 nose_size = { 0.30f, 0.45f, 0.60f };
	Vector3 nose_pos  = { UNIT_SIZE_X * 0.5f, 0.0f, 0.0f };

	float center_z = u->position.z + UNIT_SIZE_Z * 0.5f;

	rlPushMatrix();
	rlTranslatef(u->position.x, u->position.y, center_z);
	rlRotatef(u->yaw * UNITS_RAD2DEG, 0.0f, 0.0f, 1.0f);

	DrawCubeV((Vector3){ 0.0f, 0.0f, 0.0f }, body_size, body);
	DrawCubeWiresV((Vector3){ 0.0f, 0.0f, 0.0f }, body_size, BLACK);

	DrawCubeV(nose_pos, nose_size, (Color){ 30, 30, 30, 255 });
	DrawCubeWiresV(nose_pos, nose_size, BLACK);

	rlPopMatrix();
}
// }}}

// {{{ void units_render()
void units_render(void)
{
	for (int i = 0; i < g_units.count; i++) {
		const Unit *u = &g_units.pool[i];
		if (!u->alive) continue;
		draw_unit(u);
	}
}
// }}}
