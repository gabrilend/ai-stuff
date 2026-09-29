/*
 * 2D Interface Drawing Implementation (Issue 518a)
 *
 * See ui2d.h.
 */

#include <string.h>
#include "ui2d.h"
#include "geometry.h"

static Texture2D g_images[UI_MAX_IMAGES];
static int g_image_count = 0;
static RenderTexture2D g_portrait;
static bool g_portrait_ready = false;

/* {{{ check_color
 * Colour from arguments first..first+3 (alpha optional, default 255) */
static Color check_color(lua_State* L, int first) {
    return (Color){ (unsigned char)luaL_checkinteger(L, first),
                    (unsigned char)luaL_checkinteger(L, first + 1),
                    (unsigned char)luaL_checkinteger(L, first + 2),
                    (unsigned char)luaL_optinteger(L, first + 3, 255) };
}

static float num(lua_State* L, int i) {
    return (float)luaL_checknumber(L, i);
}
/* }}} */

/* {{{ Shapes */
int l_ui_rect(lua_State* L) {
    DrawRectangleRec((Rectangle){ num(L, 1), num(L, 2), num(L, 3), num(L, 4) }, check_color(L, 5));
    return 0;
}

int l_ui_frame(lua_State* L) {
    DrawRectangleLinesEx((Rectangle){ num(L, 1), num(L, 2), num(L, 3), num(L, 4) }, num(L, 5),
                         check_color(L, 6));
    return 0;
}

int l_ui_line(lua_State* L) {
    DrawLineEx((Vector2){ num(L, 1), num(L, 2) }, (Vector2){ num(L, 3), num(L, 4) }, num(L, 5),
               check_color(L, 6));
    return 0;
}

int l_ui_tri(lua_State* L) {
    Vector2 a = { num(L, 1), num(L, 2) }, b = { num(L, 3), num(L, 4) }, c = { num(L, 5), num(L, 6) };
    /* raylib draws counter-clockwise triangles only; screen y points down */
    float cross = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
    if (cross > 0) { Vector2 t = b; b = c; c = t; }
    DrawTriangle(a, b, c, check_color(L, 7));
    return 0;
}

int l_ui_circle(lua_State* L) {
    DrawCircleV((Vector2){ num(L, 1), num(L, 2) }, num(L, 3), check_color(L, 4));
    return 0;
}
/* }}} */

/* {{{ Text */
int l_ui_text(lua_State* L) {
    DrawText(luaL_checkstring(L, 1), (int)num(L, 2), (int)num(L, 3), (int)num(L, 4), check_color(L, 5));
    return 0;
}

int l_ui_text_width(lua_State* L) {
    lua_pushinteger(L, MeasureText(luaL_checkstring(L, 1), (int)num(L, 2)));
    return 1;
}
/* }}} */

/* {{{ Images */
int l_ui_image_load(lua_State* L) {
    int w = (int)luaL_checkinteger(L, 1), h = (int)luaL_checkinteger(L, 2);
    size_t len;
    const char* rgba = luaL_checklstring(L, 3, &len);
    if (w <= 0 || h <= 0 || len < (size_t)w * h * 4) {
        return luaL_error(L, "ui_image_load: need %d bytes, got %d", w * h * 4, (int)len);
    }
    if (g_image_count >= UI_MAX_IMAGES) {
        lua_pushinteger(L, -1);
        return 1;
    }
    Image img = { .data = (void*)rgba, .width = w, .height = h, .mipmaps = 1,
                  .format = PIXELFORMAT_UNCOMPRESSED_R8G8B8A8 };
    g_images[g_image_count] = LoadTextureFromImage(img);
    lua_pushinteger(L, g_image_count++);
    return 1;
}

int l_ui_image(lua_State* L) {
    int id = (int)luaL_checkinteger(L, 1);
    if (id < 0 || id >= g_image_count) return 0;
    Texture2D t = g_images[id];
    DrawTexturePro(t, (Rectangle){ 0, 0, (float)t.width, (float)t.height },
                   (Rectangle){ num(L, 2), num(L, 3), num(L, 4), num(L, 5) }, (Vector2){ 0, 0 }, 0.0f,
                   (Color){ 255, 255, 255, (unsigned char)luaL_optinteger(L, 6, 255) });
    return 0;
}
/* }}} */

/* {{{ Portrait */
void ui2d_render_portrait(void) {
    if (!g_portrait_ready) {
        g_portrait = LoadRenderTexture(PORTRAIT_SIZE, PORTRAIT_SIZE);
        g_portrait_ready = true;
    }
    /* a figure about one render unit tall, seen from the front and a
     * little above */
    Camera3D cam = { .position = { 0.0f, 0.78f, 1.55f }, .target = { 0.0f, 0.48f, 0.0f },
                     .up = { 0.0f, 1.0f, 0.0f }, .fovy = 42.0f, .projection = CAMERA_PERSPECTIVE };
    BeginTextureMode(g_portrait);
        ClearBackground((Color){ 18, 22, 30, 255 });
        BeginMode3D(cam);
            geometry_draw_portrait();
        EndMode3D();
    EndTextureMode();
}

int l_ui_portrait(lua_State* L) {
    if (!g_portrait_ready) return 0;
    /* render textures are stored upside down */
    DrawTexturePro(g_portrait.texture, (Rectangle){ 0, 0, PORTRAIT_SIZE, -PORTRAIT_SIZE },
                   (Rectangle){ num(L, 1), num(L, 2), num(L, 3), num(L, 4) }, (Vector2){ 0, 0 }, 0.0f, WHITE);
    return 0;
}

void ui2d_free(void) {
    for (int i = 0; i < g_image_count; i++) UnloadTexture(g_images[i]);
    g_image_count = 0;
    if (g_portrait_ready) UnloadRenderTexture(g_portrait);
    g_portrait_ready = false;
}
/* }}} */

/* {{{ l_ui_screen */
int l_ui_screen(lua_State* L) {
    lua_pushinteger(L, GetScreenWidth());
    lua_pushinteger(L, GetScreenHeight());
    return 2;
}
/* }}} */
