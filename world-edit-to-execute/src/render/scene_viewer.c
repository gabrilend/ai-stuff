/*
 * Scene Viewer (Issues 516e, 517e)
 *
 * A window, a WC3-style camera and a fixed 50 Hz tick; everything else is a
 * Lua scene script: the fort (src/demo/fort/main.lua, 516) or a WC3 map
 * (src/demo/wc3map/main.lua, 517). Started as the fort demo.
 *
 * Usage: scene_viewer [PROJECT_ROOT [SCENE_SCRIPT [SCENE_ARG]]]
 *   PROJECT_ROOT  default: the current directory
 *   SCENE_SCRIPT  default: src/demo/fort/main.lua (relative to the root)
 *   SCENE_ARG     handed to the script as the global SCENE_ARG (a map path)
 *
 * A scene script defines scene_tick(dt), scene_paint(), scene_status() and
 * scene_key(name), and may define scene_ground(x, y) (WC3 ground height,
 * for the camera) and the global CAMERA_START = { x, y, distance }.
 *
 * A scene with an interface also defines scene_ui(), drawn over the view
 * with render.ui_*; it reads input through the global table `viewer` (see
 * register_viewer below). Such a scene owns the keyboard (letters are its
 * hotkeys, Esc its cancel) and quits through viewer.quit().
 *
 * Keys without an interface: arrows/WASD pan, mouse wheel zoom, 1 WC3
 *       default camera distance, R "rings" (the fort's range rings), Esc
 *       quit. With one: arrows and the screen edges pan, wheel zooms.
 *
 * For unattended runs:
 *   SCENE_SHOTS="4,12,24"  save the screen at these simulated seconds
 *   SCENE_SHOT_DIR=path    where to save them (default: current directory)
 *   SCENE_QUIT_AT=26       quit at this simulated second
 *   SCENE_CAMERA="x,y,d"   start the camera looking at WC3 point (x, y)
 *                          from d units away
 */

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "raylib.h"
#include "rlgl.h"
#include "bridge.h"
#include "slots.h"
#include "terrain.h"
#include "geometry.h"
#include "landscape.h"
#include "ui2d.h"
#include "models.h"
#include "fog.h"

/* {{{ Camera
 * WC3's default game camera (Blizzard.j's bj_CAMERA_DEFAULT_* constants)
 * looks down at an angle of attack of 304 degrees (56 below level) from
 * 1650 units away with a field of view of 70. raylib's fovy is vertical;
 * which way WC3 measures its 70 is unconfirmed. Pan speed and zoom limits
 * are STAND-INS (unmeasured). */
#define WC3_UNITS_PER_TILE   128.0f
#define CAM_PITCH_DEG        56.0f
#define CAM_FOV_DEG          70.0f
#define CAM_DEFAULT_DISTANCE 1650.0f
#define CAM_MIN_DISTANCE     250.0f    /* map cameras come close (DAoW's: 400) */
#define CAM_MAX_DISTANCE     9000.0f
#define CAM_PAN_SPEED        1400.0f   /* WC3 units per second */

typedef struct {
    float x, z;          /* target, render units */
    float y;             /* ground height under the target, render units */
    float distance;      /* WC3 units */
    float rotation;      /* degrees, WC3's: 90 looks north */
    float pitch;         /* degrees down from level (WC3's angle of attack 304 = 56 down) */
    float fov;           /* degrees */
} ViewCamera;

/* Place a raylib camera at the target, looking the camera's way (WC3's
 * default: north, 56 degrees down) */
static void apply_camera(const ViewCamera* fc, Camera3D* cam) {
    float d = fc->distance / WC3_UNITS_PER_TILE;
    float pitch = fc->pitch * DEG2RAD;
    float rot = fc->rotation * DEG2RAD;
    /* the way it looks, on the ground: WC3 (cos, sin) is render (cos, -sin) */
    float fx = cosf(rot), fz = -sinf(rot);
    cam->target = (Vector3){ fc->x, fc->y, fc->z };
    cam->position = (Vector3){ fc->x - fx * d * cosf(pitch), fc->y + d * sinf(pitch), fc->z - fz * d * cosf(pitch) };
    cam->up = (Vector3){ 0.0f, 1.0f, 0.0f };
    cam->fovy = fc->fov;
    cam->projection = CAMERA_PERSPECTIVE;
}
/* }}} */

/* {{{ Lua helpers */
static bool call_lua(lua_State* L, const char* fn, const char* arg_string,
                     double arg_number, bool has_number) {
    lua_getglobal(L, fn);
    if (!lua_isfunction(L, -1)) {
        lua_pop(L, 1);
        return false;
    }
    int nargs = 0;
    if (arg_string) { lua_pushstring(L, arg_string); nargs++; }
    if (has_number) { lua_pushnumber(L, arg_number); nargs++; }
    if (lua_pcall(L, nargs, 0, 0) != 0) {
        fprintf(stderr, "[scene] %s: %s\n", fn, lua_tostring(L, -1));
        lua_pop(L, 1);
        return false;
    }
    return true;
}

static void read_status(lua_State* L, char* out, size_t size) {
    out[0] = '\0';
    lua_getglobal(L, "scene_status");
    if (lua_isfunction(L, -1) && lua_pcall(L, 0, 1, 0) == 0) {
        const char* s = lua_tostring(L, -1);
        if (s) snprintf(out, size, "%s", s);
    }
    lua_pop(L, 1);
}
/* }}} */

/* {{{ Screenshot schedule */
#define MAX_SHOTS 16
static float g_shots[MAX_SHOTS];
static int g_shot_count = 0;
static int g_next_shot = 0;

static void parse_shots(const char* spec) {
    while (spec && *spec && g_shot_count < MAX_SHOTS) {
        g_shots[g_shot_count++] = strtof(spec, NULL);
        spec = strchr(spec, ',');
        if (spec) spec++;
    }
}
/* }}} */

/* {{{ Viewer state shared with Lua */
static ViewCamera g_fc;
static Camera3D g_camera;
static bool g_quit = false;

static const struct { int key; const char* name; } KEY_NAMES[] = {
    { KEY_ESCAPE, "ESCAPE" }, { KEY_TAB, "TAB" }, { KEY_ENTER, "ENTER" },
    { KEY_BACKSPACE, "BACKSPACE" }, { KEY_SPACE, "SPACE" }, { KEY_DELETE, "DELETE" },
    { KEY_F1, "F1" }, { KEY_F2, "F2" }, { KEY_F3, "F3" }, { KEY_F4, "F4" },
    { KEY_F5, "F5" }, { KEY_F6, "F6" }, { KEY_F7, "F7" }, { KEY_F8, "F8" },
    { KEY_F9, "F9" }, { KEY_F10, "F10" }, { KEY_F11, "F11" }, { KEY_F12, "F12" },
    { KEY_KP_1, "KP_1" }, { KEY_KP_2, "KP_2" }, { KEY_KP_4, "KP_4" },
    { KEY_KP_5, "KP_5" }, { KEY_KP_7, "KP_7" }, { KEY_KP_8, "KP_8" },
    { KEY_LEFT, "LEFT" }, { KEY_RIGHT, "RIGHT" }, { KEY_UP, "UP" }, { KEY_DOWN, "DOWN" },
    { KEY_HOME, "HOME" }, { KEY_END, "END" }, { KEY_PAGE_UP, "PAGE_UP" }, { KEY_PAGE_DOWN, "PAGE_DOWN" },
};

/* keys held down repeat (text editing) */
static const int REPEATING[] = { KEY_BACKSPACE, KEY_DELETE, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
                                 KEY_ENTER, KEY_PAGE_UP, KEY_PAGE_DOWN };

/* the interface holds the camera still (a panel over the whole view) */
static bool g_hold_camera = false;
static float g_wheel = 0.0f;

/* {{{ viewer.camera() -> x, y, distance, rotation, angle of attack, field
 * of view (WC3's: degrees, the angle of attack 360 less the pitch down) */
static int lv_camera(lua_State* L) {
    lua_pushnumber(L, g_fc.x * WC3_UNITS_PER_TILE);
    lua_pushnumber(L, -g_fc.z * WC3_UNITS_PER_TILE);
    lua_pushnumber(L, g_fc.distance);
    lua_pushnumber(L, g_fc.rotation);
    lua_pushnumber(L, 360.0f - g_fc.pitch);
    lua_pushnumber(L, g_fc.fov);
    return 6;
}
/* }}} */

/* {{{ viewer.set_camera(x, y [, distance [, rotation, angle of attack, field of view]]) */
static int lv_set_camera(lua_State* L) {
    g_fc.x = (float)luaL_checknumber(L, 1) / WC3_UNITS_PER_TILE;
    g_fc.z = -(float)luaL_checknumber(L, 2) / WC3_UNITS_PER_TILE;
    if (lua_isnumber(L, 3)) g_fc.distance = (float)lua_tonumber(L, 3);
    if (lua_isnumber(L, 4)) g_fc.rotation = (float)lua_tonumber(L, 4);
    if (lua_isnumber(L, 5)) {
        /* the angle of attack: 304 looks 56 down; kept between level and straight down */
        float pitch = 360.0f - fmodf((float)lua_tonumber(L, 5) + 360.0f, 360.0f);
        if (pitch >= 360.0f) pitch -= 360.0f;
        g_fc.pitch = fmaxf(1.0f, fminf(89.0f, pitch));
    }
    if (lua_isnumber(L, 6)) g_fc.fov = fmaxf(20.0f, fminf(120.0f, (float)lua_tonumber(L, 6)));
    return 0;
}
/* }}} */

/* {{{ viewer.to_screen(x, y, z) -> sx, sy, in_front */
static int lv_to_screen(lua_State* L) {
    Vector3 p = { (float)luaL_checknumber(L, 1) / WC3_UNITS_PER_TILE,
                  (float)luaL_checknumber(L, 3) / WC3_UNITS_PER_TILE,
                  -(float)luaL_checknumber(L, 2) / WC3_UNITS_PER_TILE };
    Vector2 v = GetWorldToScreen(p, g_camera);
    Vector3 f = { g_camera.target.x - g_camera.position.x, g_camera.target.y - g_camera.position.y,
                  g_camera.target.z - g_camera.position.z };
    float ahead = f.x * (p.x - g_camera.position.x) + f.y * (p.y - g_camera.position.y)
                + f.z * (p.z - g_camera.position.z);
    lua_pushnumber(L, v.x);
    lua_pushnumber(L, v.y);
    lua_pushboolean(L, ahead > 0);
    return 3;
}
/* }}} */

/* {{{ viewer.to_ground(sx, sy) -> x, y (WC3), where the screen point's ray
 * meets the level of the ground under the camera's target */
static int lv_to_ground(lua_State* L) {
    Vector2 at = { (float)luaL_checknumber(L, 1), (float)luaL_checknumber(L, 2) };
#if RAYLIB_VERSION_MAJOR > 5 || (RAYLIB_VERSION_MAJOR == 5 && RAYLIB_VERSION_MINOR >= 5)
    Ray ray = GetScreenToWorldRay(at, g_camera);
#else
    Ray ray = GetMouseRay(at, g_camera);   /* the same, before raylib 5.5 */
#endif
    if (fabsf(ray.direction.y) < 1e-6f) return 0;
    float t = (g_fc.y - ray.position.y) / ray.direction.y;
    if (t < 0) return 0;
    lua_pushnumber(L, (ray.position.x + ray.direction.x * t) * WC3_UNITS_PER_TILE);
    lua_pushnumber(L, -(ray.position.z + ray.direction.z * t) * WC3_UNITS_PER_TILE);
    return 2;
}
/* }}} */

/* {{{ viewer.mouse() -> x, y, left_pressed, left_down, left_released,
 * right_pressed */
static int lv_mouse(lua_State* L) {
    Vector2 m = GetMousePosition();
    lua_pushnumber(L, m.x);
    lua_pushnumber(L, m.y);
    lua_pushboolean(L, IsMouseButtonPressed(MOUSE_BUTTON_LEFT));
    lua_pushboolean(L, IsMouseButtonDown(MOUSE_BUTTON_LEFT));
    lua_pushboolean(L, IsMouseButtonReleased(MOUSE_BUTTON_LEFT));
    lua_pushboolean(L, IsMouseButtonPressed(MOUSE_BUTTON_RIGHT));
    return 6;
}
/* }}} */

/* {{{ viewer.keys() -> { names pressed this frame } */
static int lv_keys(lua_State* L) {
    lua_newtable(L);
    int n = 0;
    int k;
    while ((k = GetKeyPressed()) != 0) {
        const char* name = NULL;
        char buf[2] = { 0, 0 };
        if ((k >= KEY_A && k <= KEY_Z) || (k >= KEY_ZERO && k <= KEY_NINE)) {
            buf[0] = (char)k;
            name = buf;
        } else {
            for (size_t i = 0; i < sizeof(KEY_NAMES) / sizeof(KEY_NAMES[0]); i++) {
                if (KEY_NAMES[i].key == k) name = KEY_NAMES[i].name;
            }
        }
        if (name) {
            lua_pushstring(L, name);
            lua_rawseti(L, -2, ++n);
        }
    }
    for (size_t r = 0; r < sizeof(REPEATING) / sizeof(REPEATING[0]); r++) {
        if (!IsKeyPressedRepeat(REPEATING[r])) continue;
        for (size_t i = 0; i < sizeof(KEY_NAMES) / sizeof(KEY_NAMES[0]); i++) {
            if (KEY_NAMES[i].key == REPEATING[r]) {
                lua_pushstring(L, KEY_NAMES[i].name);
                lua_rawseti(L, -2, ++n);
            }
        }
    }
    return 1;
}
/* }}} */

/* {{{ viewer.chars() -> the text typed this frame (UTF-8), for chat */
static int lv_chars(lua_State* L) {
    char buf[256];
    int n = 0;
    int c;
    while ((c = GetCharPressed()) != 0) {
        if (n > (int)sizeof(buf) - 5) continue;
        if (c < 0x80) {
            buf[n++] = (char)c;
        } else if (c < 0x800) {
            buf[n++] = (char)(0xC0 | (c >> 6));
            buf[n++] = (char)(0x80 | (c & 0x3F));
        } else if (c < 0x10000) {
            buf[n++] = (char)(0xE0 | (c >> 12));
            buf[n++] = (char)(0x80 | ((c >> 6) & 0x3F));
            buf[n++] = (char)(0x80 | (c & 0x3F));
        }
    }
    lua_pushlstring(L, buf, (size_t)n);
    return 1;
}
/* }}} */

/* {{{ viewer.key_down("SHIFT" | "CTRL" | "ALT") -> held */
static int lv_key_down(lua_State* L) {
    const char* m = luaL_checkstring(L, 1);
    bool down = false;
    if (strcmp(m, "SHIFT") == 0) down = IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT);
    else if (strcmp(m, "CTRL") == 0) down = IsKeyDown(KEY_LEFT_CONTROL) || IsKeyDown(KEY_RIGHT_CONTROL);
    else if (strcmp(m, "ALT") == 0) down = IsKeyDown(KEY_LEFT_ALT) || IsKeyDown(KEY_RIGHT_ALT);
    lua_pushboolean(L, down);
    return 1;
}
/* }}} */

/* {{{ viewer.play_sound(bytes, ext) / viewer.stop_sound(): one sound at a
 * time, for the editor's preview (issue 907); false when there's no audio
 * device or the file can't be read (raylib reads WAV, MP3, OGG) */
static bool g_audio_tried = false;
static bool g_sound_loaded = false;
static Sound g_sound;

static int lv_stop_sound(lua_State* L) {
    (void)L;
    if (g_sound_loaded) {
        StopSound(g_sound);
        UnloadSound(g_sound);
        g_sound_loaded = false;
    }
    return 0;
}

static int lv_play_sound(lua_State* L) {
    size_t len;
    const char* data = luaL_checklstring(L, 1, &len);
    const char* ext = luaL_optstring(L, 2, ".wav");
    if (!g_audio_tried) {
        g_audio_tried = true;
        InitAudioDevice();
    }
    if (!IsAudioDeviceReady()) {
        lua_pushboolean(L, 0);
        lua_pushstring(L, "no audio device");
        return 2;
    }
    lv_stop_sound(L);
    Wave w = LoadWaveFromMemory(ext, (const unsigned char*)data, (int)len);
    if (w.data == NULL) {
        lua_pushboolean(L, 0);
        lua_pushstring(L, "can't read the sound");
        return 2;
    }
    g_sound = LoadSoundFromWave(w);
    UnloadWave(w);
    g_sound_loaded = true;
    PlaySound(g_sound);
    lua_pushboolean(L, 1);
    return 1;
}
/* }}} */

/* {{{ viewer.wheel() -> the mouse wheel's turn this frame */
static int lv_wheel(lua_State* L) {
    lua_pushnumber(L, g_wheel);
    return 1;
}
/* }}} */

/* {{{ viewer.hold_camera(held): no panning or zooming while held */
static int lv_hold_camera(lua_State* L) {
    g_hold_camera = lua_toboolean(L, 1);
    return 0;
}
/* }}} */

static int lv_quit(lua_State* L) {
    (void)L;
    g_quit = true;
    return 0;
}

/* {{{ register_viewer */
static void register_viewer(lua_State* L) {
    static const luaL_Reg fns[] = {
        { "camera", lv_camera }, { "set_camera", lv_set_camera },
        { "to_screen", lv_to_screen }, { "to_ground", lv_to_ground },
        { "mouse", lv_mouse }, { "keys", lv_keys }, { "chars", lv_chars }, { "key_down", lv_key_down },
        { "wheel", lv_wheel }, { "hold_camera", lv_hold_camera }, { "quit", lv_quit },
        { "play_sound", lv_play_sound }, { "stop_sound", lv_stop_sound }, { NULL, NULL },
    };
    lua_newtable(L);
    for (const luaL_Reg* f = fns; f->name; f++) {
        lua_pushcfunction(L, f->func);
        lua_setfield(L, -2, f->name);
    }
    lua_setglobal(L, "viewer");
}
/* }}} */
/* }}} */

/* {{{ ground_under
 * The scene's ground height at the camera's target (render units), via
 * its scene_ground(x, y) in WC3 units; 0 without one. */
static float ground_under(lua_State* L, const ViewCamera* fc) {
    float y = 0.0f;
    lua_getglobal(L, "scene_ground");
    if (lua_isfunction(L, -1)) {
        lua_pushnumber(L, fc->x * WC3_UNITS_PER_TILE);
        lua_pushnumber(L, -fc->z * WC3_UNITS_PER_TILE);
        if (lua_pcall(L, 2, 1, 0) == 0) {
            y = (float)lua_tonumber(L, -1) / WC3_UNITS_PER_TILE;
        }
        lua_pop(L, 1);
    } else {
        lua_pop(L, 1);
    }
    return y;
}
/* }}} */

/* {{{ start_camera
 * The scene's CAMERA_START = { x, y, distance } (WC3 units), then
 * SCENE_CAMERA over it */
static void start_camera(lua_State* L, ViewCamera* fc) {
    float cx = 0.0f, cy = -128.0f, cd = fc->distance;
    lua_getglobal(L, "CAMERA_START");
    if (lua_istable(L, -1)) {
        lua_rawgeti(L, -1, 1); if (lua_isnumber(L, -1)) cx = (float)lua_tonumber(L, -1); lua_pop(L, 1);
        lua_rawgeti(L, -1, 2); if (lua_isnumber(L, -1)) cy = (float)lua_tonumber(L, -1); lua_pop(L, 1);
        lua_rawgeti(L, -1, 3); if (lua_isnumber(L, -1)) cd = (float)lua_tonumber(L, -1); lua_pop(L, 1);
    }
    lua_pop(L, 1);
    const char* spec = getenv("SCENE_CAMERA");
    if (spec) sscanf(spec, "%f,%f,%f", &cx, &cy, &cd);
    fc->x = cx / WC3_UNITS_PER_TILE;
    fc->z = -cy / WC3_UNITS_PER_TILE;   /* WC3 north is render -z */
    fc->distance = cd;
}
/* }}} */

/* {{{ main */
int main(int argc, char** argv) {
    const char* root = argc > 1 ? argv[1] : ".";
    const char* scene = argc > 2 ? argv[2] : "src/demo/fort/main.lua";
    const char* shot_dir = getenv("SCENE_SHOT_DIR") ? getenv("SCENE_SHOT_DIR") : ".";
    const char* quit_at_s = getenv("SCENE_QUIT_AT");
    float quit_at = quit_at_s ? strtof(quit_at_s, NULL) : -1.0f;
    parse_shots(getenv("SCENE_SHOTS"));

    SetConfigFlags(FLAG_MSAA_4X_HINT);
    InitWindow(1280, 720, "Scene viewer - WC3 geometry");
    SetTargetFPS(60);

    /* Lua, with the render module preloaded and the project on the path */
    SlotArray* slots = slot_array_create();
    bridge_init(slots);
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "preload");
    lua_pushcfunction(L, luaopen_render);
    lua_setfield(L, -2, "render");
    lua_pop(L, 1);
    lua_pushfstring(L, "%s/src/?.lua;%s/src/?/init.lua;", root, root);
    lua_getfield(L, -2, "path");
    lua_concat(L, 2);
    lua_setfield(L, -2, "path");
    lua_pop(L, 1);
    lua_pushstring(L, root);
    lua_setglobal(L, "SCENE_ROOT");
    register_viewer(L);
    if (argc > 3) {
        lua_pushstring(L, argv[3]);
        lua_setglobal(L, "SCENE_ARG");
    }

    char script[1024];
    snprintf(script, sizeof(script), "%s/%s", root, scene);
    if (luaL_dofile(L, script) != 0) {
        fprintf(stderr, "[scene] %s\n", lua_tostring(L, -1));
        CloseWindow();
        return 1;
    }

    g_fc = (ViewCamera){ 0.0f, 1.0f, 0.0f, 2600.0f, 90.0f, CAM_PITCH_DEG, CAM_FOV_DEG };
    start_camera(L, &g_fc);
    lua_getglobal(L, "scene_ui");
    bool has_ui = lua_isfunction(L, -1);
    lua_pop(L, 1);
    if (has_ui) SetExitKey(KEY_NULL);   /* Esc is the interface's cancel */
    const float tick = 0.02f;   /* 50 Hz simulation */
    float pending = 0.0f, sim_time = 0.0f;
    char status[256];
    bool unattended = g_shot_count > 0 || quit_at > 0;

    while (!WindowShouldClose() && !g_quit) {
        float dt = GetFrameTime();
        if (dt > 0.1f) dt = 0.1f;

        /* {{{ camera input */
        float pan = CAM_PAN_SPEED / WC3_UNITS_PER_TILE * dt * (g_fc.distance / CAM_DEFAULT_DISTANCE);
        bool left = IsKeyDown(KEY_LEFT), right = IsKeyDown(KEY_RIGHT);
        bool up = IsKeyDown(KEY_UP), down = IsKeyDown(KEY_DOWN);
        if (!has_ui) {
            left |= IsKeyDown(KEY_A); right |= IsKeyDown(KEY_D);
            up |= IsKeyDown(KEY_W); down |= IsKeyDown(KEY_S);
        } else if (!unattended && IsWindowFocused()) {
            /* the screen edges scroll, as in WC3 */
            Vector2 m = GetMousePosition();
            left |= m.x <= 2; right |= m.x >= GetScreenWidth() - 3;
            up |= m.y <= 2; down |= m.y >= GetScreenHeight() - 3;
        }
        g_wheel = GetMouseWheelMove();
        if (g_hold_camera) left = right = up = down = false;
        if (left) g_fc.x -= pan;
        if (right) g_fc.x += pan;
        if (up) g_fc.z -= pan;
        if (down) g_fc.z += pan;
        if (!g_hold_camera) g_fc.distance -= g_wheel * 150.0f;
        if (!has_ui) {
            if (IsKeyPressed(KEY_ONE)) {
                g_fc.distance = CAM_DEFAULT_DISTANCE;
                g_fc.rotation = 90.0f; g_fc.pitch = CAM_PITCH_DEG; g_fc.fov = CAM_FOV_DEG;
            }
            if (IsKeyPressed(KEY_R)) call_lua(L, "scene_key", "rings", 0, false);
        }
        if (g_fc.distance < CAM_MIN_DISTANCE) g_fc.distance = CAM_MIN_DISTANCE;
        if (g_fc.distance > CAM_MAX_DISTANCE) g_fc.distance = CAM_MAX_DISTANCE;
        /* }}} */

        /* {{{ simulation: fixed ticks, as WC3 steps its game */
        /* unattended runs advance a fixed 1/60 s per frame, so a slow
         * machine takes longer but reaches the same scene at each second */
        pending += unattended ? 1.0f / 60.0f : dt;
        int steps = 0;
        while (pending >= tick && steps < 5) {
            call_lua(L, "scene_tick", NULL, tick, true);
            pending -= tick;
            sim_time += tick;
            steps++;
        }
        /* }}} */

        /* the target glides to the ground under it */
        float ground = ground_under(L, &g_fc);
        g_fc.y += (ground - g_fc.y) * (unattended ? 1.0f : fminf(1.0f, dt * 8.0f));
        apply_camera(&g_fc, &g_camera);
        call_lua(L, "scene_paint", NULL, 0, false);

        /* draw what the camera can see: out to about twice its distance */
        float view = g_fc.distance / WC3_UNITS_PER_TILE * 2.0f;
        geometry_set_view(g_fc.x, g_fc.z, view);
        ui2d_render_portrait();

        BeginDrawing();
            ClearBackground((Color){ 24, 28, 40, 255 });
            /* with fog of war the world is drawn off screen, then shaded
             * onto it (fog.c) */
            int fogged = fog_active();
            if (fogged) fog_begin();
            BeginMode3D(g_camera);
                terrain_draw_region(terrain_get_global(), g_fc.x, g_fc.z, view * 0.9f);
                landscape_draw(g_fc.x, g_fc.z, view);
                geometry_draw();
                models_draw(g_fc.x, g_fc.z, view * 1.1f);
                if (fogged) fog_capture();
            EndMode3D();
            if (fogged) fog_end();

            if (has_ui) {
                call_lua(L, "scene_ui", NULL, 0, false);
            } else {
                read_status(L, status, sizeof(status));
                DrawRectangle(0, 0, 1280, 30, (Color){ 0, 0, 0, 150 });
                DrawText(status, 12, 7, 18, (Color){ 250, 190, 110, 255 });
                DrawText(TextFormat("camera %.0f  |  arrows/WASD pan  wheel zoom  1 default  R rings  |  %d FPS",
                                    g_fc.distance, GetFPS()),
                         12, 696, 16, (Color){ 200, 205, 220, 255 });
            }

            if (g_next_shot < g_shot_count && sim_time >= g_shots[g_next_shot]) {
                rlDrawRenderBatchActive();
                Image img = LoadImageFromScreen();
                char path[1024];
                snprintf(path, sizeof(path), "%s/scene-%05.1f.png", shot_dir, g_shots[g_next_shot]);
                ExportImage(img, path);
                UnloadImage(img);
                printf("[scene] saved %s\n", path);
                g_next_shot++;
            }
        EndDrawing();

        if (quit_at > 0 && sim_time >= quit_at) break;
    }

    lua_close(L);
    ui2d_free();
    landscape_free();
    slot_array_destroy(slots);
    CloseWindow();
    return 0;
}
/* }}} */
