/*
 * models.c - textured models (Issue 522c); see models.h
 *
 * Coordinates: model space is WC3's (x east, y north, z up, units of one
 * WC3 unit); the world is drawn with 128 WC3 units to a render unit, x
 * east, y up, z south. An instance's matrix does the rotation by facing,
 * the axis swap and the scale in one.
 *
 * WC3's filter modes: 0 none (opaque), 1 transparent (alpha-tested),
 * 2 blend, 3 additive, 4 add-alpha, 5 modulate, 6 modulate 2x. Opaque and
 * alpha-tested parts are drawn first with depth writes; blended ones
 * after, without writing depth (unsorted: close enough for a first pass).
 */
#include "models.h"
#include "raylib.h"
#include "raymath.h"
#include "rlgl.h"
#include "lauxlib.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define WC3_UNITS 128.0f

typedef struct {
    int mesh, tex, filter, team, two_sided, unshaded;
    float alpha;
} Part;

typedef struct {
    Part* parts;
    int part_count;
} ModelDef;

typedef struct {
    int model;
    Matrix m;
    Color team;
    float alpha;
    float x, z;
} Instance;

static Texture2D* g_tex = NULL;
static int g_tex_count = 0, g_tex_cap = 0;
static Mesh* g_mesh = NULL;
static int g_mesh_count = 0, g_mesh_cap = 0;
static ModelDef* g_models = NULL;
static int g_model_count = 0, g_model_cap = 0;
static Instance* g_inst = NULL;
static int g_inst_count = 0, g_inst_cap = 0;
static int g_last_drawn = 0;

static Shader g_shader;
static int g_loc_alpha_test = -1, g_loc_unshaded = -1, g_loc_light = -1;
static Material g_material;
static Texture2D g_white;
static int g_ready = 0;

/* {{{ shader */
static const char* VS =
    "#version 330\n"
    "in vec3 vertexPosition; in vec2 vertexTexCoord; in vec3 vertexNormal;\n"
    "uniform mat4 mvp; uniform mat4 matModel;\n"
    "out vec2 uv; out vec3 normal;\n"
    "void main() {\n"
    "  uv = vertexTexCoord;\n"
    "  normal = normalize(mat3(matModel) * vertexNormal);\n"
    "  gl_Position = mvp * vec4(vertexPosition, 1.0);\n"
    "}\n";

static const char* FS =
    "#version 330\n"
    "in vec2 uv; in vec3 normal;\n"
    "uniform sampler2D texture0; uniform vec4 colDiffuse;\n"
    "uniform int alphaTest; uniform int unshaded; uniform vec3 lightDir;\n"
    "out vec4 finalColor;\n"
    "void main() {\n"
    "  vec4 c = texture(texture0, uv) * colDiffuse;\n"
    "  if (alphaTest == 1 && c.a < 0.75) discard;\n"
    "  float l = 1.0;\n"
    "  if (unshaded == 0) l = 0.5 + 0.6 * max(dot(normalize(normal), lightDir), 0.0);\n"
    "  finalColor = vec4(c.rgb * l, c.a);\n"
    "}\n";
/* }}} */

/* {{{ models_init */
void models_init(void) {
    if (g_ready) return;
    g_shader = LoadShaderFromMemory(VS, FS);
    g_shader.locs[SHADER_LOC_MATRIX_MVP] = GetShaderLocation(g_shader, "mvp");
    g_shader.locs[SHADER_LOC_MATRIX_MODEL] = GetShaderLocation(g_shader, "matModel");
    g_shader.locs[SHADER_LOC_COLOR_DIFFUSE] = GetShaderLocation(g_shader, "colDiffuse");
    g_shader.locs[SHADER_LOC_MAP_DIFFUSE] = GetShaderLocation(g_shader, "texture0");
    g_shader.locs[SHADER_LOC_VERTEX_POSITION] = GetShaderLocationAttrib(g_shader, "vertexPosition");
    g_shader.locs[SHADER_LOC_VERTEX_TEXCOORD01] = GetShaderLocationAttrib(g_shader, "vertexTexCoord");
    g_shader.locs[SHADER_LOC_VERTEX_NORMAL] = GetShaderLocationAttrib(g_shader, "vertexNormal");
    g_loc_alpha_test = GetShaderLocation(g_shader, "alphaTest");
    g_loc_unshaded = GetShaderLocation(g_shader, "unshaded");
    g_loc_light = GetShaderLocation(g_shader, "lightDir");
    Vector3 light = Vector3Normalize((Vector3){ -0.45f, 0.8f, 0.4f });   /* render space: from the south west, high */
    SetShaderValue(g_shader, g_loc_light, &light, SHADER_UNIFORM_VEC3);
    g_material = LoadMaterialDefault();
    g_material.shader = g_shader;
    Image white = GenImageColor(2, 2, WHITE);
    g_white = LoadTextureFromImage(white);
    UnloadImage(white);
    g_ready = 1;
}
/* }}} */

/* {{{ growth */
static void* grow(void* p, int* cap, int need, size_t size) {
    if (need <= *cap) return p;
    int c = *cap ? *cap * 2 : 64;
    while (c < need) c *= 2;
    *cap = c;
    return realloc(p, (size_t)c * size);
}
/* }}} */

/* {{{ l_tex_create: (w, h, rgba [, wrap]) -> id (1-based) */
int l_tex_create(lua_State* L) {
    models_init();
    int w = (int)luaL_checkinteger(L, 1), h = (int)luaL_checkinteger(L, 2);
    size_t len;
    const char* rgba = luaL_checklstring(L, 3, &len);
    int wrap = lua_isnoneornil(L, 4) ? 1 : lua_toboolean(L, 4);
    if ((size_t)w * h * 4 > len) return luaL_error(L, "tex_create: %d x %d needs %d bytes, got %d", w, h, w * h * 4, (int)len);
    Image img = { .data = (void*)rgba, .width = w, .height = h, .mipmaps = 1,
                  .format = PIXELFORMAT_UNCOMPRESSED_R8G8B8A8 };
    Texture2D t = LoadTextureFromImage(img);
    if ((w & (w - 1)) == 0 && (h & (h - 1)) == 0) {
        GenTextureMipmaps(&t);
        SetTextureFilter(t, TEXTURE_FILTER_TRILINEAR);
    } else {
        SetTextureFilter(t, TEXTURE_FILTER_BILINEAR);
    }
    SetTextureWrap(t, wrap ? TEXTURE_WRAP_REPEAT : TEXTURE_WRAP_CLAMP);
    g_tex = grow(g_tex, &g_tex_cap, g_tex_count + 1, sizeof(Texture2D));
    g_tex[g_tex_count++] = t;
    lua_pushinteger(L, g_tex_count);
    return 1;
}
/* }}} */

/* {{{ l_mesh_create: (verts, indices) -> id */
int l_mesh_create(lua_State* L) {
    models_init();
    size_t vlen, ilen;
    const float* v = (const float*)luaL_checklstring(L, 1, &vlen);
    const unsigned short* idx = (const unsigned short*)luaL_checklstring(L, 2, &ilen);
    int nv = (int)(vlen / (8 * sizeof(float)));
    int ni = (int)(ilen / sizeof(unsigned short));
    if (nv == 0 || ni < 3) return luaL_error(L, "mesh_create: empty mesh");
    Mesh mesh = { 0 };
    mesh.vertexCount = nv;
    mesh.triangleCount = ni / 3;
    mesh.vertices = MemAlloc(nv * 3 * sizeof(float));
    mesh.normals = MemAlloc(nv * 3 * sizeof(float));
    mesh.texcoords = MemAlloc(nv * 2 * sizeof(float));
    mesh.indices = MemAlloc(ni * sizeof(unsigned short));
    for (int i = 0; i < nv; i++) {
        const float* s = v + i * 8;
        memcpy(mesh.vertices + i * 3, s, 3 * sizeof(float));
        memcpy(mesh.normals + i * 3, s + 3, 3 * sizeof(float));
        memcpy(mesh.texcoords + i * 2, s + 6, 2 * sizeof(float));
    }
    for (int i = 0; i < ni; i++) {
        mesh.indices[i] = idx[i] < nv ? idx[i] : 0;
    }
    UploadMesh(&mesh, false);
    g_mesh = grow(g_mesh, &g_mesh_cap, g_mesh_count + 1, sizeof(Mesh));
    g_mesh[g_mesh_count++] = mesh;
    lua_pushinteger(L, g_mesh_count);
    return 1;
}
/* }}} */

/* {{{ l_model_create: ({ parts }) -> id */
static int field_int(lua_State* L, int t, const char* k, int def) {
    lua_getfield(L, t, k);
    int v = lua_isnil(L, -1) ? def : (lua_isboolean(L, -1) ? lua_toboolean(L, -1) : (int)lua_tointeger(L, -1));
    lua_pop(L, 1);
    return v;
}

int l_model_create(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    int n = (int)lua_objlen(L, 1);
    ModelDef def = { .parts = calloc(n > 0 ? n : 1, sizeof(Part)), .part_count = 0 };
    for (int i = 1; i <= n; i++) {
        lua_rawgeti(L, 1, i);
        int t = lua_gettop(L);
        Part p;
        p.mesh = field_int(L, t, "mesh", 0);
        p.tex = field_int(L, t, "tex", 0);
        p.filter = field_int(L, t, "filter", 0);
        p.team = field_int(L, t, "team", 0);
        p.two_sided = field_int(L, t, "two_sided", 0);
        p.unshaded = field_int(L, t, "unshaded", 0);
        lua_getfield(L, t, "alpha");
        p.alpha = lua_isnil(L, -1) ? 1.0f : (float)lua_tonumber(L, -1);
        lua_pop(L, 2);
        if (p.mesh >= 1 && p.mesh <= g_mesh_count) def.parts[def.part_count++] = p;
    }
    g_models = grow(g_models, &g_model_cap, g_model_count + 1, sizeof(ModelDef));
    g_models[g_model_count++] = def;
    lua_pushinteger(L, g_model_count);
    return 1;
}
/* }}} */

/* {{{ l_model_draw: (id, x, y, z, facing, scale, r, g, b [, alpha]) */
int l_model_draw(lua_State* L) {
    int id = (int)luaL_checkinteger(L, 1);
    if (id < 1 || id > g_model_count) return 0;
    float x = (float)luaL_checknumber(L, 2), y = (float)luaL_checknumber(L, 3), z = (float)luaL_checknumber(L, 4);
    float yaw = (float)luaL_checknumber(L, 5), s = (float)luaL_optnumber(L, 6, 1.0);
    Color team = { (unsigned char)luaL_optinteger(L, 7, 255), (unsigned char)luaL_optinteger(L, 8, 255),
                   (unsigned char)luaL_optinteger(L, 9, 255), 255 };
    float alpha = (float)luaL_optnumber(L, 10, 1.0);
    float k = s / WC3_UNITS, c = cosf(yaw), sn = sinf(yaw);
    Matrix m = { 0 };
    /* render = (k(c x - s y), k z, -k(s x + c y)) + (x, z, -y)/128 */
    m.m0 = k * c;   m.m4 = -k * sn; m.m8 = 0;  m.m12 = x / WC3_UNITS;
    m.m1 = 0;       m.m5 = 0;       m.m9 = k;  m.m13 = z / WC3_UNITS;
    m.m2 = -k * sn; m.m6 = -k * c;  m.m10 = 0; m.m14 = -y / WC3_UNITS;
    m.m15 = 1;
    g_inst = grow(g_inst, &g_inst_cap, g_inst_count + 1, sizeof(Instance));
    g_inst[g_inst_count++] = (Instance){ id, m, team, alpha, x / WC3_UNITS, -y / WC3_UNITS };
    return 0;
}
/* }}} */

/* {{{ models_draw */
static void draw_part(const Part* p, const Instance* in) {
    int alpha_test = p->filter == 1;
    SetShaderValue(g_shader, g_loc_alpha_test, &alpha_test, SHADER_UNIFORM_INT);
    SetShaderValue(g_shader, g_loc_unshaded, &p->unshaded, SHADER_UNIFORM_INT);
    Texture2D t = (p->tex >= 1 && p->tex <= g_tex_count) ? g_tex[p->tex - 1] : g_white;
    g_material.maps[MATERIAL_MAP_DIFFUSE].texture = t;
    Color col = WHITE;
    if (p->team) col = in->team;
    col.a = (unsigned char)fmaxf(0.0f, fminf(255.0f, 255.0f * p->alpha * in->alpha));
    g_material.maps[MATERIAL_MAP_DIFFUSE].color = col;
    DrawMesh(g_mesh[p->mesh - 1], g_material, in->m);
}

void models_draw(float view_x, float view_z, float radius) {
    if (!g_ready || g_inst_count == 0) { g_last_drawn = 0; return; }
    rlDrawRenderBatchActive();
    rlDisableBackfaceCulling();
    int drawn = 0;
    float r2 = radius * radius;
    /* pass 1: opaque and alpha-tested, writing depth */
    rlDisableColorBlend();
    for (int i = 0; i < g_inst_count; i++) {
        Instance* in = &g_inst[i];
        float dx = in->x - view_x, dz = in->z - view_z;
        if (radius > 0 && dx * dx + dz * dz > r2) { in->model = 0; continue; }
        drawn++;
        ModelDef* d = &g_models[in->model - 1];
        for (int j = 0; j < d->part_count; j++) {
            if (d->parts[j].filter <= 1) draw_part(&d->parts[j], in);
        }
    }
    rlEnableColorBlend();
    /* pass 2: blended, not writing depth */
    rlDrawRenderBatchActive();
    rlDisableDepthMask();
    for (int i = 0; i < g_inst_count; i++) {
        Instance* in = &g_inst[i];
        if (in->model == 0) continue;
        ModelDef* d = &g_models[in->model - 1];
        for (int j = 0; j < d->part_count; j++) {
            const Part* p = &d->parts[j];
            if (p->filter <= 1) continue;
            if (p->filter == 3 || p->filter == 4) BeginBlendMode(BLEND_ADDITIVE);
            else if (p->filter == 5 || p->filter == 6) BeginBlendMode(BLEND_MULTIPLIED);
            else BeginBlendMode(BLEND_ALPHA);
            draw_part(p, in);
            EndBlendMode();
        }
    }
    rlDrawRenderBatchActive();
    rlEnableDepthMask();
    rlEnableBackfaceCulling();
    g_last_drawn = drawn;
    g_inst_count = 0;
}
/* }}} */

/* {{{ l_model_stats */
int l_model_stats(lua_State* L) {
    lua_pushinteger(L, g_tex_count);
    lua_pushinteger(L, g_mesh_count);
    lua_pushinteger(L, g_model_count);
    lua_pushinteger(L, g_last_drawn);
    return 4;
}
/* }}} */
