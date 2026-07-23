/* 002-render.h — the first-person renderer.
 *
 * Turns the world's tile grid (issue 103) into 3D geometry and draws it from the
 * player's camera. Geometry is built ONCE into per-object meshes — one mesh per
 * room, each a list of faces carrying their vertices, a normal (for the lighting
 * and backface work still to come), and a fill + edge colour. This is the
 * per-object vertex datastructure the renderer design calls for; visibility is
 * left to the GPU depth buffer for now, with door-portal culling the intended
 * next layer.
 *
 * Coordinate mapping lives here: the world is (x, y) horizontal with z as height;
 * raylib is x-right, y-up, z-toward-viewer, so a world point (wx, wy, wz) becomes
 * raylib (wx, wz, wy). The rest of the engine never sees raylib coordinates.
 */
#ifndef FPS_RENDER_H
#define FPS_RENDER_H

#include "001-world.h"

typedef struct scene scene_t;

/* Build the per-room meshes from a world's tiles: a floor and ceiling per open
 * cell, and a wall wherever an open cell meets a solid one or a taller floor
 * (so steps and doorways fall out naturally). Built once; NULL on OOM. */
scene_t *scene_build(const world_t *w);
void     scene_destroy(scene_t *s);

/* Draw the scene first-person: the eye sits at world (px, py) at height pz,
 * looking along the horizontal facing (fx, fy). */
void scene_render(const scene_t *s, float px, float py, float pz,
                  float fx, float fy);

#endif /* FPS_RENDER_H */
