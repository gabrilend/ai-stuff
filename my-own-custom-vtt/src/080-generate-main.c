/*
 * 080-generate-main.c -- a description and a seed become a world file.
 *
 * Four stages, four programs' worth of work, one command:
 *
 *   validate -- refuse before anything expensive
 *   lay out  -- rooms and corridors as a graph, with no coordinates
 *   realise  -- topology into segments and polygons
 *   furnish  -- things standing in it
 *
 * Then check that what came out is what was asked for -- a different question
 * from whether it is a coherent world, and the only one that can tell a
 * generator from a random number visualiser.
 *
 * Usage:
 *   080-generate <description> <seed> <output>
 */

#include "078-generate.h"
#include "033-validate.h"
#include "035-worldfile.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* {{{ static double wall_now */
static double wall_now(void)
{
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (double)now.tv_sec + ((double)now.tv_nsec / 1000000000.0);
}
/* }}} */

/* {{{ int main */
int main(int argc, char **argv)
{
    struct description d;
    struct fault_list faults;
    struct world w;
    struct layout l;
    struct validation_failure failure;
    const char *why = NULL;
    char message[512];
    uint64_t seed;
    double started;

    uint32_t things, walls, regions, vertices, lights, strings;

    setvbuf(stdout, NULL, _IOLBF, 0);

    if (argc < 4) {
        uint32_t count = 0;
        const char *const *words = description_vocabulary(&count);
        uint32_t i;

        printf("usage: %s <description> <seed> <output>\n\n", argv[0]);
        printf("The words a description may use:\n\n");

        for (i = 0; i < count; i++) {
            printf("    %s\n", words[i]);
        }

        printf("\nAnd no others. A closed vocabulary has nowhere for a\n");
        printf("plausible-sounding invention to go.\n");
        return 1;
    }

    seed = strtoull(argv[2], NULL, 10);

    /* Stage one: the wall. Refuse before anything expensive happens. */
    if (!description_read_file(&d, argv[1], &faults)) {
        faults_report(&faults, argv[1]);
        return 1;
    }

    printf("  %s\n", d.name);
    printf("    %u rooms, %u to %u metres, %u loop%s, %u light%s\n",
           d.rooms, d.smallest, d.largest,
           d.loops, (d.loops == 1) ? "" : "s",
           d.lights, (d.lights == 1) ? "" : "s");

    if (d.required_count > 0) {
        uint32_t i;
        printf("    requiring:");
        for (i = 0; i < d.required_count; i++) {
            printf("%s %s", (i > 0) ? "," : "", d.required[i]);
        }
        printf("\n");
    }

    printf("    seed %llu\n\n", (unsigned long long)seed);

    generate_capacity_hint(&d, &things, &walls, &regions,
                           &vertices, &lights, &strings);

    if (!world_init(&w, things, walls, regions, vertices, lights, strings)) {
        printf("  could not make room for a world that size\n");
        return 1;
    }

    started = wall_now();

    if (!generate(&w, &d, seed, NULL, &l, &why)) {
        printf("  could not generate: %s\n", why);
        world_release(&w);
        return 1;
    }

    /* Where it came from, so the file can say. */
    w.seed = seed;
    snprintf(w.origin, sizeof(w.origin), "%s", d.name);

    printf("  laid out   %u rooms, %u passages, %u loop%s\n",
           l.node_count, l.edge_count, layout_loop_count(&l),
           (layout_loop_count(&l) == 1) ? "" : "s");
    printf("  realised   %u walls, %u regions\n",
           world_wall_count(&w) - 1, world_region_count(&w) - 1);
    printf("  furnished  %u things, %u lights\n",
           world_thing_count(&w) - 1, world_light_count(&w) - 1);
    printf("  took       %.4f seconds\n\n", wall_now() - started);

    /* Is it a coherent world? */
    if (!world_validate(&w, &failure)) {
        printf("  the generated world does not validate: %s\n",
               validation_failure_describe(&failure, message, sizeof(message)));
        world_release(&w);
        return 1;
    }

    /*
     * And is it the world that was ASKED FOR? A different question -- the
     * validator would happily pass a coherent dungeon with three rooms when
     * somebody wanted eight.
     */
    if (!generate_check(&w, &l, &d, &faults)) {
        printf("  it is a valid world, but not the one described:\n\n");
        faults_report(&faults, "the generated world");
        world_release(&w);
        return 1;
    }

    printf("  valid, and it is what was described.\n");

    {
        FILE *out = fopen(argv[3], "wb");
        struct worldfile_error trouble;

        if (out == NULL) {
            printf("  could not open %s for writing\n", argv[3]);
            world_release(&w);
            return 1;
        }

        if (!worldfile_write(&w, out, &trouble)) {
            printf("  could not write it: %s\n",
                   worldfile_error_describe(&trouble, message, sizeof(message)));
            fclose(out);
            world_release(&w);
            return 1;
        }

        fclose(out);
    }

    printf("  written to %s\n", argv[3]);
    printf("  world hash %016llx\n", (unsigned long long)world_hash(&w));
    printf("\n");
    printf("  That file carries the description's name and the seed, so it can\n");
    printf("  say where it came from. Change one line and regenerate -- a map is\n");
    printf("  not a thing you replace.\n");

    world_release(&w);
    return 0;
}
/* }}} */
