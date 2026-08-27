/*
 * 073-rules.c -- LuaJIT, sandboxed, with a narrow window on the world.
 *
 * Interface and reasoning are in 073-rules.h.
 *
 * The shape: one Lua state; a `vtt` table of C functions that is the entire
 * surface a ruleset can reach; hooks resolved once at load into registry
 * references rather than looked up by name at call time; and a request queue
 * drained after each hook so a ruleset never mutates the world underneath a pass
 * that is iterating it.
 */

#include "073-rules.h"
#include "073-embedded-copier.h"
#include "070-scope.h"
#include "031-region.h"

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>

/*
 * The names a ruleset must not have.
 *
 * Every one of these is a way to make a replay diverge silently, or to reach off
 * the machine. A ruleset that calls the clock, or reads ambient randomness, or
 * writes a file, destroys the reproducibility everything else in this project was
 * built to protect -- and destroys it QUIETLY, so the divergence appears an hour
 * in with nothing to point at.
 */
static const char *const forbidden_global[] = {
    "io", "os", "dofile", "loadfile", "load", "loadstring", "require",
    "package", "debug", NULL
};

static const char *const forbidden_math[] = {
    "random", "randomseed", NULL
};

static const char *const hook_names[HOOK_COUNT] = {
    "on_load", "on_command", "on_action", "on_tick",
    "on_region_enter", "on_interact", "may_know", "describe"
};

/* {{{ static struct ruleset *self */
static struct ruleset *self(lua_State *L)
{
    struct ruleset *r;

    /*
     * The ruleset is kept in the registry rather than in an upvalue, so that
     * every C function can find it the same way and none of them has to be
     * closed over anything.
     */
    lua_pushlightuserdata(L, (void *)&hook_names);
    lua_rawget(L, LUA_REGISTRYINDEX);
    r = lua_touserdata(L, -1);
    lua_pop(L, 1);

    return r;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * The window on the world
 *
 * Read-only, by index, bounds-checked at the boundary. A bad index returns nil,
 * which is the one place in this project where nil is the right answer -- a
 * ruleset author is not the validator's problem, and a Lua error at the point of
 * the mistake is more useful than a silent empty record.
 * ------------------------------------------------------------------------- */

/* {{{ static int lua_thing_count */
static int lua_thing_count(lua_State *L)
{
    lua_pushinteger(L, (lua_Integer)world_thing_count(self(L)->world));
    return 1;
}
/* }}} */

/* {{{ static int lua_thing */
static int lua_thing(lua_State *L)
{
    struct ruleset *r = self(L);
    uint32_t index = (uint32_t)luaL_checkinteger(L, 1);
    const struct thing *t;

    if (index == 0 || index >= world_thing_count(r->world)) {
        lua_pushnil(L);
        return 1;
    }

    t = world_thing_const(r->world, index);

    /*
     * A COPY, not a handle. A ruleset holding a reference into the world could
     * write through it, and then there would be two ways for a body to end up
     * somewhere -- which would disagree about walls within a week.
     */
    lua_newtable(L);

    lua_pushinteger(L, (lua_Integer)index);      lua_setfield(L, -2, "index");
    lua_pushnumber(L, (double)t->x / WC_ONE);    lua_setfield(L, -2, "x");
    lua_pushnumber(L, (double)t->y / WC_ONE);    lua_setfield(L, -2, "y");
    lua_pushinteger(L, (lua_Integer)t->facing);  lua_setfield(L, -2, "facing");
    lua_pushinteger(L, (lua_Integer)t->kind);    lua_setfield(L, -2, "kind");
    lua_pushinteger(L, (lua_Integer)t->region);  lua_setfield(L, -2, "region");
    lua_pushboolean(L, thing_can_see(t));        lua_setfield(L, -2, "sees");

    /*
     * NOT the sheet index, and not the scope. A ruleset reaches its own sheet
     * through vtt.sheet(), and who commands a body is a permission question that
     * rules do not get to ask.
     */

    return 1;
}
/* }}} */

/* {{{ static int lua_distance */
static int lua_distance(lua_State *L)
{
    struct ruleset *r = self(L);
    uint32_t a = (uint32_t)luaL_checkinteger(L, 1);
    uint32_t b = (uint32_t)luaL_checkinteger(L, 2);
    const struct thing *ta;
    const struct thing *tb;

    if (a == 0 || a >= world_thing_count(r->world) ||
        b == 0 || b >= world_thing_count(r->world)) {
        lua_pushnil(L);
        return 1;
    }

    ta = world_thing_const(r->world, a);
    tb = world_thing_const(r->world, b);

    /*
     * In metres, as a number, because a ruleset thinks in whatever units its
     * game uses and converting from thousandths at every call site is how a
     * ruleset ends up with a factor of a thousand in one branch.
     */
    lua_pushnumber(L, (double)fx_dist(ta->x, ta->y, tb->x, tb->y) / WC_ONE);
    return 1;
}
/* }}} */

/* {{{ static int lua_region_of */
static int lua_region_of(lua_State *L)
{
    struct ruleset *r = self(L);
    uint32_t index = (uint32_t)luaL_checkinteger(L, 1);

    if (index == 0 || index >= world_thing_count(r->world)) {
        lua_pushnil(L);
        return 1;
    }

    lua_pushinteger(L, (lua_Integer)world_thing_const(r->world, index)->region);
    return 1;
}
/* }}} */

/* {{{ static int lua_region_name */
static int lua_region_name(lua_State *L)
{
    struct ruleset *r = self(L);
    uint32_t index = (uint32_t)luaL_checkinteger(L, 1);
    uint32_t length = 0;
    const char *text;

    if (index == 0 || index >= world_region_count(r->world)) {
        lua_pushnil(L);
        return 1;
    }

    text = string_pool_read(&r->world->strings,
                            world_region_const(r->world, index)->name_offset,
                            &length);

    lua_pushlstring(L, text, (size_t)length);
    return 1;
}
/* }}} */

/* {{{ static int lua_tick */
static int lua_tick(lua_State *L)
{
    /*
     * The tick number, and no access to the time of day. A ruleset that could
     * read the clock would make a replay diverge without anybody being able to
     * see why.
     */
    lua_pushnumber(L, (double)self(L)->sim->tick);
    return 1;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * Sheets
 * ------------------------------------------------------------------------- */

/* ------------------------------------------------------------------------- *
 * Copying a sheet without reading it
 *
 * A rollback restores the world by copying flat bytes. A sheet is a Lua table,
 * so it needs a different kind of copy -- and for four phases it simply did not
 * get one, which was the largest known hole in the project.
 *
 * THE COPIER IS LUA, NOT C, and that is the point. It lives in the registry
 * where a ruleset cannot reach it, and C only ever says "copy" and "put back".
 * So the rule that the server never reads a sheet stays literally true: nothing
 * in C ever looks inside one.
 *
 * IT REFUSES WHAT IT CANNOT COPY, by name and by path. The generic-serialisation
 * option was rejected in issue 703 for "breaking quietly on a closure" -- and
 * that is a property of one implementation of it, not of the idea. A copier can
 * know perfectly well what it cannot copy. The whole difference between a good
 * answer and a bad one is whether it says so.
 * ------------------------------------------------------------------------- */

/* {{{ static int install_the_copier */
static int install_the_copier(lua_State *L, char *trouble, size_t capacity)
{
    if (luaL_loadstring(L, embedded_sheet_copier) != 0) {
        snprintf(trouble, capacity, "the sheet copier would not compile: %s",
                 lua_tostring(L, -1));
        return 0;
    }

    if (lua_pcall(L, 0, 2, 0) != 0) {
        snprintf(trouble, capacity, "the sheet copier would not run: %s",
                 lua_tostring(L, -1));
        return 0;
    }

    /* Two values back: the guard metatable, and the copy function. Both into the
     * registry, which the sandbox cannot see. */
    lua_setfield(L, LUA_REGISTRYINDEX, "vtt_sheet_copy");
    lua_setfield(L, LUA_REGISTRYINDEX, "vtt_sheet_guard");

    return 1;
}
/* }}} */

/* {{{ static int lua_sheet */
static int lua_sheet(lua_State *L)
{
    uint32_t index = (uint32_t)luaL_checkinteger(L, 1);

    /*
     * The ruleset's own storage for a thing, in whatever shape it likes. The
     * server allocates the index and never reads what is behind it -- a server
     * that knew what a hit point was would not be system-agnostic.
     */
    lua_getfield(L, LUA_REGISTRYINDEX, "vtt_sheets");

    lua_pushinteger(L, (lua_Integer)index);
    lua_rawget(L, -2);

    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        lua_newtable(L);

        /* The guard, so storing a function in a sheet fails at the line that
         * did it rather than at the next rollback. */
        lua_getfield(L, LUA_REGISTRYINDEX, "vtt_sheet_guard");
        lua_setmetatable(L, -2);

        lua_pushinteger(L, (lua_Integer)index);
        lua_pushvalue(L, -2);
        lua_rawset(L, -4);
    }

    return 1;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * Requests
 * ------------------------------------------------------------------------- */

/* {{{ static int queue_request */
static int queue_request(lua_State *L, uint8_t kind,
                         uint32_t thing, int32_t ax, int32_t ay)
{
    struct ruleset *r = self(L);

    if (r->request_count >= RULES_MAX_REQUESTS) {
        /*
         * Refused rather than grown. A ruleset that wants to move a thousand
         * things in one hook has a bug, and letting it would mean a beat that
         * takes an unbounded amount of time.
         */
        lua_pushboolean(L, 0);
        return 1;
    }

    r->requests[r->request_count].kind = kind;
    r->requests[r->request_count].thing = thing;
    r->requests[r->request_count].ax = ax;
    r->requests[r->request_count].ay = ay;
    r->request_count++;

    lua_pushboolean(L, 1);
    return 1;
}
/* }}} */

/* {{{ static int lua_move */
static int lua_move(lua_State *L)
{
    uint32_t thing = (uint32_t)luaL_checkinteger(L, 1);
    double x = luaL_checknumber(L, 2);
    double y = luaL_checknumber(L, 3);

    /*
     * A REQUEST, checked the same way a participant's is. A ruleset does not get
     * to place things through walls, and does not get a second movement path --
     * two ways for a body to end up somewhere would disagree about walls within
     * a week.
     */
    return queue_request(L, REQUEST_MOVE, thing,
                         (int32_t)(x * WC_ONE), (int32_t)(y * WC_ONE));
}
/* }}} */

/* {{{ static int lua_set_hidden */
static int lua_set_hidden(lua_State *L)
{
    uint32_t thing = (uint32_t)luaL_checkinteger(L, 1);
    int hidden = lua_toboolean(L, 2);

    return queue_request(L, REQUEST_SET_HIDDEN, thing, hidden, 0);
}
/* }}} */

/* {{{ static int lua_set_kind */
static int lua_set_kind(lua_State *L)
{
    uint32_t thing = (uint32_t)luaL_checkinteger(L, 1);
    int32_t kind = (int32_t)luaL_checkinteger(L, 2);

    return queue_request(L, REQUEST_SET_KIND, thing, kind, 0);
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * Dice
 * ------------------------------------------------------------------------- */

/* {{{ static int lua_stream_between */
static int lua_stream_between(lua_State *L)
{
    struct ruleset *r = self(L);
    uint32_t stream;
    int64_t low;
    int64_t high;

    lua_getfield(L, 1, "index");
    stream = (uint32_t)lua_tointeger(L, -1);
    lua_pop(L, 1);

    low = (int64_t)luaL_checkinteger(L, 2);
    high = (int64_t)luaL_checkinteger(L, 3);

    lua_pushinteger(L, (lua_Integer)stream_between(&r->sim->streams, stream, low, high));
    return 1;
}
/* }}} */

/* {{{ static int lua_stream_below */
static int lua_stream_below(lua_State *L)
{
    struct ruleset *r = self(L);
    uint32_t stream;
    uint64_t bound;

    lua_getfield(L, 1, "index");
    stream = (uint32_t)lua_tointeger(L, -1);
    lua_pop(L, 1);

    bound = (uint64_t)luaL_checkinteger(L, 2);

    lua_pushinteger(L, (lua_Integer)stream_below(&r->sim->streams, stream, bound));
    return 1;
}
/* }}} */

/* {{{ static int lua_stream */
static int lua_stream(lua_State *L)
{
    struct ruleset *r = self(L);
    const char *name = luaL_checkstring(L, 1);
    uint32_t index = stream_named(&r->sim->streams, name);

    /*
     * A stream nobody could name is refused rather than silently shared. Two
     * names differing only past a cut would become one stream, and the two
     * things drawing from them would start interfering with nothing reporting it.
     */
    if (index >= STREAMS_MAX) {
        return luaL_error(L, "no room for a stream called '%s', "
                             "or the name is too long", name);
    }

    lua_newtable(L);

    lua_pushinteger(L, (lua_Integer)index);
    lua_setfield(L, -2, "index");

    lua_pushcfunction(L, lua_stream_between);
    lua_setfield(L, -2, "between");

    lua_pushcfunction(L, lua_stream_below);
    lua_setfield(L, -2, "below");

    return 1;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * Loading
 * ------------------------------------------------------------------------- */

/* {{{ static void install_window */
static void install_window(lua_State *L)
{
    lua_newtable(L);

    lua_pushcfunction(L, lua_thing);        lua_setfield(L, -2, "thing");
    lua_pushcfunction(L, lua_thing_count);  lua_setfield(L, -2, "thing_count");
    lua_pushcfunction(L, lua_distance);     lua_setfield(L, -2, "distance");
    lua_pushcfunction(L, lua_region_of);    lua_setfield(L, -2, "region_of");
    lua_pushcfunction(L, lua_region_name);  lua_setfield(L, -2, "region_name");
    lua_pushcfunction(L, lua_tick);         lua_setfield(L, -2, "tick");
    lua_pushcfunction(L, lua_sheet);        lua_setfield(L, -2, "sheet");
    lua_pushcfunction(L, lua_move);         lua_setfield(L, -2, "move");
    lua_pushcfunction(L, lua_set_hidden);   lua_setfield(L, -2, "set_hidden");
    lua_pushcfunction(L, lua_set_kind);     lua_setfield(L, -2, "set_kind");
    lua_pushcfunction(L, lua_stream);       lua_setfield(L, -2, "stream");

    lua_setglobal(L, "vtt");
}
/* }}} */

/* {{{ static void close_the_doors */
static void close_the_doors(lua_State *L)
{
    uint32_t i;

    /*
     * Removed by name, after the libraries are opened. Removing rather than
     * never opening, because LuaJIT's own startup wants some of them -- and a
     * name that is nil is a name a ruleset fails on at the point of use, which
     * is where a person can see it.
     */
    for (i = 0; forbidden_global[i] != NULL; i++) {
        lua_pushnil(L);
        lua_setglobal(L, forbidden_global[i]);
    }

    lua_getglobal(L, "math");
    if (lua_istable(L, -1)) {
        for (i = 0; forbidden_math[i] != NULL; i++) {
            lua_pushnil(L);
            lua_setfield(L, -2, forbidden_math[i]);
        }
    }
    lua_pop(L, 1);
}
/* }}} */

/* {{{ static int compare_names */
static int compare_names(const void *a, const void *b)
{
    return strcmp(*(const char **)a, *(const char **)b);
}
/* }}} */

/* {{{ int rules_load */
int rules_load(struct ruleset *r, struct world *w, struct sim *sim,
               const char *directory, const char **why)
{
    static char trouble[512];
    lua_State *L;
    DIR *dir;
    struct dirent *entry;
    char *names[64];
    uint32_t name_count = 0;
    uint32_t i;

    memset(r, 0, sizeof(struct ruleset));
    r->world = w;
    r->sim = sim;

    for (i = 0; i < HOOK_COUNT; i++) {
        r->hook[i] = LUA_NOREF;
    }

    L = luaL_newstate();
    if (L == NULL) {
        *why = "could not start Lua";
        return 0;
    }

    r->state = L;

    luaL_openlibs(L);
    close_the_doors(L);

    /* So every C function can find the ruleset without being closed over it. */
    lua_pushlightuserdata(L, (void *)&hook_names);
    lua_pushlightuserdata(L, r);
    lua_rawset(L, LUA_REGISTRYINDEX);

    lua_newtable(L);
    lua_setfield(L, LUA_REGISTRYINDEX, "vtt_sheets");

    lua_newtable(L);
    lua_setfield(L, LUA_REGISTRYINDEX, "vtt_sheet_snapshots");

    if (!install_the_copier(L, trouble, sizeof(trouble))) {
        snprintf(r->last_error, sizeof(r->last_error), "%.240s", trouble);
        lua_close(L);
        r->state = NULL;
        return 0;
    }

    install_window(L);

    dir = opendir(directory);
    if (dir == NULL) {
        snprintf(trouble, sizeof(trouble),
                 "there is no ruleset directory at %s", directory);
        *why = trouble;
        return 0;
    }

    while ((entry = readdir(dir)) != NULL) {
        size_t length = strlen(entry->d_name);

        if (length < 5 || strcmp(entry->d_name + length - 4, ".lua") != 0) {
            continue;
        }

        if (name_count < 64) {
            names[name_count] = malloc(length + 1);
            memcpy(names[name_count], entry->d_name, length + 1);
            name_count++;
        }
    }

    closedir(dir);

    /*
     * Numeric order, the same discipline as the source: reading a ruleset from
     * its lowest number is the story of what it is.
     */
    qsort(names, name_count, sizeof(char *), compare_names);

    for (i = 0; i < name_count; i++) {
        char path[1024];

        snprintf(path, sizeof(path), "%s/%s", directory, names[i]);

        if (luaL_loadfile(L, path) != 0 || lua_pcall(L, 0, 0, 0) != 0) {
            /*
             * Named, with the line, and the server REFUSES TO START. A server
             * running with half a ruleset is worse than one that would not
             * start, because the half that loaded will look like the whole.
             */
            snprintf(trouble, sizeof(trouble), "%s", lua_tostring(L, -1));
            *why = trouble;

            for (; i < name_count; i++) {
                free(names[i]);
            }
            return 0;
        }

        free(names[i]);
        r->loaded_files++;
    }

    /*
     * Hooks resolved ONCE, into registry references. Looking them up by name per
     * body per beat would be a string hash somebody chose to pay for.
     */
    for (i = 0; i < HOOK_COUNT; i++) {
        lua_getglobal(L, hook_names[i]);

        if (lua_isfunction(L, -1)) {
            r->hook[i] = luaL_ref(L, LUA_REGISTRYINDEX);
            r->present[i] = 1;
        } else {
            lua_pop(L, 1);
        }
    }

    if (r->present[HOOK_ON_LOAD]) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, r->hook[HOOK_ON_LOAD]);

        if (lua_pcall(L, 0, 0, 0) != 0) {
            snprintf(trouble, sizeof(trouble),
                     "on_load failed: %s", lua_tostring(L, -1));
            *why = trouble;
            return 0;
        }
    }

    return 1;
}
/* }}} */

/* {{{ void rules_release */
void rules_release(struct ruleset *r)
{
    if (r->state != NULL) {
        lua_close((lua_State *)r->state);
        r->state = NULL;
    }
}
/* }}} */

/* {{{ int rules_has */
int rules_has(const struct ruleset *r, int hook)
{
    if (hook < 0 || hook >= HOOK_COUNT) {
        return 0;
    }

    return r->present[hook] && !r->abandoned[hook];
}
/* }}} */

/* {{{ static void note_failure */
static void note_failure(struct ruleset *r, int hook)
{
    lua_State *L = r->state;

    snprintf(r->last_error, sizeof(r->last_error), "%s", lua_tostring(L, -1));
    lua_pop(L, 1);

    /*
     * The half-applied requests are DISCARDED, not partly honoured. A queue
     * drained after the hook returns makes that free, which is one of the
     * reasons it is a queue.
     */
    r->request_count = 0;

    r->failures[hook]++;

    if (r->failures[hook] >= HOOK_FAILURE_LIMIT) {
        r->abandoned[hook] = 1;
    }
}
/* }}} */

/* {{{ static void drain_requests */
static void drain_requests(struct ruleset *r)
{
    uint32_t i;

    for (i = 0; i < r->request_count; i++) {
        const struct rule_request *q = &r->requests[i];
        struct thing *t;

        if (q->thing == 0 || q->thing >= world_thing_count(r->world)) {
            continue;   /* A bad index is refused, never clamped. */
        }

        t = world_thing(r->world, q->thing);

        switch (q->kind) {
        case REQUEST_MOVE:
            /*
             * Through the ordinary order machinery, so the motion pass resolves
             * it against walls exactly as it would a player's. A ruleset does not
             * get to place things through stone.
             */
            sim_order_move(r->sim, q->thing, (wcoord)q->ax, (wcoord)q->ay,
                           WC_ONE / 2);
            break;

        case REQUEST_SET_HIDDEN:
            if (q->ax) {
                t->flags |= THING_HIDDEN;
            } else {
                t->flags &= (uint16_t)~THING_HIDDEN;
            }
            break;

        case REQUEST_SET_KIND:
            t->kind = (uint32_t)q->ax;
            break;

        default:
            break;
        }
    }

    r->request_count = 0;
}
/* }}} */

/* {{{ uint16_t rules_on_command */
uint16_t rules_on_command(struct ruleset *r, uint32_t viewer,
                          const struct log_entry *entry)
{
    lua_State *L = r->state;

    r->last_refusal[0] = '\0';

    if (!rules_has(r, HOOK_ON_COMMAND)) {
        return REFUSED_NOT_AT_ALL;
    }

    lua_rawgeti(L, LUA_REGISTRYINDEX, r->hook[HOOK_ON_COMMAND]);

    lua_pushinteger(L, (lua_Integer)viewer);
    lua_pushstring(L, verb_name(entry->verb));
    lua_pushinteger(L, (lua_Integer)entry->subject);
    lua_pushnumber(L, (double)entry->ax / WC_ONE);
    lua_pushnumber(L, (double)entry->ay / WC_ONE);

    if (lua_pcall(L, 5, 2, 0) != 0) {
        /*
         * AN ERROR IS NOT A REFUSAL. The ruleset has failed rather than declined,
         * and those look different because "you may not" and "the rules are
         * broken" send a person to look at different things.
         */
        note_failure(r, HOOK_ON_COMMAND);
        snprintf(r->last_refusal, sizeof(r->last_refusal),
                 /* Bounded explicitly, so the truncation is chosen rather than warned about. */
                 "the ruleset failed while deciding: %.180s", r->last_error);
        return REFUSED_BY_THE_RULES;
    }

    {
        int permitted = lua_toboolean(L, -2);
        const char *sentence = lua_tostring(L, -1);

        if (sentence != NULL) {
            snprintf(r->last_refusal, sizeof(r->last_refusal), "%s", sentence);
        }

        lua_pop(L, 2);

        if (permitted) {
            drain_requests(r);
            return REFUSED_NOT_AT_ALL;
        }
    }

    /* A refusal makes no changes, whatever it asked for on the way past. */
    r->request_count = 0;

    if (r->last_refusal[0] == '\0') {
        snprintf(r->last_refusal, sizeof(r->last_refusal),
                 "the rules do not allow that, and did not say why -- which is "
                 "a bug in the ruleset");
    }

    return REFUSED_BY_THE_RULES;
}
/* }}} */

/* {{{ void rules_on_tick */
void rules_on_tick(struct ruleset *r)
{
    lua_State *L = r->state;

    if (!rules_has(r, HOOK_ON_TICK)) {
        return;
    }

    lua_rawgeti(L, LUA_REGISTRYINDEX, r->hook[HOOK_ON_TICK]);
    lua_pushnumber(L, (double)r->sim->tick);

    if (lua_pcall(L, 1, 0, 0) != 0) {
        note_failure(r, HOOK_ON_TICK);
        return;
    }

    drain_requests(r);
}
/* }}} */

/* {{{ void rules_on_region_enter */
void rules_on_region_enter(struct ruleset *r, uint32_t thing,
                           uint32_t left, uint32_t entered)
{
    lua_State *L = r->state;

    if (!rules_has(r, HOOK_ON_REGION_ENTER)) {
        return;
    }

    lua_rawgeti(L, LUA_REGISTRYINDEX, r->hook[HOOK_ON_REGION_ENTER]);
    lua_pushinteger(L, (lua_Integer)thing);
    lua_pushinteger(L, (lua_Integer)left);
    lua_pushinteger(L, (lua_Integer)entered);

    if (lua_pcall(L, 3, 0, 0) != 0) {
        note_failure(r, HOOK_ON_REGION_ENTER);
        return;
    }

    drain_requests(r);
}
/* }}} */

/* {{{ void rules_may_know */
void rules_may_know(struct ruleset *r, uint32_t viewer, uint32_t thing,
                    char *into, uint32_t capacity)
{
    lua_State *L = r->state;

    into[0] = '\0';

    /*
     * NO HOOK MEANS NOTHING. Adding a rules layer must not widen what is sent by
     * default -- a system that becomes more revealing because somebody loaded a
     * ruleset that does not mention the subject has the default backwards.
     */
    if (!rules_has(r, HOOK_MAY_KNOW)) {
        return;
    }

    lua_rawgeti(L, LUA_REGISTRYINDEX, r->hook[HOOK_MAY_KNOW]);
    lua_pushinteger(L, (lua_Integer)viewer);
    lua_pushinteger(L, (lua_Integer)thing);

    if (lua_pcall(L, 2, 1, 0) != 0) {
        note_failure(r, HOOK_MAY_KNOW);
        return;
    }

    if (lua_isstring(L, -1)) {
        snprintf(into, (size_t)capacity, "%s", lua_tostring(L, -1));
    }

    lua_pop(L, 1);

    /* may_know never changes anything, so anything it asked for is discarded. */
    r->request_count = 0;
}
/* }}} */

/* {{{ void rules_describe */
void rules_describe(struct ruleset *r, uint32_t kind, char *into, uint32_t capacity)
{
    lua_State *L = r->state;

    into[0] = '\0';

    if (!rules_has(r, HOOK_DESCRIBE)) {
        return;
    }

    lua_rawgeti(L, LUA_REGISTRYINDEX, r->hook[HOOK_DESCRIBE]);
    lua_pushinteger(L, (lua_Integer)kind);

    if (lua_pcall(L, 1, 1, 0) != 0) {
        note_failure(r, HOOK_DESCRIBE);
        return;
    }

    if (lua_isstring(L, -1)) {
        snprintf(into, (size_t)capacity, "%s", lua_tostring(L, -1));
    }

    lua_pop(L, 1);
    r->request_count = 0;
}
/* }}} */

/* {{{ int rules_on_interact */
int rules_on_interact(struct ruleset *r, uint32_t viewer, uint32_t actor,
                      uint32_t subject, uint32_t intent)
{
    lua_State *L = r->state;

    r->last_refusal[0] = '\0';

    if (!rules_has(r, HOOK_ON_INTERACT)) {
        /*
         * No hook means no rules about acting on things, which means you cannot.
         * Refused rather than allowed: the server does not know what an intent
         * means, and allowing something it cannot describe would be the server
         * having an opinion by the back door.
         */
        snprintf(r->last_refusal, sizeof(r->last_refusal),
                 "this ruleset has no rules about acting on things you do not"
                 " command");
        return 0;
    }

    lua_rawgeti(L, LUA_REGISTRYINDEX, r->hook[HOOK_ON_INTERACT]);
    lua_pushinteger(L, (lua_Integer)viewer);
    lua_pushinteger(L, (lua_Integer)actor);
    lua_pushinteger(L, (lua_Integer)subject);
    lua_pushinteger(L, (lua_Integer)intent);

    if (lua_pcall(L, 4, 2, 0) != 0) {
        note_failure(r, HOOK_ON_INTERACT);
        snprintf(r->last_refusal, sizeof(r->last_refusal),
                 "the ruleset failed while deciding: %.180s", r->last_error);
        return 0;
    }

    {
        int allowed = lua_toboolean(L, -2);

        if (lua_isstring(L, -1)) {
            snprintf(r->last_refusal, sizeof(r->last_refusal),
                     "%s", lua_tostring(L, -1));
        } else if (!allowed) {
            snprintf(r->last_refusal, sizeof(r->last_refusal),
                     "the ruleset declined, without saying why");
        }

        lua_settop(L, lua_gettop(L) - 2);

        /*
         * Whatever it asked for is drained here, the same as every other hook --
         * a hook does not touch the world, it queues, so a hook that failed
         * part-way has its queue cleared and nothing it asked for happens.
         */
        drain_requests(r);

        return allowed;
    }
}
/* }}} */

/* {{{ uint16_t rules_on_action */
uint16_t rules_on_action(struct ruleset *r, uint32_t viewer,
                         const struct log_entry *entry)
{
    lua_State *L = r->state;

    r->last_refusal[0] = '\0';

    /*
     * The one door every game-specific verb comes through. Casting, attacking,
     * searching -- all of it, here, with a scope attached and the server never
     * growing a case for any of them.
     */
    if (!rules_has(r, HOOK_ON_ACTION)) {
        snprintf(r->last_refusal, sizeof(r->last_refusal),
                 "this ruleset has no actions");
        return REFUSED_BY_THE_RULES;
    }

    lua_rawgeti(L, LUA_REGISTRYINDEX, r->hook[HOOK_ON_ACTION]);
    lua_pushinteger(L, (lua_Integer)viewer);
    lua_pushinteger(L, (lua_Integer)entry->subject);
    lua_pushnumber(L, (double)entry->ax);
    lua_pushnumber(L, (double)entry->ay);

    if (lua_pcall(L, 4, 2, 0) != 0) {
        note_failure(r, HOOK_ON_ACTION);
        snprintf(r->last_refusal, sizeof(r->last_refusal),
                 "the ruleset failed while acting: %.180s", r->last_error);
        return REFUSED_BY_THE_RULES;
    }

    {
        int worked = lua_toboolean(L, -2);
        const char *sentence = lua_tostring(L, -1);

        if (sentence != NULL) {
            snprintf(r->last_refusal, sizeof(r->last_refusal), "%s", sentence);
        }

        lua_pop(L, 2);

        if (worked) {
            drain_requests(r);
            return REFUSED_NOT_AT_ALL;
        }
    }

    r->request_count = 0;
    return REFUSED_BY_THE_RULES;
}
/* }}} */

/* {{{ uint32_t rules_requests_made */
uint32_t rules_requests_made(const struct ruleset *r)
{
    return r->request_count;
}
/* }}} */

/* {{{ int rules_sheets_survive_rollback */
int rules_sheets_survive_rollback(const struct ruleset *r)
{
    (void)r;

    /*
     * YES, SINCE THE FOURTH OPTION.
     *
     * For four phases this returned 0 and the phase 7 demo showed the hole
     * happening, because a rollback that looks like it worked is worse than one
     * that plainly did not. Three ways out had been written down and all three
     * rejected -- and the second of them, "serialise the table generically", was
     * rejected for breaking QUIETLY on a closure.
     *
     * That is a property of one implementation of it, not of the idea. A copier
     * can know perfectly well what it cannot copy. So this one refuses, by name
     * and by path, and a turn whose sheets could not be copied is marked
     * not-rollbackable rather than half-restored.
     *
     * See rules_snapshot_sheets below, and issue 703, which was reopened to
     * close this rather than a new issue being written beside it.
     */
    return 1;
}
/* }}} */

/* {{{ int rules_snapshot_sheets */
int rules_snapshot_sheets(struct ruleset *r, uint32_t turn, const char **why)
{
    lua_State *L = r->state;
    int base;

    *why = "";

    if (L == NULL) {
        return 1;    /* No ruleset means no sheets, which copies perfectly. */
    }

    base = lua_gettop(L);

    lua_getfield(L, LUA_REGISTRYINDEX, "vtt_sheet_copy");
    lua_getfield(L, LUA_REGISTRYINDEX, "vtt_sheets");
    lua_pushstring(L, "sheet");
    lua_newtable(L);                       /* the "seen" set, for cycles */

    if (lua_pcall(L, 3, 2, 0) != 0) {
        snprintf(r->last_error, sizeof(r->last_error),
                 "the sheets could not be copied: %s", lua_tostring(L, -1));
        *why = r->last_error;
        lua_settop(L, base);
        return 0;
    }

    /* Two returns: the copy, or nil and a sentence saying where it stopped. */
    if (lua_isnil(L, -2)) {
        snprintf(r->last_error, sizeof(r->last_error),
                 "the sheets could not be copied: %s",
                 lua_isstring(L, -1) ? lua_tostring(L, -1) : "no reason given");
        *why = r->last_error;
        lua_settop(L, base);
        return 0;
    }

    lua_pop(L, 1);                         /* drop the empty reason */

    lua_getfield(L, LUA_REGISTRYINDEX, "vtt_sheet_snapshots");
    lua_pushinteger(L, (lua_Integer)turn);
    lua_pushvalue(L, -3);
    lua_rawset(L, -3);

    lua_settop(L, base);
    return 1;
}
/* }}} */

/* {{{ int rules_restore_sheets */
int rules_restore_sheets(struct ruleset *r, uint32_t turn, const char **why)
{
    lua_State *L = r->state;
    int base;

    *why = "";

    if (L == NULL) {
        return 1;
    }

    base = lua_gettop(L);

    lua_getfield(L, LUA_REGISTRYINDEX, "vtt_sheet_snapshots");
    lua_pushinteger(L, (lua_Integer)turn);
    lua_rawget(L, -2);

    if (lua_isnil(L, -1)) {
        snprintf(r->last_error, sizeof(r->last_error),
                 "there is no sheet snapshot for turn %u", (unsigned)turn);
        *why = r->last_error;
        lua_settop(L, base);
        return 0;
    }

    /*
     * Copied BACK rather than swapped in. The snapshot stays where it is, so a
     * turn can be rolled back to twice -- which the replay path does when a
     * retcon is followed by another one.
     */
    lua_getfield(L, LUA_REGISTRYINDEX, "vtt_sheet_copy");
    lua_pushvalue(L, -2);
    lua_pushstring(L, "sheet");
    lua_newtable(L);

    if (lua_pcall(L, 3, 2, 0) != 0 || lua_isnil(L, -2)) {
        snprintf(r->last_error, sizeof(r->last_error),
                 "the sheet snapshot could not be copied back");
        *why = r->last_error;
        lua_settop(L, base);
        return 0;
    }

    lua_pop(L, 1);
    lua_setfield(L, LUA_REGISTRYINDEX, "vtt_sheets");

    lua_settop(L, base);
    return 1;
}
/* }}} */

/* {{{ void rules_forget_sheet_snapshot */
void rules_forget_sheet_snapshot(struct ruleset *r, uint32_t turn)
{
    lua_State *L = r->state;

    if (L == NULL) {
        return;
    }

    /*
     * A slot in the ring is being reused, so the sheets it held are unreachable
     * and should stop being kept alive. Without this the snapshots table grows
     * for the length of the session, holding every turn ever played -- which is
     * a leak that only appears on a long evening.
     */
    lua_getfield(L, LUA_REGISTRYINDEX, "vtt_sheet_snapshots");
    lua_pushinteger(L, (lua_Integer)turn);
    lua_pushnil(L);
    lua_rawset(L, -3);
    lua_pop(L, 1);
}
/* }}} */
