/*
 * Landscape (Issue 517b)
 *
 * A map's ground as flat-shaded triangles: two per terrain cell, each lit by
 * its own slope, steep ones coloured as cliff rock; and a water surface over
 * every cell where water shows, shaded by its depth. Built once from packed
 * arrays that Lua prepares, kept on the GPU in chunks, drawn near the camera.
 *
 * Placement matches geometry/kit.lua to_render: WC3 (X, Y, Z) is drawn at
 * render (X * scale, Z * scale, -Y * scale).
 */

#ifndef LANDSCAPE_H
#define LANDSCAPE_H

#include <lua.h>
#include <lauxlib.h>

#define LAND_CHUNK 32   /* cells per chunk side */

void landscape_draw(float cam_x, float cam_z, float radius);   /* render units */
void landscape_free(void);

/* render.land_build(w, h, x0, y0, tile, scale, heights, colors, water)
 *   w, h     tilepoints across and up (cells are (w-1) x (h-1))
 *   x0, y0   WC3 position of tilepoint (0, 0); tile: WC3 units between tilepoints
 *   scale    render units per WC3 unit
 *   heights  string: w*h float32 ground z (WC3), rows from y = 0
 *   colors   string: (w-1)*(h-1)*3 bytes, one RGB per cell
 *   water    string: w*h float32 water z, or below the ground where dry
 * -> number of chunks built */
int l_land_build(lua_State* L);
int l_land_free(lua_State* L);

/* render.land_tiles(textures, cells): ground textures over the land
 * (Issue 526); see landscape.c for the layout -> triangles built */
int l_land_tiles(lua_State* L);

#endif /* LANDSCAPE_H */
