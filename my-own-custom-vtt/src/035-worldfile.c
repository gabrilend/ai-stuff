/*
 * 035-worldfile.c -- writing a world down, and reading one back.
 *
 * Interface and reasoning are in 035-worldfile.h.
 *
 * Almost the whole job is the header plus a field-at-a-time walk of each block.
 * There is no per-type serialiser, no pointer translation, and no graph walk --
 * because every reference in the world is an index. That is the payoff of the
 * decision in 023-blocks.h, and it is worth naming because it looks like luck.
 *
 * The same field walk serves the hash, so the two cannot drift about what is in
 * a world.
 */

#include "035-worldfile.h"

#include <stdio.h>
#include <string.h>

/* ------------------------------------------------------------------------- *
 * Bytes
 *
 * Everything is little-endian and written a byte at a time. Two reasons, and
 * both are about a file outliving the machine that made it: a byte at a time
 * means no assumption about alignment, and an explicit order means a big-endian
 * reader gets the same numbers rather than mirrored ones.
 * ------------------------------------------------------------------------- */

/* {{{ static int put32 */
static int put32(FILE *out, uint32_t value)
{
    uint8_t bytes[4];

    bytes[0] = (uint8_t)(value & 0xFFu);
    bytes[1] = (uint8_t)((value >> 8) & 0xFFu);
    bytes[2] = (uint8_t)((value >> 16) & 0xFFu);
    bytes[3] = (uint8_t)((value >> 24) & 0xFFu);

    return fwrite(bytes, 1, 4, out) == 4;
}
/* }}} */

/* {{{ static int put64 */
static int put64(FILE *out, uint64_t value)
{
    return put32(out, (uint32_t)(value & 0xFFFFFFFFu)) &&
           put32(out, (uint32_t)(value >> 32));
}
/* }}} */

/* {{{ static int get32 */
static int get32(FILE *in, uint32_t *value)
{
    uint8_t bytes[4];

    if (fread(bytes, 1, 4, in) != 4) {
        return 0;
    }

    *value = (uint32_t)bytes[0]
           | ((uint32_t)bytes[1] << 8)
           | ((uint32_t)bytes[2] << 16)
           | ((uint32_t)bytes[3] << 24);

    return 1;
}
/* }}} */

/* {{{ static int get64 */
static int get64(FILE *in, uint64_t *value)
{
    uint32_t low;
    uint32_t high;

    if (!get32(in, &low) || !get32(in, &high)) {
        return 0;
    }

    *value = (uint64_t)low | ((uint64_t)high << 32);
    return 1;
}
/* }}} */

/* {{{ static int fail */
static int fail(struct worldfile_error *error,
                const char *what, int64_t found, int64_t expected)
{
    error->what     = what;
    error->found    = found;
    error->expected = expected;
    return 0;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * The hash
 *
 * FNV-1a over the same field walk the writer uses. Chosen because it is a dozen
 * lines with no dependency and no version of its own -- a hash borrowed from a
 * library can change between releases and take the meaning of every recorded
 * world hash with it.
 * ------------------------------------------------------------------------- */

#define FNV_OFFSET 1469598103934665603ull
#define FNV_PRIME  1099511628211ull

/* {{{ static void hash_bytes */
static void hash_bytes(uint64_t *h, const void *data, size_t length)
{
    const uint8_t *bytes = data;
    size_t i;

    for (i = 0; i < length; i++) {
        *h ^= (uint64_t)bytes[i];
        *h *= FNV_PRIME;
    }
}
/* }}} */

/* {{{ static void hash_u32 */
static void hash_u32(uint64_t *h, uint32_t value)
{
    /*
     * Fed as four explicit bytes rather than as the struct's memory, so that the
     * hash does not depend on this machine's byte order. Two builds must agree
     * about a world's hash or the determinism harness in phase 3 reports a
     * divergence that is really just an endianness difference.
     */
    uint8_t bytes[4];

    bytes[0] = (uint8_t)(value & 0xFFu);
    bytes[1] = (uint8_t)((value >> 8) & 0xFFu);
    bytes[2] = (uint8_t)((value >> 16) & 0xFFu);
    bytes[3] = (uint8_t)((value >> 24) & 0xFFu);

    hash_bytes(h, bytes, 4);
}
/* }}} */

/* {{{ uint64_t world_hash */
uint64_t world_hash(const struct world *w)
{
    uint64_t h = FNV_OFFSET;
    uint32_t count;
    uint32_t i;

    /*
     * Fields, never structs. A struct's padding bytes are whatever the compiler
     * left there, and hashing them would make the same world hash differently on
     * two builds -- which is exactly the false alarm the determinism harness must
     * never raise.
     */
    count = world_thing_count(w);
    hash_u32(&h, count);
    for (i = 0; i < count; i++) {
        const struct thing *t = world_thing_const(w, i);
        hash_u32(&h, (uint32_t)t->x);
        hash_u32(&h, (uint32_t)t->y);
        hash_u32(&h, t->scope);
        hash_u32(&h, t->region);
        hash_u32(&h, t->kind);
        hash_u32(&h, t->sheet);
        hash_u32(&h, t->sight_range);
        hash_u32(&h, t->sprite_category);
        hash_u32(&h, t->sprite_seed);
        hash_u32(&h, t->facing);
        hash_u32(&h, t->radius);
        hash_u32(&h, t->sight_arc);
        hash_u32(&h, t->flags);
    }

    count = world_wall_count(w);
    hash_u32(&h, count);
    for (i = 0; i < count; i++) {
        const struct wall *wl = world_wall_const(w, i);
        hash_u32(&h, (uint32_t)wl->ax);
        hash_u32(&h, (uint32_t)wl->ay);
        hash_u32(&h, (uint32_t)wl->bx);
        hash_u32(&h, (uint32_t)wl->by);
        hash_u32(&h, wl->door);
        hash_u32(&h, wl->flags);
    }

    count = world_region_count(w);
    hash_u32(&h, count);
    for (i = 0; i < count; i++) {
        const struct region *r = world_region_const(w, i);
        hash_u32(&h, r->first_vertex);
        hash_u32(&h, r->vertex_count);
        hash_u32(&h, r->parent);
        hash_u32(&h, r->name_offset);
    }

    count = world_vertex_count(w);
    hash_u32(&h, count);
    for (i = 0; i < count; i++) {
        const struct vertex *v = world_vertex_const(w, i);
        hash_u32(&h, (uint32_t)v->x);
        hash_u32(&h, (uint32_t)v->y);
    }

    count = world_light_count(w);
    hash_u32(&h, count);
    for (i = 0; i < count; i++) {
        const struct light *l = world_light_const(w, i);
        hash_u32(&h, l->thing);
        hash_u32(&h, l->radius);
        hash_u32(&h, l->dim_radius);
        hash_u32(&h, l->colour);
        hash_u32(&h, l->arc);
    }

    count = world_scope_count(w);
    hash_u32(&h, count);
    for (i = 0; i < count; i++) {
        const struct scope *sc = world_scope_const(w, i);
        hash_u32(&h, sc->viewer);
        hash_u32(&h, sc->region);
        hash_u32(&h, sc->first_member);
        hash_u32(&h, sc->member_count);
        hash_u32(&h, sc->name_offset);
        hash_u32(&h, sc->membership);
        hash_u32(&h, sc->style);
        hash_u32(&h, sc->flags);
    }

    count = world_member_count(w);
    hash_u32(&h, count);
    for (i = 0; i < count; i++) {
        hash_u32(&h, world_member_at(w, i));
    }

    hash_u32(&h, w->strings.used);
    hash_bytes(&h, w->strings.data, w->strings.used);

    hash_u32(&h, (uint32_t)w->min_x);
    hash_u32(&h, (uint32_t)w->min_y);
    hash_u32(&h, (uint32_t)w->max_x);
    hash_u32(&h, (uint32_t)w->max_y);
    hash_u32(&h, (uint32_t)(w->tick & 0xFFFFFFFFu));
    hash_u32(&h, (uint32_t)(w->tick >> 32));

    /* Where it came from is part of what a world is, so it is part of the hash. */
    hash_u32(&h, (uint32_t)(w->seed & 0xFFFFFFFFu));
    hash_u32(&h, (uint32_t)(w->seed >> 32));
    hash_bytes(&h, w->origin, sizeof(w->origin));

    return h;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * Writing
 * ------------------------------------------------------------------------- */

/* {{{ int worldfile_write */
int worldfile_write(const struct world *w, FILE *out, struct worldfile_error *error)
{
    uint32_t count;
    uint32_t i;

    if (!put32(out, WORLDFILE_MAGIC) ||
        !put32(out, WORLDFILE_VERSION) ||
        !put32(out, (uint32_t)WC_ONE)) {
        return fail(error, "could not write the file header", 0, 0);
    }

    /*
     * The scale is written down so that a world made under a different
     * fixed-point scale is refused rather than silently misread -- every
     * coordinate in it would be off by a factor of two or a thousand, and
     * nothing about the file would look wrong.
     */

    if (!put32(out, world_thing_count(w)) ||
        !put32(out, world_wall_count(w)) ||
        !put32(out, world_region_count(w)) ||
        !put32(out, world_vertex_count(w)) ||
        !put32(out, world_light_count(w)) ||
        !put32(out, world_scope_count(w)) ||
        !put32(out, world_member_count(w)) ||
        !put32(out, w->strings.used)) {
        return fail(error, "could not write the block counts", 0, 0);
    }

    if (!put32(out, (uint32_t)w->min_x) ||
        !put32(out, (uint32_t)w->min_y) ||
        !put32(out, (uint32_t)w->max_x) ||
        !put32(out, (uint32_t)w->max_y) ||
        !put64(out, w->tick) ||
        !put64(out, w->seed) ||
        !put64(out, world_hash(w))) {
        return fail(error, "could not write the world header", 0, 0);
    }

    if (fwrite(w->origin, 1, sizeof(w->origin), out) != sizeof(w->origin)) {
        return fail(error, "could not write where this world came from", 0, 0);
    }

    count = world_thing_count(w);
    for (i = 0; i < count; i++) {
        const struct thing *t = world_thing_const(w, i);
        if (!put32(out, (uint32_t)t->x) || !put32(out, (uint32_t)t->y) ||
            !put32(out, t->scope) || !put32(out, t->region) ||
            !put32(out, t->kind) || !put32(out, t->sheet) ||
            !put32(out, t->sight_range) ||
            !put32(out, t->sprite_category) || !put32(out, t->sprite_seed) ||
            !put32(out, t->facing) || !put32(out, t->radius) ||
            !put32(out, t->sight_arc) || !put32(out, t->flags)) {
            return fail(error, "could not write a thing", (int64_t)i, 0);
        }
    }

    count = world_wall_count(w);
    for (i = 0; i < count; i++) {
        const struct wall *wl = world_wall_const(w, i);
        if (!put32(out, (uint32_t)wl->ax) || !put32(out, (uint32_t)wl->ay) ||
            !put32(out, (uint32_t)wl->bx) || !put32(out, (uint32_t)wl->by) ||
            !put32(out, wl->door) || !put32(out, wl->flags)) {
            return fail(error, "could not write a wall", (int64_t)i, 0);
        }
    }

    count = world_region_count(w);
    for (i = 0; i < count; i++) {
        const struct region *r = world_region_const(w, i);
        if (!put32(out, r->first_vertex) || !put32(out, r->vertex_count) ||
            !put32(out, r->parent) || !put32(out, r->name_offset)) {
            return fail(error, "could not write a region", (int64_t)i, 0);
        }
    }

    count = world_vertex_count(w);
    for (i = 0; i < count; i++) {
        const struct vertex *v = world_vertex_const(w, i);
        if (!put32(out, (uint32_t)v->x) || !put32(out, (uint32_t)v->y)) {
            return fail(error, "could not write a vertex", (int64_t)i, 0);
        }
    }

    count = world_light_count(w);
    for (i = 0; i < count; i++) {
        const struct light *l = world_light_const(w, i);
        if (!put32(out, l->thing) || !put32(out, l->radius) ||
            !put32(out, l->dim_radius) || !put32(out, l->colour) ||
            !put32(out, l->arc)) {
            return fail(error, "could not write a light", (int64_t)i, 0);
        }
    }

    count = world_scope_count(w);
    for (i = 0; i < count; i++) {
        const struct scope *sc = world_scope_const(w, i);
        if (!put32(out, sc->viewer) || !put32(out, sc->region) ||
            !put32(out, sc->first_member) || !put32(out, sc->member_count) ||
            !put32(out, sc->name_offset) ||
            !put32(out, sc->membership) || !put32(out, sc->style) ||
            !put32(out, sc->flags)) {
            return fail(error, "could not write a scope", (int64_t)i, 0);
        }
    }

    count = world_member_count(w);
    for (i = 0; i < count; i++) {
        if (!put32(out, world_member_at(w, i))) {
            return fail(error, "could not write a scope member", (int64_t)i, 0);
        }
    }

    if (w->strings.used > 0 &&
        fwrite(w->strings.data, 1, w->strings.used, out) != w->strings.used) {
        return fail(error, "could not write the string pool", 0, 0);
    }

    return 1;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * The converter chain
 *
 * A file older than this build is walked forward one version at a time. Version
 * 3 to version 7 is four converters run in sequence, not a converter written for
 * that particular jump -- otherwise the number of converters grows as the square
 * of the number of versions, and nobody writes the sixteenth one.
 *
 * The chain is empty, because there is only one version. It exists anyway: an
 * empty chain that is here is a chain somebody will extend, and a chain that is
 * not here is a chain somebody will work around.
 * ------------------------------------------------------------------------- */

/* {{{ static int migrate_forward */
static int migrate_forward(struct world *w, uint32_t from_version,
                           struct worldfile_error *error)
{

    /*
     * A ladder, each rung moving a world forward exactly one step. Version 3 to
     * version 7 will be four converters run in sequence rather than a converter
     * written for that particular jump -- otherwise the count grows as the
     * square of the number of versions and nobody writes the sixteenth one.
     */
    /*
     * Recorded before anything is converted, so a caller can say what it loaded.
     * A world that needed no rung leaves this zero.
     */
    if (from_version != WORLDFILE_VERSION) {
        w->migrated_from = from_version;
    }

    if (from_version == 1) {
        /*
         * Version 1 had no origin. Nothing to convert -- the reader already left
         * the fields empty -- but the rung exists so that the NEXT one has
         * something to stand on, and so that a version 1 file is accepted rather
         * than refused for being old.
         */
        snprintf(w->origin, sizeof(w->origin), "%s", "unknown -- a version 1 file");
        from_version = 2;
    }

    if (from_version == 2) {
        /*
         * Version 2 had no sprite on a thing. Nothing to convert: the reader
         * leaves both fields zero, and zero in sprite_category already means
         * "wears nothing" by the same convention as every other index in the
         * project. So an old world loads as a world where nobody is wearing
         * anything, which is exactly what it was.
         *
         * The rung exists anyway rather than being skipped, because a ladder
         * with a missing rung is a ladder somebody works around.
         */
        from_version = 3;
    }

    if (from_version == WORLDFILE_VERSION) {
        return 1;
    }

    return fail(error,
                "this file's format is older than any converter this build has",
                (int64_t)from_version, (int64_t)WORLDFILE_VERSION);
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * Reading
 * ------------------------------------------------------------------------- */

/* {{{ int worldfile_read */
int worldfile_read(struct world *w, FILE *in, struct worldfile_error *error)
{
    uint32_t magic;
    uint32_t version;
    uint32_t scale;
    uint32_t thing_count;
    uint32_t wall_count;
    uint32_t region_count;
    uint32_t vertex_count;
    uint32_t light_count;
    uint32_t scope_count;
    uint32_t member_count;
    uint32_t string_used;
    uint64_t stored_hash;
    uint32_t i;

    if (!get32(in, &magic)) {
        return fail(error, "the file is too short to hold a header", 0, 0);
    }

    if (magic != WORLDFILE_MAGIC) {
        return fail(error, "this is not a world file",
                    (int64_t)magic, (int64_t)WORLDFILE_MAGIC);
    }

    if (!get32(in, &version) || !get32(in, &scale)) {
        return fail(error, "the file is too short to hold a header", 0, 0);
    }

    /*
     * A file newer than this build is refused, naming both versions. There is no
     * way to guess what a future format meant, and guessing would be worse than
     * refusing -- a world read wrongly is a world that looks fine.
     */
    if (version > WORLDFILE_VERSION) {
        return fail(error, "this file was written by a newer build than this one",
                    (int64_t)version, (int64_t)WORLDFILE_VERSION);
    }

    if (scale != (uint32_t)WC_ONE) {
        return fail(error, "this world was written at a different fixed-point scale",
                    (int64_t)scale, (int64_t)WC_ONE);
    }

    if (!get32(in, &thing_count) || !get32(in, &wall_count) ||
        !get32(in, &region_count) || !get32(in, &vertex_count) ||
        !get32(in, &light_count) || !get32(in, &scope_count) ||
        !get32(in, &member_count) || !get32(in, &string_used)) {
        return fail(error, "the file is too short to hold its block counts", 0, 0);
    }

    {
        uint32_t min_x;
        uint32_t min_y;
        uint32_t max_x;
        uint32_t max_y;

        if (!get32(in, &min_x) || !get32(in, &min_y) ||
            !get32(in, &max_x) || !get32(in, &max_y) ||
            !get64(in, &w->tick)) {
            return fail(error, "the file is too short to hold its world header", 0, 0);
        }

        /*
         * The origin arrived in version 2. A version 1 file simply does not
         * carry it, and the converter below fills it with "unknown" -- which is
         * exactly what the ladder is for, and the first time it has done
         * anything.
         */
        if (version >= 2) {
            if (!get64(in, &w->seed)) {
                return fail(error, "the file is too short to hold its seed", 0, 0);
            }
        } else {
            w->seed = 0;
        }

        if (!get64(in, &stored_hash)) {
            return fail(error, "the file is too short to hold its hash", 0, 0);
        }

        if (version >= 2) {
            if (fread(w->origin, 1, sizeof(w->origin), in) != sizeof(w->origin)) {
                return fail(error,
                            "the file is too short to hold where it came from",
                            0, 0);
            }
        } else {
            memset(w->origin, 0, sizeof(w->origin));
        }

        w->min_x = (wcoord)min_x;
        w->min_y = (wcoord)min_y;
        w->max_x = (wcoord)max_x;
        w->max_y = (wcoord)max_y;
    }

    /*
     * Every count includes the sentinel at index 0, so a count of zero is a
     * malformed file rather than an empty block. Checked before anything is
     * allocated, so that a nonsense header costs nothing.
     */
    if (thing_count == 0 || wall_count == 0 || region_count == 0 ||
        vertex_count == 0 || light_count == 0 ||
        scope_count == 0 || member_count == 0) {
        return fail(error, "a block count of zero -- every block holds a sentinel",
                    0, 1);
    }

    /*
     * The blocks are read into a world that already has its sentinels. Index 0
     * of each is overwritten by the file's own sentinel, which the validator
     * then checks is still empty -- so a file that claimed index 0 is caught by
     * the same check that catches a running program claiming it.
     */
    for (i = 0; i < thing_count; i++) {
        struct thing *t;
        uint32_t index = (i == 0) ? 0 : world_add_thing(w);
        uint32_t x, y, facing, radius, sight_arc, flags;

        if (i != 0 && index == 0) {
            return fail(error, "ran out of memory reading things", (int64_t)i, 0);
        }

        t = world_thing(w, index);

        if (!get32(in, &x) || !get32(in, &y) ||
            !get32(in, &t->scope) || !get32(in, &t->region) ||
            !get32(in, &t->kind) || !get32(in, &t->sheet) ||
            !get32(in, &t->sight_range)) {
            return fail(error, "the file ended part-way through the things",
                        (int64_t)i, (int64_t)thing_count);
        }

        /*
         * The two sprite fields arrived in version 3. An older file simply does
         * not have them, and the reader must not go looking -- reading two words
         * that are not there would swallow the next thing's position and every
         * record after it would be a plausible-looking lie.
         *
         * They are left zero, which already means "wears nothing".
         */
        if (version >= 3u) {
            if (!get32(in, &t->sprite_category) || !get32(in, &t->sprite_seed)) {
                return fail(error,
                            "the file ended part-way through a thing's sprite",
                            (int64_t)i, (int64_t)thing_count);
            }
        }

        if (!get32(in, &facing) || !get32(in, &radius) ||
            !get32(in, &sight_arc) || !get32(in, &flags)) {
            return fail(error, "the file ended part-way through the things",
                        (int64_t)i, (int64_t)thing_count);
        }

        t->x = (wcoord)x;
        t->y = (wcoord)y;
        t->facing = (wangle)facing;
        t->radius = (uint16_t)radius;
        t->sight_arc = (wangle)sight_arc;
        t->flags = (uint16_t)flags;
    }

    for (i = 0; i < wall_count; i++) {
        struct wall *wl;
        uint32_t index = (i == 0) ? 0 : world_add_wall(w);
        uint32_t ax, ay, bx, by, flags;

        if (i != 0 && index == 0) {
            return fail(error, "ran out of memory reading walls", (int64_t)i, 0);
        }

        wl = world_wall(w, index);

        if (!get32(in, &ax) || !get32(in, &ay) ||
            !get32(in, &bx) || !get32(in, &by) ||
            !get32(in, &wl->door) || !get32(in, &flags)) {
            return fail(error, "the file ended part-way through the walls",
                        (int64_t)i, (int64_t)wall_count);
        }

        wl->ax = (wcoord)ax;
        wl->ay = (wcoord)ay;
        wl->bx = (wcoord)bx;
        wl->by = (wcoord)by;
        wl->flags = (uint16_t)flags;
    }

    for (i = 0; i < region_count; i++) {
        struct region *r;
        uint32_t index = (i == 0) ? 0 : world_add_region(w);

        if (i != 0 && index == 0) {
            return fail(error, "ran out of memory reading regions", (int64_t)i, 0);
        }

        r = world_region(w, index);

        if (!get32(in, &r->first_vertex) || !get32(in, &r->vertex_count) ||
            !get32(in, &r->parent) || !get32(in, &r->name_offset)) {
            return fail(error, "the file ended part-way through the regions",
                        (int64_t)i, (int64_t)region_count);
        }
    }

    for (i = 0; i < vertex_count; i++) {
        struct vertex *v;
        uint32_t index = (i == 0) ? 0 : world_add_vertex(w, 0, 0);
        uint32_t x, y;

        if (i != 0 && index == 0) {
            return fail(error, "ran out of memory reading vertices", (int64_t)i, 0);
        }

        v = world_vertex(w, index);

        if (!get32(in, &x) || !get32(in, &y)) {
            return fail(error, "the file ended part-way through the vertices",
                        (int64_t)i, (int64_t)vertex_count);
        }

        v->x = (wcoord)x;
        v->y = (wcoord)y;
    }

    for (i = 0; i < light_count; i++) {
        struct light *l;
        uint32_t index = (i == 0) ? 0 : world_add_light(w);
        uint32_t arc;

        if (i != 0 && index == 0) {
            return fail(error, "ran out of memory reading lights", (int64_t)i, 0);
        }

        l = world_light(w, index);

        if (!get32(in, &l->thing) || !get32(in, &l->radius) ||
            !get32(in, &l->dim_radius) || !get32(in, &l->colour) ||
            !get32(in, &arc)) {
            return fail(error, "the file ended part-way through the lights",
                        (int64_t)i, (int64_t)light_count);
        }

        l->arc = (wangle)arc;
    }

    for (i = 0; i < scope_count; i++) {
        struct scope *sc;
        uint32_t index = (i == 0) ? 0 : world_add_scope(w);
        uint32_t membership, style, flags;

        if (i != 0 && index == 0) {
            return fail(error, "ran out of memory reading scopes", (int64_t)i, 0);
        }

        sc = world_scope(w, index);

        if (!get32(in, &sc->viewer) || !get32(in, &sc->region) ||
            !get32(in, &sc->first_member) || !get32(in, &sc->member_count) ||
            !get32(in, &sc->name_offset) ||
            !get32(in, &membership) || !get32(in, &style) || !get32(in, &flags)) {
            return fail(error, "the file ended part-way through the scopes",
                        (int64_t)i, (int64_t)scope_count);
        }

        sc->membership = (uint8_t)membership;
        sc->style = (uint8_t)style;
        sc->flags = (uint16_t)flags;
    }

    for (i = 0; i < member_count; i++) {
        uint32_t thing = 0;
        uint32_t index;

        if (!get32(in, &thing)) {
            return fail(error, "the file ended part-way through the scope members",
                        (int64_t)i, (int64_t)member_count);
        }

        if (i != 0) {
            index = world_add_member(w, thing);
            if (index == 0) {
                return fail(error, "ran out of memory reading scope members",
                            (int64_t)i, 0);
            }
        }
    }

    if (string_used > w->strings.capacity) {
        return fail(error, "the string pool in this file is larger than the one prepared for it",
                    (int64_t)string_used, (int64_t)w->strings.capacity);
    }

    if (string_used > 0 &&
        fread(w->strings.data, 1, string_used, in) != string_used) {
        return fail(error, "the file ended part-way through the string pool",
                    0, (int64_t)string_used);
    }
    w->strings.used = string_used;

    if (!migrate_forward(w, version, error)) {
        return 0;
    }

    /*
     * The hash is checked last, because a mismatch here means the bytes changed
     * on the disk rather than that the format was misunderstood -- and every
     * other failure above is a better explanation of the same symptom.
     *
     * AND IT IS SKIPPED FOR A MIGRATED FILE, which is a genuine loss and not a
     * convenience.
     *
     * The hash is a walk over every field of every record, and the walk is this
     * build's walk. A version 2 file's hash was computed before things had a
     * sprite, so it covered nine fields per thing where this one covers eleven.
     * Recomputing it here would compare two different questions and always
     * disagree, and keeping a hash function per version is exactly the
     * once-per-pair growth the converter ladder was built to avoid.
     *
     * So an old file is loaded on the strength of its structure parsing cleanly
     * and nothing else, and `migrated_from` records that so a caller can say so.
     * The real fix is a checksum over the file's BYTES rather than over the
     * world's FIELDS -- version-independent by construction. Open question 15.4.
     */
    if (w->migrated_from == 0 && world_hash(w) != stored_hash) {
        return fail(error, "this file's contents do not match the hash written into it",
                    (int64_t)world_hash(w), (int64_t)stored_hash);
    }

    return 1;
}
/* }}} */

/* {{{ const char *worldfile_error_describe */
const char *worldfile_error_describe(const struct worldfile_error *error,
                                     char *buffer,
                                     uint32_t buffer_size)
{
    if (error->expected == 0 && error->found == 0) {
        snprintf(buffer, (size_t)buffer_size, "%s.", error->what);
    } else {
        snprintf(buffer, (size_t)buffer_size,
                 "%s (found %lld, expected %lld).",
                 error->what,
                 (long long)error->found,
                 (long long)error->expected);
    }

    return buffer;
}
/* }}} */
