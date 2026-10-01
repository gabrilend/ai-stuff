/*
 * fog.h - fog of war, drawn over the world (Issue 524)
 *
 * The 3D view is drawn into a texture with its depth; a last pass finds
 * each pixel's place on the map from the depth and darkens it by the fog
 * texture there: black where never seen, dim where seen before, as is
 * where seen now. Everything drawn in 3D (ground, doodads, models) is
 * shaded alike; the interface is drawn after, untouched.
 *
 * Lua (render.*):
 *   fog_set(w, h, x0, y0, cell, shades)   shades: a byte per cell, w x h,
 *        row 0 southmost (0 black .. 255 clear); cell (i, j) is centred
 *        on WC3 point (x0 + i * cell, y0 + j * cell). Turns the fog on.
 *   fog_off()                             no fog pass
 */
#ifndef FOG_H
#define FOG_H

#include "lua.h"
#include "raylib.h"

int fog_active(void);
void fog_begin(void);      /* before BeginMode3D: draw into the fog's target */
void fog_capture(void);    /* inside BeginMode3D, after drawing: the matrices */
void fog_end(void);        /* after EndMode3D: the shaded picture to the screen */

int l_fog_set(lua_State* L);
int l_fog_off(lua_State* L);

#endif
