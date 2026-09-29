/*
 * Fort Demo (Issue 516e)
 *
 * A window, a WC3-style camera and a fixed 50 Hz tick; everything else is
 * Lua (src/demo/fort/main.lua): the ground, the fort painted with the
 * geometry kit, and the bowmen's behaviours.
 *
 * Usage: fort_demo [PROJECT_ROOT]      (default: the current directory)
 *
 * Keys: arrows/WASD pan, mouse wheel zoom, 1 WC3 default camera distance,
 *       R cycle range rings, Esc quit.
 *
 * For unattended runs:
 *   FORT_SHOTS="4,12,24"   save the screen at these simulated seconds
 *   FORT_SHOT_DIR=path     where to save them (default: current directory)
 *   FORT_QUIT_AT=26        quit at this simulated second
 *   FORT_CAMERA="x,y,d"    start the camera looking at WC3 point (x, y)
 *                          (the fort's centre is 0,0) from d units away
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
#define CAM_MAX_DISTANCE     4200.0f
#define CAM_PAN_SPEED        1400.0f   /* WC3 units per second */

typedef struct {
    float x, z;          /* target, render units */
    float distance;      /* WC3 units */
} FortCamera;

/* Place a raylib camera looking north (render -z) at the target */
static void apply_camera(const FortCamera* fc, Camera3D* cam) {
    float d = fc->distance / WC3_UNITS_PER_TILE;
    float pitch = CAM_PITCH_DEG * DEG2RAD;
    cam->target = (Vector3){ fc->x, 0.0f, fc->z };
    cam->position = (Vector3){ fc->x, d * sinf(pitch), fc->z + d * cosf(pitch) };
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
        fprintf(stderr, "[fort] %s: %s\n", fn, lua_tostring(L, -1));
        lua_pop(L, 1);
        return false;
    }
    return true;
}

static void read_status(lua_State* L, char* out, size_t size) {
    out[0] = '\0';
    lua_getglobal(L, "fort_status");
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

/* {{{ main */
int main(int argc, char** argv) {
    const char* root = argc > 1 ? argv[1] : ".";
    const char* shot_dir = getenv("FORT_SHOT_DIR") ? getenv("FORT_SHOT_DIR") : ".";
    const char* quit_at_s = getenv("FORT_QUIT_AT");
    float quit_at = quit_at_s ? strtof(quit_at_s, NULL) : -1.0f;
    parse_shots(getenv("FORT_SHOTS"));

    SetConfigFlags(FLAG_MSAA_4X_HINT);
    InitWindow(1280, 720, "Fort - WC3 geometry and behaviour demo");
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
    lua_setglobal(L, "FORT_ROOT");

    char script[1024];
    snprintf(script, sizeof(script), "%s/src/demo/fort/main.lua", root);
    if (luaL_dofile(L, script) != 0) {
        fprintf(stderr, "[fort] %s\n", lua_tostring(L, -1));
        CloseWindow();
        return 1;
    }

    FortCamera fc = { 0.0f, 1.0f, 2600.0f };
    const char* cam_spec = getenv("FORT_CAMERA");
    if (cam_spec) {
        float cx = 0, cy = 0, cd = fc.distance;
        if (sscanf(cam_spec, "%f,%f,%f", &cx, &cy, &cd) >= 2) {
            fc.x = cx / WC3_UNITS_PER_TILE;
            fc.z = -cy / WC3_UNITS_PER_TILE;   /* WC3 north is render -z */
            fc.distance = cd;
        }
    }
    Camera3D camera = { 0 };
    const float tick = 0.02f;   /* 50 Hz simulation */
    float pending = 0.0f, sim_time = 0.0f;
    char status[256];

    while (!WindowShouldClose()) {
        float dt = GetFrameTime();
        if (dt > 0.1f) dt = 0.1f;

        /* {{{ input */
        float pan = CAM_PAN_SPEED / WC3_UNITS_PER_TILE * dt;
        if (IsKeyDown(KEY_LEFT) || IsKeyDown(KEY_A))  fc.x -= pan;
        if (IsKeyDown(KEY_RIGHT) || IsKeyDown(KEY_D)) fc.x += pan;
        if (IsKeyDown(KEY_UP) || IsKeyDown(KEY_W))    fc.z -= pan;
        if (IsKeyDown(KEY_DOWN) || IsKeyDown(KEY_S))  fc.z += pan;
        fc.distance -= GetMouseWheelMove() * 150.0f;
        if (IsKeyPressed(KEY_ONE)) fc.distance = CAM_DEFAULT_DISTANCE;
        if (fc.distance < CAM_MIN_DISTANCE) fc.distance = CAM_MIN_DISTANCE;
        if (fc.distance > CAM_MAX_DISTANCE) fc.distance = CAM_MAX_DISTANCE;
        if (IsKeyPressed(KEY_R)) call_lua(L, "fort_key", "rings", 0, false);
        /* }}} */

        /* {{{ simulation: fixed ticks, as WC3 steps its game */
        /* unattended runs advance a fixed 1/60 s per frame, so a slow
         * machine takes longer but reaches the same scene at each second */
        bool unattended = g_shot_count > 0 || quit_at > 0;
        pending += unattended ? 1.0f / 60.0f : dt;
        int steps = 0;
        while (pending >= tick && steps < 5) {
            call_lua(L, "fort_tick", NULL, tick, true);
            pending -= tick;
            sim_time += tick;
            steps++;
        }
        /* }}} */

        apply_camera(&fc, &camera);
        call_lua(L, "fort_paint", NULL, 0, false);

        BeginDrawing();
            ClearBackground((Color){ 24, 28, 40, 255 });
            BeginMode3D(camera);
                TerrainGrid* terrain = terrain_get_global();
                terrain_draw_region(terrain, fc.x, fc.z,
                                    fc.distance / WC3_UNITS_PER_TILE * 1.8f);
                geometry_draw();
            EndMode3D();

            read_status(L, status, sizeof(status));
            DrawRectangle(0, 0, 1280, 30, (Color){ 0, 0, 0, 150 });
            DrawText(status, 12, 7, 18, (Color){ 250, 190, 110, 255 });
            DrawText(TextFormat("camera %.0f  |  arrows/WASD pan  wheel zoom  1 default  R range rings  |  %d FPS",
                                fc.distance, GetFPS()),
                     12, 696, 16, (Color){ 200, 205, 220, 255 });

            if (g_next_shot < g_shot_count && sim_time >= g_shots[g_next_shot]) {
                rlDrawRenderBatchActive();
                Image img = LoadImageFromScreen();
                char path[1024];
                snprintf(path, sizeof(path), "%s/fort-%05.1f.png", shot_dir, g_shots[g_next_shot]);
                ExportImage(img, path);
                UnloadImage(img);
                printf("[fort] saved %s\n", path);
                g_next_shot++;
            }
        EndDrawing();

        if (quit_at > 0 && sim_time >= quit_at) break;
    }

    lua_close(L);
    slot_array_destroy(slots);
    CloseWindow();
    return 0;
}
/* }}} */
