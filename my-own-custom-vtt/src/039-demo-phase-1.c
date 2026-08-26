/*
 * 039-demo-phase-1.c -- what phase one built, shown rather than described.
 *
 * Phase one claims that a world can be described, held, checked, and
 * round-tripped. This program demonstrates each of those and reports the numbers
 * behind them, measured during the run rather than quoted from a document -- a
 * document with a hard-coded measurement in it becomes wrong without anybody
 * noticing.
 *
 * It also deliberately breaks a world, so that the most important component of
 * the phase is visible: a validator that refuses to guess, and says which field
 * and why.
 *
 * Run through ./run-phase-demo 1, which is the front door.
 */

#include "037-fixture.h"
#include "035-worldfile.h"
#include "033-validate.h"
#include "031-region.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* Everything this writes is ephemeral and belongs in RAM. */
#define SCRATCH "/dev/shm/my-own-custom-vtt"

/* {{{ static double seconds_since */
static double seconds_since(clock_t start)
{
    /*
     * clock() is used here and nowhere in the simulation. A demo may read a
     * clock; the simulation may not, because a replay that consults the time of
     * day is a replay that does not reproduce.
     */
    return (double)(clock() - start) / (double)CLOCKS_PER_SEC;
}
/* }}} */

/* {{{ static void rule */
static void rule(const char *title)
{
    printf("\n");
    printf("  %s\n", title);
    printf("  ");
    {
        size_t i;
        size_t width = strlen(title);
        for (i = 0; i < width; i++) {
            printf("-");
        }
    }
    printf("\n\n");
}
/* }}} */

/* {{{ static void report_counts */
static void report_counts(const struct world *w)
{
    rule("What is in this world");

    printf("    %-12s %8s %10s\n", "block", "records", "bytes");
    printf("    %-12s %8u %10lu\n", "things",
           world_thing_count(w), (unsigned long)block_bytes_used(&w->things));
    printf("    %-12s %8u %10lu\n", "walls",
           world_wall_count(w), (unsigned long)block_bytes_used(&w->walls));
    printf("    %-12s %8u %10lu\n", "regions",
           world_region_count(w), (unsigned long)block_bytes_used(&w->regions));
    printf("    %-12s %8u %10lu\n", "vertices",
           world_vertex_count(w), (unsigned long)block_bytes_used(&w->vertices));
    printf("    %-12s %8u %10lu\n", "lights",
           world_light_count(w), (unsigned long)block_bytes_used(&w->lights));
    printf("    %-12s %8u %10lu\n", "strings",
           w->strings.used, (unsigned long)w->strings.used);

    printf("\n");
    printf("    Every count includes the empty record at index 0, which is\n");
    printf("    reserved so that nothing in this project checks for null.\n");
}
/* }}} */

/* {{{ static void report_nesting */
static void report_nesting(const struct world *w)
{
    uint32_t i;
    uint32_t deepest = 0;
    uint32_t deepest_region = 0;

    rule("How deeply regions nest");

    for (i = 1; i < world_region_count(w); i++) {
        uint32_t depth = region_depth(w, i);
        if (depth > deepest) {
            deepest = depth;
            deepest_region = i;
        }
    }

    for (i = 1; i < world_region_count(w); i++) {
        const struct region *r = world_region_const(w, i);
        uint32_t length = 0;
        const char *name = string_pool_read(&w->strings, r->name_offset, &length);
        uint32_t depth = region_depth(w, i);
        uint32_t indent;

        printf("    ");
        for (indent = 1; indent < depth; indent++) {
            printf("    ");
        }
        printf("%.*s", (int)length, name);

        if (r->parent != 0) {
            uint32_t parent_length = 0;
            const char *parent_name = string_pool_read(
                &w->strings, world_region_const(w, r->parent)->name_offset,
                &parent_length);
            printf("  (inside %.*s)", (int)parent_length, parent_name);
        }
        printf("\n");
    }

    printf("\n");
    printf("    Deepest chain: %u.\n", deepest);
    printf("    That number is the cost of a permission check, because deciding\n");
    printf("    whether a scope over one region covers another is a walk up it.\n");

    (void)deepest_region;
}
/* }}} */

/* {{{ static void report_validation */
static void report_validation(const struct world *w)
{
    struct validation_failure failure;
    char message[256];
    clock_t start;
    int i;
    const int repeats = 1000;

    rule("Checking it");

    start = clock();
    for (i = 0; i < repeats; i++) {
        world_validate(w, &failure);
    }

    printf("    Validated %d times in %.4f seconds.\n", repeats, seconds_since(start));
    printf("    That is %.1f microseconds a pass.\n",
           seconds_since(start) * 1000000.0 / (double)repeats);
    printf("\n");
    printf("    This runs whenever a world is loaded and after any structural\n");
    printf("    change. It is what every other file's right to skip checking is\n");
    printf("    bought with -- there are no bounds tests and no null tests in the\n");
    printf("    hot paths, because this pass already established they would pass.\n");

    if (world_validate(w, &failure)) {
        printf("\n    This world: valid.\n");
    } else {
        printf("\n    This world: INVALID -- %s\n",
               validation_failure_describe(&failure, message, sizeof(message)));
    }
}
/* }}} */

/* {{{ static void report_refusals */
static void report_refusals(void)
{
    struct validation_failure failure;
    char message[256];

    rule("And refusing to guess");

    printf("    A demo that only shows success has not shown the most important\n");
    printf("    thing this phase built. Each line below is a world broken on\n");
    printf("    purpose, and what the validator says about it.\n\n");

    {
        struct world w;
        fixture_make_two_rooms(&w);
        world_thing(&w, 2)->region = 9999;
        world_validate(&w, &failure);
        printf("    a body pointing at a region that does not exist\n");
        printf("      -> %s\n\n", validation_failure_describe(&failure, message, sizeof(message)));
        world_release(&w);
    }

    {
        struct world w;
        fixture_make_two_rooms(&w);
        world_wall(&w, 1)->bx = world_wall(&w, 1)->ax;
        world_wall(&w, 1)->by = world_wall(&w, 1)->ay;
        world_validate(&w, &failure);
        printf("    a wall with no length, which has no side to be on\n");
        printf("      -> %s\n\n", validation_failure_describe(&failure, message, sizeof(message)));
        world_release(&w);
    }

    {
        struct world w;
        fixture_make_two_rooms(&w);
        world_region(&w, 1)->parent = 1;
        world_validate(&w, &failure);
        printf("    a region that contains itself\n");
        printf("      -> %s\n\n", validation_failure_describe(&failure, message, sizeof(message)));
        world_release(&w);
    }

    {
        struct world w;
        fixture_make_two_rooms(&w);
        world_thing(&w, 4)->x += WC_ONE * 100;
        world_validate(&w, &failure);
        printf("    a body moved without its region being updated\n");
        printf("      -> %s\n\n", validation_failure_describe(&failure, message, sizeof(message)));
        world_release(&w);
    }

    printf("    None of these was repaired, clamped, or given a default. A\n");
    printf("    fallback is a warning and a warning is an error.\n");
}
/* }}} */

/* {{{ static long file_size */
static long file_size(const char *path)
{
    FILE *f = fopen(path, "rb");
    long size;

    if (f == NULL) {
        return -1;
    }

    fseek(f, 0, SEEK_END);
    size = ftell(f);
    fclose(f);

    return size;
}
/* }}} */

/* {{{ static int report_round_trip */
static int report_round_trip(const struct world *w)
{
    const char *first  = SCRATCH "/phase-1-demo-first.vttw";
    const char *second = SCRATCH "/phase-1-demo-second.vttw";
    struct worldfile_error error;
    struct world loaded;
    char message[256];
    clock_t start;
    size_t memory_bytes;
    long disk_bytes;
    int identical = 0;

    rule("Writing it down, and reading it back");

    memory_bytes = block_bytes_used(&w->things)
                 + block_bytes_used(&w->walls)
                 + block_bytes_used(&w->regions)
                 + block_bytes_used(&w->vertices)
                 + block_bytes_used(&w->lights)
                 + w->strings.used;

    {
        FILE *out = fopen(first, "wb");
        if (out == NULL) {
            printf("    Could not open %s for writing.\n", first);
            return 0;
        }
        start = clock();
        if (!worldfile_write(w, out, &error)) {
            printf("    Write failed: %s\n",
                   worldfile_error_describe(&error, message, sizeof(message)));
            fclose(out);
            return 0;
        }
        fclose(out);
        printf("    Wrote in %.4f seconds.\n", seconds_since(start));
    }

    disk_bytes = file_size(first);

    printf("    %lu bytes in memory, %ld bytes on disk.\n",
           (unsigned long)memory_bytes, disk_bytes);
    printf("\n");
    printf("    The file is the larger of the two because every field is written\n");
    printf("    at its own full width, one at a time, rather than the records\n");
    printf("    being dumped as they sit. Dumping is faster and is how a file\n");
    printf("    becomes unreadable on the next compiler, because whatever padding\n");
    printf("    the compiler chose would end up on the disk.\n\n");

    {
        FILE *in = fopen(first, "rb");
        world_init(&loaded, 4, 4, 4, 4, 4, 2048);

        if (in == NULL) {
            printf("    Could not reopen %s.\n", first);
            world_release(&loaded);
            return 0;
        }

        start = clock();
        if (!worldfile_read(&loaded, in, &error)) {
            printf("    Read failed: %s\n",
                   worldfile_error_describe(&error, message, sizeof(message)));
            fclose(in);
            world_release(&loaded);
            return 0;
        }
        fclose(in);
        printf("    Read in %.4f seconds.\n\n", seconds_since(start));
    }

    printf("    world hash before writing: %016llx\n",
           (unsigned long long)world_hash(w));
    printf("    world hash after reading:  %016llx\n",
           (unsigned long long)world_hash(&loaded));

    {
        FILE *out = fopen(second, "wb");
        if (out != NULL) {
            worldfile_write(&loaded, out, &error);
            fclose(out);
        }
    }

    {
        long a = file_size(first);
        long b = file_size(second);
        FILE *fa = fopen(first, "rb");
        FILE *fb = fopen(second, "rb");

        identical = (a == b) && (a > 0) && fa != NULL && fb != NULL;

        if (identical) {
            long i;
            for (i = 0; i < a; i++) {
                if (fgetc(fa) != fgetc(fb)) {
                    identical = 0;
                    break;
                }
            }
        }

        if (fa != NULL) fclose(fa);
        if (fb != NULL) fclose(fb);
    }

    printf("\n");
    if (identical) {
        printf("    Written, read, and written again: the two files are\n");
        printf("    byte for byte identical.\n");
        printf("\n");
        printf("    That is the whole claim of phase one.\n");
    } else {
        printf("    THE TWO FILES DIFFER. The round trip does not hold.\n");
    }

    world_release(&loaded);
    remove(first);
    remove(second);

    return identical;
}
/* }}} */

/* {{{ int main */
int main(void)
{
    struct world w;
    struct validation_failure failure;
    char message[256];

    printf("\n");
    printf("  ===========================================================\n");
    printf("   PHASE ONE -- The world holds still\n");
    printf("  ===========================================================\n");
    printf("\n");
    printf("  No network, no sight, no rules, no clock. Just a world that can\n");
    printf("  be described, held, checked, and written down.\n");

    if (!fixture_make_two_rooms(&w)) {
        printf("\n  Could not build the fixture world.\n");
        return 1;
    }

    if (!world_validate(&w, &failure)) {
        printf("\n  The fixture does not validate: %s\n",
               validation_failure_describe(&failure, message, sizeof(message)));
        world_release(&w);
        return 1;
    }

    report_counts(&w);
    report_nesting(&w);
    report_validation(&w);

    if (!report_round_trip(&w)) {
        world_release(&w);
        return 1;
    }

    report_refusals();

    printf("\n");
    printf("  Next: phase two, where this world can be seen from inside it.\n");
    printf("\n");

    world_release(&w);
    return 0;
}
/* }}} */
