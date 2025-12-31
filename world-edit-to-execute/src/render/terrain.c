/*
 * Terrain Grid Implementation (Issue 508d)
 *
 * Implements terrain grid storage and rendering. The terrain is rendered
 * as a series of flat colored quads (DrawPlane) positioned in 3D space.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include "terrain.h"
#include "raylib.h"

/* {{{ Global terrain instance */
static TerrainGrid* g_terrain = NULL;

TerrainGrid* terrain_get_global(void) {
    return g_terrain;
}

void terrain_set_global(TerrainGrid* t) {
    g_terrain = t;
}
/* }}} */

/* {{{ terrain_create */
TerrainGrid* terrain_create(int width, int height, float tile_size) {
    /* Validate dimensions */
    if (width <= 0 || height <= 0 ||
        width > TERRAIN_MAX_WIDTH || height > TERRAIN_MAX_HEIGHT) {
        fprintf(stderr, "[terrain] Invalid dimensions: %dx%d (max %dx%d)\n",
                width, height, TERRAIN_MAX_WIDTH, TERRAIN_MAX_HEIGHT);
        return NULL;
    }

    if (tile_size <= 0.0f) {
        fprintf(stderr, "[terrain] Invalid tile size: %.2f\n", tile_size);
        return NULL;
    }

    TerrainGrid* t = (TerrainGrid*)malloc(sizeof(TerrainGrid));
    if (!t) {
        fprintf(stderr, "[terrain] Failed to allocate grid struct\n");
        return NULL;
    }

    t->width = width;
    t->height = height;
    t->tile_size = tile_size;
    t->offset_x = 0.0f;
    t->offset_z = 0.0f;
    t->initialized = false;

    /* Allocate color data (3 bytes per tile: RGB) */
    size_t color_bytes = (size_t)width * (size_t)height * 3;
    t->colors = (unsigned char*)malloc(color_bytes);
    if (!t->colors) {
        fprintf(stderr, "[terrain] Failed to allocate %zu bytes for colors\n", color_bytes);
        free(t);
        return NULL;
    }

    /* Initialize all tiles to dark gray (default terrain color) */
    for (size_t i = 0; i < color_bytes; i += 3) {
        t->colors[i] = 60;      /* R */
        t->colors[i + 1] = 60;  /* G */
        t->colors[i + 2] = 60;  /* B */
    }

    t->initialized = true;
    printf("[terrain] Created %dx%d grid, tile_size=%.2f, %zu bytes\n",
           width, height, tile_size, color_bytes);

    return t;
}
/* }}} */

/* {{{ terrain_destroy */
void terrain_destroy(TerrainGrid* t) {
    if (!t) return;

    if (t->colors) {
        free(t->colors);
        t->colors = NULL;
    }

    t->initialized = false;
    free(t);

    printf("[terrain] Destroyed grid\n");
}
/* }}} */

/* {{{ terrain_set_tile */
void terrain_set_tile(TerrainGrid* t, int x, int y,
                      unsigned char r, unsigned char g, unsigned char b) {
    if (!t || !t->colors || !t->initialized) return;
    if (x < 0 || x >= t->width || y < 0 || y >= t->height) return;

    size_t idx = ((size_t)y * t->width + x) * 3;
    t->colors[idx] = r;
    t->colors[idx + 1] = g;
    t->colors[idx + 2] = b;
}
/* }}} */

/* {{{ terrain_set_offset */
void terrain_set_offset(TerrainGrid* t, float offset_x, float offset_z) {
    if (!t) return;
    t->offset_x = offset_x;
    t->offset_z = offset_z;
}
/* }}} */

/* {{{ terrain_get_tile */
bool terrain_get_tile(TerrainGrid* t, int x, int y,
                      unsigned char* r, unsigned char* g, unsigned char* b) {
    if (!t || !t->colors || !t->initialized) return false;
    if (x < 0 || x >= t->width || y < 0 || y >= t->height) return false;

    size_t idx = ((size_t)y * t->width + x) * 3;
    if (r) *r = t->colors[idx];
    if (g) *g = t->colors[idx + 1];
    if (b) *b = t->colors[idx + 2];

    return true;
}
/* }}} */

/* {{{ terrain_draw */
void terrain_draw(TerrainGrid* t) {
    if (!t || !t->colors || !t->initialized) return;

    float half_tile = t->tile_size * 0.5f;

    for (int y = 0; y < t->height; y++) {
        for (int x = 0; x < t->width; x++) {
            size_t idx = ((size_t)y * t->width + x) * 3;
            unsigned char r = t->colors[idx];
            unsigned char g = t->colors[idx + 1];
            unsigned char b = t->colors[idx + 2];

            /* Calculate world position (center of tile) */
            float wx = t->offset_x + x * t->tile_size + half_tile;
            float wz = t->offset_z + y * t->tile_size + half_tile;
            float wy = 0.0f;  /* Ground level */

            Color col = { r, g, b, 255 };

            /* Draw as flat cube (very thin in Y) for visibility */
            DrawCube((Vector3){ wx, wy, wz },
                     t->tile_size * 0.98f, 0.1f, t->tile_size * 0.98f, col);
        }
    }
}
/* }}} */

/* {{{ terrain_draw_grid_lines */
void terrain_draw_grid_lines(TerrainGrid* t) {
    if (!t || !t->initialized) return;

    Color line_color = { 80, 80, 80, 255 };
    float y = 0.05f;  /* Slightly above tiles */

    /* Vertical lines (along Z axis) */
    for (int x = 0; x <= t->width; x++) {
        float wx = t->offset_x + x * t->tile_size;
        float z_start = t->offset_z;
        float z_end = t->offset_z + t->height * t->tile_size;

        DrawLine3D((Vector3){ wx, y, z_start },
                   (Vector3){ wx, y, z_end },
                   line_color);
    }

    /* Horizontal lines (along X axis) */
    for (int z = 0; z <= t->height; z++) {
        float wz = t->offset_z + z * t->tile_size;
        float x_start = t->offset_x;
        float x_end = t->offset_x + t->width * t->tile_size;

        DrawLine3D((Vector3){ x_start, y, wz },
                   (Vector3){ x_end, y, wz },
                   line_color);
    }
}
/* }}} */

/* {{{ Lua Bridge Implementation */

/* {{{ l_terrain_create
 * Lua: render.terrain_create(width, height, tile_size) */
int l_terrain_create(lua_State* L) {
    int width = luaL_checkinteger(L, 1);
    int height = luaL_checkinteger(L, 2);
    float tile_size = (float)luaL_checknumber(L, 3);

    /* Destroy existing terrain if any */
    if (g_terrain) {
        terrain_destroy(g_terrain);
        g_terrain = NULL;
    }

    g_terrain = terrain_create(width, height, tile_size);

    lua_pushboolean(L, g_terrain != NULL);
    return 1;
}
/* }}} */

/* {{{ l_terrain_destroy
 * Lua: render.terrain_destroy() */
int l_terrain_destroy(lua_State* L) {
    (void)L;  /* Unused */

    if (g_terrain) {
        terrain_destroy(g_terrain);
        g_terrain = NULL;
    }

    return 0;
}
/* }}} */

/* {{{ l_terrain_set_tile
 * Lua: render.terrain_set_tile(x, y, r, g, b) */
int l_terrain_set_tile(lua_State* L) {
    if (!g_terrain) return 0;

    int x = luaL_checkinteger(L, 1);
    int y = luaL_checkinteger(L, 2);
    int r = luaL_checkinteger(L, 3);
    int g = luaL_checkinteger(L, 4);
    int b = luaL_checkinteger(L, 5);

    /* Clamp to 0-255 */
    if (r < 0) r = 0; else if (r > 255) r = 255;
    if (g < 0) g = 0; else if (g > 255) g = 255;
    if (b < 0) b = 0; else if (b > 255) b = 255;

    terrain_set_tile(g_terrain, x, y,
                     (unsigned char)r, (unsigned char)g, (unsigned char)b);

    return 0;
}
/* }}} */

/* {{{ l_terrain_set_offset
 * Lua: render.terrain_set_offset(offset_x, offset_z) */
int l_terrain_set_offset(lua_State* L) {
    if (!g_terrain) return 0;

    float offset_x = (float)luaL_checknumber(L, 1);
    float offset_z = (float)luaL_checknumber(L, 2);

    terrain_set_offset(g_terrain, offset_x, offset_z);

    return 0;
}
/* }}} */

/* {{{ l_terrain_set_tiles
 * Lua: render.terrain_set_tiles(tiles_table)
 * Bulk set tiles from Lua table: {{x, y, r, g, b}, ...} */
int l_terrain_set_tiles(lua_State* L) {
    if (!g_terrain) return 0;

    luaL_checktype(L, 1, LUA_TTABLE);

    /* Iterate over the table */
    int len = (int)lua_objlen(L, 1);
    for (int i = 1; i <= len; i++) {
        lua_rawgeti(L, 1, i);  /* Push table[i] */

        if (lua_istable(L, -1)) {
            /* Extract {x, y, r, g, b} */
            lua_rawgeti(L, -1, 1); int x = (int)lua_tointeger(L, -1); lua_pop(L, 1);
            lua_rawgeti(L, -1, 2); int y = (int)lua_tointeger(L, -1); lua_pop(L, 1);
            lua_rawgeti(L, -1, 3); int r = (int)lua_tointeger(L, -1); lua_pop(L, 1);
            lua_rawgeti(L, -1, 4); int g = (int)lua_tointeger(L, -1); lua_pop(L, 1);
            lua_rawgeti(L, -1, 5); int b = (int)lua_tointeger(L, -1); lua_pop(L, 1);

            /* Clamp and set */
            if (r < 0) r = 0; else if (r > 255) r = 255;
            if (g < 0) g = 0; else if (g > 255) g = 255;
            if (b < 0) b = 0; else if (b > 255) b = 255;

            terrain_set_tile(g_terrain, x, y,
                             (unsigned char)r, (unsigned char)g, (unsigned char)b);
        }

        lua_pop(L, 1);  /* Pop table[i] */
    }

    return 0;
}
/* }}} */

/* {{{ l_terrain_info
 * Lua: render.terrain_info() -> width, height, tile_size */
int l_terrain_info(lua_State* L) {
    if (!g_terrain) {
        lua_pushnil(L);
        return 1;
    }

    lua_pushinteger(L, g_terrain->width);
    lua_pushinteger(L, g_terrain->height);
    lua_pushnumber(L, g_terrain->tile_size);

    return 3;
}
/* }}} */

/* }}} */
