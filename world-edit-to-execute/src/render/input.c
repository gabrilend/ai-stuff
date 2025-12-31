/*
 * Input and Selection Implementation (Issue 508e)
 *
 * Handles mouse tracking, entity picking via ray casting, and selection
 * management. Selection state is synchronized with RenderSlot.selected flags.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <lua.h>
#include <lauxlib.h>
#include "input.h"
#include "raylib.h"
#include "raymath.h"

/* {{{ Global State */
static InputState g_input = {0};
static SelectionState g_selection = {0};
static SlotArray* g_input_slots = NULL;  /* Reference for Lua bridge */
/* }}} */

/* {{{ Global State Access */
InputState* input_get_state(void) {
    return &g_input;
}

SelectionState* selection_get_state(void) {
    return &g_selection;
}
/* }}} */

/* {{{ input_init */
void input_init(Camera3D* camera) {
    memset(&g_input, 0, sizeof(InputState));
    g_input.camera = camera;
    selection_init();
    printf("[input] Initialized with camera reference\n");
}
/* }}} */

/* {{{ input_set_camera */
void input_set_camera(Camera3D* camera) {
    g_input.camera = camera;
}
/* }}} */

/* {{{ input_screen_to_world */
bool input_screen_to_world(int screen_x, int screen_y,
                           float* world_x, float* world_z) {
    if (!g_input.camera) return false;

    /* Get ray from camera through screen point */
    Ray ray = GetMouseRay((Vector2){(float)screen_x, (float)screen_y}, *g_input.camera);

    /* Intersect with ground plane (Y = 0) */
    /* Ray: P = origin + t * direction */
    /* Plane: Y = 0, so origin.y + t * direction.y = 0 */
    /* t = -origin.y / direction.y */

    if (fabsf(ray.direction.y) < 0.0001f) {
        /* Ray is parallel to ground plane */
        return false;
    }

    float t = -ray.position.y / ray.direction.y;
    if (t < 0) {
        /* Intersection is behind camera */
        return false;
    }

    *world_x = ray.position.x + t * ray.direction.x;
    *world_z = ray.position.z + t * ray.direction.z;

    return true;
}
/* }}} */

/* {{{ input_world_to_screen */
bool input_world_to_screen(float world_x, float world_y, float world_z,
                           int* screen_x, int* screen_y) {
    if (!g_input.camera) return false;

    Vector2 screen = GetWorldToScreen((Vector3){world_x, world_y, world_z}, *g_input.camera);

    *screen_x = (int)screen.x;
    *screen_y = (int)screen.y;

    /* Check if position is in front of camera (simplified) */
    return screen.x >= 0 && screen.y >= 0;
}
/* }}} */

/* {{{ input_update */
void input_update(void) {
    /* Store previous frame button states for edge detection */
    bool prev_left = g_input.left_down;
    bool prev_right = g_input.right_down;

    /* Update mouse position */
    g_input.mouse_x = GetMouseX();
    g_input.mouse_y = GetMouseY();

    /* Update mouse ray */
    if (g_input.camera) {
        g_input.mouse_ray = GetMouseRay(
            (Vector2){(float)g_input.mouse_x, (float)g_input.mouse_y},
            *g_input.camera
        );
    }

    /* Convert to world coordinates */
    if (!input_screen_to_world(g_input.mouse_x, g_input.mouse_y,
                               &g_input.world_x, &g_input.world_z)) {
        g_input.world_x = 0;
        g_input.world_z = 0;
    }
    g_input.world_y = 0;  /* Ground plane */

    /* Button states */
    g_input.left_down = IsMouseButtonDown(MOUSE_LEFT_BUTTON);
    g_input.right_down = IsMouseButtonDown(MOUSE_RIGHT_BUTTON);
    g_input.middle_down = IsMouseButtonDown(MOUSE_MIDDLE_BUTTON);

    /* Edge detection */
    g_input.left_pressed = g_input.left_down && !prev_left;
    g_input.right_pressed = g_input.right_down && !prev_right;
    g_input.left_released = !g_input.left_down && prev_left;
    g_input.right_released = !g_input.right_down && prev_right;

    /* Drag state management */
    if (g_input.left_pressed) {
        g_input.drag_start_x = g_input.mouse_x;
        g_input.drag_start_y = g_input.mouse_y;
        g_input.dragging = false;
    }

    if (g_input.left_down && !g_input.dragging) {
        int dx = g_input.mouse_x - g_input.drag_start_x;
        int dy = g_input.mouse_y - g_input.drag_start_y;
        if (dx*dx + dy*dy > DRAG_THRESHOLD * DRAG_THRESHOLD) {
            g_input.dragging = true;
        }
    }

    if (g_input.left_released) {
        g_input.drag_end_x = g_input.mouse_x;
        g_input.drag_end_y = g_input.mouse_y;
    }

    /* Keyboard modifiers */
    g_input.shift_held = IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT);
    g_input.ctrl_held = IsKeyDown(KEY_LEFT_CONTROL) || IsKeyDown(KEY_RIGHT_CONTROL);
    g_input.alt_held = IsKeyDown(KEY_LEFT_ALT) || IsKeyDown(KEY_RIGHT_ALT);
}
/* }}} */

/* {{{ pick_entity_at_world */
int pick_entity_at_world(SlotArray* slots, float wx, float wz, float radius) {
    if (!slots) return -1;

    int best = -1;
    float best_dist_sq = radius * radius;

    for (int i = 0; i < MAX_SLOTS; i++) {
        ComponentSlot* slot = slot_get(slots, i);
        if (!slot || !slot->in_use || !slot->data || !slot->data->visible) continue;

        RenderSlot* r = slot->data;
        float dx = r->x - wx;
        float dz = r->z - wz;
        float dist_sq = dx*dx + dz*dz;

        if (dist_sq < best_dist_sq) {
            best_dist_sq = dist_sq;
            best = i;
        }
    }

    return best;
}
/* }}} */

/* {{{ pick_entity_at_screen */
int pick_entity_at_screen(SlotArray* slots, int screen_x, int screen_y) {
    if (!slots || !g_input.camera) return -1;

    Ray ray = GetMouseRay((Vector2){(float)screen_x, (float)screen_y}, *g_input.camera);

    int best = -1;
    float best_dist = 1000000.0f;

    for (int i = 0; i < MAX_SLOTS; i++) {
        ComponentSlot* slot = slot_get(slots, i);
        if (!slot || !slot->in_use || !slot->data || !slot->data->visible) continue;

        RenderSlot* r = slot->data;

        /* Use sphere collision for picking */
        float pick_radius = r->scale * 0.5f;
        if (pick_radius < 0.3f) pick_radius = 0.3f;

        Vector3 center = { r->x, r->y, r->z };
        RayCollision col = GetRayCollisionSphere(ray, center, pick_radius);

        if (col.hit && col.distance < best_dist) {
            best_dist = col.distance;
            best = i;
        }
    }

    return best;
}
/* }}} */

/* {{{ pick_entities_in_rect */
int pick_entities_in_rect(SlotArray* slots,
                          int x1, int y1, int x2, int y2,
                          int* out, int max) {
    if (!slots || !g_input.camera || !out) return 0;

    /* Normalize rectangle */
    if (x1 > x2) { int t = x1; x1 = x2; x2 = t; }
    if (y1 > y2) { int t = y1; y1 = y2; y2 = t; }

    int count = 0;

    for (int i = 0; i < MAX_SLOTS && count < max; i++) {
        ComponentSlot* slot = slot_get(slots, i);
        if (!slot || !slot->in_use || !slot->data || !slot->data->visible) continue;

        RenderSlot* r = slot->data;

        /* Convert to screen coords */
        int sx, sy;
        if (!input_world_to_screen(r->x, r->y, r->z, &sx, &sy)) continue;

        if (sx >= x1 && sx <= x2 && sy >= y1 && sy <= y2) {
            out[count++] = i;
        }
    }

    return count;
}
/* }}} */

/* {{{ selection_init */
void selection_init(void) {
    memset(&g_selection, 0, sizeof(SelectionState));
    g_selection.count = 0;
}
/* }}} */

/* {{{ selection_clear */
void selection_clear(SlotArray* slots) {
    for (int i = 0; i < g_selection.count; i++) {
        if (slots) {
            ComponentSlot* cs = slot_get(slots, g_selection.slots[i]);
            if (cs && cs->data) {
                cs->data->selected = false;
            }
        }
    }
    g_selection.count = 0;
}
/* }}} */

/* {{{ selection_contains */
bool selection_contains(int slot_index) {
    for (int i = 0; i < g_selection.count; i++) {
        if (g_selection.slots[i] == slot_index) {
            return true;
        }
    }
    return false;
}
/* }}} */

/* {{{ selection_add */
void selection_add(SlotArray* slots, int slot_index) {
    if (g_selection.count >= MAX_SELECTION) return;
    if (selection_contains(slot_index)) return;
    if (slot_index < 0) return;

    /* Update render slot */
    if (slots) {
        ComponentSlot* cs = slot_get(slots, slot_index);
        if (cs && cs->data) {
            cs->data->selected = true;
        }
    }

    g_selection.slots[g_selection.count++] = slot_index;
}
/* }}} */

/* {{{ selection_remove */
void selection_remove(SlotArray* slots, int slot_index) {
    int found = -1;
    for (int i = 0; i < g_selection.count; i++) {
        if (g_selection.slots[i] == slot_index) {
            found = i;
            break;
        }
    }

    if (found < 0) return;

    /* Update render slot */
    if (slots) {
        ComponentSlot* cs = slot_get(slots, slot_index);
        if (cs && cs->data) {
            cs->data->selected = false;
        }
    }

    /* Remove by shifting */
    for (int i = found; i < g_selection.count - 1; i++) {
        g_selection.slots[i] = g_selection.slots[i + 1];
    }
    g_selection.count--;
}
/* }}} */

/* {{{ selection_toggle */
void selection_toggle(SlotArray* slots, int slot_index) {
    if (selection_contains(slot_index)) {
        selection_remove(slots, slot_index);
    } else {
        selection_add(slots, slot_index);
    }
}
/* }}} */

/* {{{ selection_get_count */
int selection_get_count(void) {
    return g_selection.count;
}
/* }}} */

/* {{{ selection_get_slot */
int selection_get_slot(int index) {
    if (index < 0 || index >= g_selection.count) return -1;
    return g_selection.slots[index];
}
/* }}} */

/* {{{ process_selection_input */
void process_selection_input(SlotArray* slots) {
    if (!slots) return;

    /* Store reference for Lua bridge */
    g_input_slots = slots;

    /* Left click - single select */
    if (g_input.left_released && !g_input.dragging) {
        int slot = pick_entity_at_screen(slots, g_input.mouse_x, g_input.mouse_y);

        if (!g_input.shift_held) {
            selection_clear(slots);
        }

        if (slot >= 0) {
            if (g_input.shift_held && selection_contains(slot)) {
                selection_remove(slots, slot);
            } else {
                selection_add(slots, slot);
            }
        }
    }

    /* Box select on drag release */
    if (g_input.left_released && g_input.dragging) {
        int picked[MAX_SELECTION];
        int count = pick_entities_in_rect(
            slots,
            g_input.drag_start_x, g_input.drag_start_y,
            g_input.drag_end_x, g_input.drag_end_y,
            picked, MAX_SELECTION
        );

        if (!g_input.shift_held) {
            selection_clear(slots);
        }

        for (int i = 0; i < count; i++) {
            selection_add(slots, picked[i]);
        }

        g_input.dragging = false;
    }

    /* Reset drag state on release */
    if (g_input.left_released) {
        g_input.dragging = false;
    }
}
/* }}} */

/* {{{ draw_selection_box */
void draw_selection_box(void) {
    if (!g_input.dragging || !g_input.left_down) return;

    int x1 = g_input.drag_start_x;
    int y1 = g_input.drag_start_y;
    int x2 = g_input.mouse_x;
    int y2 = g_input.mouse_y;

    /* Normalize */
    int left = x1 < x2 ? x1 : x2;
    int top = y1 < y2 ? y1 : y2;
    int width = abs(x2 - x1);
    int height = abs(y2 - y1);

    /* Draw filled rectangle with transparency */
    DrawRectangle(left, top, width, height, (Color){0, 255, 0, 40});

    /* Draw border */
    DrawRectangleLines(left, top, width, height, GREEN);
}
/* }}} */

/* {{{ draw_selection_circles */
void draw_selection_circles(SlotArray* slots) {
    if (!slots) return;

    for (int i = 0; i < g_selection.count; i++) {
        ComponentSlot* cs = slot_get(slots, g_selection.slots[i]);
        if (!cs || !cs->data || !cs->data->visible) continue;

        RenderSlot* r = cs->data;

        /* Draw circle under entity */
        float radius = r->scale * 0.6f;
        if (radius < 0.4f) radius = 0.4f;

        DrawCircle3D(
            (Vector3){r->x, 0.05f, r->z},
            radius,
            (Vector3){1.0f, 0.0f, 0.0f},
            90.0f,
            GREEN
        );
    }
}
/* }}} */

/* {{{ Lua Bridge Implementation */

/* {{{ l_get_selection */
int l_get_selection(lua_State* L) {
    lua_newtable(L);

    for (int i = 0; i < g_selection.count; i++) {
        int slot_index = g_selection.slots[i];
        if (g_input_slots) {
            ComponentSlot* cs = slot_get(g_input_slots, slot_index);
            if (cs) {
                lua_pushinteger(L, cs->entity_id);
                lua_rawseti(L, -2, i + 1);
            }
        }
    }

    return 1;
}
/* }}} */

/* {{{ l_set_selection */
int l_set_selection(lua_State* L) {
    if (!g_input_slots) return 0;

    luaL_checktype(L, 1, LUA_TTABLE);

    selection_clear(g_input_slots);

    int len = (int)lua_objlen(L, 1);
    for (int i = 1; i <= len && g_selection.count < MAX_SELECTION; i++) {
        lua_rawgeti(L, 1, i);
        if (lua_isnumber(L, -1)) {
            int entity_id = (int)lua_tointeger(L, -1);
            int slot = slot_find_by_entity(g_input_slots, entity_id);
            if (slot >= 0) {
                selection_add(g_input_slots, slot);
            }
        }
        lua_pop(L, 1);
    }

    return 0;
}
/* }}} */

/* {{{ l_clear_selection */
int l_clear_selection(lua_State* L) {
    (void)L;
    if (g_input_slots) {
        selection_clear(g_input_slots);
    }
    return 0;
}
/* }}} */

/* {{{ l_get_entity_at */
int l_get_entity_at(lua_State* L) {
    if (!g_input_slots) {
        lua_pushnil(L);
        return 1;
    }

    int screen_x = luaL_checkinteger(L, 1);
    int screen_y = luaL_checkinteger(L, 2);

    int slot = pick_entity_at_screen(g_input_slots, screen_x, screen_y);
    if (slot >= 0) {
        ComponentSlot* cs = slot_get(g_input_slots, slot);
        if (cs) {
            lua_pushinteger(L, cs->entity_id);
            return 1;
        }
    }

    lua_pushnil(L);
    return 1;
}
/* }}} */

/* {{{ l_get_mouse_world */
int l_get_mouse_world(lua_State* L) {
    lua_pushnumber(L, g_input.world_x);
    lua_pushnumber(L, g_input.world_y);
    lua_pushnumber(L, g_input.world_z);
    return 3;
}
/* }}} */

/* {{{ l_is_selected */
int l_is_selected(lua_State* L) {
    if (!g_input_slots) {
        lua_pushboolean(L, 0);
        return 1;
    }

    int entity_id = luaL_checkinteger(L, 1);
    int slot = slot_find_by_entity(g_input_slots, entity_id);

    lua_pushboolean(L, selection_contains(slot) ? 1 : 0);
    return 1;
}
/* }}} */

/* }}} */
