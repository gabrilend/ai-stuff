/*
 * 036-test-worldfile.c -- the round trip, and every way of refusing.
 *
 * The round trip is the whole specification of the format: write a world, read
 * it back, write it again, and compare the two files byte for byte. If that
 * holds, the format is a format. If it does not, nothing else about it matters.
 *
 * The refusals matter almost as much, because this is a long-lived format now --
 * the world persists between sessions -- and every one of them is a message a
 * person will read while trying to work out why last week's dungeon will not
 * load.
 */

#include "020-test-harness.h"
#include "035-worldfile.h"
#include "033-validate.h"
#include "031-region.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define M(n) ((wcoord)((n) * WC_ONE))

/* Scratch files live in the RAM tier, never on a disk anybody has to clean up. */
#define SCRATCH_DIR "/dev/shm/my-own-custom-vtt"

/* {{{ static uint32_t add_box */
static uint32_t add_box(struct world *w,
                        wcoord x0, wcoord y0, wcoord x1, wcoord y1,
                        uint32_t parent)
{
    uint32_t first = world_add_vertex(w, x0, y0);
    uint32_t region;
    struct region *r;

    world_add_vertex(w, x1, y0);
    world_add_vertex(w, x1, y1);
    world_add_vertex(w, x0, y1);

    region = world_add_region(w);
    r = world_region(w, region);
    r->first_vertex = first;
    r->vertex_count = 4;
    r->parent = parent;

    return region;
}
/* }}} */

/* {{{ static void build_a_world */
static void build_a_world(struct world *w)
{
    uint32_t tavern;
    uint32_t cellar;
    uint32_t torch;
    uint32_t light;
    uint32_t i;

    world_init(w, 32, 32, 8, 128, 8, 2048);

    tavern = add_box(w, 0, 0, M(20), M(20), 0);
    cellar = add_box(w, M(2), M(2), M(8), M(8), tavern);

    world_region(w, tavern)->name_offset = string_pool_add(&w->strings, "The Tavern", 10);
    world_region(w, cellar)->name_offset = string_pool_add(&w->strings, "The Cellar", 10);

    for (i = 0; i < 4; i++) {
        uint32_t wall = world_add_wall(w);
        struct wall *wl = world_wall(w, wall);
        wl->ax = (wcoord)(i * WC_ONE);
        wl->ay = 0;
        wl->bx = (wcoord)((i + 1) * WC_ONE);
        wl->by = M(3);
        wl->flags = BLOCKS_SIGHT | BLOCKS_MOVEMENT;
    }

    torch = world_add_thing(w);
    {
        struct thing *t = world_thing(w, torch);
        t->x = M(5);
        t->y = M(5);
        t->facing = WA_QUARTER;
        t->radius = (uint16_t)(WC_ONE / 4);
        t->flags = THING_EMITS_LIGHT;
        t->region = region_deepest_containing(w, t->x, t->y);
    }

    light = world_add_light(w);
    {
        struct light *l = world_light(w, light);
        l->thing = torch;
        l->radius = M(6);
        l->dim_radius = M(3);
        l->colour = 0xFFAA6633u;
        l->arc = 65535;
    }

    w->min_x = 0;
    w->min_y = 0;
    w->max_x = M(20);
    w->max_y = M(20);
    w->tick = 4207;
}
/* }}} */

/* {{{ static long file_bytes */
static long file_bytes(const char *path, uint8_t **out)
{
    FILE *f = fopen(path, "rb");
    long size;
    uint8_t *buffer;

    if (f == NULL) {
        *out = NULL;
        return -1;
    }

    fseek(f, 0, SEEK_END);
    size = ftell(f);
    fseek(f, 0, SEEK_SET);

    buffer = malloc((size_t)size);
    if (buffer == NULL || fread(buffer, 1, (size_t)size, f) != (size_t)size) {
        free(buffer);
        fclose(f);
        *out = NULL;
        return -1;
    }

    fclose(f);
    *out = buffer;
    return size;
}
/* }}} */

/* {{{ static void test_round_trip */
static void test_round_trip(void)
{
    struct world original;
    struct world loaded;
    struct worldfile_error error;
    struct validation_failure failure;
    char message[256];
    const char *first_path  = SCRATCH_DIR "/test-world-first.vttw";
    const char *second_path = SCRATCH_DIR "/test-world-second.vttw";

    TEST_CASE("a world survives being written and read");

    build_a_world(&original);

    {
        FILE *out = fopen(first_path, "wb");
        CHECK(out != NULL);
        if (out != NULL) {
            if (!worldfile_write(&original, out, &error)) {
                vtt_report_failure(__FILE__, __LINE__,
                    worldfile_error_describe(&error, message, sizeof(message)));
            }
            fclose(out);
        }
    }

    world_init(&loaded, 4, 4, 4, 4, 4, 2048);
    {
        FILE *in = fopen(first_path, "rb");
        CHECK(in != NULL);
        if (in != NULL) {
            if (!worldfile_read(&loaded, in, &error)) {
                vtt_report_failure(__FILE__, __LINE__,
                    worldfile_error_describe(&error, message, sizeof(message)));
            }
            fclose(in);
        }
    }

    TEST_CASE("the world that came back is the world that went in");

    CHECK_EQ(world_thing_count(&loaded), world_thing_count(&original));
    CHECK_EQ(world_wall_count(&loaded), world_wall_count(&original));
    CHECK_EQ(world_region_count(&loaded), world_region_count(&original));
    CHECK_EQ(world_vertex_count(&loaded), world_vertex_count(&original));
    CHECK_EQ(world_light_count(&loaded), world_light_count(&original));
    CHECK_EQ(loaded.tick, original.tick);
    CHECK_EQ(loaded.max_x, original.max_x);

    /* The hash is the compact form of all of the above, and of everything else. */
    CHECK_EQ(world_hash(&loaded), world_hash(&original));

    TEST_CASE("a file that parsed is still put through the validator");

    /*
     * Always. A file can be perfectly well-formed and describe a world whose
     * region field has drifted or whose light points at nothing.
     */
    if (!world_validate(&loaded, &failure)) {
        vtt_report_failure(__FILE__, __LINE__,
            validation_failure_describe(&failure, message, sizeof(message)));
    } else {
        CHECK(1);
    }

    TEST_CASE("writing it again produces the same bytes");

    /*
     * The sharpest form of the round trip. Equal counts and an equal hash could
     * both be true of a writer that dropped a field the reader also ignores;
     * byte equality across a second write cannot.
     */
    {
        FILE *out = fopen(second_path, "wb");
        CHECK(out != NULL);
        if (out != NULL) {
            worldfile_write(&loaded, out, &error);
            fclose(out);
        }
    }

    {
        uint8_t *first = NULL;
        uint8_t *second = NULL;
        long first_size = file_bytes(first_path, &first);
        long second_size = file_bytes(second_path, &second);

        CHECK(first_size > 0);
        CHECK_EQ(second_size, first_size);

        if (first != NULL && second != NULL && first_size == second_size) {
            CHECK_EQ(memcmp(first, second, (size_t)first_size), 0);
        }

        free(first);
        free(second);
    }

    remove(first_path);
    remove(second_path);

    world_release(&original);
    world_release(&loaded);
}
/* }}} */

/* {{{ static void write_then_corrupt */
static void write_then_corrupt(const char *path, long offset, uint8_t value)
{
    struct world w;
    struct worldfile_error error;
    FILE *f;

    build_a_world(&w);

    f = fopen(path, "wb");
    if (f != NULL) {
        worldfile_write(&w, f, &error);
        fclose(f);
    }

    world_release(&w);

    if (offset >= 0) {
        f = fopen(path, "r+b");
        if (f != NULL) {
            fseek(f, offset, SEEK_SET);
            fwrite(&value, 1, 1, f);
            fclose(f);
        }
    }
}
/* }}} */

/* {{{ static int read_expecting_failure */
static int read_expecting_failure(const char *path, struct worldfile_error *error)
{
    struct world w;
    FILE *in;
    int result;

    world_init(&w, 4, 4, 4, 4, 4, 2048);

    in = fopen(path, "rb");
    if (in == NULL) {
        world_release(&w);
        return 0;
    }

    result = worldfile_read(&w, in, error);
    fclose(in);
    world_release(&w);

    return result;
}
/* }}} */

/* {{{ static void test_refusals */
static void test_refusals(void)
{
    struct worldfile_error error;
    const char *path = SCRATCH_DIR "/test-world-broken.vttw";

    TEST_CASE("something that is not a world file is refused as such");

    /* Byte 0 is the first byte of the magic. */
    write_then_corrupt(path, 0, 0x00);
    CHECK_EQ(read_expecting_failure(path, &error), 0);
    CHECK(strstr(error.what, "not a world file") != NULL);

    TEST_CASE("a file from a newer build is refused, naming both versions");

    /*
     * Never "failed to load". A version skew's worst symptom is a message that
     * does not say which of the two ends to change.
     */
    write_then_corrupt(path, 4, 99);
    CHECK_EQ(read_expecting_failure(path, &error), 0);
    CHECK(strstr(error.what, "newer build") != NULL);
    CHECK_EQ(error.found, 99);
    CHECK_EQ(error.expected, WORLDFILE_VERSION);

    TEST_CASE("a world written at a different scale is refused, not misread");

    /*
     * Every coordinate would be off by a factor of a thousand and nothing about
     * the file would look wrong. This is the check that turns a silent disaster
     * into a sentence.
     */
    write_then_corrupt(path, 8, 99);
    CHECK_EQ(read_expecting_failure(path, &error), 0);
    CHECK(strstr(error.what, "scale") != NULL);

    TEST_CASE("corrupted contents are caught by the hash");

    /* Well past the header, into the record data. */
    write_then_corrupt(path, 120, 0xFF);
    CHECK_EQ(read_expecting_failure(path, &error), 0);

    TEST_CASE("a truncated file is refused rather than half-read");

    {
        uint8_t *bytes = NULL;
        long size;

        write_then_corrupt(path, -1, 0);
        size = file_bytes(path, &bytes);

        CHECK(size > 80);

        /*
         * Rewritten short rather than truncated in place, because truncate() is
         * POSIX and this project builds as strict C99. Eighty bytes is past the
         * header and part-way into the records, which is where a half-written
         * file would actually stop.
         */
        if (bytes != NULL && size > 80) {
            FILE *f = fopen(path, "wb");
            if (f != NULL) {
                fwrite(bytes, 1, 80, f);
                fclose(f);
            }
        }
        free(bytes);

        CHECK_EQ(read_expecting_failure(path, &error), 0);
        CHECK(strstr(error.what, "ended part-way") != NULL ||
              strstr(error.what, "too short") != NULL);
    }

    remove(path);
}
/* }}} */

/* {{{ static void test_hash_notices_everything */
static void test_hash_notices_everything(void)
{
    struct world a;
    struct world b;

    TEST_CASE("two identical worlds hash the same");

    build_a_world(&a);
    build_a_world(&b);

    CHECK_EQ(world_hash(&a), world_hash(&b));

    TEST_CASE("a single changed coordinate changes the hash");

    world_thing(&b, 1)->x += 1;
    CHECK(world_hash(&a) != world_hash(&b));

    TEST_CASE("a changed tick changes the hash");

    build_a_world(&b);
    b.tick += 1;
    CHECK(world_hash(&a) != world_hash(&b));

    TEST_CASE("a changed name changes the hash");

    build_a_world(&b);
    string_pool_add(&b.strings, "extra", 5);
    CHECK(world_hash(&a) != world_hash(&b));

    world_release(&a);
    world_release(&b);
}
/* }}} */

/*
 * A file written before things wore sprites still loads.
 *
 * Built by taking a current file apart rather than by keeping an old one around:
 * a fixture file in the repository would drift out of date the moment anything
 * else about the format changed, and then this test would be proving that an
 * ancient artifact still parses rather than that the LADDER works.
 *
 * The two sprite words are cut out of every thing record and the version is set
 * back to 2, which is exactly what a version 2 file is.
 */
/* {{{ static void test_a_version_two_file_still_loads */
static void test_a_version_two_file_still_loads(void)
{
    /* Where the things begin: magic, version, scale, eight counts, the extent,
     * the tick, the seed, the hash, and the origin. */
    const uint32_t things_begin = 12u + 32u + 16u + 8u + 8u + 8u + 64u;

    /* A version 3 thing is twelve words; the two sprite words sit after the
     * first seven. */
    const uint32_t thing_bytes_v3 = 12u * 4u;
    const uint32_t sprite_at = 7u * 4u;

    struct world made;
    struct world loaded;
    struct worldfile_error error;
    const char *path = SCRATCH_DIR "/version-two.world";
    unsigned char *bytes;
    long length;
    uint32_t thing_count;
    uint32_t i;
    FILE *f;

    TEST_CASE("a file from before things wore sprites still loads");

    CHECK_EQ(world_init(&made, 8, 8, 8, 8, 8, 256), 1);

    {
        uint32_t one = world_add_thing(&made);
        struct thing *t = world_thing(&made, one);

        t->x = M(3);
        t->y = M(4);
        t->kind = 7;
        t->radius = 500;
        t->sprite_category = 11;
        t->sprite_seed = 4242;
    }

    made.min_x = M(-10);
    made.min_y = M(-10);
    made.max_x = M(10);
    made.max_y = M(10);

    f = fopen(path, "wb");
    CHECK(f != NULL);
    if (f == NULL) {
        world_release(&made);
        return;
    }
    CHECK_EQ(worldfile_write(&made, f, &error), 1);
    fclose(f);

    thing_count = world_thing_count(&made);

    /* Read it back as bytes and cut the sprite words out of every thing. */
    f = fopen(path, "rb");
    CHECK(f != NULL);
    if (f == NULL) {
        world_release(&made);
        return;
    }

    fseek(f, 0, SEEK_END);
    length = ftell(f);
    fseek(f, 0, SEEK_SET);

    bytes = (unsigned char *)malloc((size_t)length);
    CHECK(bytes != NULL);
    if (bytes == NULL) {
        fclose(f);
        world_release(&made);
        return;
    }

    CHECK_EQ(fread(bytes, 1, (size_t)length, f), (size_t)length);
    fclose(f);

    /* Backwards, so that removing one record does not move the next one's
     * offset out from under the loop. */
    for (i = thing_count; i > 0; i--) {
        uint32_t cut_at = things_begin + (i - 1u) * thing_bytes_v3 + sprite_at;
        uint32_t after = cut_at + 8u;

        memmove(bytes + cut_at, bytes + after, (size_t)length - after);
        length -= 8;
    }

    /* And it is a version 2 file. */
    bytes[4] = 2;

    f = fopen(path, "wb");
    CHECK(f != NULL);
    if (f != NULL) {
        fwrite(bytes, 1, (size_t)length, f);
        fclose(f);
    }
    free(bytes);

    CHECK_EQ(world_init(&loaded, 8, 8, 8, 8, 8, 256), 1);

    f = fopen(path, "rb");
    CHECK(f != NULL);
    if (f == NULL) {
        world_release(&made);
        world_release(&loaded);
        return;
    }

    if (!worldfile_read(&loaded, f, &error)) {
        char sentence[256];

        fprintf(stderr, "    a version 2 file was refused: %s\n",
                worldfile_error_describe(&error, sentence, sizeof(sentence)));
        CHECK(0);
    }
    fclose(f);

    /* Everything that existed in version 2 came back. */
    CHECK_EQ(world_thing_count(&loaded), thing_count);
    CHECK_EQ(world_thing(&loaded, 1)->x, M(3));
    CHECK_EQ(world_thing(&loaded, 1)->kind, 7);
    CHECK_EQ(world_thing(&loaded, 1)->radius, 500);

    /* And what did not exist reads as nothing, rather than as whatever the next
     * record's first word happened to be -- which is what a reader that did not
     * know about the version would have produced. */
    CHECK_EQ(world_thing(&loaded, 1)->sprite_category, 0);
    CHECK_EQ(world_thing(&loaded, 1)->sprite_seed, 0);

    /* The world knows it was migrated, so a caller can say that its checksum
     * was not verified rather than letting a skipped check pass unmentioned. */
    CHECK_EQ(loaded.migrated_from, 2);

    /* A current file is not marked as migrated. */
    {
        struct world current;

        CHECK_EQ(world_init(&current, 8, 8, 8, 8, 8, 256), 1);

        f = fopen(SCRATCH_DIR "/version-three.world", "wb");
        if (f != NULL) {
            worldfile_write(&made, f, &error);
            fclose(f);

            f = fopen(SCRATCH_DIR "/version-three.world", "rb");
            if (f != NULL) {
                CHECK_EQ(worldfile_read(&current, f, &error), 1);
                fclose(f);
                CHECK_EQ(current.migrated_from, 0);
                CHECK_EQ(world_thing(&current, 1)->sprite_seed, 4242);
            }
        }

        world_release(&current);
    }

    world_release(&made);
    world_release(&loaded);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_round_trip();
    test_refusals();
    test_hash_notices_everything();
    test_a_version_two_file_still_loads();

    return vtt_test_finish("036-test-worldfile");
}
/* }}} */
