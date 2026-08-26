/*
 * 094-creature.c -- grouping chambers into bands, and hanging fins off them.
 *
 * Two halves. The tiling, which is arithmetic and is the same shape for every
 * run of a given creature -- so a deformation means something. And the
 * attachments, one small function per animal, each of which asks the tiling
 * where its walls are rather than being told a column.
 *
 * See 094-creature.h for why ornament is never made of walls.
 */

#include "094-creature.h"

#include <string.h>

/*
 * How the eight cells are grouped into bands, per creature. This is the whole of
 * what makes one animal a different shape from another, so it is data rather
 * than code -- four rows you can read side by side and compare.
 *
 * A band is a horizontal run of chambers sharing walls. Indent is columns from
 * the body's left edge, and it is what tapers a fish and squares off a mammoth.
 */
#define MAX_BANDS 4
#define MAX_IN_BAND 4

struct band_plan {
    uint8_t  cells[MAX_IN_BAND];
    uint8_t  count;
    uint8_t  indent_eighths;   /* Of the slack between this band and the widest. */
};

struct creature_plan {
    const char *name;
    struct band_plan bands[MAX_BANDS];
    uint8_t band_count;

    /* Room the attachments need around the body. */
    uint8_t margin_left;
    uint8_t margin_right;
    uint8_t margin_top;
    uint8_t margin_bottom;
};

/*
 * Indents are in EIGHTHS OF THE SLACK rather than in columns, so a band that
 * happens to be narrow is centred or pushed by the same proportion whatever the
 * numbers are. A column count here would be a magic number that stopped being
 * right the first time a label changed length.
 */
static const struct creature_plan plans[CREATURE_COUNT] = {
    {
        "fish",
        {
            { { CELL_BEATS, CELL_TURNS, CELL_SEATS }, 3, 6 },
            { { CELL_COMMANDS, CELL_REFUSED, CELL_ROLLBACKS }, 3, 0 },
            { { CELL_THINGS, CELL_CHECKSUM }, 2, 4 }
        },
        3, 10, 8, 3, 3
    },
    {
        "bird",
        {
            { { CELL_BEATS, CELL_TURNS }, 2, 8 },
            { { CELL_COMMANDS, CELL_REFUSED, CELL_ROLLBACKS }, 3, 4 },
            { { CELL_SEATS, CELL_THINGS }, 2, 2 },
            { { CELL_CHECKSUM }, 1, 5 }
        },
        4, 9, 9, 4, 3
    },
    {
        "dragon",
        {
            { { CELL_BEATS, CELL_TURNS, CELL_SEATS, CELL_COMMANDS }, 4, 0 },
            { { CELL_REFUSED, CELL_ROLLBACKS, CELL_THINGS, CELL_CHECKSUM }, 4, 2 }
        },
        2, 12, 12, 5, 4
    },
    {
        "mammoth",
        {
            { { CELL_BEATS, CELL_TURNS, CELL_SEATS }, 3, 5 },
            { { CELL_COMMANDS, CELL_REFUSED }, 2, 8 },
            { { CELL_ROLLBACKS, CELL_THINGS, CELL_CHECKSUM }, 3, 0 }
        },
        3, 11, 6, 3, 4
    }
};

/* {{{ const char *creature_name */
const char *creature_name(uint8_t kind)
{
    if (kind >= CREATURE_COUNT) {
        return "(not a creature)";
    }
    return plans[kind].name;
}
/* }}} */

/* {{{ uint8_t creature_from_seed */
uint8_t creature_from_seed(uint64_t seed)
{
    /*
     * Stirred first, then the high bits taken.
     *
     * An earlier version took the high bits of the seed as given, which meant
     * every seed below about five hundred million million picked the fish --
     * including 1, 2 and 3, which is what anybody writing a test or setting a
     * seed by hand will reach for. A record's seed is well mixed in practice and
     * that hid it.
     *
     * This is the standard splitmix finalizer. It is frozen: changing it would
     * silently give every previously written seed a different animal, and a
     * record log is a thing people keep.
     */
    uint64_t stirred = seed;

    stirred ^= stirred >> 30;
    stirred *= 0xBF58476D1CE4E5B9ull;
    stirred ^= stirred >> 27;
    stirred *= 0x94D049BB133111EBull;
    stirred ^= stirred >> 31;

    return (uint8_t)((stirred >> 59) % CREATURE_COUNT);
}
/* }}} */

/* {{{ uint32_t chamber_width_for */
uint32_t chamber_width_for(uint32_t cell)
{
    uint32_t label = (uint32_t)strlen(record_label(cell));
    uint32_t value = record_widest_value(cell);
    uint32_t inner = (label > value) ? label : value;

    /* Two walls and a column of padding either side. */
    return inner + 4u;
}
/* }}} */

/* {{{ static uint32_t band_width */
static uint32_t band_width(const struct band_plan *b)
{
    uint32_t total = 0;
    uint32_t i;

    for (i = 0; i < b->count; i++) {
        total += chamber_width_for(b->cells[i]);
    }

    /* Neighbouring chambers share a wall, so each join gives a column back. */
    return total - (b->count - 1u);
}
/* }}} */

/* {{{ int creature_lay_out */
int creature_lay_out(struct creature *c, uint8_t kind)
{
    const struct creature_plan *plan;
    uint32_t widest = 0;
    uint32_t band;
    uint32_t placed = 0;

    if (kind >= CREATURE_COUNT) {
        return 0;
    }

    memset(c, 0, sizeof(*c));
    c->kind = kind;
    plan = &plans[kind];

    for (band = 0; band < plan->band_count; band++) {
        uint32_t w = band_width(&plan->bands[band]);

        if (w > widest) {
            widest = w;
        }
    }

    c->body_x = plan->margin_left;
    c->body_y = plan->margin_top;
    c->body_width = widest;

    /* Four rows per band, sharing the wall between one band and the next. */
    c->body_height = 1u + plan->band_count * 3u;

    c->width  = plan->margin_left + widest + plan->margin_right;
    c->height = plan->margin_top + c->body_height + plan->margin_bottom;

    if (c->width > CANVAS_MAX_WIDTH || c->height > CANVAS_MAX_HEIGHT) {
        /* Refused rather than squeezed. A squeezed chamber is a value with
         * nowhere to go, and a value with nowhere to go is a record that is
         * silently not a record. */
        return 0;
    }

    for (band = 0; band < plan->band_count; band++) {
        const struct band_plan *b = &plan->bands[band];
        uint32_t slack = widest - band_width(b);
        uint32_t x = c->body_x + (slack * b->indent_eighths) / 8u;
        uint32_t y = c->body_y + band * 3u;
        uint32_t i;

        for (i = 0; i < b->count; i++) {
            struct chamber *ch = &c->chambers[placed];
            uint32_t w = chamber_width_for(b->cells[i]);

            ch->cell = b->cells[i];
            ch->band = band;
            ch->x0 = x;
            ch->x1 = x + w - 1u;
            ch->y0 = y;
            ch->y1 = y + 3u;

            x = ch->x1;      /* The next chamber shares this wall. */
            placed++;
        }
    }

    c->chamber_count = placed;
    return 1;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * Asking the tiling where things are.
 *
 * Every attachment below is written in this vocabulary. None of them names a
 * column. That is the whole mechanism: move a wall and the ornament moves with
 * it, out of step with the ornament anchored to a different wall.
 * ------------------------------------------------------------------------- */

/* {{{ uint32_t creature_band_count */
uint32_t creature_band_count(const struct creature *c)
{
    uint32_t most = 0;
    uint32_t i;

    for (i = 0; i < c->chamber_count; i++) {
        if (c->chambers[i].band + 1u > most) {
            most = c->chambers[i].band + 1u;
        }
    }
    return most;
}
/* }}} */

/* {{{ void creature_band_bounds */
void creature_band_bounds(const struct creature *c, uint32_t band,
                          uint32_t *x0, uint32_t *y0, uint32_t *x1, uint32_t *y1)
{
    uint32_t i;
    int found = 0;

    *x0 = 0; *y0 = 0; *x1 = 0; *y1 = 0;

    for (i = 0; i < c->chamber_count; i++) {
        const struct chamber *ch = &c->chambers[i];

        if (ch->band != band) {
            continue;
        }

        if (!found) {
            *x0 = ch->x0; *y0 = ch->y0; *x1 = ch->x1; *y1 = ch->y1;
            found = 1;
            continue;
        }

        if (ch->x0 < *x0) { *x0 = ch->x0; }
        if (ch->x1 > *x1) { *x1 = ch->x1; }
    }
}
/* }}} */

/* {{{ uint32_t creature_widest_band */
uint32_t creature_widest_band(const struct creature *c)
{
    uint32_t best = 0;
    uint32_t best_width = 0;
    uint32_t band;

    for (band = 0; band < creature_band_count(c); band++) {
        uint32_t x0, y0, x1, y1;

        creature_band_bounds(c, band, &x0, &y0, &x1, &y1);

        if (x1 - x0 > best_width) {
            best_width = x1 - x0;
            best = band;
        }
    }

    return best;
}
/* }}} */

/* {{{ static const struct chamber *first_in_band */
static const struct chamber *first_in_band(const struct creature *c, uint32_t band)
{
    uint32_t i;

    for (i = 0; i < c->chamber_count; i++) {
        if (c->chambers[i].band == band) {
            return &c->chambers[i];
        }
    }
    return &c->chambers[0];
}
/* }}} */

/* {{{ static const struct chamber *last_in_band */
static const struct chamber *last_in_band(const struct creature *c, uint32_t band)
{
    const struct chamber *found = &c->chambers[0];
    uint32_t i;

    for (i = 0; i < c->chamber_count; i++) {
        if (c->chambers[i].band == band) {
            found = &c->chambers[i];
        }
    }
    return found;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * The attachments.
 *
 * Ornament is glyphs, never strokes -- a fin made of box-drawing characters
 * could close a rectangle, and the reader would read it as a chamber. And no
 * ornament may touch a wall: the canvas counts it when one does, and a test
 * insists on zero for every creature.
 * ------------------------------------------------------------------------- */

/* {{{ static void draw_fish */
static void draw_fish(const struct creature *c, struct canvas *canvas)
{
    uint32_t spine = creature_widest_band(c);
    uint32_t sx0, sy0, sx1, sy1;
    const struct chamber *crest = first_in_band(c, 0);
    const struct chamber *keel = first_in_band(c, creature_band_count(c) - 1u);
    uint32_t i;

    creature_band_bounds(c, spine, &sx0, &sy0, &sx1, &sy1);

    /*
     * The tail: a fan off the widest band's left wall. Anchored to that wall, so
     * widening a value in that band swings the whole tail sideways while the
     * fins above and below stay where they were.
     */
    if (sx0 >= 9u) {
        canvas_text(canvas, sx0 - 7u, sy0 - 1u, "\\\\");
        canvas_text(canvas, sx0 - 6u, sy0, "\\\\\\");
        canvas_text(canvas, sx0 - 8u, sy0 + 1u, "<=======");
        canvas_text(canvas, sx0 - 6u, sy0 + 2u, "///");
        canvas_text(canvas, sx0 - 7u, sy0 + 3u, "//");
    }

    (void)i;

    /* The dorsal fin, on the wall to the right of the top band's first
     * chamber. */
    canvas_text(canvas, crest->x1 - 2u, crest->y0 - 1u, "/\\/\\");
    canvas_put(canvas, crest->x1 - 3u, crest->y0 - 2u, '^');

    /* The pelvic fin, under the bottom band's first chamber. */
    canvas_text(canvas, keel->x0 + 3u, keel->y1 + 1u, "\\/\\/");

    /* The head, entirely outside the body, with an eye that looks at you. */
    canvas_put(canvas, sx1 + 1u, sy0, '\\');
    canvas_text(canvas, sx1 + 1u, sy0 + 1u, " o");
    canvas_text(canvas, sx1 + 2u, sy0 + 2u, ">");
    canvas_put(canvas, sx1 + 1u, sy1, '/');
}
/* }}} */

/* {{{ static void draw_bird */
static void draw_bird(const struct creature *c, struct canvas *canvas)
{
    uint32_t span = creature_widest_band(c);
    uint32_t sx0, sy0, sx1, sy1;
    const struct chamber *crown = first_in_band(c, 0);
    const struct chamber *rump = first_in_band(c, creature_band_count(c) - 1u);
    uint32_t i;

    creature_band_bounds(c, span, &sx0, &sy0, &sx1, &sy1);

    /*
     * Two wings, springing from the two ends of the widest band and sweeping up
     * and out. They are the clearest demonstration of the anchoring: the left
     * wing hangs off one wall and the right off another, so widening a value
     * between them moves one wing and not the other.
     */
    for (i = 1; i <= 5u; i++) {
        uint32_t y = (sy0 > i) ? sy0 - i : 0u;

        if (sx0 >= i + 1u) {
            canvas_put(canvas, sx0 - i - 1u, y, '/');
            canvas_put(canvas, sx0 - i, y, '=');
        }

        canvas_put(canvas, sx1 + i + 1u, y, '\\');
        canvas_put(canvas, sx1 + i, y, '=');
    }

    /* The head, above the top band's first chamber and clear of it. */
    canvas_text(canvas, crown->x0 + 1u, crown->y0 - 2u, "(o)>");

    /* Tail feathers, under the last band. */
    canvas_text(canvas, rump->x0 + 2u, rump->y1 + 1u, "\\|/");
    canvas_put(canvas, rump->x0 + 3u, rump->y1 + 2u, 'V');
}
/* }}} */

/* {{{ static void draw_dragon */
static void draw_dragon(const struct creature *c, struct canvas *canvas)
{
    uint32_t bands = creature_band_count(c);
    uint32_t back = 0;
    uint32_t belly = bands - 1u;
    uint32_t bx0, by0, bx1, by1;
    uint32_t ux0, uy0, ux1, uy1;
    uint32_t i;

    creature_band_bounds(c, back, &bx0, &by0, &bx1, &by1);
    creature_band_bounds(c, belly, &ux0, &uy0, &ux1, &uy1);

    /* The neck rises from the top band's right wall, and the head sits on it. */
    for (i = 1; i <= 3u; i++) {
        canvas_put(canvas, bx1 + i, by0 - i, '/');
    }
    canvas_text(canvas, bx1 + 4u, by0 - 4u, "<oo>=~");

    /* One wing, spread above the back, well clear of the neck. */
    canvas_text(canvas, bx0 + 4u, by0 - 2u, "/\\_/\\_/\\_/\\");
    canvas_text(canvas, bx0 + 6u, by0 - 3u, "_/     \\_");

    /* A leg under each chamber of the bottom band. Four chambers, four legs,
     * and each one stands where its own chamber does. */
    for (i = 0; i < c->chamber_count; i++) {
        const struct chamber *ch = &c->chambers[i];

        if (ch->band != belly) {
            continue;
        }

        canvas_put(canvas, ch->x0 + 3u, uy1 + 1u, '|');
        canvas_put(canvas, ch->x0 + 3u, uy1 + 2u, 'V');
    }

    /* The tail, trailing left from the belly band. */
    if (ux0 >= 9u) {
        canvas_text(canvas, ux0 - 8u, uy0 + 1u, "~~~~~~~");
        canvas_text(canvas, ux0 - 9u, uy0 + 2u, "<~~~");
    }
}
/* }}} */

/* {{{ static void draw_mammoth */
static void draw_mammoth(const struct creature *c, struct canvas *canvas)
{
    uint32_t bands = creature_band_count(c);
    uint32_t withers = 0;
    uint32_t ground = bands - 1u;
    uint32_t wx0, wy0, wx1, wy1;
    const struct chamber *skull = first_in_band(c, ground);
    const struct chamber *rear = last_in_band(c, ground);
    uint32_t gx0, gy0, gx1, gy1;
    uint32_t x;

    creature_band_bounds(c, withers, &wx0, &wy0, &wx1, &wy1);
    creature_band_bounds(c, ground, &gx0, &gy0, &gx1, &gy1);

    /* A shaggy back, spanning the top band's own width. */
    for (x = wx0 + 1u; x < wx1; x++) {
        canvas_put(canvas, x, wy0 - 1u, ((x - wx0) % 2u == 0u) ? '^' : '~');
    }

    /*
     * Four legs: a front pair under the leftmost chamber of the bottom band and
     * a back pair under the rightmost. Four, because a mammoth has four -- and
     * a leg under every chamber gave six, which the drawing said out loud the
     * first time anybody looked at it.
     */
    canvas_text(canvas, skull->x0 + 2u, gy1 + 1u, "||");
    canvas_text(canvas, skull->x0 + 2u, gy1 + 2u, "LJ");
    canvas_text(canvas, skull->x1 - 3u, gy1 + 1u, "||");
    canvas_text(canvas, skull->x1 - 3u, gy1 + 2u, "LJ");
    canvas_text(canvas, rear->x0 + 2u, gy1 + 1u, "||");
    canvas_text(canvas, rear->x0 + 2u, gy1 + 2u, "LJ");
    canvas_text(canvas, rear->x1 - 3u, gy1 + 1u, "||");
    canvas_text(canvas, rear->x1 - 3u, gy1 + 2u, "LJ");

    /* The head is the bottom band's leftmost chamber. Trunk and tusk curl down
     * from its left wall, outside the body. */
    if (skull->x0 >= 6u) {
        canvas_text(canvas, skull->x0 - 2u, skull->y0, "~~");
        canvas_text(canvas, skull->x0 - 4u, skull->y0 + 1u, "~~");
        canvas_text(canvas, skull->x0 - 5u, skull->y0 + 2u, "~");
        canvas_text(canvas, skull->x0 - 6u, skull->y0 + 3u, "'~(");
    }

    /* An ear, hanging off the top band's left wall. */
    if (wx0 >= 3u) {
        canvas_put(canvas, wx0 - 1u, wy0 + 1u, ')');
        canvas_put(canvas, wx0 - 2u, wy0 + 2u, ')');
    }
}
/* }}} */

typedef void (*attach_handler)(const struct creature *, struct canvas *);

static const attach_handler attachments[CREATURE_COUNT] = {
    draw_fish, draw_bird, draw_dragon, draw_mammoth
};

/* {{{ void creature_draw */
void creature_draw(const struct creature *c, const struct record *r,
                   struct canvas *canvas)
{
    uint32_t i;

    /* The chambers first: they are the table, and the ornament hangs off them. */
    for (i = 0; i < c->chamber_count; i++) {
        const struct chamber *ch = &c->chambers[i];
        char value[RECORD_VALUE_MAX + 2];

        canvas_box(canvas, ch->x0, ch->y0, ch->x1, ch->y1);

        canvas_text(canvas, ch->x0 + 2u, ch->y0 + 1u, record_label(ch->cell));

        record_value_text(r, ch->cell, value, sizeof(value));
        canvas_text_right(canvas, ch->x1 - 2u, ch->y0 + 2u, value);
    }

    if (c->kind < CREATURE_COUNT) {
        attachments[c->kind](c, canvas);
    }
}
/* }}} */
