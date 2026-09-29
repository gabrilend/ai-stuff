/*
 * Geometry Painting (Issue 516a)
 *
 * Flat-shaded solids that Lua paints into the world: boxes, wedges (ramps)
 * and free quads. Each face is shaded by how squarely it meets a fixed light,
 * so shapes read as solid without lighting shaders; the look is plain
 * polygons in flat colours.
 *
 * Two layers:
 *   static  - kept until geometry_clear(false): buildings, walls, ramps
 *   dynamic - drawn once, then emptied by geometry_draw(): units, arrows,
 *             anything Lua repaints every frame
 *
 * Coordinates are render space: y up, ground at y = 0. A box or wedge is
 * placed by the centre of its base; yaw turns local +x toward local +z,
 * so yaw = facing when WC3 (x, y) maps to render (x, z).
 */

#ifndef GEOMETRY_H
#define GEOMETRY_H

#include <stdbool.h>
#include <lua.h>
#include <lauxlib.h>
#include "raylib.h"

#define GEO_MAX_STATIC  400000   /* grows as needed up to this */
#define GEO_MAX_DYNAMIC 65536

typedef enum {
    GEO_BOX,
    GEO_WEDGE,   /* rises along local +x: height 0 at -x, full at +x */
    GEO_QUAD,
} GeoKind;

typedef struct {
    GeoKind kind;
    Vector3 base;      /* box/wedge: centre of the base */
    Vector3 size;      /* box/wedge: x length, y height, z depth */
    float yaw;         /* box/wedge: radians about +y */
    Vector3 quad[4];   /* quad: corners in order around the edge */
    Color color;
} GeoPrim;

/* {{{ C API */
int  geometry_add_box(bool dynamic, Vector3 base, Vector3 size, float yaw, Color color);
int  geometry_add_wedge(bool dynamic, Vector3 base, Vector3 size, float yaw, Color color);
int  geometry_add_quad(bool dynamic, const Vector3 corners[4], Color color);
void geometry_clear(bool dynamic);
int  geometry_count(bool dynamic);
void geometry_draw(void);   /* static, then dynamic; empties dynamic */

/* Baking (517b): move every static primitive into GPU meshes, grouped in
 * square chunks of chunk_size render units, and draw only the chunks within
 * the view set by geometry_set_view. Returns the number of chunks. */
int  geometry_bake(float chunk_size);
void geometry_set_view(float cx, float cz, float radius);

/* Portrait layer (518a): while the target is the portrait, primitives go to
 * a list that ui2d draws into the portrait texture, then empties */
#define GEO_MAX_PORTRAIT 1024
void geometry_set_portrait_target(bool on);
void geometry_draw_portrait(void);

/* The flat shade of a face with corners a, b, c (shared with landscape.c) */
Color geometry_shade(Vector3 a, Vector3 b, Vector3 c, Color col);
/* }}} */

/* {{{ Lua API (registered by luaopen_render)
 * render.geo_box(x, y, z, sx, sy, sz, yaw, r, g, b [, dynamic]) -> index | -1
 * render.geo_wedge(x, y, z, sx, sy, sz, yaw, r, g, b [, dynamic]) -> index | -1
 * render.geo_quad(x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4, r, g, b [, dynamic]) -> index | -1
 * render.geo_clear([dynamic])     (no argument: both layers, and baked chunks)
 * render.geo_count([dynamic]) -> n
 * render.geo_bake(chunk_size) -> chunks   (517b)
 * render.geo_target("portrait" | "world")  (518a)
 */
int l_geo_box(lua_State* L);
int l_geo_wedge(lua_State* L);
int l_geo_quad(lua_State* L);
int l_geo_clear(lua_State* L);
int l_geo_count(lua_State* L);
int l_geo_bake(lua_State* L);
int l_geo_target(lua_State* L);
/* }}} */

#endif /* GEOMETRY_H */
