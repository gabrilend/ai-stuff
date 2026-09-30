/*
 * fog.c - fog of war, drawn over the world (Issue 524); see fog.h
 *
 * The world is drawn into g_target (a colour texture and a depth
 * texture). The pass back to the screen runs a shader that turns each
 * pixel's depth into a point in render space (inverse view-projection),
 * that into WC3 x and y (x = rx * 128, y = -rz * 128), and reads the fog
 * texture there (filtered, so the edges are soft).
 */
#include "fog.h"
#include "raymath.h"
#include "rlgl.h"
#include "lauxlib.h"
#include <stddef.h>

static int g_on = 0;
static Texture2D g_fog = { 0 };
static float g_area[4];                 /* WC3: x, y of the grid's corner, width, height */
static RenderTexture2D g_target = { 0 };
static int g_tw = 0, g_th = 0;
static Shader g_shader;
static int g_loc_depth = -1, g_loc_fog = -1, g_loc_inv = -1, g_loc_area = -1;
static int g_ready = 0;
static Matrix g_inv;
static Texture2D g_depth = { 0 };

static const char* FS =
    "#version 330\n"
    "in vec2 fragTexCoord; in vec4 fragColor;\n"
    "uniform sampler2D texture0; uniform sampler2D depthTex; uniform sampler2D fogTex;\n"
    "uniform mat4 invViewProj; uniform vec4 fogArea;\n"
    "out vec4 finalColor;\n"
    "void main() {\n"
    "  vec4 c = texture(texture0, fragTexCoord);\n"
    "  float d = texture(depthTex, fragTexCoord).r;\n"
    "  if (d >= 0.999999) { finalColor = c; return; }\n"
    "  vec4 p = invViewProj * vec4(fragTexCoord * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);\n"
    "  p /= p.w;\n"
    "  vec2 f = (vec2(p.x * 128.0, -p.z * 128.0) - fogArea.xy) / fogArea.zw;\n"
    "  float v = 0.0;\n"
    "  if (f.x >= 0.0 && f.y >= 0.0 && f.x <= 1.0 && f.y <= 1.0) v = texture(fogTex, f).r;\n"
    "  finalColor = vec4(c.rgb * v, c.a);\n"
    "}\n";

/* {{{ setup */
static void init(void) {
    if (g_ready) return;
    g_shader = LoadShaderFromMemory(NULL, FS);
    g_loc_depth = GetShaderLocation(g_shader, "depthTex");
    g_loc_fog = GetShaderLocation(g_shader, "fogTex");
    g_loc_inv = GetShaderLocation(g_shader, "invViewProj");
    g_loc_area = GetShaderLocation(g_shader, "fogArea");
    g_ready = 1;
}

static void make_target(int w, int h) {
    if (g_target.id != 0 && g_tw == w && g_th == h) return;
    if (g_target.id != 0) {
        rlUnloadFramebuffer(g_target.id);
        rlUnloadTexture(g_target.texture.id);
        rlUnloadTexture(g_depth.id);
    }
    RenderTexture2D t = { 0 };
#if RAYLIB_VERSION_MAJOR > 5 || (RAYLIB_VERSION_MAJOR == 5 && RAYLIB_VERSION_MINOR >= 5)
    t.id = rlLoadFramebuffer();
#else
    t.id = rlLoadFramebuffer(w, h);
#endif
    rlEnableFramebuffer(t.id);
    t.texture.id = rlLoadTexture(NULL, w, h, PIXELFORMAT_UNCOMPRESSED_R8G8B8A8, 1);
    t.texture.width = w; t.texture.height = h; t.texture.mipmaps = 1;
    t.texture.format = PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
    g_depth.id = rlLoadTextureDepth(w, h, false);
    g_depth.width = w; g_depth.height = h; g_depth.mipmaps = 1;
    g_depth.format = 19;   /* depth (raylib's PIXELFORMAT_... has none: only used to sample) */
    t.depth = g_depth;
    rlFramebufferAttach(t.id, t.texture.id, RL_ATTACHMENT_COLOR_CHANNEL0, RL_ATTACHMENT_TEXTURE2D, 0);
    rlFramebufferAttach(t.id, g_depth.id, RL_ATTACHMENT_DEPTH, RL_ATTACHMENT_TEXTURE2D, 0);
    if (!rlFramebufferComplete(t.id)) TraceLog(LOG_WARNING, "FOG: framebuffer incomplete");
    rlDisableFramebuffer();
    g_target = t;
    g_tw = w; g_th = h;
}
/* }}} */

/* {{{ the pass */
int fog_active(void) { return g_on; }

void fog_begin(void) {
    init();
    make_target(GetScreenWidth(), GetScreenHeight());
    BeginTextureMode(g_target);
    ClearBackground((Color){ 24, 28, 40, 255 });
}

void fog_capture(void) {
    Matrix view = rlGetMatrixModelview();
    Matrix proj = rlGetMatrixProjection();
    g_inv = MatrixInvert(MatrixMultiply(view, proj));
}

void fog_end(void) {
    EndTextureMode();
    BeginShaderMode(g_shader);
        SetShaderValueMatrix(g_shader, g_loc_inv, g_inv);
        SetShaderValue(g_shader, g_loc_area, g_area, SHADER_UNIFORM_VEC4);
        SetShaderValueTexture(g_shader, g_loc_depth, g_depth);
        SetShaderValueTexture(g_shader, g_loc_fog, g_fog);
        /* render textures are stored upside down */
        DrawTextureRec(g_target.texture, (Rectangle){ 0, 0, (float)g_tw, (float)-g_th }, (Vector2){ 0, 0 }, WHITE);
    EndShaderMode();
}
/* }}} */

/* {{{ Lua */
int l_fog_set(lua_State* L) {
    int w = (int)luaL_checkinteger(L, 1), h = (int)luaL_checkinteger(L, 2);
    float x0 = (float)luaL_checknumber(L, 3), y0 = (float)luaL_checknumber(L, 4);
    float cell = (float)luaL_checknumber(L, 5);
    size_t len;
    const char* shades = luaL_checklstring(L, 6, &len);
    if (w <= 0 || h <= 0 || len < (size_t)w * h) return luaL_error(L, "fog_set: need %d bytes, got %d", w * h, (int)len);
    if (g_fog.id == 0 || g_fog.width != w || g_fog.height != h) {
        if (g_fog.id != 0) UnloadTexture(g_fog);
        Image img = { .data = (void*)shades, .width = w, .height = h, .mipmaps = 1,
                      .format = PIXELFORMAT_UNCOMPRESSED_GRAYSCALE };
        g_fog = LoadTextureFromImage(img);
        SetTextureFilter(g_fog, TEXTURE_FILTER_BILINEAR);
        SetTextureWrap(g_fog, TEXTURE_WRAP_CLAMP);
    } else {
        UpdateTexture(g_fog, shades);
    }
    /* texel i covers x0 + (i - 0.5) cell .. x0 + (i + 0.5) cell */
    g_area[0] = x0 - cell / 2; g_area[1] = y0 - cell / 2;
    g_area[2] = w * cell; g_area[3] = h * cell;
    g_on = 1;
    return 0;
}

int l_fog_off(lua_State* L) {
    (void)L;
    g_on = 0;
    return 0;
}
/* }}} */
