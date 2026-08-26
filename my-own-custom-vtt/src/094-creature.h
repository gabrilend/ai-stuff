/*
 * 094-creature.h -- a creature is a tiling of chambers, and the tiling is the
 * table.
 *
 * "The carving is the table. Its lines are the cell walls." That is a constraint
 * rather than a metaphor, and this is where it becomes geometry: a creature is a
 * TILING OF RECTANGULAR CHAMBERS, each chamber one cell of the spreadsheet, and
 * the creature's silhouette is the boundary of the tiling.
 *
 * There is no picture layer over a data layer. There is one layer.
 *
 * THE CREATURES ARE GENERATED, NOT DRAWN. Four hand-drawn animals would be four
 * things to maintain and would never fit a different number of cells. Each
 * creature is a RULE for grouping chambers into bands, plus attachments that hang
 * off named edges of the resulting tiling.
 *
 * THE ATTACHMENTS HANG OFF THE CHAMBERS, and that is what makes the fragility
 * work. A fin does not sit at a column somebody typed; it sits at the wall
 * between two chambers. So when a hand-edit pushes a value one character wider,
 * the wall moves, every wall to its right on that row moves with it, and the
 * animal is visibly lopsided against the rows above and below. That is the
 * checksum you can see, and it only works because the anatomy is defined in
 * terms of the table.
 *
 * ATTACHMENTS ARE GLYPHS, NEVER STROKES. A fin drawn with box-drawing characters
 * could accidentally close a rectangle, and the reader finds chambers by looking
 * for closed rectangles -- so an ornamental one would read as a cell. Ornament
 * cannot be made of walls.
 *
 * See docs/018-the-record-log-is-an-engraving.md and issue 1003.
 */

#ifndef VTT_CREATURE_H
#define VTT_CREATURE_H

#include <stdint.h>

#include "090-record.h"
#include "092-canvas.h"

#define CREATURE_FISH     0u
#define CREATURE_BIRD     1u
#define CREATURE_DRAGON   2u
#define CREATURE_MAMMOTH  3u
#define CREATURE_COUNT    4u

/*
 * One cell of the spreadsheet, which is one chamber of the animal. Walls sit ON
 * the boundary coordinates, so two chambers side by side share a column.
 *
 * Four rows tall: the top wall, the label, the value, the bottom wall. The label
 * above the value rather than beside it, because beside it makes a chamber as
 * wide as both together and eight of those is a creature nobody can see the
 * whole of.
 */
struct chamber {
    uint32_t x0;
    uint32_t y0;
    uint32_t x1;
    uint32_t y1;
    uint32_t cell;

    /* Which horizontal run of chambers it belongs to. Attachments ask for a
     * band's edge, never for a column. */
    uint32_t band;
};

struct creature {
    uint8_t kind;

    struct chamber chambers[RECORD_CELLS];
    uint32_t       chamber_count;

    /* Where the body sits on the canvas, and how big the whole carving is. */
    uint32_t body_x;
    uint32_t body_y;
    uint32_t body_width;
    uint32_t body_height;

    uint32_t width;
    uint32_t height;
};

/*
 * Which creature a seed gets.
 *
 * The seed comes from the run, so THE CREATURE BELONGS TO THAT RUN -- bespoke, as
 * the document says, and reproducible, which is what lets the round trip be a
 * byte comparison rather than a judgement.
 */
uint8_t creature_from_seed(uint64_t seed);

const char *creature_name(uint8_t kind);

/*
 * Lay out the tiling. Returns 1, or 0 if the creature would not fit on a canvas
 * -- refused rather than squeezed, because a squeezed chamber is a value with
 * nowhere to go.
 */
int creature_lay_out(struct creature *c, uint8_t kind);

/* Draw the tiling and its attachments onto a canvas sized by creature_lay_out. */
void creature_draw(const struct creature *c, const struct record *r,
                   struct canvas *canvas);

/* How wide a chamber holding this cell must be. What the tiling is built from. */
uint32_t chamber_width_for(uint32_t cell);

/*
 * The edges of one band of chambers. This is the vocabulary the attachments are
 * written in -- a wing springs from a band's corner, and when a hand-edit widens
 * a value the band's corner moves and the wing goes with it.
 *
 * Any of the four outputs may be asked for; all are filled.
 */
void creature_band_bounds(const struct creature *c, uint32_t band,
                          uint32_t *x0, uint32_t *y0, uint32_t *x1, uint32_t *y1);

/* How many bands this creature has. */
uint32_t creature_band_count(const struct creature *c);

/* The widest band, which is the one a body's silhouette is measured from. */
uint32_t creature_widest_band(const struct creature *c);

#endif
