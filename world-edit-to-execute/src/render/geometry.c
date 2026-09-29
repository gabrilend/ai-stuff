/*
 * Geometry Painting Implementation (Issue 516a)
 *
 * See geometry.h. Primitives are stored as data and turned into triangles
 * when drawn; faces are drawn from both sides, so corner order never hides
 * a face.
 */

#include <math.h>
#include "geometry.h"
#include "rlgl.h"

/* {{{ Module State */
static GeoPrim g_static[GEO_MAX_STATIC];
static int g_static_count = 0;
static GeoPrim g_dynamic[GEO_MAX_DYNAMIC];
static int g_dynamic_count = 0;
/* }}} */

/* {{{ Light
 * Direction the light comes from (normalised in shade()). Mostly overhead,
 * a little from +x and -z, so the three visible faces of a box differ. */
static const Vector3 LIGHT = { 0.45f, 1.0f, -0.3f };
/* }}} */

/* {{{ add_prim */
static int add_prim(bool dynamic, GeoPrim prim) {
    if (dynamic) {
        if (g_dynamic_count >= GEO_MAX_DYNAMIC) return -1;
        g_dynamic[g_dynamic_count] = prim;
        return g_dynamic_count++;
    }
    if (g_static_count >= GEO_MAX_STATIC) return -1;
    g_static[g_static_count] = prim;
    return g_static_count++;
}
/* }}} */

/* {{{ geometry_add_box */
int geometry_add_box(bool dynamic, Vector3 base, Vector3 size, float yaw, Color color) {
    GeoPrim p = { .kind = GEO_BOX, .base = base, .size = size, .yaw = yaw, .color = color };
    return add_prim(dynamic, p);
}
/* }}} */

/* {{{ geometry_add_wedge */
int geometry_add_wedge(bool dynamic, Vector3 base, Vector3 size, float yaw, Color color) {
    GeoPrim p = { .kind = GEO_WEDGE, .base = base, .size = size, .yaw = yaw, .color = color };
    return add_prim(dynamic, p);
}
/* }}} */

/* {{{ geometry_add_quad */
int geometry_add_quad(bool dynamic, const Vector3 corners[4], Color color) {
    GeoPrim p = { .kind = GEO_QUAD, .color = color };
    for (int i = 0; i < 4; i++) p.quad[i] = corners[i];
    return add_prim(dynamic, p);
}
/* }}} */

/* {{{ geometry_clear */
void geometry_clear(bool dynamic) {
    if (dynamic) g_dynamic_count = 0;
    else g_static_count = 0;
}
/* }}} */

/* {{{ geometry_count */
int geometry_count(bool dynamic) {
    return dynamic ? g_dynamic_count : g_static_count;
}
/* }}} */

/* {{{ shade
 * Colour of a face with the given corners: 55% ambient, the rest by how
 * squarely the face meets the light (either side counts, as faces are
 * two-sided). */
static Color shade(Vector3 a, Vector3 b, Vector3 c, Color col) {
    Vector3 u = { b.x - a.x, b.y - a.y, b.z - a.z };
    Vector3 v = { c.x - a.x, c.y - a.y, c.z - a.z };
    Vector3 n = { u.y * v.z - u.z * v.y, u.z * v.x - u.x * v.z, u.x * v.y - u.y * v.x };
    float nl = sqrtf(n.x * n.x + n.y * n.y + n.z * n.z);
    float ll = sqrtf(LIGHT.x * LIGHT.x + LIGHT.y * LIGHT.y + LIGHT.z * LIGHT.z);
    float k = 0.55f;
    if (nl > 0.0f) {
        float d = (n.x * LIGHT.x + n.y * LIGHT.y + n.z * LIGHT.z) / (nl * ll);
        k += 0.45f * fabsf(d);
    }
    return (Color){ (unsigned char)(col.r * k), (unsigned char)(col.g * k),
                    (unsigned char)(col.b * k), col.a };
}
/* }}} */

/* {{{ face
 * Draw a flat face of 3 or 4 corners in one shade. */
static void face(Vector3 a, Vector3 b, Vector3 c, const Vector3* d, Color col) {
    Color s = shade(a, b, c, col);
    DrawTriangle3D(a, b, c, s);
    if (d) DrawTriangle3D(a, c, *d, s);
}
/* }}} */

/* {{{ corner
 * World position of a local point (lx along the prim's length, ly up,
 * lz across) of a box or wedge. */
static Vector3 corner(const GeoPrim* p, float lx, float ly, float lz) {
    float c = cosf(p->yaw), s = sinf(p->yaw);
    return (Vector3){ p->base.x + lx * c - lz * s,
                      p->base.y + ly,
                      p->base.z + lx * s + lz * c };
}
/* }}} */

/* {{{ draw_box */
static void draw_box(const GeoPrim* p) {
    float hx = p->size.x * 0.5f, h = p->size.y, hz = p->size.z * 0.5f;
    Vector3 b0 = corner(p, -hx, 0, -hz), b1 = corner(p, hx, 0, -hz);
    Vector3 b2 = corner(p, hx, 0, hz),   b3 = corner(p, -hx, 0, hz);
    Vector3 t0 = corner(p, -hx, h, -hz), t1 = corner(p, hx, h, -hz);
    Vector3 t2 = corner(p, hx, h, hz),   t3 = corner(p, -hx, h, hz);

    face(t0, t1, t2, &t3, p->color);   /* top */
    face(b0, b1, b2, &b3, p->color);   /* bottom */
    face(b0, b1, t1, &t0, p->color);   /* -z side */
    face(b1, b2, t2, &t1, p->color);   /* +x end */
    face(b2, b3, t3, &t2, p->color);   /* +z side */
    face(b3, b0, t0, &t3, p->color);   /* -x end */
}
/* }}} */

/* {{{ draw_wedge
 * Ramp: flat base, slope from the -x edge (height 0) up to the +x edge
 * (full height), an upright face at +x, and triangles at both sides. */
static void draw_wedge(const GeoPrim* p) {
    float hx = p->size.x * 0.5f, h = p->size.y, hz = p->size.z * 0.5f;
    Vector3 b0 = corner(p, -hx, 0, -hz), b1 = corner(p, hx, 0, -hz);
    Vector3 b2 = corner(p, hx, 0, hz),   b3 = corner(p, -hx, 0, hz);
    Vector3 t1 = corner(p, hx, h, -hz),  t2 = corner(p, hx, h, hz);

    face(b0, b1, b2, &b3, p->color);   /* base */
    face(b0, t1, t2, &b3, p->color);   /* slope */
    face(b1, b2, t2, &t1, p->color);   /* upright end */
    face(b0, b1, t1, NULL, p->color);  /* -z side */
    face(b3, b2, t2, NULL, p->color);  /* +z side */
}
/* }}} */

/* {{{ draw_prim */
static void draw_prim(const GeoPrim* p) {
    switch (p->kind) {
        case GEO_BOX:   draw_box(p); break;
        case GEO_WEDGE: draw_wedge(p); break;
        case GEO_QUAD:  face(p->quad[0], p->quad[1], p->quad[2], &p->quad[3], p->color); break;
    }
}
/* }}} */

/* {{{ geometry_draw */
void geometry_draw(void) {
    /* raylib batches triangles and draws them later; flush around the
     * culling change so it applies to exactly these faces */
    rlDrawRenderBatchActive();
    rlDisableBackfaceCulling();
    for (int i = 0; i < g_static_count; i++) draw_prim(&g_static[i]);
    for (int i = 0; i < g_dynamic_count; i++) draw_prim(&g_dynamic[i]);
    rlDrawRenderBatchActive();
    rlEnableBackfaceCulling();
    g_dynamic_count = 0;
}
/* }}} */

/* {{{ Lua helpers */
static Color check_color(lua_State* L, int first) {
    return (Color){ (unsigned char)luaL_checkinteger(L, first),
                    (unsigned char)luaL_checkinteger(L, first + 1),
                    (unsigned char)luaL_checkinteger(L, first + 2), 255 };
}

/* Shared by geo_box and geo_wedge: same arguments */
static int add_solid_from_lua(lua_State* L, GeoKind kind) {
    Vector3 base = { (float)luaL_checknumber(L, 1), (float)luaL_checknumber(L, 2),
                     (float)luaL_checknumber(L, 3) };
    Vector3 size = { (float)luaL_checknumber(L, 4), (float)luaL_checknumber(L, 5),
                     (float)luaL_checknumber(L, 6) };
    float yaw = (float)luaL_checknumber(L, 7);
    Color color = check_color(L, 8);
    bool dynamic = lua_toboolean(L, 11);
    int index = kind == GEO_BOX
        ? geometry_add_box(dynamic, base, size, yaw, color)
        : geometry_add_wedge(dynamic, base, size, yaw, color);
    lua_pushinteger(L, index);
    return 1;
}
/* }}} */

/* {{{ l_geo_box */
int l_geo_box(lua_State* L) {
    return add_solid_from_lua(L, GEO_BOX);
}
/* }}} */

/* {{{ l_geo_wedge */
int l_geo_wedge(lua_State* L) {
    return add_solid_from_lua(L, GEO_WEDGE);
}
/* }}} */

/* {{{ l_geo_quad */
int l_geo_quad(lua_State* L) {
    Vector3 corners[4];
    for (int i = 0; i < 4; i++) {
        corners[i] = (Vector3){ (float)luaL_checknumber(L, i * 3 + 1),
                                (float)luaL_checknumber(L, i * 3 + 2),
                                (float)luaL_checknumber(L, i * 3 + 3) };
    }
    Color color = check_color(L, 13);
    lua_pushinteger(L, geometry_add_quad(lua_toboolean(L, 16), corners, color));
    return 1;
}
/* }}} */

/* {{{ l_geo_clear */
int l_geo_clear(lua_State* L) {
    if (lua_isnoneornil(L, 1)) {
        geometry_clear(false);
        geometry_clear(true);
    } else {
        geometry_clear(lua_toboolean(L, 1));
    }
    return 0;
}
/* }}} */

/* {{{ l_geo_count */
int l_geo_count(lua_State* L) {
    lua_pushinteger(L, geometry_count(lua_toboolean(L, 1)));
    return 1;
}
/* }}} */
