/*
 * crossing-host.c - two armies swapping sides, drawn from what arrives from the server (issue 804)
 *
 * What this is: a raylib window whose every drawn unit has come from the
 * server as bytes. Three threads:
 *
 *   the server     runs the game (src/net/crossing_sim.lua: units that path
 *                  around each other) on a thread of its own, started by...
 *   the receiver   this program's second thread, which holds a Lua state
 *                  running src/net/renderer_link.lua. It polls for arrived
 *                  messages, reads each with the C reader generated from
 *                  the Lua message descriptions (net-messages.h), writes
 *                  unit states straight into the mailbox's writing buffer
 *                  and publishes, and keeps the waiting dialog's news and
 *                  the units' paths for the draw thread. It is the only
 *                  thread that touches Lua.
 *   the draw       thread (main) owns the window. It takes the newest state
 *                  from the mailbox, never waiting, and draws the arena, the
 *                  units, their paths, the numbers, and -- while the game is
 *                  paused -- the waiting dialog with every player's slider
 *                  and a vote button. Keys disturb the connection live.
 *
 * The draw thread asks things of the receiver (a slider moved, a vote, a
 * disturbance) through `wants`, under the news lock; the receiver passes
 * them to Lua on its next turn.
 *
 * Modes:
 *   (none)                      the window, until closed
 *   --check SECONDS [D J L]     no window: takes states for SECONDS while
 *                               the connection has D ms delay, J ms jitter
 *                               and L loss (0..1); fails on two units
 *                               overlapping, a tick going backwards, or too
 *                               few states
 *   --shot SECONDS PATH [paused] a hidden window; a picture after SECONDS.
 *                               With "paused", the stand-in player goes
 *                               silent at once and this player's slider is
 *                               set to half a second, so the picture shows
 *                               the waiting dialog
 */
#include "raylib.h"
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#include <math.h>
#include <pthread.h>
#include <semaphore.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "mailbox.h"
#include "net-messages.h"

#define MOST_UNITS 256
#define MOST_PATH 128          /* points kept per unit's path */
#define MOST_ROWS 64
#define MOST_COLS 128
#define TOLERANCE_LEAST_MS 250 /* the slider's ends: the server's numbers (src/net/server.lua) */
#define TOLERANCE_MOST_MS 10000

/* {{{ static double now_us(void) */
static double now_us(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1e6 + ts.tv_nsec / 1e3;
}
/* }}} */

/* One unit as drawn: where on the ground (x, z), how fast, which way it
 * faces, its size on the ground, whether it is walking, whose it is. */
typedef struct {
    uint32_t id;
    float    x, z, vx, vz, facing, radius;
    int      walking, team;
} cross_unit;

/* One whole state, as the mailbox carries it. */
typedef struct {
    uint32_t   tick;
    double     received_us;   /* when the receiver published it */
    int        count;
    cross_unit units[MOST_UNITS];
} cross_state;

/* The map, filled once by the receiver before the window opens. */
typedef struct {
    int   rows, cols;
    char  cell[MOST_ROWS][MOST_COLS];   /* '#' wall, else ground */
    float cell_size;
    sem_t ready;
} cross_map;

/* Everything but the states, shared under `lock`: the waiting dialog's
 * news, paths, counts, and what the draw thread wants of the receiver. */
typedef struct {
    pthread_mutex_t lock;
    int      paused;
    uint32_t paused_tick;
    int      silent_count;
    struct { int player; uint32_t silent_ms, countdown_ms; } silent[8];
    uint32_t in_force_ms;
    uint32_t tolerance_ms[8];
    int      players_known;
    int      votes_needed, votes[8];
    int      path_len[MOST_UNITS + 1];
    float    path[MOST_UNITS + 1][MOST_PATH][2];
    long     messages, states, refused, stale;
    /* what the draw thread wants done; -1 = nothing */
    int      want_tolerance_ms, want_vote;
    int      want_disturb;                 /* 1 when the three below changed */
    double   delay_ms, jitter_ms, loss;
    int      want_silence;                 /* -1 nothing, 0 talk, 1 silent */
    int      stand_in_silent;
} cross_news;

static cross_map   map;
static cross_news  news = { .lock = PTHREAD_MUTEX_INITIALIZER, .want_tolerance_ms = -1, .want_vote = -1, .want_silence = -1 };
static mailbox    *mb;
static atomic_int  stopping;
static const char *project_dir;

/* {{{ static void lua_must(lua_State *L, int status, const char *what) */
static void lua_must(lua_State *L, int status, const char *what)
{
    if (status != 0) {
        fprintf(stderr, "Lua failed %s: %s\n", what, lua_tostring(L, -1));
        exit(1);
    }
}
/* }}} */

/* {{{ The receiver's handlers, one per message type (a dispatch table) */
static net_unit_states_units scratch_units[MOST_UNITS];
static net_paths_stopped     scratch_stopped[MOST_UNITS];
static net_paths_points      scratch_points[MOST_UNITS * MOST_PATH];
static net_waiting_silent    scratch_silent[8];
static net_tolerances_players scratch_players[8];
static net_votes_silent      scratch_votes[8];

/* {{{ static void refused(const char *why) */
static void refused(const char *why)
{
    fprintf(stderr, "a message was refused: %s\n", why);
    pthread_mutex_lock(&news.lock);
    news.refused++;
    pthread_mutex_unlock(&news.lock);
}
/* }}} */

/* {{{ static void on_unit_states(const uint8_t *b, size_t n) */
/* Straight into the mailbox's writing buffer, then published. Two paths: a
 * state newer than any shown -> published; one older or the same -> dropped
 * as stale. On a real network (and with jitter here) messages overtake each
 * other; the first version published whatever came last, and the picture
 * jumped backwards 96 times in 8 seconds of 60 ms jitter. */
static uint32_t newest_shown;
static void on_unit_states(const uint8_t *b, size_t n)
{
    net_unit_states m = { .units = scratch_units, .units_room = MOST_UNITS };
    const char *why = net_decode_unit_states(b, n, &m);
    if (why) { refused(why); return; }
    if (m.tick <= newest_shown) {
        pthread_mutex_lock(&news.lock);
        news.stale++;
        pthread_mutex_unlock(&news.lock);
        return;
    }
    newest_shown = m.tick;
    cross_state *s = mailbox_writing(mb, 0);
    s->tick = m.tick;
    s->count = m.units_count;
    for (int i = 0; i < m.units_count; i++) {
        net_unit_states_units *u = &m.units[i];
        s->units[i] = (cross_unit){ u->id, u->x, u->z, u->vx, u->vz, u->facing, u->radius, u->anim == 1, u->team };
    }
    s->received_us = now_us();
    mailbox_publish(mb, 0);
    pthread_mutex_lock(&news.lock);
    news.states++;
    pthread_mutex_unlock(&news.lock);
}
/* }}} */

/* {{{ static void on_paths(const uint8_t *b, size_t n) */
/* A unit named in the message gets its new path (or none); others keep
 * theirs. */
static void on_paths(const uint8_t *b, size_t n)
{
    net_paths m = { .stopped = scratch_stopped, .stopped_room = MOST_UNITS,
                    .points = scratch_points, .points_room = MOST_UNITS * MOST_PATH };
    const char *why = net_decode_paths(b, n, &m);
    if (why) { refused(why); return; }
    pthread_mutex_lock(&news.lock);
    for (int i = 0; i < m.stopped_count; i++)
        if (m.stopped[i].id <= MOST_UNITS) news.path_len[m.stopped[i].id] = 0;
    uint32_t current = 0;
    for (int i = 0; i < m.points_count; i++) {
        uint32_t id = m.points[i].id;
        if (id > MOST_UNITS) continue;
        if (id != current) { news.path_len[id] = 0; current = id; }   /* a unit's points come together */
        if (news.path_len[id] < MOST_PATH) {
            news.path[id][news.path_len[id]][0] = m.points[i].x;
            news.path[id][news.path_len[id]][1] = m.points[i].y;
            news.path_len[id]++;
        }
    }
    pthread_mutex_unlock(&news.lock);
}
/* }}} */

/* {{{ static void on_waiting(const uint8_t *b, size_t n) */
static void on_waiting(const uint8_t *b, size_t n)
{
    net_waiting m = { .silent = scratch_silent, .silent_room = 8 };
    const char *why = net_decode_waiting(b, n, &m);
    if (why) { refused(why); return; }
    pthread_mutex_lock(&news.lock);
    news.paused = m.paused;
    news.paused_tick = m.tick;
    news.silent_count = m.silent_count;
    for (int i = 0; i < m.silent_count; i++) {
        news.silent[i].player = m.silent[i].player;
        news.silent[i].silent_ms = m.silent[i].silent_ms;
        news.silent[i].countdown_ms = m.silent[i].countdown_ms;
    }
    pthread_mutex_unlock(&news.lock);
}
/* }}} */

/* {{{ static void on_tolerances(const uint8_t *b, size_t n) */
static void on_tolerances(const uint8_t *b, size_t n)
{
    net_tolerances m = { .players = scratch_players, .players_room = 8 };
    const char *why = net_decode_tolerances(b, n, &m);
    if (why) { refused(why); return; }
    pthread_mutex_lock(&news.lock);
    news.in_force_ms = m.in_force_ms;
    news.players_known = m.players_count;
    for (int i = 0; i < m.players_count; i++)
        if (m.players[i].player < 8) news.tolerance_ms[m.players[i].player] = m.players[i].ms;
    pthread_mutex_unlock(&news.lock);
}
/* }}} */

/* {{{ static void on_votes(const uint8_t *b, size_t n) */
static void on_votes(const uint8_t *b, size_t n)
{
    net_votes m = { .silent = scratch_votes, .silent_room = 8 };
    const char *why = net_decode_votes(b, n, &m);
    if (why) { refused(why); return; }
    pthread_mutex_lock(&news.lock);
    news.votes_needed = m.needed;
    memset(news.votes, 0, sizeof news.votes);
    for (int i = 0; i < m.silent_count; i++)
        if (m.silent[i].player < 8) news.votes[m.silent[i].player] = m.silent[i].votes;
    pthread_mutex_unlock(&news.lock);
}
/* }}} */

/* {{{ static void on_ignored(const uint8_t *b, size_t n) */
/* Order answers and events: this demo gives no orders and has no deaths. */
static void on_ignored(const uint8_t *b, size_t n) { (void)b; (void)n; }
/* }}} */

typedef void (*message_handler)(const uint8_t *, size_t);
static message_handler handlers[256] = {
    [NET_UNIT_STATES] = on_unit_states, [NET_PATHS] = on_paths, [NET_WAITING] = on_waiting,
    [NET_TOLERANCES] = on_tolerances, [NET_VOTES] = on_votes,
    [NET_ORDER_ANSWER] = on_ignored, [NET_EVENTS] = on_ignored,
};
/* }}} */

/* {{{ static void call_link(lua_State *L, const char *fn, int args, int results) */
/* Calls link[fn] with the `args` values already pushed; leaves `results`. */
static void call_link(lua_State *L, const char *fn, int args, int results)
{
    lua_getglobal(L, "link");
    lua_getfield(L, -1, fn);
    lua_remove(L, -2);
    lua_insert(L, -1 - args);
    lua_must(L, lua_pcall(L, args, results, 0), fn);
}
/* }}} */

/* {{{ static void apply_wants(lua_State *L) */
/* What the draw thread asked for, passed to Lua. */
static void apply_wants(lua_State *L)
{
    pthread_mutex_lock(&news.lock);
    int tolerance = news.want_tolerance_ms, vote = news.want_vote, silence = news.want_silence, disturb = news.want_disturb;
    double delay = news.delay_ms, jitter = news.jitter_ms, loss = news.loss;
    news.want_tolerance_ms = news.want_vote = news.want_silence = -1;
    news.want_disturb = 0;
    pthread_mutex_unlock(&news.lock);
    if (tolerance >= 0) { lua_pushinteger(L, tolerance); call_link(L, "tolerance", 1, 0); }
    if (vote >= 0) { lua_pushinteger(L, vote); call_link(L, "vote", 1, 0); }
    if (silence >= 0) { lua_pushboolean(L, silence); call_link(L, "silence_stand_in", 1, 0); }
    if (disturb) {
        lua_pushnumber(L, delay); lua_pushnumber(L, jitter); lua_pushnumber(L, loss);
        call_link(L, "disturb", 3, 0);
    }
}
/* }}} */

/* {{{ static void *receiver_run(void *arg) */
/* THREADING { -- the receiving thread: the only one that touches Lua */
static void *receiver_run(void *arg)
{
    (void)arg;
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);
    char setup[1024];
    snprintf(setup, sizeof setup,
             "package.path = '%s/src/?.lua;%s/src/?/init.lua;' .. package.path\n"
             "link = require('net.renderer_link')", project_dir, project_dir);
    lua_must(L, luaL_dostring(L, setup), "loading the link");

    /* the map: rows, cell size; CROSSING_TWO_RADII=1 turns the larger
     * pathing radius on, to compare the two by eye */
    lua_pushstring(L, project_dir);
    const char *two = getenv("CROSSING_TWO_RADII");
    lua_pushboolean(L, two && strcmp(two, "1") == 0);
    call_link(L, "start", 2, 2);
    map.cell_size = (float)lua_tonumber(L, -1);
    lua_pop(L, 1);
    map.rows = (int)lua_objlen(L, -1);
    if (map.rows > MOST_ROWS) { fprintf(stderr, "the map has more than %d rows\n", MOST_ROWS); exit(1); }
    for (int y = 0; y < map.rows; y++) {
        lua_rawgeti(L, -1, y + 1);
        size_t len;
        const char *row = lua_tolstring(L, -1, &len);
        if (len > MOST_COLS) { fprintf(stderr, "the map has more than %d columns\n", MOST_COLS); exit(1); }
        map.cols = (int)len;
        for (size_t x = 0; x < len; x++) map.cell[y][x] = row[x];
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
    sem_post(&map.ready);

    while (!atomic_load(&stopping)) {
        apply_wants(L);
        call_link(L, "poll", 0, 1);
        int count = (int)lua_objlen(L, -1);
        for (int i = 1; i <= count; i++) {
            lua_rawgeti(L, -1, i);
            size_t n;
            const uint8_t *b = (const uint8_t *)lua_tolstring(L, -1, &n);
            /* Two paths: a type this program reads -> its handler; any other -> refused */
            if (n > 0 && handlers[b[0]]) handlers[b[0]](b, n);
            else refused("a message of a type this renderer doesn't read");
            lua_pop(L, 1);
        }
        lua_pop(L, 1);
        pthread_mutex_lock(&news.lock);
        news.messages += count;
        pthread_mutex_unlock(&news.lock);
        struct timespec rest = { 0, 1000000 };   /* a millisecond */
        nanosleep(&rest, NULL);
    }
    call_link(L, "stop", 0, 1);
    lua_close(L);
    return NULL;
}
/* } THREADING */
/* }}} */

/* {{{ static void want(int *field, int value) */
static void want(int *field, int value)
{
    pthread_mutex_lock(&news.lock);
    *field = value;
    pthread_mutex_unlock(&news.lock);
}
/* }}} */

/* {{{ static void want_disturbance(double delay, double jitter, double loss) */
static void want_disturbance(double delay, double jitter, double loss)
{
    pthread_mutex_lock(&news.lock);
    news.delay_ms = delay; news.jitter_ms = jitter; news.loss = loss;
    news.want_disturb = 1;
    pthread_mutex_unlock(&news.lock);
}
/* }}} */

/* {{{ static int overlapping(const cross_state *s) */
/* How many pairs of units overlap in a state (the crowd's promise is none). */
static int overlapping(const cross_state *s)
{
    int pairs = 0;
    for (int i = 0; i < s->count; i++)
        for (int j = i + 1; j < s->count; j++) {
            float reach = s->units[i].radius + s->units[j].radius;
            float dx = s->units[i].x - s->units[j].x, dz = s->units[i].z - s->units[j].z;
            if (dx * dx + dz * dz < reach * reach - 1e-4f) pairs++;
        }
    return pairs;
}
/* }}} */

/* {{{ static int check(double seconds, double delay, double jitter, double loss) */
/* No window: take states as they come and hold them to the promises. */
static int check(double seconds, double delay, double jitter, double loss)
{
    want_disturbance(delay, jitter, loss);
    double start = now_us();
    long taken = 0, overlaps = 0, backwards = 0;
    uint32_t first = 0, last = 0;
    while (now_us() - start < seconds * 1e6) {
        int is_new;
        const cross_state *s = mailbox_take(mb, &is_new);
        /* Two paths: nothing new -> rest a moment; a new state -> check it */
        if (!is_new) { struct timespec r = { 0, 500000 }; nanosleep(&r, NULL); continue; }
        if (taken == 0) first = s->tick;
        else if (s->tick <= last) backwards++;
        last = s->tick;
        overlaps += overlapping(s);
        taken++;
    }
    pthread_mutex_lock(&news.lock);
    long refused_count = news.refused, stale = news.stale;
    pthread_mutex_unlock(&news.lock);
    /* at 62.5 ticks a second, less loss, allowing half again for a busy
     * machine and for states overtaken by newer ones */
    double expected = seconds * 62.5 * (1 - loss) * 0.5;
    printf("check\t%.0f s\tdelay %.0f jitter %.0f loss %.2f\tstates %ld (ticks %u..%u)\toverlaps %ld\tbackwards %ld\tstale dropped %ld\trefused %ld\n",
           seconds, delay, jitter, loss, taken, first, last, overlaps, backwards, stale, refused_count);
    int ok = overlaps == 0 && backwards == 0 && refused_count == 0 && taken >= expected;
    if (!ok) fprintf(stderr, "check failed (needed at least %.0f states, no overlaps, nothing backwards or refused)\n", expected);
    return ok ? 0 : 1;
}
/* }}} */

/* {{{ static Vector3 ground(float x, float z, float up) */
static Vector3 ground(float x, float z, float up) { return (Vector3){ x, up, z }; }
/* }}} */

/* {{{ static void draw_world(const cross_state *s, double seconds) */
/* The arena, the paths, the units. */
static void draw_world(const cross_state *s, double seconds)
{
    float c = map.cell_size;
    DrawPlane(ground(map.cols * c / 2, map.rows * c / 2, 0), (Vector2){ map.cols * c, map.rows * c }, (Color){ 52, 60, 48, 255 });
    for (int y = 0; y < map.rows; y++)
        for (int x = 0; x < map.cols; x++)
            if (map.cell[y][x] == '#')
                DrawCube(ground((x + 0.5f) * c, (y + 0.5f) * c, 0.5f), c, 1.0f, c, (Color){ 120, 112, 100, 255 });

    /* each unit's path, from where it is through its waypoints */
    pthread_mutex_lock(&news.lock);
    for (int i = 0; i < s->count; i++) {
        uint32_t id = s->units[i].id;
        if (id > MOST_UNITS || news.path_len[id] == 0) continue;
        Color col = s->units[i].team == 0 ? (Color){ 230, 90, 70, 110 } : (Color){ 80, 140, 240, 110 };
        Vector3 from = ground(s->units[i].x, s->units[i].z, 0.04f);
        for (int k = 0; k < news.path_len[id]; k++) {
            Vector3 to = ground(news.path[id][k][0], news.path[id][k][1], 0.04f);
            DrawLine3D(from, to, col);
            from = to;
        }
    }
    pthread_mutex_unlock(&news.lock);

    for (int i = 0; i < s->count; i++) {
        const cross_unit *u = &s->units[i];
        int west = u->team == 0;
        Color body = west ? (Color){ 214, 72, 59, 255 } : (Color){ 59, 127, 217, 255 };
        /* its size on the ground, as a ring under its feet: green for
         * player 0's side, purple for player 1's (the owner, 2026-09-25) */
        Color ring = west ? (Color){ 70, 220, 90, 255 } : (Color){ 190, 90, 230, 255 };
        DrawCircle3D(ground(u->x, u->z, 0.03f), u->radius, (Vector3){ 1, 0, 0 }, 90.0f, ring);
        DrawCircle3D(ground(u->x, u->z, 0.035f), u->radius * 0.97f, (Vector3){ 1, 0, 0 }, 90.0f, ring);
        /* the body, sized by the radius; walking units bob, a little out of
         * step with each other */
        float r = u->radius * 0.8f, h = 0.5f + u->radius * 0.9f;
        float bob = u->walking ? 0.06f * fabsf(sinf((float)seconds * 9.0f + (float)u->id)) : 0;
        DrawCylinder(ground(u->x, u->z, bob), r, r * 0.8f, h, 14, body);
        /* a nose, to show which way it faces */
        Vector3 nose = ground(u->x + cosf(u->facing) * r, u->z + sinf(u->facing) * r, h * 0.78f + bob);
        DrawSphere(nose, 0.05f + r * 0.12f, RAYWHITE);
    }
}
/* }}} */

/* {{{ static int button(Rectangle r, const char *label, int enabled) */
/* A clickable box; 1 on the frame it is clicked. */
static int button(Rectangle r, const char *label, int enabled)
{
    int over = CheckCollisionPointRec(GetMousePosition(), r);
    Color fill = !enabled ? (Color){ 60, 60, 60, 255 } : over ? (Color){ 190, 90, 60, 255 } : (Color){ 150, 70, 50, 255 };
    DrawRectangleRec(r, fill);
    DrawText(label, (int)r.x + 10, (int)r.y + 7, 18, enabled ? RAYWHITE : GRAY);
    return enabled && over && IsMouseButtonPressed(MOUSE_BUTTON_LEFT);
}
/* }}} */

/* {{{ static void draw_waiting(int *dragging, float *drag_ms) */
/* The waiting dialog: who is silent, the countdown, every player's slider
 * (this player's can be dragged; it is sent when let go), vote buttons. */
static void draw_waiting(int *dragging, float *drag_ms)
{
    pthread_mutex_lock(&news.lock);
    cross_news n = news;   /* a copy, drawn without the lock held */
    pthread_mutex_unlock(&news.lock);
    int w = 560, h = 190 + 40 * n.silent_count, x = (GetScreenWidth() - w) / 2, y = 150;
    DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(), (Color){ 0, 0, 0, 90 });
    DrawRectangle(x, y, w, h, (Color){ 24, 26, 30, 240 });
    DrawRectangleLines(x, y, w, h, (Color){ 200, 170, 90, 255 });
    DrawText("Waiting for players...", x + 20, y + 14, 24, (Color){ 230, 200, 120, 255 });
    DrawText(TextFormat("paused on tick %u", n.paused_tick), x + 330, y + 20, 16, GRAY);
    int row = y + 54;
    for (int i = 0; i < n.silent_count; i++) {
        int p = n.silent[i].player;
        DrawText(TextFormat("player %d: silent %.1f s", p, n.silent[i].silent_ms / 1000.0), x + 20, row + 6, 18, RAYWHITE);
        int open = n.silent[i].countdown_ms == 0;
        const char *label = open ? TextFormat("vote to drop (%d/%d)", n.votes[p], n.votes_needed)
                                 : TextFormat("vote in %.0f s", n.silent[i].countdown_ms / 1000.0);
        if (button((Rectangle){ (float)x + 300, (float)row, 240, 32 }, label, open)) want(&news.want_vote, p);
        row += 40;
    }
    DrawText("network tolerance (silence before a pause); the lowest is in force", x + 20, row + 6, 14, GRAY);
    row += 28;
    for (int p = 0; p < 2; p++) {
        float ms = (p == 0 && *dragging) ? *drag_ms : (float)n.tolerance_ms[p];
        Rectangle track = { (float)x + 150, (float)row + 8, 300, 8 };
        float t = (ms - TOLERANCE_LEAST_MS) / (TOLERANCE_MOST_MS - TOLERANCE_LEAST_MS);
        DrawText(TextFormat("player %d%s", p, p == 0 ? " (you)" : ""), x + 20, row, 18, RAYWHITE);
        DrawRectangleRec(track, (Color){ 70, 70, 70, 255 });
        DrawCircle((int)(track.x + t * track.width), (int)track.y + 4, 9, p == 0 ? (Color){ 230, 200, 120, 255 } : GRAY);
        DrawText(TextFormat("%.2f s%s", ms / 1000, (uint32_t)ms == n.in_force_ms ? "  in force" : ""), x + 465, row, 16, RAYWHITE);
        /* only this player's slider moves; it is sent when let go */
        if (p == 0) {
            Rectangle grab = { track.x - 10, track.y - 12, track.width + 20, 32 };
            if (IsMouseButtonPressed(MOUSE_BUTTON_LEFT) && CheckCollisionPointRec(GetMousePosition(), grab)) *dragging = 1;
            if (*dragging) {
                float f = (GetMousePosition().x - track.x) / track.width;
                f = f < 0 ? 0 : f > 1 ? 1 : f;
                *drag_ms = TOLERANCE_LEAST_MS + f * (TOLERANCE_MOST_MS - TOLERANCE_LEAST_MS);
                if (IsMouseButtonReleased(MOUSE_BUTTON_LEFT)) { *dragging = 0; want(&news.want_tolerance_ms, (int)*drag_ms); }
            }
        }
        row += 30;
    }
}
/* }}} */

/* The disturbance steps each key cycles through. */
static const double delays[] = { 0, 50, 100, 200, 400 };
static const double jitters[] = { 0, 20, 60, 150 };
static const double losses[] = { 0, 0.1, 0.3, 0.6 };

/* {{{ int main(int argc, char **argv) */
int main(int argc, char **argv)
{
    double check_seconds = 0, shot_seconds = 0, d = 0, j = 0, l = 0;
    int shot_paused = 0;
    const char *shot_path = NULL;
    project_dir = getenv("CROSSING_DIR");
    if (!project_dir) { fprintf(stderr, "CROSSING_DIR must name the project (run-crossing.sh sets it)\n"); return 64; }
    if (argc >= 3 && strcmp(argv[1], "--check") == 0) {
        check_seconds = atof(argv[2]);
        if (argc == 6) { d = atof(argv[3]); j = atof(argv[4]); l = atof(argv[5]); }
        else if (argc != 3) { fprintf(stderr, "usage: --check SECONDS [DELAY JITTER LOSS]\n"); return 64; }
    } else if ((argc == 4 || argc == 5) && strcmp(argv[1], "--shot") == 0) {
        shot_seconds = atof(argv[2]);
        shot_path = argv[3];
        if (argc == 5 && strcmp(argv[4], "paused") != 0) { fprintf(stderr, "--shot takes \"paused\" or nothing after the path\n"); return 64; }
        shot_paused = argc == 5;
    } else if (argc != 1) {
        fprintf(stderr, "usage: %s [--check SECONDS [DELAY JITTER LOSS] | --shot SECONDS PATH]\n", argv[0]);
        return 64;
    }

    mb = mailbox_create(sizeof(cross_state), 1);
    if (!mb) { fprintf(stderr, "no memory for the mailbox\n"); return 71; }
    sem_init(&map.ready, 0, 0);
    pthread_t receiver;
    pthread_create(&receiver, NULL, receiver_run, NULL);
    sem_wait(&map.ready);   /* the map comes first: the only wait, and only once */

    int rc = 0;
    if (check_seconds > 0) {
        rc = check(check_seconds, d, j, l);
    } else {
        if (shot_path) SetConfigFlags(FLAG_WINDOW_HIDDEN);
        SetConfigFlags(FLAG_MSAA_4X_HINT);
        InitWindow(1280, 760, "crossing armies, drawn from the server");
        SetTargetFPS(60);
        float cx = map.cols * map.cell_size / 2, cz = map.rows * map.cell_size / 2;
        Camera3D cam = { .position = { cx, 30, cz + 24 }, .target = { cx, 0, cz }, .up = { 0, 1, 0 }, .fovy = 45, .projection = CAMERA_PERSPECTIVE };
        RenderTexture2D target = { 0 };
        if (shot_path) target = LoadRenderTexture(1280, 760);
        int di = 0, ji = 0, li = 0, dragging = 0;
        if (shot_paused) {
            pthread_mutex_lock(&news.lock);
            news.stand_in_silent = 1;
            news.want_silence = 1;
            news.want_tolerance_ms = 500;
            pthread_mutex_unlock(&news.lock);
        }
        float drag_ms = 2000;
        double start = now_us();
        while (!WindowShouldClose()) {
            /* the keys: the connection's troubles, live */
            if (IsKeyPressed(KEY_D)) { di = (di + 1) % 5; want_disturbance(delays[di], jitters[ji], losses[li]); }
            if (IsKeyPressed(KEY_J)) { ji = (ji + 1) % 4; want_disturbance(delays[di], jitters[ji], losses[li]); }
            if (IsKeyPressed(KEY_L)) { li = (li + 1) % 4; want_disturbance(delays[di], jitters[ji], losses[li]); }
            if (IsKeyPressed(KEY_C)) { di = ji = li = 0; want_disturbance(0, 0, 0); }
            if (IsKeyPressed(KEY_S)) {
                pthread_mutex_lock(&news.lock);
                news.stand_in_silent = !news.stand_in_silent;
                news.want_silence = news.stand_in_silent;
                pthread_mutex_unlock(&news.lock);
            }
            int is_new;
            const cross_state *s = mailbox_take(mb, &is_new);   /* the newest state, as late as possible */
            double seconds = (now_us() - start) / 1e6;
            if (shot_path) BeginTextureMode(target); else BeginDrawing();
            ClearBackground((Color){ 18, 22, 26, 255 });
            BeginMode3D(cam);
            draw_world(s, seconds);
            EndMode3D();

            pthread_mutex_lock(&news.lock);
            int paused = news.paused, silent = news.stand_in_silent;
            long states = news.states, messages = news.messages;
            uint32_t in_force = news.in_force_ms;
            pthread_mutex_unlock(&news.lock);
            DrawRectangle(10, 10, 560, 142, (Color){ 0, 0, 0, 150 });
            DrawText(TextFormat("%d units, every one drawn from the server's messages", s->count), 20, 18, 18, RAYWHITE);
            DrawText(TextFormat("tick %u   state %.0f ms old   %ld states, %ld messages   %d fps", s->tick,
                                (now_us() - s->received_us) / 1000, states, messages, GetFPS()), 20, 42, 16, (Color){ 69, 180, 170, 255 });
            DrawText(TextFormat("connection: delay %.0f ms [D]  jitter %.0f ms [J]  loss %.0f%% [L]  clear [C]",
                                delays[di], jitters[ji], losses[li] * 100), 20, 66, 16, (Color){ 222, 170, 66, 255 });
            DrawText(TextFormat("player 1 (a stand-in): %s [S]   tolerance in force: %s", silent ? "SILENT" : "talking",
                                in_force ? TextFormat("%.2f s", in_force / 1000.0) : "2.00 s (starting)"), 20, 90, 16, (Color){ 190, 150, 210, 255 });
            DrawText("red/green ring: player 0's army (you)   blue/purple ring: player 1's   lines: planned paths", 20, 114, 16, GRAY);
            if (paused) draw_waiting(&dragging, &drag_ms);
            if (shot_path) { EndTextureMode(); BeginDrawing(); EndDrawing(); } else EndDrawing();
            if (shot_path && seconds >= shot_seconds) {
                Image img = LoadImageFromTexture(target.texture);
                ImageFlipVertical(&img);   /* textures are stored bottom row first */
                int saved = ExportImage(img, shot_path);
                UnloadImage(img);
                if (!saved) { fprintf(stderr, "the picture could not be saved to %s\n", shot_path); rc = 1; }
                break;
            }
        }
        if (shot_path) UnloadRenderTexture(target);
        CloseWindow();
    }
    atomic_store(&stopping, 1);
    pthread_join(receiver, NULL);
    mailbox_destroy(mb);
    return rc;
}
/* }}} */
