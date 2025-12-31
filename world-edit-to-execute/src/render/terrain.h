/*
 * Terrain Grid Renderer (Issue 508d)
 *
 * Renders map terrain as a colored tile grid. Each tile's color is determined
 * by the terrain type from the w3e parser. Height variation is not rendered
 * in this initial implementation - just flat colored tiles.
 *
 * Architecture:
 *   Lua (map_renderer) -> terrain C API -> terrain grid -> draw thread
 */

#ifndef TERRAIN_H
#define TERRAIN_H

#include <stdbool.h>

/* {{{ Configuration */
#define TERRAIN_MAX_WIDTH 512
#define TERRAIN_MAX_HEIGHT 512
/* }}} */

/* {{{ TerrainGrid - stores tile colors for rendering
 * The grid is a flattened 2D array of RGB colors.
 * Index formula: (y * width + x) * 3 for the red component */
typedef struct terrain_grid {
    int width;               /* Number of tiles in X direction */
    int height;              /* Number of tiles in Y direction */
    float tile_size;         /* World units per tile (typically 128/4 = 32) */
    float offset_x;          /* World offset to center the map */
    float offset_z;          /* World offset to center the map */
    unsigned char* colors;   /* RGB data, 3 bytes per tile (width * height * 3) */
    bool initialized;        /* True after terrain_create() succeeds */
} TerrainGrid;
/* }}} */

/* {{{ Lifecycle Functions */

/* terrain_create
 * Allocates and initializes a terrain grid.
 * Returns NULL if allocation fails or dimensions exceed limits. */
TerrainGrid* terrain_create(int width, int height, float tile_size);

/* terrain_destroy
 * Frees terrain grid and its color data. */
void terrain_destroy(TerrainGrid* t);

/* }}} */

/* {{{ Tile Operations */

/* terrain_set_tile
 * Sets the RGB color of a single tile at (x, y).
 * Does nothing if coordinates are out of bounds. */
void terrain_set_tile(TerrainGrid* t, int x, int y,
                      unsigned char r, unsigned char g, unsigned char b);

/* terrain_set_offset
 * Sets the world offset for centering the terrain. */
void terrain_set_offset(TerrainGrid* t, float offset_x, float offset_z);

/* terrain_get_tile
 * Gets the RGB color of a tile. Returns false if out of bounds. */
bool terrain_get_tile(TerrainGrid* t, int x, int y,
                      unsigned char* r, unsigned char* g, unsigned char* b);

/* }}} */

/* {{{ Rendering */

/* terrain_draw
 * Renders the terrain grid as colored quads in 3D space.
 * Must be called within BeginMode3D/EndMode3D block. */
void terrain_draw(TerrainGrid* t);

/* terrain_draw_grid_lines
 * Renders grid lines on top of terrain for debugging.
 * Must be called within BeginMode3D/EndMode3D block. */
void terrain_draw_grid_lines(TerrainGrid* t);

/* }}} */

/* {{{ Lua Bridge Functions
 * These are registered as render.terrain_xxx in Lua.
 * Declared here for bridge.c to use. */

#include <lua.h>

/* render.terrain_create(width, height, tile_size) */
int l_terrain_create(lua_State* L);

/* render.terrain_destroy() */
int l_terrain_destroy(lua_State* L);

/* render.terrain_set_tile(x, y, r, g, b) */
int l_terrain_set_tile(lua_State* L);

/* render.terrain_set_offset(offset_x, offset_z) */
int l_terrain_set_offset(lua_State* L);

/* render.terrain_set_tiles(tiles_table)
 * Bulk set tiles from Lua table: {{x, y, r, g, b}, ...} */
int l_terrain_set_tiles(lua_State* L);

/* render.terrain_info() -> width, height, tile_size */
int l_terrain_info(lua_State* L);

/* }}} */

/* {{{ Global Terrain Access
 * The global terrain grid, shared between bridge and main. */
TerrainGrid* terrain_get_global(void);
void terrain_set_global(TerrainGrid* t);
/* }}} */

#endif /* TERRAIN_H */
