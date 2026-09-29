/*
 * models.h - textured models (Issue 522c)
 *
 * WC3 models (parsers/mdx.lua) turned into GPU meshes and textures by
 * render/model_cache.lua, drawn here: each model is a list of parts
 * (a mesh with a texture, WC3's filter mode, two-sidedness and whether
 * it takes the team colour), placed per frame as instances.
 *
 * Lua (render.*):
 *   tex_create(w, h, rgba [, wrap])        -> texture id
 *   mesh_create(verts, indices [, skin])   -> mesh id
 *        verts: floats x y z nx ny nz u v per vertex (model space, WC3 units)
 *        indices: uint16 triangle list
 *        skin: uint16 per vertex, its matrix group (Issue 523)
 *   model_create({ {mesh=, tex=, filter=, two_sided=, team=, unshaded=, alpha=, skin=}, ... }
 *                [, { groups of skin 1, groups of skin 2, ... }]) -> model id
 *   model_draw(id, x, y, z, facing, scale, r, g, b [, alpha [, pose]])   queue one for this frame
 *        pose: floats: one alpha per part given, then per skin a 3 x 4
 *        row-major matrix per group (model space); drawn in rest pose
 *        without one
 *   model_stats() -> textures, meshes, models, instances drawn last frame
 */
#ifndef MODELS_H
#define MODELS_H

#include "lua.h"

void models_init(void);
void models_draw(float view_x, float view_z, float radius);   /* the queued instances; clears the queue */

int l_tex_create(lua_State* L);
int l_mesh_create(lua_State* L);
int l_model_create(lua_State* L);
int l_model_draw(lua_State* L);
int l_model_stats(lua_State* L);

#endif
