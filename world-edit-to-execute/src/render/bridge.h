/*
 * Lua-C Bridge (Issue 508c)
 *
 * Exposes the slot system to Lua, allowing game logic to create/update/destroy
 * render entities. Lua calls these C functions directly; no queuing.
 *
 * Architecture:
 *   Lua game logic -> bridge functions -> slot system -> render thread
 */

#ifndef BRIDGE_H
#define BRIDGE_H

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include "slots.h"

/* {{{ Bridge Initialization
 * Must be called before any Lua code uses the render module.
 * Stores a reference to the slot array for all bridge functions. */
void bridge_init(SlotArray* slots);
/* }}} */

/* {{{ Lua Module Registration
 * Call this to register the "render" module in a Lua state.
 * After calling, Lua code can: local render = require("render") */
int luaopen_render(lua_State* L);
/* }}} */

/* {{{ Bridge State Query
 * Returns the slot array pointer, or NULL if not initialized. */
SlotArray* bridge_get_slots(void);
/* }}} */

/* {{{ Lua API Functions
 * These are registered as render.xxx in Lua.
 * They should not be called directly from C. */

/* render.create_entity(entity_id, mesh_id, x, y, z) -> slot_index
 * Creates a render slot for an entity. Returns -1 if allocation fails. */
int l_create_entity(lua_State* L);

/* render.destroy_entity(slot_index)
 * Releases a render slot back to the free list. */
int l_destroy_entity(lua_State* L);

/* render.set_position(slot_index, x, y, z)
 * Updates entity world position. */
int l_set_position(lua_State* L);

/* render.set_color(slot_index, r, g, b [, a])
 * Updates entity RGBA color. Alpha defaults to 255. */
int l_set_color(lua_State* L);

/* render.set_selected(slot_index, selected)
 * Sets selection state for highlight ring. */
int l_set_selected(lua_State* L);

/* render.set_visible(slot_index, visible)
 * Hides/shows entity without deallocating slot. */
int l_set_visible(lua_State* L);

/* render.set_scale(slot_index, scale)
 * Sets uniform scale factor. */
int l_set_scale(lua_State* L);

/* render.set_team(slot_index, team_id)
 * Sets team for color tinting. -1 = no team. */
int l_set_team(lua_State* L);

/* render.set_rotation(slot_index, rotation, spin, facing)
 * Sets all orientation angles in degrees. */
int l_set_rotation(lua_State* L);

/* render.set_mesh(slot_index, mesh_id)
 * Changes the mesh/model to render. */
int l_set_mesh(lua_State* L);

/* render.get_slot_count() -> active, max
 * Returns active slot count and max capacity. */
int l_get_slot_count(lua_State* L);

/* render.find_by_entity(entity_id) -> slot_index or nil
 * Finds slot for an entity ID. Returns nil if not found. */
int l_find_by_entity(lua_State* L);

/* }}} */

#endif /* BRIDGE_H */
