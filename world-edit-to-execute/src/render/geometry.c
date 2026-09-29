/*
 * Geometry Painting Implementation (Issue 516a)
 *
 * See geometry.h. Primitives are stored as data and turned into triangles
 * when drawn; faces are drawn from both sides, so corner order never hides
 * a face.
 */

#include <math.h>
#include <stdlib.h>
#include "geometry.h"
#include "raymath.h"
#include "rlgl.h"

/* {{{ Module State */
static GeoPrim* g_static = NULL;     /* grows by doubling up to GEO_MAX_STATIC */
static int g_static_cap = 0;
static int g_static_count = 0;
static GeoPrim g_dynamic[GEO_MAX_DYNAMIC];
static int g_dynamic_count = 0;
static GeoPrim g_portrait[GEO_MAX_PORTRAIT];
static int g_portrait_count = 0;
static bool g_portrait_target = false;

/* Baked chunks (517b) */
typedef struct {
    Mesh mesh;
    float cx, cz;
} BakedChunk;
static BakedChunk* g_baked = NULL;
static int g_baked_count = 0;
static float g_baked_reach = 0.0f;
static Material g_bake_material;
static bool g_bake_material_ready = false;
static float g_view_x = 0.0f, g_view_z = 0.0f, g_view_r = -1.0f;   /* r < 0: all */
/* }}} */

/* {{{ Triangle sink
 * Shapes hand their triangles to the sink: drawn at once, or collected
 * into a buffer while baking. */
typedef struct {
    float* pos;
    unsigned char* col;
    int count, cap;
} TriBuf;
static TriBuf* g_sink = NULL;   /* NULL: draw immediately */

static void emit_tri(Vector3 a, Vector3 b, Vector3 c, Color col) {
    if (!g_sink) {
        DrawTriangle3D(a, b, c, col);
        return;
    }
    TriBuf* t = g_sink;
    if (t->count + 3 > t->cap) {
        int cap = t->cap ? t->cap * 2 : 3072;
        t->pos = (float*)realloc(t->pos, sizeof(float) * 3 * cap);
        t->col = (unsigned char*)realloc(t->col, 4 * cap);
        t->cap = cap;
    }
    Vector3 v[3] = { a, b, c };
    for (int i = 0; i < 3; i++) {
        int k = t->count++;
        t->pos[k * 3] = v[i].x;
        t->pos[k * 3 + 1] = v[i].y;
        t->pos[k * 3 + 2] = v[i].z;
        t->col[k * 4] = col.r;
        t->col[k * 4 + 1] = col.g;
        t->col[k * 4 + 2] = col.b;
        t->col[k * 4 + 3] = col.a;
    }
}
/* }}} */

/* {{{ Light
 * Direction the light comes from (normalised in shade()). Mostly overhead,
 * a little from +x and -z, so the three visible faces of a box differ. */
static const Vector3 LIGHT = { 0.45f, 1.0f, -0.3f };
/* }}} */

/* {{{ add_prim */
static int add_prim(bool dynamic, GeoPrim prim) {
    if (g_portrait_target) {
        if (g_portrait_count >= GEO_MAX_PORTRAIT) return -1;
        g_portrait[g_portrait_count] = prim;
        return g_portrait_count++;
    }
    if (dynamic) {
        if (g_dynamic_count >= GEO_MAX_DYNAMIC) return -1;
        g_dynamic[g_dynamic_count] = prim;
        return g_dynamic_count++;
    }
    if (g_static_count >= g_static_cap) {
        if (g_static_cap >= GEO_MAX_STATIC) return -1;
        int cap = g_static_cap ? g_static_cap * 2 : 4096;
        if (cap > GEO_MAX_STATIC) cap = GEO_MAX_STATIC;
        GeoPrim* grown = (GeoPrim*)realloc(g_static, sizeof(GeoPrim) * cap);
        if (!grown) return -1;
        g_static = grown;
        g_static_cap = cap;
    }
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

/* {{{ geometry_clear
 * Clearing the static layer also drops any baked chunks. */
void geometry_clear(bool dynamic) {
    if (dynamic) {
        g_dynamic_count = 0;
        return;
    }
    g_static_count = 0;
    for (int i = 0; i < g_baked_count; i++) UnloadMesh(g_baked[i].mesh);
    free(g_baked);
    g_baked = NULL;
    g_baked_count = 0;
}
/* }}} */

/* {{{ geometry_count */
int geometry_count(bool dynamic) {
    return dynamic ? g_dynamic_count : g_static_count;
}
/* }}} */

/* {{{ geometry_shade
 * Colour of a face with the given corners: 55% ambient, the rest by how
 * squarely the face meets the light (either side counts, as faces are
 * two-sided). */
Color geometry_shade(Vector3 a, Vector3 b, Vector3 c, Color col) {
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
    Color s = geometry_shade(a, b, c, col);
    emit_tri(a, b, c, s);
    if (d) emit_tri(a, c, *d, s);
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

/* {{{ Baking */
static int cmp_chunk_key(const void* a, const void* b) {
    long long ka = *(const long long*)a, kb = *(const long long*)b;
    return (ka > kb) - (ka < kb);
}

/* {{{ geometry_bake */
int geometry_bake(float chunk_size) {
    if (chunk_size <= 0.0f || g_static_count == 0) return g_baked_count;
    if (!g_bake_material_ready) {
        g_bake_material = LoadMaterialDefault();
        g_bake_material_ready = true;
    }

    /* sort primitives by chunk: key = chunk index packed with prim index */
    long long* keys = (long long*)malloc(sizeof(long long) * 2 * g_static_count);
    for (int i = 0; i < g_static_count; i++) {
        const GeoPrim* p = &g_static[i];
        Vector3 at = p->kind == GEO_QUAD ? p->quad[0] : p->base;
        long long gx = (long long)floorf(at.x / chunk_size) + (1 << 20);
        long long gz = (long long)floorf(at.z / chunk_size) + (1 << 20);
        keys[i * 2] = (gx << 21) | gz;
        keys[i * 2 + 1] = i;
    }
    qsort(keys, g_static_count, sizeof(long long) * 2, cmp_chunk_key);

    int start = 0;
    while (start < g_static_count) {
        int end = start;
        while (end < g_static_count && keys[end * 2] == keys[start * 2]) end++;

        TriBuf buf = { 0 };
        g_sink = &buf;
        for (int k = start; k < end; k++) draw_prim(&g_static[keys[k * 2 + 1]]);
        g_sink = NULL;

        if (buf.count > 0) {
            BakedChunk* grown = (BakedChunk*)realloc(g_baked, sizeof(BakedChunk) * (g_baked_count + 1));
            if (grown) {
                g_baked = grown;
                BakedChunk* ch = &g_baked[g_baked_count++];
                long long gx = (keys[start * 2] >> 21) - (1 << 20);
                long long gz = (keys[start * 2] & ((1 << 21) - 1)) - (1 << 20);
                ch->cx = (gx + 0.5f) * chunk_size;
                ch->cz = (gz + 0.5f) * chunk_size;
                /* hand the buffers to raylib, which frees them with the mesh */
                Mesh m = { 0 };
                m.vertexCount = buf.count;
                m.triangleCount = buf.count / 3;
                m.vertices = (float*)MemAlloc(sizeof(float) * 3 * buf.count);
                m.colors = (unsigned char*)MemAlloc(4 * buf.count);
                for (int v = 0; v < buf.count * 3; v++) m.vertices[v] = buf.pos[v];
                for (int v = 0; v < buf.count * 4; v++) m.colors[v] = buf.col[v];
                UploadMesh(&m, false);
                ch->mesh = m;
            }
        }
        free(buf.pos);
        free(buf.col);
        start = end;
    }
    free(keys);

    /* a primitive can reach past its chunk; allow a chunk and a half */
    g_baked_reach = chunk_size * 1.5f;
    g_static_count = 0;
    return g_baked_count;
}
/* }}} */

/* {{{ geometry_set_view */
void geometry_set_view(float cx, float cz, float radius) {
    g_view_x = cx;
    g_view_z = cz;
    g_view_r = radius;
}
/* }}} */
/* }}} */

/* {{{ geometry_draw */
void geometry_draw(void) {
    /* raylib batches triangles and draws them later; flush around the
     * culling change so it applies to exactly these faces */
    rlDrawRenderBatchActive();
    rlDisableBackfaceCulling();
    if (g_baked_count > 0) {
        Matrix id = MatrixIdentity();
        float reach = g_view_r + g_baked_reach;
        for (int i = 0; i < g_baked_count; i++) {
            float dx = g_baked[i].cx - g_view_x, dz = g_baked[i].cz - g_view_z;
            if (g_view_r >= 0.0f && dx * dx + dz * dz > reach * reach) continue;
            DrawMesh(g_baked[i].mesh, g_bake_material, id);
        }
    }
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

/* {{{ Portrait layer */
void geometry_set_portrait_target(bool on) {
    g_portrait_target = on;
}

void geometry_draw_portrait(void) {
    rlDrawRenderBatchActive();
    rlDisableBackfaceCulling();
    for (int i = 0; i < g_portrait_count; i++) draw_prim(&g_portrait[i]);
    rlDrawRenderBatchActive();
    rlEnableBackfaceCulling();
    g_portrait_count = 0;
}

int l_geo_target(lua_State* L) {
    const char* t = luaL_checkstring(L, 1);
    geometry_set_portrait_target(t[0] == 'p');
    return 0;
}
/* }}} */

/* {{{ l_geo_bake */
int l_geo_bake(lua_State* L) {
    lua_pushinteger(L, geometry_bake((float)luaL_checknumber(L, 1)));
    return 1;
}
/* }}} */

/* {{{ l_geo_count */
int l_geo_count(lua_State* L) {
    lua_pushinteger(L, geometry_count(lua_toboolean(L, 1)));
    return 1;
}
/* }}} */
