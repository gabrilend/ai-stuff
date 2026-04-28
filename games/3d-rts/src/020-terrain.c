// 020-terrain.c — Heightmap terrain implementation.
//
// The heightmap is generated once at startup from a sum of sine
// octaves with mild phase offsets — deterministic, so the same world
// reproduces without persistence. Hills are tall enough to break line
// of sight (issue 111 will rely on this) without making the unit's
// view feel like a rollercoaster: peak-to-peak Z range is ~6 units.
//
// raylib's GenMeshHeightmap helper assumes Y-up, which would put our
// height in the wrong axis. So the mesh is built by hand: one vertex
// per grid corner, two triangles per tile, indexed for memory
// efficiency. Lighting is baked per-vertex from a fixed sun direction
// because the default raylib shader does not consume normals — the
// vertex color is the only knob the GPU actually looks at, and
// per-vertex lighting through it gives readable shading "for free."
//
// terrain_height_at and terrain_segment_blocked are queries against
// the static heights array. They run from any thread without a lock
// once terrain_init has returned. This is the cheapest possible
// thread sharing: const data does not need a mutex.

#include "020-terrain.h"

#include <math.h>

#include <raylib.h>
#include <raymath.h>

// Tunables. Local to this file for now; promote to 010-config.h once
// other modules need to know about them.

// 64×64 tiles → 65×65 heightmap vertices, world from -32 to +32.
#define MAP_SIZE_TILES   64
#define MAP_VERTS        (MAP_SIZE_TILES + 1)
#define TILE_SIZE_WORLD  1.0f
#define MAP_HALF_WORLD   ((float)MAP_SIZE_TILES * TILE_SIZE_WORLD * 0.5f)

// Procedural noise octaves: { amplitude, freq_x, freq_y }. Felt-quality
// numbers tuned so that low-frequency hills dominate the shape and
// the higher octaves add character without dominating LoS-relevant
// silhouettes.
static const float NOISE_OCTAVES[][3] = {
	{ 2.5f, 0.15f, 0.13f },
	{ 1.0f, 0.40f, 0.35f },
	{ 0.4f, 0.90f, 1.10f },
};
#define NOISE_OCTAVE_COUNT ((int)(sizeof(NOISE_OCTAVES) / sizeof(NOISE_OCTAVES[0])))

// Static "sun" direction for the lighting bake. Pointing slightly off
// straight-up so slopes self-shade differently across the map.
// Coordinates here are world-space (Z-up).
static const Vector3 SUN_DIR = { 0.4f, 0.5f, 0.8f };

// Ambient floor and full-sun ceiling for the bake. 0.45 is enough to
// keep the dark side legible while still letting the sun-facing side
// have visible shading.
static const float LIGHT_AMBIENT = 0.45f;

// Singleton state. The heights array is read-only after terrain_init
// returns and is safe to read from any thread without a lock. The
// mesh and material are owned by the main thread.
static struct {
	float    heights[MAP_VERTS][MAP_VERTS];
	Mesh     mesh;
	Material material;
	bool     initialized;
} g_terrain;

// {{{ static float noise_at_world()
// Evaluates the height function at a world-space (x, y). Used both
// by the grid generator and (in principle) by anything that wants a
// "what would this position be if the grid were continuous" answer —
// only the grid generator calls it today.
static float noise_at_world(float x, float y)
{
	float z = 0.0f;
	for (int k = 0; k < NOISE_OCTAVE_COUNT; k++) {
		float amp = NOISE_OCTAVES[k][0];
		float fx  = NOISE_OCTAVES[k][1];
		float fy  = NOISE_OCTAVES[k][2];
		z += amp * sinf(x * fx + (float)k * 0.7f) *
		           cosf(y * fy + (float)k * 1.3f);
	}
	return z;
}
// }}}

// {{{ static Vector3 normal_at_grid()
// Per-vertex normal via central differences over the heightmap.
// Boundary cells fall back to one-sided differences.
static Vector3 normal_at_grid(int i, int j)
{
	int ip = (i + 1 < MAP_VERTS) ? i + 1 : i;
	int im = (i - 1 >= 0)        ? i - 1 : i;
	int jp = (j + 1 < MAP_VERTS) ? j + 1 : j;
	int jm = (j - 1 >= 0)        ? j - 1 : j;
	float dx = (g_terrain.heights[ip][j] - g_terrain.heights[im][j]) /
	           ((float)(ip - im) * TILE_SIZE_WORLD);
	float dy = (g_terrain.heights[i][jp] - g_terrain.heights[i][jm]) /
	           ((float)(jp - jm) * TILE_SIZE_WORLD);
	// Tangents: t_x = (1, 0, dx), t_y = (0, 1, dy).
	// Surface normal = cross(t_x, t_y) = (-dx, -dy, 1), then normalize.
	return Vector3Normalize((Vector3){ -dx, -dy, 1.0f });
}
// }}}

// {{{ static Color color_at_height()
// Altitude tint: dark forest green in the valleys, tan-ish at peaks.
// The constants are felt-quality numbers; revisit when (and if) the
// game ever grows a real biome / texture pipeline.
static Color color_at_height(float z)
{
	float t = (z + 4.0f) / 8.0f;
	if (t < 0.0f) t = 0.0f;
	if (t > 1.0f) t = 1.0f;
	unsigned char r = (unsigned char)(70.0f  + t * 150.0f);
	unsigned char g = (unsigned char)(105.0f + t *  85.0f);
	unsigned char b = (unsigned char)(55.0f  + t *  85.0f);
	return (Color){ r, g, b, 255 };
}
// }}}

// {{{ static Color light_bake()
// Multiplies a base color by a Lambertian factor against the sun
// direction. The result becomes the final per-vertex color — the GPU
// interpolates it across the surface so the shading reads even with
// raylib's default unlit shader.
static Color light_bake(Color base, Vector3 normal)
{
	Vector3 sun  = Vector3Normalize(SUN_DIR);
	float   ndotl = Vector3DotProduct(normal, sun);
	if (ndotl < 0.0f) ndotl = 0.0f;
	float lit = LIGHT_AMBIENT + (1.0f - LIGHT_AMBIENT) * ndotl;
	if (lit > 1.0f) lit = 1.0f;
	return (Color){
		(unsigned char)((float)base.r * lit),
		(unsigned char)((float)base.g * lit),
		(unsigned char)((float)base.b * lit),
		base.a,
	};
}
// }}}

// {{{ static void build_mesh()
// Walks the heightmap, fills vertex / color / index arrays, uploads
// to the GPU. Indexed because (65² verts, 64²·2 tris) is much smaller
// stored as 4225 unique vertices + 24576 indices than as 24576
// duplicated vertices.
static void build_mesh(void)
{
	int vcount = MAP_VERTS * MAP_VERTS;
	int tcount = MAP_SIZE_TILES * MAP_SIZE_TILES * 2;

	Mesh m = (Mesh){ 0 };
	m.vertexCount   = vcount;
	m.triangleCount = tcount;
	m.vertices = (float *)         MemAlloc(sizeof(float)         * 3 * vcount);
	m.colors   = (unsigned char *) MemAlloc(sizeof(unsigned char) * 4 * vcount);
	m.indices  = (unsigned short *)MemAlloc(sizeof(unsigned short) * 3 * tcount);

	for (int j = 0; j < MAP_VERTS; j++) {
		for (int i = 0; i < MAP_VERTS; i++) {
			int idx = j * MAP_VERTS + i;
			float wx = (float)i * TILE_SIZE_WORLD - MAP_HALF_WORLD;
			float wy = (float)j * TILE_SIZE_WORLD - MAP_HALF_WORLD;
			float wz = g_terrain.heights[i][j];
			m.vertices[idx * 3 + 0] = wx;
			m.vertices[idx * 3 + 1] = wy;
			m.vertices[idx * 3 + 2] = wz;

			Vector3 n   = normal_at_grid(i, j);
			Color   col = light_bake(color_at_height(wz), n);
			m.colors[idx * 4 + 0] = col.r;
			m.colors[idx * 4 + 1] = col.g;
			m.colors[idx * 4 + 2] = col.b;
			m.colors[idx * 4 + 3] = col.a;
		}
	}

	// Two triangles per tile, CCW from +Z so the surface faces up.
	int t = 0;
	for (int j = 0; j < MAP_SIZE_TILES; j++) {
		for (int i = 0; i < MAP_SIZE_TILES; i++) {
			unsigned short v00 = (unsigned short)(j * MAP_VERTS + i);
			unsigned short v10 = (unsigned short)(j * MAP_VERTS + (i + 1));
			unsigned short v01 = (unsigned short)((j + 1) * MAP_VERTS + i);
			unsigned short v11 = (unsigned short)((j + 1) * MAP_VERTS + (i + 1));
			m.indices[t++] = v00;
			m.indices[t++] = v10;
			m.indices[t++] = v01;
			m.indices[t++] = v10;
			m.indices[t++] = v11;
			m.indices[t++] = v01;
		}
	}

	UploadMesh(&m, false);
	g_terrain.mesh = m;
}
// }}}

// {{{ void terrain_init()
void terrain_init(void)
{
	for (int i = 0; i < MAP_VERTS; i++) {
		for (int j = 0; j < MAP_VERTS; j++) {
			float wx = (float)i * TILE_SIZE_WORLD - MAP_HALF_WORLD;
			float wy = (float)j * TILE_SIZE_WORLD - MAP_HALF_WORLD;
			g_terrain.heights[i][j] = noise_at_world(wx, wy);
		}
	}

	build_mesh();
	g_terrain.material    = LoadMaterialDefault();
	g_terrain.initialized = true;
}
// }}}

// {{{ void terrain_shutdown()
void terrain_shutdown(void)
{
	if (!g_terrain.initialized) return;
	UnloadMesh(g_terrain.mesh);
	UnloadMaterial(g_terrain.material);
	g_terrain.initialized = false;
}
// }}}

// {{{ void terrain_draw()
void terrain_draw(void)
{
	DrawMesh(g_terrain.mesh, g_terrain.material, MatrixIdentity());
}
// }}}

// {{{ float terrain_height_at()
// Bilinear interpolation over the four nearest grid cells. Out-of-
// bounds queries clamp to the boundary, per docs/002-mechanics.md
// ("Out-of-bounds X/Y is undefined and should be clamped at the
// boundary").
float terrain_height_at(float x, float y)
{
	float gx = (x + MAP_HALF_WORLD) / TILE_SIZE_WORLD;
	float gy = (y + MAP_HALF_WORLD) / TILE_SIZE_WORLD;
	if (gx < 0.0f) gx = 0.0f;
	if (gy < 0.0f) gy = 0.0f;
	if (gx > (float)(MAP_VERTS - 1)) gx = (float)(MAP_VERTS - 1);
	if (gy > (float)(MAP_VERTS - 1)) gy = (float)(MAP_VERTS - 1);

	int i0 = (int)floorf(gx);
	int j0 = (int)floorf(gy);
	int i1 = (i0 + 1 < MAP_VERTS) ? i0 + 1 : i0;
	int j1 = (j0 + 1 < MAP_VERTS) ? j0 + 1 : j0;
	float fx = gx - (float)i0;
	float fy = gy - (float)j0;

	float h00 = g_terrain.heights[i0][j0];
	float h10 = g_terrain.heights[i1][j0];
	float h01 = g_terrain.heights[i0][j1];
	float h11 = g_terrain.heights[i1][j1];
	float h0  = h00 * (1.0f - fx) + h10 * fx;
	float h1  = h01 * (1.0f - fx) + h11 * fx;
	return h0 * (1.0f - fy) + h1 * fy;
}
// }}}

// {{{ bool terrain_pick()
// March the cursor ray through the world and return the first point
// where it crosses below the heightmap. Strategy:
//   1. Walk the ray in fixed steps. At each step decide whether the
//      current sample is above or below terrain.
//   2. The instant a sample flips from above to below, the crossing
//      is between (prev, cur) — binary-search to refine.
//   3. After the search, snap the Y/Z to the terrain so the result
//      is *exactly* on the surface (the search converges close but
//      not perfectly because of the bilinear interpolation).
//
// The march stops at PICK_MAX_DIST, which is chosen comfortably past
// the camera's max distance plus the world's diagonal so a ray
// pointing into the map always finds the surface before the cap.
// A ray pointing away from the world (cursor above the horizon)
// hits the cap with no crossing and the function returns false —
// which is the correct "miss" signal.
bool terrain_pick(Camera3D camera, Vector2 mouse, Vector3 *out)
{
	const float PICK_STEP     = 0.5f;
	const float PICK_MAX_DIST = 500.0f;
	const int   REFINE_ITERS  = 24;

	Ray r = GetMouseRay(mouse, camera);

	Vector3 prev    = r.position;
	float   prev_h  = terrain_height_at(prev.x, prev.y);
	bool    prev_up = prev.z >= prev_h;

	for (float t = PICK_STEP; t < PICK_MAX_DIST; t += PICK_STEP) {
		Vector3 cur = {
			r.position.x + r.direction.x * t,
			r.position.y + r.direction.y * t,
			r.position.z + r.direction.z * t,
		};
		float cur_h  = terrain_height_at(cur.x, cur.y);
		bool  cur_up = cur.z >= cur_h;

		if (prev_up && !cur_up) {
			// Crossed. Binary-search between prev (above) and cur
			// (below) for the X/Y where ray.z meets terrain.z.
			Vector3 lo = prev;
			Vector3 hi = cur;
			for (int i = 0; i < REFINE_ITERS; i++) {
				Vector3 mid = {
					(lo.x + hi.x) * 0.5f,
					(lo.y + hi.y) * 0.5f,
					(lo.z + hi.z) * 0.5f,
				};
				float h = terrain_height_at(mid.x, mid.y);
				if (mid.z >= h) lo = mid;
				else            hi = mid;
			}
			float fx = (lo.x + hi.x) * 0.5f;
			float fy = (lo.y + hi.y) * 0.5f;
			out->x = fx;
			out->y = fy;
			out->z = terrain_height_at(fx, fy);
			return true;
		}

		prev    = cur;
		prev_up = cur_up;
	}
	return false;
}
// }}}

// {{{ bool terrain_segment_blocked()
bool terrain_segment_blocked(Vector3 a, Vector3 b)
{
	float dx = b.x - a.x;
	float dy = b.y - a.y;
	float dz = b.z - a.z;
	float len = sqrtf(dx * dx + dy * dy + dz * dz);

	// Half-tile step is fine enough to catch ridges at the resolution
	// the heightmap can represent. Tighter steps would be wasted work.
	int steps = (int)ceilf(len / (TILE_SIZE_WORLD * 0.5f));
	if (steps < 2) steps = 2;

	// Skip the endpoints. Callers (issue 111 onward) pass shooter and
	// target positions that sit exactly on the terrain Z; including
	// the endpoints would treat any flat ground as "blocked." LoS
	// adds its own eye-height offset at the call site.
	for (int k = 1; k < steps; k++) {
		float t  = (float)k / (float)steps;
		float px = a.x + dx * t;
		float py = a.y + dy * t;
		float pz = a.z + dz * t;
		if (pz < terrain_height_at(px, py)) {
			return true;
		}
	}
	return false;
}
// }}}
