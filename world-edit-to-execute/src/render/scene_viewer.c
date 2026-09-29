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
 * Keys: arrows/WASD pan, mouse wheel zoom, 1 WC3 default camera distance,
 *       R "rings" (the fort's range rings), Esc quit.
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
#define CAM_MIN_DISTANCE     700.0f
#define CAM_MAX_DISTANCE     9000.0f
#define CAM_PAN_SPEED        1400.0f   /* WC3 units per second */

typedef struct {
    float x, z;          /* target, render units */
    float y;             /* ground height under the target, render units */
    float distance;      /* WC3 units */
} ViewCamera;

/* Place a raylib camera looking north (render -z) at the target */
static void apply_camera(const ViewCamera* fc, Camera3D* cam) {
    float d = fc->distance / WC3_UNITS_PER_TILE;
    float pitch = CAM_PITCH_DEG * DEG2RAD;
    cam->target = (Vector3){ fc->x, fc->y, fc->z };
    cam->position = (Vector3){ fc->x, fc->y + d * sinf(pitch), fc->z + d * cosf(pitch) };
    cam->up = (Vector3){ 0.0f, 1.0f, 0.0f };
    cam->fovy = CAM_FOV_DEG;
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

    ViewCamera fc = { 0.0f, 1.0f, 0.0f, 2600.0f };
    start_camera(L, &fc);
    Camera3D camera = { 0 };
    const float tick = 0.02f;   /* 50 Hz simulation */
    float pending = 0.0f, sim_time = 0.0f;
    char status[256];

    while (!WindowShouldClose()) {
        float dt = GetFrameTime();
        if (dt > 0.1f) dt = 0.1f;

        /* {{{ input */
        float pan = CAM_PAN_SPEED / WC3_UNITS_PER_TILE * dt * (fc.distance / CAM_DEFAULT_DISTANCE);
        if (IsKeyDown(KEY_LEFT) || IsKeyDown(KEY_A))  fc.x -= pan;
        if (IsKeyDown(KEY_RIGHT) || IsKeyDown(KEY_D)) fc.x += pan;
        if (IsKeyDown(KEY_UP) || IsKeyDown(KEY_W))    fc.z -= pan;
        if (IsKeyDown(KEY_DOWN) || IsKeyDown(KEY_S))  fc.z += pan;
        fc.distance -= GetMouseWheelMove() * 150.0f;
        if (IsKeyPressed(KEY_ONE)) fc.distance = CAM_DEFAULT_DISTANCE;
        if (fc.distance < CAM_MIN_DISTANCE) fc.distance = CAM_MIN_DISTANCE;
        if (fc.distance > CAM_MAX_DISTANCE) fc.distance = CAM_MAX_DISTANCE;
        if (IsKeyPressed(KEY_R)) call_lua(L, "scene_key", "rings", 0, false);
        /* }}} */

        /* {{{ simulation: fixed ticks, as WC3 steps its game */
        /* unattended runs advance a fixed 1/60 s per frame, so a slow
         * machine takes longer but reaches the same scene at each second */
        bool unattended = g_shot_count > 0 || quit_at > 0;
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
        float ground = ground_under(L, &fc);
        fc.y += (ground - fc.y) * (unattended ? 1.0f : fminf(1.0f, dt * 8.0f));
        apply_camera(&fc, &camera);
        call_lua(L, "scene_paint", NULL, 0, false);

        /* draw what the camera can see: out to about twice its distance */
        float view = fc.distance / WC3_UNITS_PER_TILE * 2.0f;
        geometry_set_view(fc.x, fc.z, view);

        BeginDrawing();
            ClearBackground((Color){ 24, 28, 40, 255 });
            BeginMode3D(camera);
                terrain_draw_region(terrain_get_global(), fc.x, fc.z, view * 0.9f);
                landscape_draw(fc.x, fc.z, view);
                geometry_draw();
            EndMode3D();

            read_status(L, status, sizeof(status));
            DrawRectangle(0, 0, 1280, 30, (Color){ 0, 0, 0, 150 });
            DrawText(status, 12, 7, 18, (Color){ 250, 190, 110, 255 });
            DrawText(TextFormat("camera %.0f  |  arrows/WASD pan  wheel zoom  1 default  R rings  |  %d FPS",
                                fc.distance, GetFPS()),
                     12, 696, 16, (Color){ 200, 205, 220, 255 });

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
    landscape_free();
    slot_array_destroy(slots);
    CloseWindow();
    return 0;
}
/* }}} */
