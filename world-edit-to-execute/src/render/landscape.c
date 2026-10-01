/*
 * Landscape Implementation (Issue 517b)
 *
 * See landscape.h. Each chunk holds two unindexed meshes (land, water) with
 * a colour per vertex; the colours already carry the flat shading, so the
 * default shader draws them as they are.
 *
 * Ground textures (Issue 526): over the coloured land, each chunk may hold
 * one textured mesh per tileset layer (up to 16), drawn lowest layer first
 * with alpha blending. A cell's lowest layer is a whole tile; each higher
 * one a subtile whose alpha covers only its corners (WC3's own blend
 * shapes, painted into the tileset textures). The vertex colours carry the
 * same flat shading as the land's. Cliff cells keep their rock colour.
 */

#include <math.h>
#include <stdlib.h>
#include <string.h>
#include "raylib.h"
#include "raymath.h"
#include "rlgl.h"
#include "landscape.h"
#include "geometry.h"
#include "models.h"

#define TILE_LAYERS 16

/* A triangle rising more than this (WC3 units, across one 128-unit cell)
 * is drawn as cliff rock. */
#define CLIFF_RISE 80.0f

typedef struct {
    Mesh land, water;
    int land_verts, water_verts;
    float cx, cz;        /* centre, render units */
    int i0, j0, i1, j1;  /* its cells */
    Mesh tiles[TILE_LAYERS];
    int tile_verts[TILE_LAYERS];
} LandChunk;

static LandChunk* g_chunks = NULL;
static int g_chunk_count = 0;
static float g_chunk_reach = 0.0f;   /* centre to corner, render units */
static Material g_material;
static bool g_material_ready = false;
/* what land_build was given, kept for land_tiles */
static int g_w = 0, g_h = 0;
static float g_x0 = 0, g_y0 = 0, g_tile = 128, g_scale = 1;
static float* g_heights = NULL;
static Material g_tile_material;
static bool g_tile_material_ready = false;
static int g_tile_tex[TILE_LAYERS];

/* {{{ Vertex buffer */
typedef struct {
    float* pos;
    unsigned char* col;
    int count, cap;
} VertBuf;

static void vb_tri(VertBuf* vb, Vector3 a, Vector3 b, Vector3 c, Color col) {
    if (vb->count + 3 > vb->cap) return;   /* sized exactly by the caller */
    Vector3 v[3] = { a, b, c };
    for (int i = 0; i < 3; i++) {
        int k = vb->count++;
        vb->pos[k * 3] = v[i].x;
        vb->pos[k * 3 + 1] = v[i].y;
        vb->pos[k * 3 + 2] = v[i].z;
        vb->col[k * 4] = col.r;
        vb->col[k * 4 + 1] = col.g;
        vb->col[k * 4 + 2] = col.b;
        vb->col[k * 4 + 3] = col.a;
    }
}

/* Hand a filled buffer to a mesh and upload it (the mesh keeps the memory) */
static Mesh vb_upload(VertBuf* vb) {
    Mesh m = { 0 };
    m.vertexCount = vb->count;
    m.triangleCount = vb->count / 3;
    m.vertices = vb->pos;
    m.colors = vb->col;
    UploadMesh(&m, false);
    return m;
}

static VertBuf vb_new(int verts) {
    VertBuf vb = { 0 };
    vb.cap = verts;
    vb.pos = (float*)MemAlloc(sizeof(float) * 3 * (verts > 0 ? verts : 1));
    vb.col = (unsigned char*)MemAlloc(4 * (verts > 0 ? verts : 1));
    return vb;
}
/* }}} */

/* {{{ Colours */
static Color mix(Color a, Color b, float t) {
    return (Color){ (unsigned char)(a.r + (b.r - a.r) * t), (unsigned char)(a.g + (b.g - a.g) * t),
                    (unsigned char)(a.b + (b.b - a.b) * t), 255 };
}

static const Color CLIFF_ROCK = { 112, 104, 96, 255 };
static const Color WATER_SHALLOW = { 72, 156, 196, 255 };
static const Color WATER_DEEP = { 22, 52, 128, 255 };

static Color land_colour(Color cell, float rise) {
    return rise > CLIFF_RISE ? mix(cell, CLIFF_ROCK, 0.7f) : cell;
}
/* }}} */

/* {{{ landscape_free */
static void free_tiles(LandChunk* ch) {
    for (int l = 0; l < TILE_LAYERS; l++) {
        if (ch->tile_verts[l] > 0) UnloadMesh(ch->tiles[l]);
        ch->tile_verts[l] = 0;
    }
}

void landscape_free(void) {
    for (int i = 0; i < g_chunk_count; i++) {
        if (g_chunks[i].land_verts > 0) UnloadMesh(g_chunks[i].land);
        if (g_chunks[i].water_verts > 0) UnloadMesh(g_chunks[i].water);
        free_tiles(&g_chunks[i]);
    }
    free(g_chunks);
    g_chunks = NULL;
    g_chunk_count = 0;
}
/* }}} */

/* {{{ l_land_build */
int l_land_build(lua_State* L) {
    int w = (int)luaL_checkinteger(L, 1);
    int h = (int)luaL_checkinteger(L, 2);
    float x0 = (float)luaL_checknumber(L, 3);
    float y0 = (float)luaL_checknumber(L, 4);
    float tile = (float)luaL_checknumber(L, 5);
    float scale = (float)luaL_checknumber(L, 6);
    size_t hl, cl, wl;
    const float* H = (const float*)luaL_checklstring(L, 7, &hl);
    const unsigned char* C = (const unsigned char*)luaL_checklstring(L, 8, &cl);
    const float* W = (const float*)luaL_checklstring(L, 9, &wl);

    if (w < 2 || h < 2 || hl < (size_t)w * h * 4 || wl < (size_t)w * h * 4
            || cl < (size_t)(w - 1) * (h - 1) * 3) {
        return luaL_error(L, "land_build: arrays too short for %d x %d tilepoints", w, h);
    }

    landscape_free();
    if (!g_material_ready) {
        g_material = LoadMaterialDefault();
        g_material_ready = true;
    }

    g_w = w; g_h = h; g_x0 = x0; g_y0 = y0; g_tile = tile; g_scale = scale;
    free(g_heights);
    g_heights = (float*)malloc(sizeof(float) * (size_t)w * h);
    memcpy(g_heights, H, sizeof(float) * (size_t)w * h);

    int cells_x = w - 1, cells_y = h - 1;
    int chunks_x = (cells_x + LAND_CHUNK - 1) / LAND_CHUNK;
    int chunks_y = (cells_y + LAND_CHUNK - 1) / LAND_CHUNK;
    g_chunks = (LandChunk*)calloc((size_t)chunks_x * chunks_y, sizeof(LandChunk));
    float half = LAND_CHUNK * tile * scale * 0.5f;
    g_chunk_reach = sqrtf(2.0f) * half;

#define P(i, j) ((Vector3){ (x0 + (i) * tile) * scale, H[(j) * w + (i)] * scale, \
                            -(y0 + (j) * tile) * scale })

    for (int cy = 0; cy < chunks_y; cy++) {
        for (int cx = 0; cx < chunks_x; cx++) {
            int i0 = cx * LAND_CHUNK, j0 = cy * LAND_CHUNK;
            int i1 = i0 + LAND_CHUNK < cells_x ? i0 + LAND_CHUNK : cells_x;
            int j1 = j0 + LAND_CHUNK < cells_y ? j0 + LAND_CHUNK : cells_y;

            /* count wet cells first, so buffers are sized exactly */
            int cells = (i1 - i0) * (j1 - j0), wet = 0;
            for (int j = j0; j < j1; j++) {
                for (int i = i0; i < i1; i++) {
                    int k[4] = { j * w + i, j * w + i + 1, (j + 1) * w + i + 1, (j + 1) * w + i };
                    for (int c = 0; c < 4; c++) {
                        if (W[k[c]] > H[k[c]]) { wet++; break; }
                    }
                }
            }

            VertBuf land = vb_new(cells * 6), water = vb_new(wet * 6);
            for (int j = j0; j < j1; j++) {
                for (int i = i0; i < i1; i++) {
                    const unsigned char* rgb = &C[((size_t)j * cells_x + i) * 3];
                    Color cell = { rgb[0], rgb[1], rgb[2], 255 };
                    int k[4] = { j * w + i, j * w + i + 1, (j + 1) * w + i + 1, (j + 1) * w + i };
                    Vector3 a = P(i, j), b = P(i + 1, j), c = P(i + 1, j + 1), d = P(i, j + 1);

                    float r1 = fmaxf(fmaxf(H[k[0]], H[k[1]]), H[k[2]]) - fminf(fminf(H[k[0]], H[k[1]]), H[k[2]]);
                    float r2 = fmaxf(fmaxf(H[k[0]], H[k[2]]), H[k[3]]) - fminf(fminf(H[k[0]], H[k[2]]), H[k[3]]);
                    vb_tri(&land, a, b, c, geometry_shade(a, b, c, land_colour(cell, r1)));
                    vb_tri(&land, a, c, d, geometry_shade(a, c, d, land_colour(cell, r2)));

                    /* water: level with the highest wet corner, deeper = darker */
                    float wz = -1e30f, floor_z = 1e30f;
                    for (int q = 0; q < 4; q++) {
                        if (W[k[q]] > H[k[q]] && W[k[q]] > wz) wz = W[k[q]];
                        if (H[k[q]] < floor_z) floor_z = H[k[q]];
                    }
                    if (wz > -1e29f) {
                        float depth = fminf(1.0f, fmaxf(0.0f, (wz - floor_z) / 256.0f));
                        Color wc = mix(WATER_SHALLOW, WATER_DEEP, depth);
                        float y = wz * scale;
                        Vector3 wa = { a.x, y, a.z }, wb = { b.x, y, b.z };
                        Vector3 wcc = { c.x, y, c.z }, wd = { d.x, y, d.z };
                        vb_tri(&water, wa, wb, wcc, wc);
                        vb_tri(&water, wa, wcc, wd, wc);
                    }
                }
            }

            LandChunk* ch = &g_chunks[g_chunk_count++];
            ch->i0 = i0; ch->j0 = j0; ch->i1 = i1; ch->j1 = j1;
            ch->cx = (x0 + (i0 + i1) * 0.5f * tile) * scale;
            ch->cz = -(y0 + (j0 + j1) * 0.5f * tile) * scale;
            ch->land_verts = land.count;
            ch->land = vb_upload(&land);
            ch->water_verts = water.count;
            if (water.count > 0) {
                ch->water = vb_upload(&water);
            } else {
                MemFree(water.pos);
                MemFree(water.col);
            }
        }
    }
#undef P

    lua_pushinteger(L, g_chunk_count);
    return 1;
}
/* }}} */

/* {{{ l_land_tiles
 * render.land_tiles(textures, cells)
 *   textures  { tex id per layer 1..16 } (tex_create ids; 0 or nil: none)
 *   cells     string: (w-1)*(h-1) cells, rows from y = 0, 8 bytes each: four
 *             (layer 0-15, subtile 0-31) pairs, lowest layer first; layer
 *             255 ends a cell's list. Subtile v is column v % 4, row v / 4
 *             of a tileset's left half (v < 16), or column 4 + (v - 16) % 4,
 *             row (v - 16) / 4 of an extended one's right half; subtiles are
 *             a quarter of the texture's height square, north at the top
 * Replaces any tiles given before. -> triangles built */
int l_land_tiles(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    size_t len;
    const unsigned char* cells = (const unsigned char*)luaL_checklstring(L, 2, &len);
    if (g_chunk_count == 0 || !g_heights) return luaL_error(L, "land_tiles: no land built");
    int cells_x = g_w - 1, cells_y = g_h - 1;
    if (len < (size_t)cells_x * cells_y * 8) {
        return luaL_error(L, "land_tiles: need %d bytes, got %d", cells_x * cells_y * 8, (int)len);
    }
    Texture2D tex[TILE_LAYERS];
    int have[TILE_LAYERS];
    for (int l = 0; l < TILE_LAYERS; l++) {
        lua_rawgeti(L, 1, l + 1);
        g_tile_tex[l] = lua_isnumber(L, -1) ? (int)lua_tointeger(L, -1) : 0;
        lua_pop(L, 1);
        have[l] = models_texture(g_tile_tex[l], &tex[l]);
    }
    if (!g_tile_material_ready) {
        g_tile_material = LoadMaterialDefault();
        g_tile_material_ready = true;
    }
    const float* H = g_heights;
    int w = g_w;
    float x0 = g_x0, y0 = g_y0, tile = g_tile, scale = g_scale;
#define P(i, j) ((Vector3){ (x0 + (i) * tile) * scale, H[(j) * w + (i)] * scale, \
                            -(y0 + (j) * tile) * scale })
    int triangles = 0;
    for (int c = 0; c < g_chunk_count; c++) {
        LandChunk* ch = &g_chunks[c];
        free_tiles(ch);
        for (int l = 0; l < TILE_LAYERS; l++) {
            if (!have[l]) continue;
            /* count this layer's cells in the chunk */
            int n = 0;
            for (int j = ch->j0; j < ch->j1; j++) {
                for (int i = ch->i0; i < ch->i1; i++) {
                    const unsigned char* e = cells + ((size_t)j * cells_x + i) * 8;
                    for (int q = 0; q < 4 && e[q * 2] != 255; q++) if (e[q * 2] == l) n++;
                }
            }
            if (n == 0) continue;
            Mesh m = { 0 };
            m.vertices = (float*)MemAlloc(sizeof(float) * 3 * 6 * n);
            m.texcoords = (float*)MemAlloc(sizeof(float) * 2 * 6 * n);
            m.colors = (unsigned char*)MemAlloc(4 * 6 * n);
            int k = 0;
            float tw = (float)tex[l].width, th = (float)tex[l].height, sub = th / 4.0f;
            for (int j = ch->j0; j < ch->j1; j++) {
                for (int i = ch->i0; i < ch->i1; i++) {
                    const unsigned char* e = cells + ((size_t)j * cells_x + i) * 8;
                    for (int q = 0; q < 4 && e[q * 2] != 255; q++) {
                        if (e[q * 2] != l) continue;
                        int v = e[q * 2 + 1];
                        int col = v < 16 ? v % 4 : 4 + (v - 16) % 4;
                        int row = v < 16 ? v / 4 : (v - 16) / 4;
                        float u0 = (col * sub + 0.5f) / tw, u1 = ((col + 1) * sub - 0.5f) / tw;
                        float v0 = (row * sub + 0.5f) / th, v1 = ((row + 1) * sub - 0.5f) / th;
                        Vector3 a = P(i, j), b = P(i + 1, j), cc = P(i + 1, j + 1), d = P(i, j + 1);
                        /* south-west a, south-east b, north-east cc, north-west d;
                         * the subtile's top is north */
                        float uv[4][2] = { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } };
                        Vector3 pos[4] = { a, b, cc, d };
                        int tri[6] = { 0, 1, 2, 0, 2, 3 };
                        Color s1 = geometry_shade(a, b, cc, WHITE), s2 = geometry_shade(a, cc, d, WHITE);
                        for (int t = 0; t < 6; t++) {
                            int p = tri[t];
                            Color sc = t < 3 ? s1 : s2;
                            m.vertices[k * 3] = pos[p].x; m.vertices[k * 3 + 1] = pos[p].y; m.vertices[k * 3 + 2] = pos[p].z;
                            m.texcoords[k * 2] = uv[p][0]; m.texcoords[k * 2 + 1] = uv[p][1];
                            m.colors[k * 4] = sc.r; m.colors[k * 4 + 1] = sc.g; m.colors[k * 4 + 2] = sc.b;
                            m.colors[k * 4 + 3] = 255;
                            k++;
                        }
                    }
                }
            }
            m.vertexCount = k;
            m.triangleCount = k / 3;
            UploadMesh(&m, false);
            ch->tiles[l] = m;
            ch->tile_verts[l] = k;
            triangles += k / 3;
        }
    }
#undef P
    lua_pushinteger(L, triangles);
    return 1;
}
/* }}} */

/* {{{ l_land_free */
int l_land_free(lua_State* L) {
    (void)L;
    landscape_free();
    return 0;
}
/* }}} */

/* {{{ landscape_draw */
void landscape_draw(float cam_x, float cam_z, float radius) {
    if (g_chunk_count == 0) return;
    rlDrawRenderBatchActive();
    rlDisableBackfaceCulling();
    Matrix id = MatrixIdentity();
    float reach = radius + g_chunk_reach;
    for (int pass = 0; pass < 2; pass++) {
        for (int i = 0; i < g_chunk_count; i++) {
            LandChunk* ch = &g_chunks[i];
            float dx = ch->cx - cam_x, dz = ch->cz - cam_z;
            if (dx * dx + dz * dz > reach * reach) continue;
            if (pass == 0 && ch->land_verts > 0) DrawMesh(ch->land, g_material, id);
            if (pass == 0) {
                for (int l = 0; l < TILE_LAYERS; l++) {
                    Texture2D t;
                    if (ch->tile_verts[l] == 0 || !models_texture(g_tile_tex[l], &t)) continue;
                    g_tile_material.maps[MATERIAL_MAP_DIFFUSE].texture = t;
                    DrawMesh(ch->tiles[l], g_tile_material, id);
                }
            }
            if (pass == 1 && ch->water_verts > 0) DrawMesh(ch->water, g_material, id);
        }
    }
    rlDrawRenderBatchActive();
    rlEnableBackfaceCulling();
}
/* }}} */
