/*
 * 044-fog.c -- setting bits, and never clearing them.
 *
 * Interface and reasoning are in 044-fog.h.
 *
 * Folding sight into memory asks, for each cell within reach, whether that cell
 * is visible -- using the same sight_point_visible the outbound filter uses. One
 * primitive, two callers. A second rasteriser written specially for the fog
 * could disagree with the one that decides what goes on a socket, and then a
 * hole in the map and a leak would look identical.
 */

#include "044-fog.h"
#include "042-sight.h"

#include <stdlib.h>
#include <string.h>

/* {{{ int fog_init */
int fog_init(struct fog *f, const struct world *w, wcoord cell_size)
{
    wcoord width;
    wcoord height;

    if (cell_size <= 0) {
        cell_size = WC_ONE;   /* One metre. */
    }

    f->origin_x  = w->min_x;
    f->origin_y  = w->min_y;
    f->cell_size = cell_size;

    width  = w->max_x - w->min_x;
    height = w->max_y - w->min_y;

    /*
     * Rounded up, and with one cell to spare in each direction, so that a body
     * standing exactly on the far edge of the world still lands inside the grid.
     * A world with no extent still gets a grid of one cell rather than none.
     */
    f->columns = (uint32_t)(width / cell_size) + 2;
    f->rows    = (uint32_t)(height / cell_size) + 2;

    f->byte_count = ((f->columns * f->rows) + 7) / 8;

    f->bits = calloc((size_t)f->byte_count, 1);
    if (f->bits == NULL) {
        f->byte_count = 0;
        return 0;
    }

    return 1;
}
/* }}} */

/* {{{ void fog_release */
void fog_release(struct fog *f)
{
    free(f->bits);
    f->bits = NULL;
    f->byte_count = 0;
    f->columns = 0;
    f->rows = 0;
}
/* }}} */

/* {{{ static int cell_of */
static int cell_of(const struct fog *f, wcoord x, wcoord y,
                   uint32_t *column, uint32_t *row)
{
    wcoord dx = x - f->origin_x;
    wcoord dy = y - f->origin_y;

    /*
     * Outside the grid is never remembered. This is a real case rather than an
     * error: the extent is what the fog was sized from, and a body may stand
     * outside it -- positions are not constrained by the extent, only recorded
     * against it.
     */
    if (dx < 0 || dy < 0) {
        return 0;
    }

    *column = (uint32_t)(dx / f->cell_size);
    *row    = (uint32_t)(dy / f->cell_size);

    if (*column >= f->columns || *row >= f->rows) {
        return 0;
    }

    return 1;
}
/* }}} */

/* {{{ static void set_cell */
static void set_cell(struct fog *f, uint32_t column, uint32_t row)
{
    uint32_t index = (row * f->columns) + column;

    f->bits[index / 8] |= (uint8_t)(1u << (index % 8));
}
/* }}} */

/* {{{ int fog_remembers */
int fog_remembers(const struct fog *f, wcoord x, wcoord y)
{
    uint32_t column;
    uint32_t row;
    uint32_t index;

    if (!cell_of(f, x, y, &column, &row)) {
        return 0;
    }

    index = (row * f->columns) + column;

    return (f->bits[index / 8] & (uint8_t)(1u << (index % 8))) != 0;
}
/* }}} */

/* {{{ void fog_fold */
void fog_fold(struct fog *f, const struct world *w, uint32_t body)
{
    const struct thing *eye = world_thing_const(w, body);
    wcoord range;
    uint32_t first_column;
    uint32_t first_row;
    uint32_t last_column;
    uint32_t last_row;
    uint32_t column;
    uint32_t row;

    if (!thing_can_see(eye)) {
        return;
    }

    range = (wcoord)eye->sight_range;

    /*
     * Only the cells within the sight circle's bounding box are considered.
     * Everything beyond it is out of range by definition, so asking would be
     * asking a question whose answer is already known.
     */
    {
        wcoord low_x  = eye->x - range;
        wcoord low_y  = eye->y - range;
        wcoord high_x = eye->x + range;
        wcoord high_y = eye->y + range;

        if (low_x < f->origin_x) low_x = f->origin_x;
        if (low_y < f->origin_y) low_y = f->origin_y;

        if (!cell_of(f, low_x, low_y, &first_column, &first_row)) {
            return;
        }

        if (!cell_of(f, high_x, high_y, &last_column, &last_row)) {
            last_column = f->columns - 1;
            last_row    = f->rows - 1;
        }
    }

    for (row = first_row; row <= last_row && row < f->rows; row++) {
        for (column = first_column; column <= last_column && column < f->columns; column++) {
            /*
             * The cell's centre stands for the cell.
             *
             * The document says a cell is remembered when any part of it falls
             * inside the visibility polygon, and testing the centre is stricter
             * than that: a cell whose corner was glimpsed but whose middle was
             * not stays unremembered.
             *
             * That is the safer direction to be wrong in. Under-claiming means a
             * person's map shows slightly less than they saw; over-claiming means
             * it shows a square metre of floor they never really looked at, and
             * open question 2.1 is about exactly that risk.
             */
            wcoord x = f->origin_x + (wcoord)(column * f->cell_size) + (f->cell_size / 2);
            wcoord y = f->origin_y + (wcoord)(row * f->cell_size) + (f->cell_size / 2);

            if (fog_remembers(f, x, y)) {
                continue;   /* Already seen. Nothing to compute. */
            }

            if (sight_point_visible(w, body, x, y)) {
                set_cell(f, column, row);
            }
        }
    }
}
/* }}} */

/* {{{ uint32_t fog_cells_seen */
uint32_t fog_cells_seen(const struct fog *f)
{
    uint32_t total = 0;
    uint32_t i;

    for (i = 0; i < f->byte_count; i++) {
        uint8_t byte = f->bits[i];

        while (byte != 0) {
            total += (byte & 1u);
            byte >>= 1;
        }
    }

    return total;
}
/* }}} */

/* {{{ uint32_t fog_cell_count */
uint32_t fog_cell_count(const struct fog *f)
{
    return f->columns * f->rows;
}
/* }}} */

/* {{{ int fog_copy */
int fog_copy(struct fog *destination, const struct fog *source)
{
    /*
     * Rollback restores the fog along with the world. That decision is written
     * up in docs/019-the-turn-is-a-transaction.md, and the short version is:
     * the program can restore state, it cannot restore ignorance. The person
     * still remembers the corridor. Their map closing over it is the price of
     * the map never contradicting the world.
     *
     * Leaving the fog alone would be the other choice, and it would leave a
     * permanent inconsistency that spreads -- a place reached in a turn that
     * never happened, contradicting the world every time anybody walks there
     * again.
     */
    if (destination->columns != source->columns ||
        destination->rows != source->rows ||
        destination->cell_size != source->cell_size) {
        return 0;
    }

    memcpy(destination->bits, source->bits, source->byte_count);

    return 1;
}
/* }}} */
