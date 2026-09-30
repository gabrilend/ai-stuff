/*
 * 2D Interface Drawing (Issue 518a)
 *
 * Screen-space drawing for interfaces written in Lua: rectangles, frames,
 * lines, triangles, circles, text, images built from RGBA bytes, and the
 * unit portrait. Coordinates are pixels from the window's top-left.
 *
 * The portrait is a small 3D view drawn into a texture each frame from the
 * geometry's portrait layer (render.geo_target("portrait")).
 */

#ifndef UI2D_H
#define UI2D_H

#include <lua.h>
#include <lauxlib.h>
#include "raylib.h"

#define UI_MAX_IMAGES 32
#define PORTRAIT_SIZE 256

/* Render the portrait layer into its texture (call before BeginDrawing) */
void ui2d_render_portrait(void);
void ui2d_free(void);

/* Lua:
 * render.ui_rect(x, y, w, h, r, g, b [, a])
 * render.ui_frame(x, y, w, h, thick, r, g, b [, a])     outline
 * render.ui_line(x1, y1, x2, y2, thick, r, g, b [, a])
 * render.ui_tri(x1, y1, x2, y2, x3, y3, r, g, b [, a])  any winding
 * render.ui_circle(x, y, radius, r, g, b [, a])
 * render.ui_text(text, x, y, size, r, g, b [, a])
 * render.ui_text_width(text, size) -> pixels
 * render.ui_image_load(w, h, rgba) -> id       rgba: w*h*4 bytes, rows from the top
 * render.ui_image(id, x, y, w, h [, a])
 * render.ui_portrait(x, y, w, h)
 * render.ui_screen() -> width, height
 */
int l_ui_rect(lua_State* L);
int l_ui_frame(lua_State* L);
int l_ui_line(lua_State* L);
int l_ui_tri(lua_State* L);
int l_ui_circle(lua_State* L);
int l_ui_text(lua_State* L);
int l_ui_text_width(lua_State* L);
int l_ui_image_load(lua_State* L);
int l_ui_image_update(lua_State* L);
int l_ui_image(lua_State* L);
int l_ui_portrait(lua_State* L);
int l_ui_screen(lua_State* L);

#endif /* UI2D_H */
