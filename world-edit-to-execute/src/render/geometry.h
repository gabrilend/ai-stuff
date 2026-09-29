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

#define GEO_MAX_STATIC  32768
#define GEO_MAX_DYNAMIC 16384

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
/* }}} */

/* {{{ Lua API (registered by luaopen_render)
 * render.geo_box(x, y, z, sx, sy, sz, yaw, r, g, b [, dynamic]) -> index | -1
 * render.geo_wedge(x, y, z, sx, sy, sz, yaw, r, g, b [, dynamic]) -> index | -1
 * render.geo_quad(x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4, r, g, b [, dynamic]) -> index | -1
 * render.geo_clear([dynamic])     (no argument: both layers)
 * render.geo_count([dynamic]) -> n
 */
int l_geo_box(lua_State* L);
int l_geo_wedge(lua_State* L);
int l_geo_quad(lua_State* L);
int l_geo_clear(lua_State* L);
int l_geo_count(lua_State* L);
/* }}} */

#endif /* GEOMETRY_H */
