/*
 * Lua-C Bridge Implementation (Issue 508c)
 *
 * Implements the bridge between Lua game logic and C render slots.
 * All functions validate inputs and handle missing/null gracefully.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "bridge.h"
#include "terrain.h"
#include "input.h"
#include "ui.h"

/* {{{ Module State
 * Stores the slot array reference. Set by bridge_init(). */
static SlotArray* g_bridge_slots = NULL;
/* }}} */

/* {{{ bridge_init */
void bridge_init(SlotArray* slots) {
    g_bridge_slots = slots;
}
/* }}} */

/* {{{ bridge_get_slots */
SlotArray* bridge_get_slots(void) {
    return g_bridge_slots;
}
/* }}} */

/* {{{ l_create_entity
 * Lua: render.create_entity(entity_id, mesh_id, x, y, z) -> slot_index */
int l_create_entity(lua_State* L) {
    if (!g_bridge_slots) {
        lua_pushinteger(L, -1);
        return 1;
    }

    int entity_id = luaL_checkinteger(L, 1);
    int mesh_id = luaL_checkinteger(L, 2);
    float x = (float)luaL_checknumber(L, 3);
    float y = (float)luaL_checknumber(L, 4);
    float z = (float)luaL_checknumber(L, 5);

    /* Allocate slot and link to entity */
    int slot_index = slot_allocate_for_entity(g_bridge_slots, entity_id);
    if (slot_index < 0) {
        lua_pushinteger(L, -1);
        return 1;
    }

    /* Create initial render data */
    RenderSlot* data = (RenderSlot*)malloc(sizeof(RenderSlot));
    if (!data) {
        slot_release(g_bridge_slots, slot_index);
        lua_pushinteger(L, -1);
        return 1;
    }

    /* Initialize with provided values and sensible defaults */
    memset(data, 0, sizeof(RenderSlot));
    data->x = x;
    data->y = y;
    data->z = z;
    data->mesh_id = mesh_id;
    data->visible = true;
    data->selected = false;
    data->scale = 1.0f;
    data->r = 255;
    data->g = 255;
    data->b = 255;
    data->a = 255;
    data->team_id = -1;
    data->rotation = 0.0f;
    data->spin = 0.0f;
    data->facing = 0.0f;

    /* Set data on slot (mise en place - old data freed automatically) */
    ComponentSlot* slot = slot_get(g_bridge_slots, slot_index);
    if (slot) {
        slot_set(slot, data);
    }

    lua_pushinteger(L, slot_index);
    return 1;
}
/* }}} */

/* {{{ l_destroy_entity
 * Lua: render.destroy_entity(slot_index) */
int l_destroy_entity(lua_State* L) {
    if (!g_bridge_slots) {
        return 0;
    }

    int slot_index = luaL_checkinteger(L, 1);
    slot_release(g_bridge_slots, slot_index);
    return 0;
}
/* }}} */

/* {{{ l_set_position
 * Lua: render.set_position(slot_index, x, y, z) */
int l_set_position(lua_State* L) {
    if (!g_bridge_slots) {
        return 0;
    }

    int slot_index = luaL_checkinteger(L, 1);
    float x = (float)luaL_checknumber(L, 2);
    float y = (float)luaL_checknumber(L, 3);
    float z = (float)luaL_checknumber(L, 4);

    ComponentSlot* slot = slot_get(g_bridge_slots, slot_index);
    if (slot && slot->in_use && slot->data) {
        slot->data->x = x;
        slot->data->y = y;
        slot->data->z = z;
    }

    return 0;
}
/* }}} */

/* {{{ l_set_color
 * Lua: render.set_color(slot_index, r, g, b [, a]) */
int l_set_color(lua_State* L) {
    if (!g_bridge_slots) {
        return 0;
    }

    int slot_index = luaL_checkinteger(L, 1);
    int r = luaL_checkinteger(L, 2);
    int g = luaL_checkinteger(L, 3);
    int b = luaL_checkinteger(L, 4);
    int a = luaL_optinteger(L, 5, 255);

    /* Clamp to 0-255 */
    if (r < 0) { r = 0; } else if (r > 255) { r = 255; }
    if (g < 0) { g = 0; } else if (g > 255) { g = 255; }
    if (b < 0) { b = 0; } else if (b > 255) { b = 255; }
    if (a < 0) { a = 0; } else if (a > 255) { a = 255; }

    ComponentSlot* slot = slot_get(g_bridge_slots, slot_index);
    if (slot && slot->in_use && slot->data) {
        slot->data->r = (unsigned char)r;
        slot->data->g = (unsigned char)g;
        slot->data->b = (unsigned char)b;
        slot->data->a = (unsigned char)a;
    }

    return 0;
}
/* }}} */

/* {{{ l_set_selected
 * Lua: render.set_selected(slot_index, selected) */
int l_set_selected(lua_State* L) {
    if (!g_bridge_slots) {
        return 0;
    }

    int slot_index = luaL_checkinteger(L, 1);
    int selected = lua_toboolean(L, 2);

    ComponentSlot* slot = slot_get(g_bridge_slots, slot_index);
    if (slot && slot->in_use && slot->data) {
        slot->data->selected = selected ? true : false;
    }

    return 0;
}
/* }}} */

/* {{{ l_set_visible
 * Lua: render.set_visible(slot_index, visible) */
int l_set_visible(lua_State* L) {
    if (!g_bridge_slots) {
        return 0;
    }

    int slot_index = luaL_checkinteger(L, 1);
    int visible = lua_toboolean(L, 2);

    ComponentSlot* slot = slot_get(g_bridge_slots, slot_index);
    if (slot && slot->in_use && slot->data) {
        slot->data->visible = visible ? true : false;
    }

    return 0;
}
/* }}} */

/* {{{ l_set_scale
 * Lua: render.set_scale(slot_index, scale) */
int l_set_scale(lua_State* L) {
    if (!g_bridge_slots) {
        return 0;
    }

    int slot_index = luaL_checkinteger(L, 1);
    float scale = (float)luaL_checknumber(L, 2);

    /* Prevent negative or zero scale */
    if (scale <= 0.0f) scale = 0.01f;

    ComponentSlot* slot = slot_get(g_bridge_slots, slot_index);
    if (slot && slot->in_use && slot->data) {
        slot->data->scale = scale;
    }

    return 0;
}
/* }}} */

/* {{{ l_set_team
 * Lua: render.set_team(slot_index, team_id) */
int l_set_team(lua_State* L) {
    if (!g_bridge_slots) {
        return 0;
    }

    int slot_index = luaL_checkinteger(L, 1);
    int team_id = luaL_checkinteger(L, 2);

    ComponentSlot* slot = slot_get(g_bridge_slots, slot_index);
    if (slot && slot->in_use && slot->data) {
        slot->data->team_id = team_id;
    }

    return 0;
}
/* }}} */

/* {{{ l_set_rotation
 * Lua: render.set_rotation(slot_index, rotation, spin, facing) */
int l_set_rotation(lua_State* L) {
    if (!g_bridge_slots) {
        return 0;
    }

    int slot_index = luaL_checkinteger(L, 1);
    float rotation = (float)luaL_checknumber(L, 2);
    float spin = (float)luaL_optnumber(L, 3, 0.0);
    float facing = (float)luaL_optnumber(L, 4, 0.0);

    ComponentSlot* slot = slot_get(g_bridge_slots, slot_index);
    if (slot && slot->in_use && slot->data) {
        slot->data->rotation = rotation;
        slot->data->spin = spin;
        slot->data->facing = facing;
    }

    return 0;
}
/* }}} */

/* {{{ l_set_mesh
 * Lua: render.set_mesh(slot_index, mesh_id) */
int l_set_mesh(lua_State* L) {
    if (!g_bridge_slots) {
        return 0;
    }

    int slot_index = luaL_checkinteger(L, 1);
    int mesh_id = luaL_checkinteger(L, 2);

    ComponentSlot* slot = slot_get(g_bridge_slots, slot_index);
    if (slot && slot->in_use && slot->data) {
        slot->data->mesh_id = mesh_id;
    }

    return 0;
}
/* }}} */

/* {{{ l_get_slot_count
 * Lua: render.get_slot_count() -> active, max */
int l_get_slot_count(lua_State* L) {
    if (!g_bridge_slots) {
        lua_pushinteger(L, 0);
        lua_pushinteger(L, 0);
        return 2;
    }

    int active = slot_get_active_count(g_bridge_slots);
    lua_pushinteger(L, active);
    lua_pushinteger(L, MAX_SLOTS);
    return 2;
}
/* }}} */

/* {{{ l_find_by_entity
 * Lua: render.find_by_entity(entity_id) -> slot_index or nil */
int l_find_by_entity(lua_State* L) {
    if (!g_bridge_slots) {
        lua_pushnil(L);
        return 1;
    }

    int entity_id = luaL_checkinteger(L, 1);
    int slot_index = slot_find_by_entity(g_bridge_slots, entity_id);

    if (slot_index < 0) {
        lua_pushnil(L);
    } else {
        lua_pushinteger(L, slot_index);
    }
    return 1;
}
/* }}} */

/* {{{ luaopen_render
 * Module registration function. Called when Lua requires "render". */
static const luaL_Reg render_funcs[] = {
    /* Entity functions (508c) */
    {"create_entity", l_create_entity},
    {"destroy_entity", l_destroy_entity},
    {"set_position", l_set_position},
    {"set_color", l_set_color},
    {"set_selected", l_set_selected},
    {"set_visible", l_set_visible},
    {"set_scale", l_set_scale},
    {"set_team", l_set_team},
    {"set_rotation", l_set_rotation},
    {"set_mesh", l_set_mesh},
    {"get_slot_count", l_get_slot_count},
    {"find_by_entity", l_find_by_entity},
    /* Terrain functions (508d) */
    {"terrain_create", l_terrain_create},
    {"terrain_destroy", l_terrain_destroy},
    {"terrain_set_tile", l_terrain_set_tile},
    {"terrain_set_offset", l_terrain_set_offset},
    {"terrain_set_tiles", l_terrain_set_tiles},
    {"terrain_info", l_terrain_info},
    /* Selection functions (508e) */
    {"get_selection", l_get_selection},
    {"set_selection", l_set_selection},
    {"clear_selection", l_clear_selection},
    {"get_entity_at", l_get_entity_at},
    {"get_mouse_world", l_get_mouse_world},
    {"is_selected", l_is_selected},
    /* Movement functions (508f) */
    {"show_move_marker", l_show_move_marker},
    /* UI functions (508g) */
    {"ui_set_resources", l_ui_set_resources},
    {"ui_set_selection", l_ui_set_selection},
    {"ui_set_game_time", l_ui_set_game_time},
    {"ui_clear_selection", l_ui_clear_selection},
    {"ui_show", l_ui_show},
    {NULL, NULL}
};

int luaopen_render(lua_State* L) {
    /* Create the module table */
    lua_newtable(L);

    /* Register all functions */
    for (const luaL_Reg* reg = render_funcs; reg->name != NULL; reg++) {
        lua_pushcfunction(L, reg->func);
        lua_setfield(L, -2, reg->name);
    }

    /* Add mesh type constants */
    lua_pushinteger(L, 0);
    lua_setfield(L, -2, "MESH_CIRCLE");
    lua_pushinteger(L, 1);
    lua_setfield(L, -2, "MESH_CUBE");
    lua_pushinteger(L, 2);
    lua_setfield(L, -2, "MESH_TRIANGLE");
    lua_pushinteger(L, 3);
    lua_setfield(L, -2, "MESH_CYLINDER");

    /* Add slot count constant */
    lua_pushinteger(L, MAX_SLOTS);
    lua_setfield(L, -2, "MAX_SLOTS");

    return 1;
}
/* }}} */
