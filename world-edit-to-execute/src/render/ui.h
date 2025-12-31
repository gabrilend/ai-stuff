/*
 * Minimal UI System (Issue 508g)
 *
 * Provides basic HUD elements for game state visibility:
 * - Resource bar at top: Gold, Lumber, Food, Game Time
 * - Selection panel at bottom: Unit name, count, HP
 *
 * Data flows from Lua via bridge functions to UIState struct.
 */

#ifndef UI_H
#define UI_H

#include <stdbool.h>
#include <lua.h>

/* {{{ Configuration */
#define UI_RESOURCE_BAR_HEIGHT 30
#define UI_SELECTION_PANEL_HEIGHT 50
#define UI_FONT_SIZE_NORMAL 16
#define UI_FONT_SIZE_SMALL 14
#define UI_FONT_SIZE_LARGE 18
/* }}} */

/* {{{ UIState - all UI data in one place
 * Updated by Lua via bridge functions. */
typedef struct ui_state {
    /* Resources (top bar) */
    int gold;
    int lumber;
    int food_used;
    int food_cap;

    /* Game time */
    float game_time;

    /* Selection info (bottom panel) */
    char selected_name[64];
    int selected_count;
    int selected_hp;
    int selected_hp_max;

    /* UI visibility flags */
    bool show_resources;
    bool show_selection;
    bool show_debug;
} UIState;
/* }}} */

/* {{{ Global UI State */
UIState* ui_get_state(void);
/* }}} */

/* {{{ UI Functions */

/* ui_init
 * Initialize UI state with default values. */
void ui_init(void);

/* ui_draw
 * Render all UI elements. Call during 2D drawing phase. */
void ui_draw(void);

/* ui_set_resources
 * Update resource display values. */
void ui_set_resources(int gold, int lumber, int food_used, int food_cap);

/* ui_set_game_time
 * Update game time display. */
void ui_set_game_time(float seconds);

/* ui_set_selection
 * Update selection panel display. */
void ui_set_selection(const char* name, int count, int hp, int hp_max);

/* ui_clear_selection
 * Clear selection panel. */
void ui_clear_selection(void);

/* }}} */

/* {{{ Lua Bridge Functions */

/* render.ui_set_resources(gold, lumber, food_used, food_cap) */
int l_ui_set_resources(lua_State* L);

/* render.ui_set_selection(name, count, hp, hp_max) */
int l_ui_set_selection(lua_State* L);

/* render.ui_set_game_time(seconds) */
int l_ui_set_game_time(lua_State* L);

/* render.ui_clear_selection() */
int l_ui_clear_selection(lua_State* L);

/* render.ui_show(element, visible)
 * element: "resources", "selection", "debug" */
int l_ui_show(lua_State* L);

/* }}} */

#endif /* UI_H */
