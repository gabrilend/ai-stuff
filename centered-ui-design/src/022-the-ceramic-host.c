/*
 * 022-the-ceramic-host.c - the few calls the render thread makes into the ceramic engine.
 *
 * In plain terms: LÖVE's main thread is the render thread. It never does
 * the world's work; it only hands work in and looks at how much has
 * landed. These calls are all it needs: start the engine; tell it where the
 * world's blocks are; hand in a stage (all of a step's unit chunks, or all
 * its cuboid chunks) as one batch; count how many chunks of a stage have
 * landed; stop.
 *
 * Nothing here waits. Handing in returns at once; counting returns at once.
 * The render thread asks again next frame.
 *
 * Built by scripts/build-ceramics: serac's emitted construction code for
 * 021-ceramics.map (with the boxes, 020) up to its own main, then this file
 * in place of that main, all compiled against libs/ceramic as one shared
 * library that LuaJIT loads (src/023-the-ceramic-host.lua).
 */
#include <stdlib.h>

/* the boxes' world (020) */
extern unit_record *ceramics_units_front;
extern unit_record *ceramics_units_back;
extern cuboid_record *ceramics_cubes_front;
extern cuboid_record *ceramics_cubes_back;
extern int ceramics_unit_count;
extern int ceramics_cube_count;
extern double ceramics_step_seconds;
extern uint32_t ceramics_seed;
extern double fold_strength, fold_tiers, fold_hub, fold_edge, figure_scale;
extern double fold_size_keep;
extern int section_count;
extern double section_r[], section_angle[], section_radius[];

/* How many records a chunk task covers. The engine's own measurements
 * (world-edit-to-execute 515a) found per-frame work must go in as chunks of
 * 8 to 64 units: one task per unit costs half a frame. */
#define CHUNK 32

/* {{{ the host's own state */
static cera_map_t *map;
static const char *last_error = "not started";
static int door_station[2], door_port[2];      /* argument 0 units, 1 cuboids */
static int result_station[2], result_port[2];  /* result 0 units, 1 cuboids */
static chunk_req *requests[2];
static chunk_done *landing[2];
static int chunks[2];
/* }}} */

/* {{{ const char *ceramics_error(void) */
/* Why the last call refused, in a sentence (or "none"). */
const char *ceramics_error(void)
{
    return last_error ? last_error : "none";
}
/* }}} */

/* {{{ static int refused(const char *why) */
/* Records a refusal; every refusal is reported to Lua, which stops the
 * game naming it (no fallbacks). */
static int refused(const char *why)
{
    last_error = why;
    return -1;
}
/* }}} */

/* {{{ void ceramics_set_fold(...) */
void ceramics_set_fold(double strength, double tiers, double hub, double edge, double figure)
{
    fold_strength = strength;
    fold_tiers = tiers;
    fold_hub = hub;
    fold_edge = edge;
    figure_scale = figure;
}
/* }}} */

/* {{{ void ceramics_set_size_keep(double keep) */
/* The size law (see 020): 0 far things shrink, 1 they keep full size. Lua
 * calls it only while no stage is in flight, so a step never sees both. */
void ceramics_set_size_keep(double keep)
{
    fold_size_keep = keep;
}
/* }}} */

/* {{{ int ceramics_set_section(int index, double r, double angle, double radius) */
int ceramics_set_section(int index, double r, double angle, double radius)
{
    if (index < 0 || index >= 8) {
        /* only eight sections fit */
        return refused("a section number must be 0 to 7");
    }
    section_r[index] = r;
    section_angle[index] = angle;
    section_radius[index] = radius;
    if (index + 1 > section_count) section_count = index + 1;
    return 0;
}
/* }}} */

/* {{{ int ceramics_start(int workers, int units, int cubes, unsigned seed) */
/* Builds the map from the description compiled in, starts the workers, and
 * prepares one batch of chunk requests per stage. 0, or -1 and a reason. */
int ceramics_start(int workers, int units, int cubes, unsigned seed)
{
    const cera_map_build_t *program = cera_map_build_find("021-ceramics.map");
    if (!program) {
        /* the library was built from another description */
        return refused("this library was not built with 021-ceramics.map");
    }
    if (section_count < 1) {
        /* cuboids would have nowhere to go */
        return refused("set the sections before starting");
    }
    ceramics_unit_count = units;
    ceramics_cube_count = cubes;
    ceramics_seed = seed;

    map = cera_map_create_empty();
    program->build(map, 0, 0);
    cera_map_start(map, workers);
    cera_pool_submitter_register(map->pool);
    const char *why = cera_map_bring_up(map);
    if (why) return refused(why);

    for (int stage = 0; stage < 2; stage++) {
        if (!cera_map_argument_at(map, stage, &door_station[stage], &door_port[stage])
            || !cera_map_result_at(map, stage, &result_station[stage], &result_port[stage])) {
            /* the description is missing a door */
            return refused("021-ceramics.map lacks argument or result 0 or 1");
        }
        int count = stage == 0 ? units : cubes;
        chunks[stage] = (count + CHUNK - 1) / CHUNK;
        requests[stage] = calloc((size_t)chunks[stage], sizeof(chunk_req));
        landing[stage] = calloc((size_t)chunks[stage], sizeof(chunk_done));
        if (!requests[stage] || !landing[stage]) return refused("no memory for the chunk lists");
        for (int c = 0; c < chunks[stage]; c++) {
            int first = c * CHUNK;
            int last = first + CHUNK < count ? first + CHUNK : count;
            requests[stage][c] = (chunk_req){ c, first, last };
        }
    }
    cera_pool_release(map->pool);
    last_error = NULL;
    return 0;
}
/* }}} */

/* {{{ void ceramics_set_world(...) */
/* Where the four blocks are this step (front is read, back is written). */
void ceramics_set_world(unit_record *units_front, unit_record *units_back,
                        cuboid_record *cubes_front, cuboid_record *cubes_back)
{
    ceramics_units_front = units_front;
    ceramics_units_back = units_back;
    ceramics_cubes_front = cubes_front;
    ceramics_cubes_back = cubes_back;
}
/* }}} */

/* {{{ int ceramics_hand_in(int stage, double step_seconds) */
/* Hands a stage in as one batch: stage 0 the unit chunks, stage 1 the
 * cuboid chunks. Returns how many chunks went in, or -1 and a reason.
 * Called only when the previous stage has wholly landed, which is the one
 * moment no task can still be writing into the landing list. */
int ceramics_hand_in(int stage, double step_seconds)
{
    if (stage < 0 || stage > 1) return refused("a stage is 0 (units) or 1 (cuboids)");
    ceramics_step_seconds = step_seconds;
    const char *why = cera_map_collect(map, result_station[stage], result_port[stage],
                                       landing[stage], chunks[stage], (int)sizeof(chunk_done));
    if (why) return refused(why);
    why = cera_map_deliver_arguments(map, door_station[stage], door_port[stage],
                                     requests[stage], chunks[stage], (int)sizeof(chunk_req));
    if (why) return refused(why);
    return chunks[stage];
}
/* }}} */

/* {{{ int ceramics_landed(int stage) */
/* How many of a stage's chunks have landed. Never waits. */
int ceramics_landed(int stage)
{
    return cera_map_collected(map, result_station[stage], result_port[stage]);
}
/* }}} */

/* {{{ int ceramics_chunks(int stage) */
int ceramics_chunks(int stage)
{
    return chunks[stage];
}
/* }}} */

/* {{{ void ceramics_stop(void) */
/* Stops the workers and lets go of the map. Call only when no stage is in
 * flight (the host waits for the last one to land first). */
void ceramics_stop(void)
{
    if (!map) return;
    cera_pool_stop(map->pool);
    cera_pool_join(map->pool);
    cera_map_destroy(map);
    map = NULL;
    for (int stage = 0; stage < 2; stage++) {
        free(requests[stage]);
        free(landing[stage]);
        requests[stage] = NULL;
        landing[stage] = NULL;
    }
}
/* }}} */

/* {{{ void ceramics_run_inline(int stage, int reversed) */
/* For tests: runs a stage's chunks on the calling thread, without the
 * engine, in order or in reverse — the order must not change the result. */
void ceramics_run_inline(int stage, double step_seconds, int reversed)
{
    ceramics_step_seconds = step_seconds;
    int count = stage == 0 ? ceramics_unit_count : ceramics_cube_count;
    int n = (count + CHUNK - 1) / CHUNK;
    for (int i = 0; i < n; i++) {
        int c = reversed ? n - 1 - i : i;
        int first = c * CHUNK;
        int last = first + CHUNK < count ? first + CHUNK : count;
        chunk_req q = { c, first, last };
        if (stage == 0) unit_chunk(q); else cuboid_chunk(q);
    }
}
/* }}} */

/* {{{ void ceramics_set_counts(int units, int cubes, unsigned seed) */
/* For tests that run stages inline without starting the engine. */
void ceramics_set_counts(int units, int cubes, unsigned seed)
{
    ceramics_unit_count = units;
    ceramics_cube_count = cubes;
    ceramics_seed = seed;
}
/* }}} */

/* {{{ void ceramics_move_reference(...) */
/* For tests: the C motion alone, to compare with src/006-the-move-box.lua. */
void ceramics_move_reference(const unit_record *source, unit_record *destination, double dt)
{
    *destination = *source;
    move_unit(source, destination, dt);
}
/* }}} */
