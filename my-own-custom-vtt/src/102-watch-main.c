/*
 * 102-watch-main.c -- the same session, in a terminal.
 *
 * A SECOND VIEW, SPEAKING THE SAME PROTOCOL, WITH NO SERVER CHANGES AT ALL.
 *
 * That constraint is the entire point of this program. If a terminal view needs
 * one line of the server changed, then the protocol was never a protocol -- it
 * was the browser's interface with extra steps. This is the generate-then-view
 * split tested at the last boundary, and it is the only test of it that cannot
 * be faked, because the second consumer is written months later by somebody who
 * was not in the room when the first one was.
 *
 * It knocks on the door itself and holds its own private port. It does not go
 * through the bridge: the bridge exists to serve a browser, and a terminal does
 * not need serving.
 *
 * WHAT IT IS NOT: it does not send commands. It watches. A view that silently
 * could not do something would be a view that lies, so it says so at startup
 * rather than leaving somebody pressing keys at it.
 *
 * WHAT IT LOSES: a sprite is six layers and a terminal has one character per
 * body. It draws the body layer's shape as a glyph and its colour as the colour,
 * and everything else is dropped. That is a lossy rendering of the paintbrush and
 * it is the DRAWING that is reduced, never the data -- the same instructions
 * arrive here as arrive at the browser.
 *
 * Usage:
 *   102-watch <address> <door-port> <name>
 *   102-watch <address> <door-port> <name> --plain     -- no colour
 *   102-watch <address> <door-port> <name> --beats N   -- stop after N updates
 */

#include "061-door.h"
#include "056-protocol.h"
#include "092-canvas.h"
#include "082-sprite.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <time.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>

/* The grid the world is drawn on. Eighty columns is a terminal. */
#define VIEW_WIDTH  78
#define VIEW_HEIGHT 30

/*
 * Characters are about twice as tall as they are wide, so a world drawn with the
 * same scale on both axes comes out squashed. Everything horizontal is stretched
 * by this, which is the one piece of arithmetic a terminal renderer has that a
 * pixel one does not.
 */
#define CHARACTER_ASPECT 2

#define MAX_THINGS 256
#define MAX_WALLS  512
#define MAX_LAYERS 6

struct seen_layer {
    uint8_t  shape;
    uint32_t colour;
    int8_t   ox;
    int8_t   oy;
    uint8_t  radius;
};

struct seen_thing {
    uint32_t index;
    int32_t  x;
    int32_t  y;
    uint32_t kind;
    uint8_t  motion;

    struct seen_layer layers[MAX_LAYERS];
    uint32_t          layer_count;
};

struct seen_wall {
    int32_t ax, ay, bx, by;
};

struct picture {
    uint64_t tick;

    struct seen_thing things[MAX_THINGS];
    uint32_t          thing_count;

    struct seen_wall walls[MAX_WALLS];
    uint32_t         wall_count;

    int32_t min_x, min_y, max_x, max_y;
    uint32_t me;
};

static volatile sig_atomic_t asked_to_stop = 0;

/* {{{ static void note_the_interrupt */
static void note_the_interrupt(int which)
{
    (void)which;
    asked_to_stop = 1;
}
/* }}} */

/* {{{ static int32_t as_signed */
static int32_t as_signed(uint32_t value)
{
    return (int32_t)value;
}
/* }}} */

/* {{{ static int8_t as_signed_byte */
static int8_t as_signed_byte(uint32_t value)
{
    /* A slot's width is the field's width, so an eight-bit signed value arrives
     * as 0 to 255 and the reader is the only thing that knows it was negative. */
    return (int8_t)(uint8_t)(value & 0xFFu);
}
/* }}} */

/* {{{ static struct seen_thing *thing_named */
static struct seen_thing *thing_named(struct picture *p, uint32_t index)
{
    uint32_t i;

    for (i = 0; i < p->thing_count; i++) {
        if (p->things[i].index == index) {
            return &p->things[i];
        }
    }
    return NULL;
}
/* }}} */

/*
 * One instruction into the picture being assembled.
 *
 * The same switch the browser has, in a different language, over the same
 * numbers. That is what "the same protocol" means when it is true.
 */
/* {{{ static int take_instruction */
static int take_instruction(struct picture *building, const struct instruction *in)
{
    switch (in->opcode) {
    case OP_HELLO:
        building->me    = in->slot[0];
        building->min_x = as_signed(in->slot[1]);
        building->min_y = as_signed(in->slot[2]);
        building->max_x = as_signed(in->slot[3]);
        building->max_y = as_signed(in->slot[4]);
        break;

    case OP_TICK:
        building->tick = ((uint64_t)in->slot[1] << 32) | (uint64_t)in->slot[0];
        break;

    case OP_WALL:
        if (building->wall_count < MAX_WALLS) {
            struct seen_wall *wl = &building->walls[building->wall_count];

            wl->ax = as_signed(in->slot[1]);
            wl->ay = as_signed(in->slot[2]);
            wl->bx = as_signed(in->slot[3]);
            wl->by = as_signed(in->slot[4]);
            building->wall_count++;
        }
        break;

    case OP_THING:
        if (building->thing_count < MAX_THINGS) {
            struct seen_thing *t = &building->things[building->thing_count];

            memset(t, 0, sizeof(*t));
            t->index  = in->slot[0];
            t->x      = as_signed(in->slot[1]);
            t->y      = as_signed(in->slot[2]);
            t->kind   = in->slot[5];
            t->motion = (uint8_t)in->slot[6];
            building->thing_count++;
        }
        break;

    case OP_LAYER: {
        struct seen_thing *wearer = thing_named(building, in->slot[0]);

        /*
         * The layers of a body always follow it, so the body is already here. A
         * layer for a body that never arrived is dropped: it would be an
         * appearance with nothing wearing it, and the only way to get one is a
         * stream that was cut, which the missing END already handles.
         */
        if (wearer != NULL && wearer->layer_count < MAX_LAYERS) {
            struct seen_layer *l = &wearer->layers[wearer->layer_count];

            l->shape  = (uint8_t)in->slot[2];
            l->colour = in->slot[3];
            l->ox     = as_signed_byte(in->slot[4]);
            l->oy     = as_signed_byte(in->slot[5]);
            l->radius = (uint8_t)in->slot[6];
            wearer->layer_count++;
        }
        break;
    }

    case OP_END:
        return 1;

    default:
        /* Fans, refusals and recalls. A watcher issues nothing, so a refusal is
         * never for it, and a recall changes nothing it is holding -- the next
         * whole picture is the correction. */
        break;
    }

    return 0;
}
/* }}} */

/*
 * The glyph a shape becomes.
 *
 * A DELIBERATE LOSS, and the table is where it is admitted. Six layers become
 * one character: the body's shape and the body's colour, and nothing else.
 */
static const char shape_glyphs[SHAPE_COUNT] = { 'o', '#', 'A', '0' };

/* {{{ static char glyph_for */
static char glyph_for(const struct seen_thing *t)
{
    if (t->layer_count == 0) {
        /* Wearing nothing. Normal -- a hand-built fixture has things with no
         * sprite. Drawn as a plain mark rather than as an error. */
        return '*';
    }

    if (t->layers[0].shape >= SHAPE_COUNT) {
        return '?';
    }

    return shape_glyphs[t->layers[0].shape];
}
/* }}} */

/* {{{ static void wear_colour */
static void wear_colour(const struct seen_thing *t, int coloured, char *into,
                        uint32_t capacity)
{
    uint32_t packed;

    into[0] = '\0';

    if (!coloured) {
        return;
    }

    packed = (t->layer_count > 0) ? t->layers[0].colour : 0x998877u;

    snprintf(into, capacity, "\033[38;2;%u;%u;%um",
             (unsigned)((packed >> 16) & 0xFFu),
             (unsigned)((packed >> 8) & 0xFFu),
             (unsigned)(packed & 0xFFu));
}
/* }}} */

/* {{{ static void draw_the_picture */
static void draw_the_picture(const struct picture *p, int coloured,
                             uint64_t frames, uint64_t bytes, uint64_t layers)
{
    struct canvas c;
    int32_t span_x = p->max_x - p->min_x;
    int32_t span_y = p->max_y - p->min_y;
    uint32_t i;
    uint32_t y;

    if (span_x <= 0 || span_y <= 0) {
        printf("  waiting for the world's extent ...\n");
        return;
    }

    if (!canvas_init(&c, VIEW_WIDTH, VIEW_HEIGHT, ALPHABET_CARVED)) {
        printf("  the view is larger than a canvas may be\n");
        return;
    }

    /*
     * World to cell. One scale for both axes so the map is not distorted, times
     * the character aspect on the horizontal -- which is the one piece of
     * arithmetic a terminal renderer has that a pixel one does not.
     */
    {
        int64_t by_width  = ((int64_t)(VIEW_WIDTH - 2) << 16) / span_x;
        int64_t by_height = ((int64_t)(VIEW_HEIGHT - 2) << 16) / span_y;
        int64_t scale = (by_width / CHARACTER_ASPECT < by_height)
                        ? by_width / CHARACTER_ASPECT : by_height;

        /* Centred, so a world that is wider than it is tall does not sit in
         * the bottom half of the screen with nothing above it. */
        uint32_t drawn_wide = (uint32_t)(((int64_t)span_x * scale
                                          * CHARACTER_ASPECT) >> 16);
        uint32_t drawn_tall = (uint32_t)(((int64_t)span_y * scale) >> 16);
        uint32_t pad_x = (VIEW_WIDTH > drawn_wide)
                         ? (VIEW_WIDTH - drawn_wide) / 2u : 0u;
        uint32_t pad_y = (VIEW_HEIGHT - 2u > drawn_tall)
                         ? (VIEW_HEIGHT - 2u - drawn_tall) / 2u : 0u;

        #define CELL_X(wx) (pad_x + (uint32_t)(((int64_t)((wx) - p->min_x) * scale \
                                        * CHARACTER_ASPECT) >> 16))
        #define CELL_Y(wy) (VIEW_HEIGHT - 2u - pad_y \
                            - (uint32_t)(((int64_t)((wy) - p->min_y) * scale) >> 16))

        for (i = 0; i < p->wall_count; i++) {
            const struct seen_wall *wl = &p->walls[i];
            uint32_t ax = CELL_X(wl->ax);
            uint32_t ay = CELL_Y(wl->ay);
            uint32_t bx = CELL_X(wl->bx);
            uint32_t by = CELL_Y(wl->by);

            /*
             * Axis-aligned walls are drawn as strokes, so their corners join
             * properly. A diagonal is drawn as slashes instead: strokes have no
             * diagonal and pretending otherwise would produce junctions that are
             * wrong in a way somebody would have to squint at.
             */
            if (ay == by) {
                canvas_across(&c, ay, ax, bx);
            } else if (ax == bx) {
                canvas_down(&c, ax, ay, by);
            } else {
                int32_t steps = (int32_t)((bx > ax) ? bx - ax : ax - bx);
                int32_t down  = (int32_t)((by > ay) ? by - ay : ay - by);
                int32_t most  = (steps > down) ? steps : down;
                int32_t step;

                if (most == 0) {
                    most = 1;
                }

                for (step = 0; step <= most; step++) {
                    uint32_t x = (uint32_t)((int32_t)ax
                                 + ((int32_t)bx - (int32_t)ax) * step / most);
                    uint32_t cy = (uint32_t)((int32_t)ay
                                  + ((int32_t)by - (int32_t)ay) * step / most);

                    canvas_put(&c, x, cy,
                               ((bx > ax) == (by > ay)) ? '\\' : '/');
                }
            }
        }

        for (i = 0; i < p->thing_count; i++) {
            const struct seen_thing *t = &p->things[i];

            canvas_put(&c, CELL_X(t->x), CELL_Y(t->y), glyph_for(t));
        }

        #undef CELL_X
        #undef CELL_Y
    }

    /* Home the cursor rather than clearing, so the picture does not flash. */
    printf("\033[H");

    for (y = 0; y < c.height; y++) {
        uint32_t x;

        for (x = 0; x < c.width; x++) {
            if (c.glyphs[y][x] != '\0') {
                const struct seen_thing *wearer = NULL;
                char tint[32];
                uint32_t n;

                /* Which body is standing here, so its own colour is used. */
                for (n = 0; n < p->thing_count; n++) {
                    /* Compared by glyph position rather than by recomputing the
                     * mapping, because the mapping is already gone. */
                    if (c.glyphs[y][x] == glyph_for(&p->things[n])) {
                        wearer = &p->things[n];
                        break;
                    }
                }

                if (wearer != NULL) {
                    wear_colour(wearer, coloured, tint, sizeof(tint));
                    printf("%s%c%s", tint, c.glyphs[y][x],
                           coloured ? "\033[0m" : "");
                } else {
                    printf("%c", c.glyphs[y][x]);
                }
            } else if ((c.strokes[y][x] & 0x0Fu) != 0) {
                printf("%s%s%s",
                       coloured ? "\033[38;2;120;110;95m" : "",
                       canvas_glyph_for(c.strokes[y][x], ALPHABET_CARVED),
                       coloured ? "\033[0m" : "");
            } else {
                printf(" ");
            }
        }

        printf("\033[K\n");
    }

    printf("\033[K  beat %-8llu  %u things  %u walls\n",
           (unsigned long long)p->tick,
           (unsigned)p->thing_count, (unsigned)p->wall_count);
    printf("\033[K  %llu updates, %llu bytes, %llu appearance instructions"
           " (%llu bytes a beat)\n",
           (unsigned long long)frames, (unsigned long long)bytes,
           (unsigned long long)layers,
           frames > 0 ? (unsigned long long)(bytes / frames) : 0ull);
    printf("\033[K  watching only -- this view sends nothing. ctrl-c to stop.\n");
}
/* }}} */

/* {{{ int main */
int main(int argc, char **argv)
{
    const char *address;
    uint16_t door_port;
    const char *name;
    int coloured = 1;
    uint64_t stop_after = 0;

    int server_socket;
    uint8_t outcome = 0;
    uint16_t private_port = 0;

    struct byte_buffer inbound;
    static struct picture shown;
    static struct picture building;
    uint8_t chunk[65536];

    uint64_t frames = 0;
    uint64_t bytes = 0;
    uint64_t layers = 0;
    int i;

    setvbuf(stdout, NULL, _IOLBF, 0);

    if (argc < 4) {
        printf("usage: %s <address> <door-port> <name> [--plain] [--beats N]\n",
               argv[0]);
        printf("\n");
        printf("A second view of the same session, in a terminal. It speaks the\n");
        printf("same protocol the browser does and the server does not know the\n");
        printf("difference.\n");
        return 1;
    }

    address = argv[1];
    door_port = (uint16_t)atoi(argv[2]);
    name = argv[3];

    for (i = 4; i < argc; i++) {
        if (strcmp(argv[i], "--plain") == 0) {
            coloured = 0;
        } else if (strcmp(argv[i], "--beats") == 0 && i + 1 < argc) {
            stop_after = (uint64_t)strtoull(argv[i + 1], NULL, 10);
            i++;
        } else {
            printf("102-watch: '%s' is not an option this program knows.\n",
                   argv[i]);
            return 1;
        }
    }

    signal(SIGINT, note_the_interrupt);
    signal(SIGTERM, note_the_interrupt);

    if (strcmp(address, "127.0.0.1") != 0 && strcmp(address, "localhost") != 0) {
        printf("This view can only reach a server on this machine so far.\n");
        printf("Given: %s\n", address);
        return 1;
    }

    printf("knocking on %s:%u as \"%s\" ...\n", address, door_port, name);

    server_socket = door_join_as_client(door_port, name, &outcome, &private_port);

    if (server_socket < 0) {
        printf("  refused: %s\n", join_sentence(outcome));
        return 1;
    }

    printf("  in, on port %u\n", private_port);
    printf("  a sprite is six layers and a terminal has one character, so this\n");
    printf("  draws the body and drops the rest. The data is whole; the drawing\n");
    printf("  is not.\n\n");

    if (!buffer_init(&inbound, 65536)) {
        printf("  no memory for a buffer\n");
        close(server_socket);
        return 1;
    }

    memset(&shown, 0, sizeof(shown));
    memset(&building, 0, sizeof(building));

    /* Clear once, then home the cursor every frame, so the picture does not
     * flash on every beat. */
    printf("\033[2J");

    while (!asked_to_stop) {
        ssize_t got = recv(server_socket, chunk, sizeof(chunk), MSG_DONTWAIT);

        if (got > 0) {
            ssize_t at;

            bytes += (uint64_t)got;

            for (at = 0; at < got; at++) {
                if (inbound.count < inbound.capacity) {
                    inbound.bytes[inbound.count] = chunk[at];
                    inbound.count++;
                }
            }
        } else if (got == 0) {
            printf("\n  the server hung up\n");
            break;
        } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
            printf("\n  lost the server\n");
            break;
        }

        for (;;) {
            struct instruction in;
            uint32_t before = inbound.read_position;
            uint8_t why = instruction_decode(&in, &inbound);

            if (why == PROTO_TRUNCATED) {
                /* Not all of it has arrived. Put the cursor back and wait --
                 * a half-read instruction is not an error, it is a network. */
                inbound.read_position = before;
                break;
            }

            if (why != PROTO_OK) {
                printf("\n  the stream could not be read: %u\n", (unsigned)why);
                asked_to_stop = 1;
                break;
            }

            if (in.opcode == OP_LAYER) {
                layers++;
            }

            if (take_instruction(&building, &in)) {
                /*
                 * An END arrived, so the picture is whole. Swapped rather than
                 * amended -- an update is the whole picture, which is what makes
                 * a dropped one cost a beat of freshness and nothing else.
                 */
                shown = building;
                memset(&building, 0, sizeof(building));

                /* The extent and who you are arrive once, in the hello, so they
                 * are carried forward rather than being lost every beat. */
                building.min_x = shown.min_x;
                building.min_y = shown.min_y;
                building.max_x = shown.max_x;
                building.max_y = shown.max_y;
                building.me    = shown.me;

                frames++;
                draw_the_picture(&shown, coloured, frames, bytes, layers);

                if (stop_after > 0 && frames >= stop_after) {
                    asked_to_stop = 1;
                }
            }

            /* Everything read so far can be forgotten once the buffer is
             * drained, so it does not grow without bound over an evening. */
            if (inbound.read_position == inbound.count) {
                buffer_clear(&inbound);
            }
        }

        {
            struct timespec rest;

            rest.tv_sec = 0;
            rest.tv_nsec = 5000000;    /* Five milliseconds. */
            nanosleep(&rest, NULL);
        }
    }

    printf("\n");
    printf("  %llu updates, %llu bytes, %llu appearance instructions\n",
           (unsigned long long)frames, (unsigned long long)bytes,
           (unsigned long long)layers);

    if (frames > 0) {
        printf("  %llu bytes an update, of which appearances were about %llu\n",
               (unsigned long long)(bytes / frames),
               (unsigned long long)((layers * 12ull) / frames));
    }

    printf("  goodbye\n");

    buffer_release(&inbound);
    close(server_socket);
    return 0;
}
/* }}} */
