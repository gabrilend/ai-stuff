/*
 * 105-demo-phase-11.c -- the last boundary.
 *
 * Phase eleven's claim is the generate-then-view split, tested where it is
 * hardest to fake: a second consumer, written last, speaking the same protocol,
 * with the server not knowing the difference.
 *
 * This is the in-process half. It builds a world, gives two people different
 * scopes over it, and reads the bytes each of them would receive -- decoding
 * them the way a view does rather than asking the filter what it would have
 * sent, because asking the filter is asking the accused.
 *
 * The out-of-process half is the wrapper: a real server, a real bridge, and two
 * real terminal views, all looking at one session at once.
 *
 * Run through ./run-phase-demo 11.
 */

#include "078-generate.h"
#include "059-outbound.h"
#include "070-scope.h"
#include "082-sprite.h"
#include "033-validate.h"
#include "031-region.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define M(n) ((wcoord)((n) * WC_ONE))

/* {{{ static void rule */
static void rule(const char *title)
{
    size_t i;
    size_t width = strlen(title);

    printf("\n  %s\n  ", title);
    for (i = 0; i < width; i++) {
        printf("-");
    }
    printf("\n\n");
}
/* }}} */

/*
 * What a stream contains, counted by reading it rather than by asking the writer.
 */
struct tally {
    uint32_t of[256];
    uint32_t instructions;
    uint32_t bytes;
};

/* {{{ static void read_the_stream */
static void read_the_stream(struct viewer *v, struct tally *into,
                            struct sprite *first_seen, int *saw_a_sprite)
{
    struct byte_buffer copy;
    uint32_t i;

    memset(into, 0, sizeof(*into));
    into->bytes = v->outbound.count;

    if (!buffer_init(&copy, v->outbound.count + 16u)) {
        return;
    }

    for (i = 0; i < v->outbound.count; i++) {
        copy.bytes[copy.count] = v->outbound.bytes[i];
        copy.count++;
    }

    for (;;) {
        struct instruction in;

        if (instruction_decode(&in, &copy) != PROTO_OK) {
            break;
        }

        into->of[in.opcode]++;
        into->instructions++;

        /*
         * The first appearance seen, reassembled -- so the demo can show that
         * what arrives on the wire really is a sprite rather than a number that
         * is claimed to be one.
         */
        if (in.opcode == OP_LAYER && !*saw_a_sprite) {
            if (first_seen->layer_count < SPRITE_MAX_LAYERS) {
                struct sprite_layer *l =
                    &first_seen->layers[first_seen->layer_count];

                l->shape    = (uint8_t)in.slot[2];
                l->offset_x = (int8_t)(uint8_t)(in.slot[4] & 0xFFu);
                l->offset_y = (int8_t)(uint8_t)(in.slot[5] & 0xFFu);
                l->radius   = (uint8_t)in.slot[6];
                first_seen->palette[0] = in.slot[3];
                first_seen->layer_count++;
            }
        }
    }

    if (first_seen->layer_count > 0) {
        *saw_a_sprite = 1;
    }

    buffer_release(&copy);
}
/* }}} */

/* {{{ static uint32_t body_at */
static uint32_t body_at(struct world *w, wcoord x, wcoord y,
                        const char *wearing, uint32_t seed)
{
    uint32_t index = world_add_thing(w);
    struct thing *t = world_thing(w, index);

    t->x = x;
    t->y = y;
    t->facing = 0;
    t->sight_arc = 65535;
    t->sight_range = (uint32_t)M(30);
    t->radius = (uint16_t)(WC_ONE / 2);
    t->kind = 1;
    t->region = region_deepest_containing(w, x, y);
    t->sprite_category = string_pool_add(&w->strings, wearing,
                                         (uint32_t)strlen(wearing));
    t->sprite_seed = seed;

    return index;
}
/* }}} */

/* {{{ int main */
int main(void)
{
    struct world w;
    struct pool *threads;
    struct session session;
    struct viewer_set viewers;
    struct description d;
    struct fault_list faults;
    const char *why = "";
    uint32_t things, walls, regions, vertices, lights, strings;

    uint32_t alice, bob;
    uint32_t her_body, his_body;
    struct viewpoint from;
    struct tally hers, his;
    struct sprite seen;
    int saw = 0;
    int beat;

    setvbuf(stdout, NULL, _IOLBF, 0);

    printf("\n");
    printf("  ===============================================================\n");
    printf("   PHASE ELEVEN -- the split, at the last boundary\n");
    printf("  ===============================================================\n");

    rule("A place, generated");

    if (!description_read_file(&d,
            "/mnt/mtwo/programming/ai-stuff/my-own-custom-vtt"
            "/input/descriptions/the-old-inn", &faults)) {
        faults_report(&faults, "the-old-inn");
        return 1;
    }

    generate_capacity_hint(&d, &things, &walls, &regions,
                           &vertices, &lights, &strings);
    things += 32;
    strings += 512;

    if (!world_init(&w, things, walls, regions, vertices, lights, strings)) {
        printf("    no memory\n");
        return 1;
    }

    if (!generate(&w, &d, 90210, NULL, NULL, &why)) {
        printf("    could not generate: %s\n", why);
        return 1;
    }

    printf("    %s: %u things, %u walls, %u regions\n", d.name,
           (unsigned)(world_thing_count(&w) - 1u),
           (unsigned)(world_wall_count(&w) - 1u),
           (unsigned)(world_region_count(&w) - 1u));

    threads = pool_start(2);
    session_start(&session, &w, threads, 90210, 8, 10);
    viewer_set_init(&viewers, 8);

    /*
     * Two people, standing in different rooms, each commanding their own body.
     * Different places means different fog means different streams, which is the
     * property the whole outbound path exists to have.
     */
    her_body = body_at(&w, M(4), M(4), "adventurer", 1001);
    his_body = body_at(&w, M(40), M(6), "adventurer", 1002);
    sim_fit_to_world(&session.sim);

    alice = viewer_add(&viewers, &w, WC_ONE);
    bob   = viewer_add(&viewers, &w, WC_ONE);
    viewer_at(&viewers, alice)->state = VIEWER_CONNECTED;
    viewer_at(&viewers, bob)->state = VIEWER_CONNECTED;

    scope_make_list(&w, alice, STYLE_DRIVEN, &her_body, 1, "her");
    scope_make_list(&w, bob, STYLE_DRIVEN, &his_body, 1, "his");

    for (beat = 0; beat < 12; beat++) {
        session_tick(&session);

        fog_fold(&viewer_at(&viewers, alice)->fog, &w, her_body);
        fog_fold(&viewer_at(&viewers, bob)->fog, &w, his_body);
    }

    rule("Two people, one world, two streams");

    memset(&seen, 0, sizeof(seen));

    viewpoint_gather(&from, &w, alice);
    outbound_build(&session, &viewers, alice, &from);
    read_the_stream(viewer_at(&viewers, alice), &hers, &seen, &saw);

    viewpoint_gather(&from, &w, bob);
    outbound_build(&session, &viewers, bob, &from);
    {
        struct sprite ignored;
        int also = 1;

        memset(&ignored, 0, sizeof(ignored));
        read_the_stream(viewer_at(&viewers, bob), &his, &ignored, &also);
    }

    printf("      instruction     hers     his\n");
    printf("      -----------   ------  ------\n");
    printf("      %-11s   %6u  %6u\n", "hello",
           (unsigned)hers.of[OP_HELLO], (unsigned)his.of[OP_HELLO]);
    printf("      %-11s   %6u  %6u\n", "tick",
           (unsigned)hers.of[OP_TICK], (unsigned)his.of[OP_TICK]);
    printf("      %-11s   %6u  %6u\n", "wall",
           (unsigned)hers.of[OP_WALL], (unsigned)his.of[OP_WALL]);
    printf("      %-11s   %6u  %6u\n", "thing",
           (unsigned)hers.of[OP_THING], (unsigned)his.of[OP_THING]);
    printf("      %-11s   %6u  %6u\n", "layer",
           (unsigned)hers.of[OP_LAYER], (unsigned)his.of[OP_LAYER]);
    printf("      %-11s   %6u  %6u\n", "fan",
           (unsigned)hers.of[OP_FAN], (unsigned)his.of[OP_FAN]);
    printf("      %-11s   %6u  %6u\n", "bytes",
           (unsigned)hers.bytes, (unsigned)his.bytes);

    printf("\n    They are standing in different rooms, so they have remembered\n");
    printf("    different walls and can see different things. Neither stream is\n");
    printf("    a filtered copy of a fuller one -- each is built from what that\n");
    printf("    person may know, and there is no fuller one anywhere.\n");

    rule("What an appearance costs");

    printf("    A sprite is at most six layers, and each layer is one\n");
    printf("    instruction: which thing, which layer, the shape, the colour,\n");
    printf("    two offsets and a radius. Every one a small integer.\n\n");

    {
        uint32_t layer_bytes = hers.of[OP_LAYER] * 12u;

        printf("      %u appearance instructions of %u total\n",
               (unsigned)hers.of[OP_LAYER], (unsigned)hers.instructions);
        printf("      about %u bytes of %u, which is %u%% of an update\n",
               (unsigned)layer_bytes, (unsigned)hers.bytes,
               hers.bytes > 0 ? (unsigned)((layer_bytes * 100u) / hers.bytes) : 0u);
        printf("      at twenty beats a second, about %u bytes a second\n",
               (unsigned)(layer_bytes * 20u));
    }

    printf("\n    Sent every update rather than once, because an update is the\n");
    printf("    whole picture -- which is what makes a dropped one cost a beat of\n");
    printf("    freshness and nothing else. Sending an appearance once and\n");
    printf("    remembering would leave anybody who lost a frame with a thing\n");
    printf("    that has no face, permanently, and nothing anywhere to notice.\n");

    rule("And it really is a sprite at the other end");

    if (!saw) {
        printf("    Nothing was wearing anything, which should not happen here.\n");
    } else {
        uint32_t layer;

        printf("    Reassembled from the instructions, the way a view does:\n\n");

        for (layer = 0; layer < seen.layer_count; layer++) {
            printf("      layer %u  %-8s at %+3d,%+3d  radius %u\n",
                   (unsigned)layer,
                   shape_name(seen.layers[layer].shape),
                   (int)seen.layers[layer].offset_x,
                   (int)seen.layers[layer].offset_y,
                   (unsigned)seen.layers[layer].radius);
        }

        printf("\n    Four shapes, three palette slots, five motions. A view\n");
        printf("    RENDERS this; it does not own it. The alternative was porting\n");
        printf("    the generator into every view and hoping they agreed.\n");
    }

    rule("The second view changed nothing in the server");

    printf("    Except that it found something.\n\n");
    printf("    The hello -- who you are and how big the world is -- was written\n");
    printf("    once, when somebody joined, into a buffer that outbound_build\n");
    printf("    clears at the top of every beat. It never arrived. The browser\n");
    printf("    had been running for six phases without receiving one; it\n");
    printf("    defaulted to body zero, which is nothing, so it simply never\n");
    printf("    highlighted anybody's own body and nobody noticed.\n\n");
    printf("    A terminal cannot draw a map at all without the extent, so the\n");
    printf("    second view found it in its first run. That is what a second\n");
    printf("    consumer is for, and it is a PHASE FOUR DEFECT rather than a\n");
    printf("    phase eleven requirement.\n\n");
    printf("    It is part of every update now: %u hello%s in this one.\n",
           (unsigned)hers.of[OP_HELLO], hers.of[OP_HELLO] == 1 ? "" : "s");

    viewer_set_release(&viewers);
    session_release(&session);
    world_release(&w);
    pool_stop(threads);

    printf("\n");
    return 0;
}
/* }}} */
