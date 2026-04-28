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
#include <stddef.h>

#include <rlgl.h>

#include "020-terrain.h"

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
	u->id         = slot;
	u->alive      = true;
	u->team       = team;
	u->position.x = x;
	u->position.y = y;
	u->position.z = terrain_height_at(x, y);
	u->yaw        = yaw;
	u->has_target = false;
	if (slot >= g_units.count) g_units.count = slot + 1;
	return slot;
}
// }}}

// {{{ void units_set_target()
void units_set_target(int id, Vector2 target)
{
	if (id < 0 || id >= UNITS_MAX) return;
	Unit *u = &g_units.pool[id];
	if (!u->alive) return;
	u->target_xy  = target;
	u->has_target = true;
}
// }}}

// {{{ void units_tick()
// Per-tick movement. Each alive unit with a target:
//   1. Computes the desired yaw to face the target (atan2 of the
//      delta vector).
//   2. Rotates yaw toward the desired yaw at most UNIT_TURN_RATE
//      radians per tick.
//   3. Moves forward in its current facing direction with speed
//      scaled by cos(remaining_angular_error). This is the
//      "tanks/people" feel: a unit aimed dead-on moves at full
//      speed, a sideways unit barely moves, a backwards unit (>90°
//      off) doesn't move at all (cos clamped to 0). Naturally
//      gives a "rotate first, then walk" pacing without needing a
//      hard threshold.
//   4. Snaps Z to the surface so the unit hugs hills.
//
// Each unit's update reads/writes only its own slot —
// slice-disjoint per the architecture doc. Adopting the task pool
// later is a `for(slice) pool_spawn(...)` swap, no redesign.
void units_tick(float dt)
{
	for (int i = 0; i < g_units.count; i++) {
		Unit *u = &g_units.pool[i];
		if (!u->alive)      continue;
		if (!u->has_target) continue;

		float dx = u->target_xy.x - u->position.x;
		float dy = u->target_xy.y - u->position.y;
		float dist_sq = dx * dx + dy * dy;

		if (dist_sq <= UNIT_REACH_RADIUS_SQ) {
			u->has_target = false;
			continue;
		}

		// Desired heading and signed shortest-path angular error.
		// Both atan2 results are in (-π, π], so the raw difference
		// is in (-2π, 2π); a single 2π fold brings it to (-π, π].
		float desired_yaw = atan2f(dy, dx);
		float ang_err     = desired_yaw - u->yaw;
		if (ang_err >  UNITS_PI) ang_err -= 2.0f * UNITS_PI;
		if (ang_err < -UNITS_PI) ang_err += 2.0f * UNITS_PI;

		// Apply turn, capped by the per-tick rate.
		float max_yaw_step = UNIT_TURN_RATE * dt;
		float yaw_step     = ang_err;
		if (yaw_step >  max_yaw_step) yaw_step =  max_yaw_step;
		if (yaw_step < -max_yaw_step) yaw_step = -max_yaw_step;
		u->yaw += yaw_step;
		if (u->yaw >  UNITS_PI) u->yaw -= 2.0f * UNITS_PI;
		if (u->yaw < -UNITS_PI) u->yaw += 2.0f * UNITS_PI;

		// Forward speed scales with how aligned we already are.
		// Squared cosine (rather than plain cos) makes the falloff
		// sharper: 30° off = 75% speed, 45° = 50%, 60° = 25%, 90° =
		// 0. This is what gives the "tanks/people" feel — units
		// can't move well until they've nearly finished turning.
		// Plain cos felt too forgiving; logged in
		// docs/balance-updates.md.
		float align = cosf(ang_err);
		if (align < 0.0f) align = 0.0f;
		align = align * align;
		float dist = sqrtf(dist_sq);
		float step = UNIT_SPEED * dt * align;
		if (step > dist) step = dist;

		// Move along current heading, not along the target vector.
		// While turning, current heading is not the target vector,
		// so the unit traces a curve toward its destination — the
		// tank-style arc-in motion.
		float fx = cosf(u->yaw);
		float fy = sinf(u->yaw);
		u->position.x += fx * step;
		u->position.y += fy * step;
		u->position.z  = terrain_height_at(u->position.x, u->position.y);
	}
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
