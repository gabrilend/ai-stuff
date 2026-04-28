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

#include <stddef.h>

#include "020-terrain.h"

// Unit dimensions. Height is taller than X/Y so the boxes read as
// "people-shaped" rather than "stone-shaped" against the 1-unit
// terrain tiles. Felt-quality numbers; revisit only if combat
// distances start to feel off.
#define UNIT_SIZE_X 0.8f
#define UNIT_SIZE_Y 0.8f
#define UNIT_SIZE_Z 1.5f

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
	if (slot >= g_units.count) g_units.count = slot + 1;
	return slot;
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
// One unit as a solid colored cube plus a black wire outline so
// silhouettes read against busy terrain. Base of the cube sits
// flush on the surface at the unit's X/Y, so center.z is the
// surface height plus half the unit's height.
static void draw_unit(const Unit *u)
{
	Vector3 center = {
		u->position.x,
		u->position.y,
		u->position.z + UNIT_SIZE_Z * 0.5f,
	};
	Vector3 size = { UNIT_SIZE_X, UNIT_SIZE_Y, UNIT_SIZE_Z };
	DrawCubeV(center, size, team_color(u->team));
	DrawCubeWiresV(center, size, BLACK);
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
