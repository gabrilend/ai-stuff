// 020-terrain.h — Heightmap terrain queries and rendering.
//
// World convention is Z-up (set by issue 103). The heightmap stores Z
// values over an X/Y grid centered on the origin: world coordinates
// run from (-MAP_HALF, -MAP_HALF) to (+MAP_HALF, +MAP_HALF) where
// MAP_HALF is half the map's world extent.
//
// Lifecycle: terrain_init() once after the window opens, then
// terrain_draw() each frame inside BeginMode3D. terrain_shutdown()
// must run before CloseWindow() since UnloadMesh wants the GL
// context.
//
// Threading: the heightmap *array* (read by terrain_height_at /
// terrain_segment_blocked) is read-only after init and can be
// queried from any thread without a lock. The mesh and material are
// owned by the main thread.

#ifndef TERRAIN_H_
#define TERRAIN_H_

#include <raylib.h>
#include <stdbool.h>

void terrain_init(void);
void terrain_shutdown(void);
void terrain_draw(void);

float terrain_height_at(float x, float y);
bool  terrain_segment_blocked(Vector3 a, Vector3 b);

#endif
