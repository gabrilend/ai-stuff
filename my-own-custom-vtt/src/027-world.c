/*
 * 027-world.c -- assembling, reaching into, and copying the world.
 *
 * Interface and record layouts are in 027-world.h. What is here is thin on
 * purpose: this file is storage and nothing else. It does not validate, it does
 * not serialise, and it has no opinion about geometry. Those are 033, 035, and
 * 029 respectively, and keeping them apart is what lets a bug in one of them
 * have a side.
 */

#include "027-world.h"

#include <string.h>

/* {{{ int world_init */
int world_init(struct world *w,
               uint32_t thing_capacity,
               uint32_t wall_capacity,
               uint32_t region_capacity,
               uint32_t vertex_capacity,
               uint32_t light_capacity,
               uint32_t string_capacity)
{
    memset(w, 0, sizeof(struct world));

    /*
     * Each of these claims its index-0 sentinel as it is created. A partial
     * failure part-way through leaves the earlier blocks allocated, so the
     * caller must release the world even when this returns failure -- which
     * world_release handles, because releasing a never-inited block is releasing
     * a null pointer and a zero count.
     */
    if (!block_init(&w->things,   sizeof(struct thing),  thing_capacity))  return 0;
    if (!block_init(&w->walls,    sizeof(struct wall),   wall_capacity))   return 0;
    if (!block_init(&w->regions,  sizeof(struct region), region_capacity)) return 0;
    if (!block_init(&w->vertices, sizeof(struct vertex), vertex_capacity)) return 0;
    if (!block_init(&w->lights,   sizeof(struct light),  light_capacity))  return 0;

    /*
     * Scopes and their members. Sized from the thing capacity rather than taking
     * a parameter of their own -- a scope per body is a generous ceiling and
     * nobody wants a sixth number to pass in.
     */
    if (!block_init(&w->scopes,  sizeof(struct scope),  thing_capacity)) return 0;
    if (!block_init(&w->members, sizeof(uint32_t),      thing_capacity)) return 0;

    if (!string_pool_init(&w->strings, string_capacity)) return 0;

    return 1;
}
/* }}} */

/* {{{ void world_release */
void world_release(struct world *w)
{
    block_release(&w->things);
    block_release(&w->walls);
    block_release(&w->regions);
    block_release(&w->vertices);
    block_release(&w->lights);
    block_release(&w->scopes);
    block_release(&w->members);
    string_pool_release(&w->strings);

    memset(w, 0, sizeof(struct world));
}
/* }}} */

/* {{{ uint32_t world_add_thing */
uint32_t world_add_thing(struct world *w)
{
    return block_alloc(&w->things);
}
/* }}} */

/* {{{ uint32_t world_add_wall */
uint32_t world_add_wall(struct world *w)
{
    return block_alloc(&w->walls);
}
/* }}} */

/* {{{ uint32_t world_add_region */
uint32_t world_add_region(struct world *w)
{
    return block_alloc(&w->regions);
}
/* }}} */

/* {{{ uint32_t world_add_vertex */
uint32_t world_add_vertex(struct world *w, wcoord x, wcoord y)
{
    uint32_t index = block_alloc(&w->vertices);
    struct vertex *v;

    if (index == BLOCK_NOTHING) {
        return BLOCK_NOTHING;
    }

    /*
     * Vertices take their values here rather than being filled in afterwards,
     * because a region's boundary is a run of consecutive indices and a caller
     * building one should not have to interleave allocating and writing.
     */
    v = block_at(&w->vertices, index);
    v->x = x;
    v->y = y;

    return index;
}
/* }}} */

/* {{{ uint32_t world_add_light */
uint32_t world_add_light(struct world *w)
{
    return block_alloc(&w->lights);
}
/* }}} */

/* {{{ uint32_t world_add_scope */
uint32_t world_add_scope(struct world *w)
{
    return block_alloc(&w->scopes);
}
/* }}} */

/* {{{ uint32_t world_add_member */
uint32_t world_add_member(struct world *w, uint32_t thing)
{
    uint32_t index = block_alloc(&w->members);
    uint32_t *slot;

    if (index == BLOCK_NOTHING) {
        return BLOCK_NOTHING;
    }

    /*
     * A LIST scope holds a slice of this pool rather than a list of its own, so
     * a scope's members must be added consecutively. That is a constraint on the
     * caller and it is worth stating: it is what lets membership be a start and
     * a count rather than an allocation per scope.
     */
    slot = block_at(&w->members, index);
    *slot = thing;

    return index;
}
/* }}} */

/* {{{ struct scope *world_scope */
struct scope *world_scope(struct world *w, uint32_t index)
{
    return block_at(&w->scopes, index);
}
/* }}} */

/* {{{ const struct scope *world_scope_const */
const struct scope *world_scope_const(const struct world *w, uint32_t index)
{
    return block_at_const(&w->scopes, index);
}
/* }}} */

/* {{{ uint32_t world_scope_count */
uint32_t world_scope_count(const struct world *w)
{
    return w->scopes.count;
}
/* }}} */

/* {{{ uint32_t world_member_count */
uint32_t world_member_count(const struct world *w)
{
    return w->members.count;
}
/* }}} */

/* {{{ uint32_t world_member_at */
uint32_t world_member_at(const struct world *w, uint32_t index)
{
    const uint32_t *slot = block_at_const(&w->members, index);
    return *slot;
}
/* }}} */

/* {{{ struct thing *world_thing */
struct thing *world_thing(struct world *w, uint32_t index)
{
    return block_at(&w->things, index);
}
/* }}} */

/* {{{ struct wall *world_wall */
struct wall *world_wall(struct world *w, uint32_t index)
{
    return block_at(&w->walls, index);
}
/* }}} */

/* {{{ struct region *world_region */
struct region *world_region(struct world *w, uint32_t index)
{
    return block_at(&w->regions, index);
}
/* }}} */

/* {{{ struct vertex *world_vertex */
struct vertex *world_vertex(struct world *w, uint32_t index)
{
    return block_at(&w->vertices, index);
}
/* }}} */

/* {{{ struct light *world_light */
struct light *world_light(struct world *w, uint32_t index)
{
    return block_at(&w->lights, index);
}
/* }}} */

/* {{{ const struct thing *world_thing_const */
const struct thing *world_thing_const(const struct world *w, uint32_t index)
{
    return block_at_const(&w->things, index);
}
/* }}} */

/* {{{ const struct wall *world_wall_const */
const struct wall *world_wall_const(const struct world *w, uint32_t index)
{
    return block_at_const(&w->walls, index);
}
/* }}} */

/* {{{ const struct region *world_region_const */
const struct region *world_region_const(const struct world *w, uint32_t index)
{
    return block_at_const(&w->regions, index);
}
/* }}} */

/* {{{ const struct vertex *world_vertex_const */
const struct vertex *world_vertex_const(const struct world *w, uint32_t index)
{
    return block_at_const(&w->vertices, index);
}
/* }}} */

/* {{{ const struct light *world_light_const */
const struct light *world_light_const(const struct world *w, uint32_t index)
{
    return block_at_const(&w->lights, index);
}
/* }}} */

/* {{{ uint32_t world_thing_count */
uint32_t world_thing_count(const struct world *w)
{
    return w->things.count;
}
/* }}} */

/* {{{ uint32_t world_wall_count */
uint32_t world_wall_count(const struct world *w)
{
    return w->walls.count;
}
/* }}} */

/* {{{ uint32_t world_region_count */
uint32_t world_region_count(const struct world *w)
{
    return w->regions.count;
}
/* }}} */

/* {{{ uint32_t world_vertex_count */
uint32_t world_vertex_count(const struct world *w)
{
    return w->vertices.count;
}
/* }}} */

/* {{{ uint32_t world_light_count */
uint32_t world_light_count(const struct world *w)
{
    return w->lights.count;
}
/* }}} */

/* {{{ int thing_blocks_sight */
int thing_blocks_sight(const struct thing *t)
{
    return (t->flags & BLOCKS_SIGHT) != 0;
}
/* }}} */

/* {{{ int thing_blocks_movement */
int thing_blocks_movement(const struct thing *t)
{
    return (t->flags & BLOCKS_MOVEMENT) != 0;
}
/* }}} */

/* {{{ int thing_is_hidden */
int thing_is_hidden(const struct thing *t)
{
    return (t->flags & THING_HIDDEN) != 0;
}
/* }}} */

/* {{{ int thing_can_see */
int thing_can_see(const struct thing *t)
{
    /*
     * A body with no range does not see, and that is the normal state of a
     * coffee cup rather than a mistake. Checked here, once, so that the sweep
     * never runs for something with no eyes.
     */
    return t->sight_range > 0 && t->sight_arc > 0;
}
/* }}} */

/* {{{ int wall_blocks_sight */
int wall_blocks_sight(const struct wall *wall)
{
    return (wall->flags & BLOCKS_SIGHT) != 0;
}
/* }}} */

/* {{{ int wall_blocks_movement */
int wall_blocks_movement(const struct wall *wall)
{
    return (wall->flags & BLOCKS_MOVEMENT) != 0;
}
/* }}} */

/* {{{ int wall_is_one_way */
int wall_is_one_way(const struct wall *wall)
{
    return (wall->flags & WALL_ONE_WAY) != 0;
}
/* }}} */

/* {{{ int world_copy */
int world_copy(struct world *destination, const struct world *source)
{
    if (!block_copy(&destination->things,   &source->things))   return 0;
    if (!block_copy(&destination->walls,    &source->walls))    return 0;
    if (!block_copy(&destination->regions,  &source->regions))  return 0;
    if (!block_copy(&destination->vertices, &source->vertices)) return 0;
    if (!block_copy(&destination->lights,   &source->lights))   return 0;
    if (!block_copy(&destination->scopes,   &source->scopes))   return 0;
    if (!block_copy(&destination->members,  &source->members))  return 0;

    /*
     * The string pool is append-only and never shrinks, so a copy is the bytes
     * plus the used count. The destination must already be at least as large;
     * since a rollback snapshot is taken of a world whose pool was sized at
     * load, that holds by construction.
     */
    if (destination->strings.capacity < source->strings.used) {
        return 0;
    }
    memcpy(destination->strings.data, source->strings.data, source->strings.used);
    destination->strings.used = source->strings.used;

    destination->min_x = source->min_x;
    destination->min_y = source->min_y;
    destination->max_x = source->max_x;
    destination->max_y = source->max_y;
    destination->tick  = source->tick;

    return 1;
}
/* }}} */
