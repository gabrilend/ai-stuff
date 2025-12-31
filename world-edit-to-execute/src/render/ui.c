/*
 * Minimal UI System Implementation (Issue 508g)
 *
 * Renders resource bar at top and selection panel at bottom.
 * All data comes from Lua via bridge functions.
 */

#include <stdio.h>
#include <string.h>
#include "ui.h"
#include "raylib.h"
#include <lauxlib.h>

/* {{{ Global UI State */
static UIState g_ui = {
    .gold = 500,
    .lumber = 150,
    .food_used = 0,
    .food_cap = 12,
    .game_time = 0.0f,
    .selected_name = "",
    .selected_count = 0,
    .selected_hp = 0,
    .selected_hp_max = 0,
    .show_resources = true,
    .show_selection = true,
    .show_debug = true
};

UIState* ui_get_state(void) {
    return &g_ui;
}
/* }}} */

/* {{{ ui_init */
void ui_init(void) {
    g_ui.gold = 500;
    g_ui.lumber = 150;
    g_ui.food_used = 0;
    g_ui.food_cap = 12;
    g_ui.game_time = 0.0f;
    g_ui.selected_name[0] = '\0';
    g_ui.selected_count = 0;
    g_ui.selected_hp = 0;
    g_ui.selected_hp_max = 0;
    g_ui.show_resources = true;
    g_ui.show_selection = true;
    g_ui.show_debug = true;
}
/* }}} */

/* {{{ format_time
 * Convert seconds to MM:SS format. */
static void format_time(float seconds, char* buf, int buf_size) {
    int total_seconds = (int)seconds;
    int minutes = total_seconds / 60;
    int secs = total_seconds % 60;
    snprintf(buf, buf_size, "%d:%02d", minutes, secs);
}
/* }}} */

/* {{{ draw_resource_bar
 * Renders the top resource bar. */
static void draw_resource_bar(void) {
    if (!g_ui.show_resources) return;

    int screen_w = GetScreenWidth();
    int bar_height = UI_RESOURCE_BAR_HEIGHT;

    /* Background with slight transparency */
    DrawRectangle(0, 0, screen_w, bar_height, (Color){20, 20, 35, 230});
    DrawLine(0, bar_height, screen_w, bar_height, (Color){60, 60, 80, 255});

    /* Gold (yellow/gold color) */
    char gold_buf[32];
    snprintf(gold_buf, sizeof(gold_buf), "Gold: %d", g_ui.gold);
    DrawText(gold_buf, 15, 7, UI_FONT_SIZE_NORMAL, (Color){255, 215, 0, 255});

    /* Lumber (brown/green color) */
    char lumber_buf[32];
    snprintf(lumber_buf, sizeof(lumber_buf), "Lumber: %d", g_ui.lumber);
    DrawText(lumber_buf, 130, 7, UI_FONT_SIZE_NORMAL, (Color){139, 90, 43, 255});

    /* Food (white, shows used/cap) */
    char food_buf[32];
    snprintf(food_buf, sizeof(food_buf), "Food: %d/%d", g_ui.food_used, g_ui.food_cap);
    /* Color based on food status */
    Color food_color = WHITE;
    if (g_ui.food_used >= g_ui.food_cap) {
        food_color = RED;  /* At cap - can't build more */
    } else if (g_ui.food_used >= g_ui.food_cap - 2) {
        food_color = YELLOW;  /* Almost at cap */
    }
    DrawText(food_buf, 270, 7, UI_FONT_SIZE_NORMAL, food_color);

    /* Game time (right side) */
    char time_buf[16];
    format_time(g_ui.game_time, time_buf, sizeof(time_buf));
    int time_width = MeasureText(time_buf, UI_FONT_SIZE_NORMAL);
    DrawText(time_buf, screen_w - time_width - 15, 7, UI_FONT_SIZE_NORMAL, LIGHTGRAY);
}
/* }}} */

/* {{{ draw_selection_panel
 * Renders the bottom selection panel. */
static void draw_selection_panel(void) {
    if (!g_ui.show_selection) return;
    if (g_ui.selected_count == 0) return;

    int screen_w = GetScreenWidth();
    int screen_h = GetScreenHeight();
    int panel_height = UI_SELECTION_PANEL_HEIGHT;
    int panel_y = screen_h - panel_height;

    /* Background with slight transparency */
    DrawRectangle(0, panel_y, screen_w, panel_height, (Color){20, 20, 35, 230});
    DrawLine(0, panel_y, screen_w, panel_y, (Color){60, 60, 80, 255});

    /* Selection info */
    char sel_buf[128];
    if (g_ui.selected_count == 1) {
        snprintf(sel_buf, sizeof(sel_buf), "Selected: %s",
                 g_ui.selected_name[0] ? g_ui.selected_name : "Unit");
    } else {
        snprintf(sel_buf, sizeof(sel_buf), "Selected: %s (%d)",
                 g_ui.selected_name[0] ? g_ui.selected_name : "Units",
                 g_ui.selected_count);
    }
    DrawText(sel_buf, 15, panel_y + 8, UI_FONT_SIZE_LARGE, WHITE);

    /* HP bar (if we have HP data) */
    if (g_ui.selected_hp_max > 0) {
        char hp_buf[48];
        snprintf(hp_buf, sizeof(hp_buf), "HP: %d/%d", g_ui.selected_hp, g_ui.selected_hp_max);
        DrawText(hp_buf, 15, panel_y + 30, UI_FONT_SIZE_SMALL, LIGHTGRAY);

        /* Visual HP bar */
        int bar_x = 120;
        int bar_y = panel_y + 30;
        int bar_w = 150;
        int bar_h = 14;

        /* Background */
        DrawRectangle(bar_x, bar_y, bar_w, bar_h, DARKGRAY);

        /* Fill based on HP percentage */
        float hp_pct = (float)g_ui.selected_hp / (float)g_ui.selected_hp_max;
        if (hp_pct > 1.0f) hp_pct = 1.0f;
        if (hp_pct < 0.0f) hp_pct = 0.0f;

        /* Color based on HP level */
        Color hp_color = GREEN;
        if (hp_pct < 0.3f) {
            hp_color = RED;
        } else if (hp_pct < 0.6f) {
            hp_color = YELLOW;
        }

        int fill_w = (int)(bar_w * hp_pct);
        DrawRectangle(bar_x, bar_y, fill_w, bar_h, hp_color);

        /* Border */
        DrawRectangleLines(bar_x, bar_y, bar_w, bar_h, GRAY);
    }
}
/* }}} */

/* {{{ ui_draw */
void ui_draw(void) {
    draw_resource_bar();
    draw_selection_panel();
}
/* }}} */

/* {{{ ui_set_resources */
void ui_set_resources(int gold, int lumber, int food_used, int food_cap) {
    g_ui.gold = gold;
    g_ui.lumber = lumber;
    g_ui.food_used = food_used;
    g_ui.food_cap = food_cap;
}
/* }}} */

/* {{{ ui_set_game_time */
void ui_set_game_time(float seconds) {
    g_ui.game_time = seconds;
}
/* }}} */

/* {{{ ui_set_selection */
void ui_set_selection(const char* name, int count, int hp, int hp_max) {
    if (name) {
        strncpy(g_ui.selected_name, name, sizeof(g_ui.selected_name) - 1);
        g_ui.selected_name[sizeof(g_ui.selected_name) - 1] = '\0';
    } else {
        g_ui.selected_name[0] = '\0';
    }
    g_ui.selected_count = count;
    g_ui.selected_hp = hp;
    g_ui.selected_hp_max = hp_max;
}
/* }}} */

/* {{{ ui_clear_selection */
void ui_clear_selection(void) {
    g_ui.selected_name[0] = '\0';
    g_ui.selected_count = 0;
    g_ui.selected_hp = 0;
    g_ui.selected_hp_max = 0;
}
/* }}} */

/* {{{ Lua Bridge Functions */

/* {{{ l_ui_set_resources */
int l_ui_set_resources(lua_State* L) {
    int gold = luaL_checkinteger(L, 1);
    int lumber = luaL_checkinteger(L, 2);
    int food_used = luaL_checkinteger(L, 3);
    int food_cap = luaL_checkinteger(L, 4);
    ui_set_resources(gold, lumber, food_used, food_cap);
    return 0;
}
/* }}} */

/* {{{ l_ui_set_selection */
int l_ui_set_selection(lua_State* L) {
    const char* name = luaL_checkstring(L, 1);
    int count = luaL_checkinteger(L, 2);
    int hp = luaL_checkinteger(L, 3);
    int hp_max = luaL_checkinteger(L, 4);
    ui_set_selection(name, count, hp, hp_max);
    return 0;
}
/* }}} */

/* {{{ l_ui_set_game_time */
int l_ui_set_game_time(lua_State* L) {
    float seconds = (float)luaL_checknumber(L, 1);
    ui_set_game_time(seconds);
    return 0;
}
/* }}} */

/* {{{ l_ui_clear_selection */
int l_ui_clear_selection(lua_State* L) {
    (void)L;  /* unused */
    ui_clear_selection();
    return 0;
}
/* }}} */

/* {{{ l_ui_show */
int l_ui_show(lua_State* L) {
    const char* element = luaL_checkstring(L, 1);
    int visible = lua_toboolean(L, 2);

    if (strcmp(element, "resources") == 0) {
        g_ui.show_resources = visible ? true : false;
    } else if (strcmp(element, "selection") == 0) {
        g_ui.show_selection = visible ? true : false;
    } else if (strcmp(element, "debug") == 0) {
        g_ui.show_debug = visible ? true : false;
    }

    return 0;
}
/* }}} */

/* }}} */
