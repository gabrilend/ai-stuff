/*
 * 106-controls.c -- turning three dials into a point, and drawing them.
 *
 * See 106-controls.h for where the scheme comes from and why the arithmetic is
 * here rather than in a view.
 */

#include "106-controls.h"

#include <stdio.h>
#include <string.h>

/*
 * The eight directions, as unit vectors in world units.
 *
 * ONE TABLE, and both views take it from here, so they cannot come to disagree
 * about what northeast means. A diagonal is 0.7071 of a unit on each axis --
 * 724 of 1024 -- because a diagonal step that moved a full unit on both axes
 * would travel forty per cent further than a straight one for the same key, and
 * a person would feel it without being able to say why.
 *
 * Y increases northward, matching the world's own convention.
 */
static const struct {
    wcoord x;
    wcoord y;
    /* Where the mark goes on the little diagram, and what the line is made of. */
    int8_t cell_x;
    int8_t cell_y;
    char   stroke;
} compass[AIM_COUNT] = {
    {    0,  WC_ONE,  0, -1, '|'  },   /* north */
    {  724,     724,  1, -1, '/'  },   /* north-east */
    { WC_ONE,     0,  1,  0, '-'  },   /* east */
    {  724,    -724,  1,  1, '\\' },   /* south-east */
    {    0, -WC_ONE,  0,  1, '|'  },   /* south */
    { -724,    -724, -1,  1, '/'  },   /* south-west */
    { -WC_ONE,    0, -1,  0, '-'  },   /* west */
    { -724,     724, -1, -1, '\\' }    /* north-west */
};

static const char *const aim_names[AIM_COUNT] = {
    "north", "north-east", "east", "south-east",
    "south", "south-west", "west", "north-west"
};

/*
 * How far each reach is.
 *
 * Three metres is inside the room with you, eight is across it, sixteen is the
 * far wall. Chosen by what a tabletop distance means rather than by doubling,
 * because a person aiming a squad is thinking in rooms.
 */
static const uint32_t reach_metres[REACH_COUNT] = { 3u, 8u, 16u };

static const char *const reach_names[REACH_COUNT] = { "close", "near", "far" };

static const char *const act_names[ACT_COUNT] = {
    "go", "face", "stop", "reach"
};

/* {{{ void dial_init */
void dial_init(struct dial *d)
{
    memset(d, 0, sizeof(*d));

    d->aim = AIM_NORTH;
    d->reach = REACH_NEAR;
    d->choosing = CHOOSING_WHOLE_PARTY;
    d->which = 0;
}
/* }}} */

/* {{{ void dial_turn_aim */
void dial_turn_aim(struct dial *d, int by)
{
    /* Wraps, because a control you can walk off the end of is a control that
     * needs a boundary check every time it is read. */
    int at = (int)d->aim + by;

    while (at < 0) {
        at += (int)AIM_COUNT;
    }

    d->aim = (uint8_t)(at % (int)AIM_COUNT);
}
/* }}} */

/* {{{ void dial_turn_reach */
void dial_turn_reach(struct dial *d, int by)
{
    /*
     * Does NOT wrap. Distance is a line rather than a circle, and a person
     * pressing "further" three times expects to be at the far end rather than
     * back where they started.
     */
    int at = (int)d->reach + by;

    if (at < 0) {
        at = 0;
    }
    if (at >= (int)REACH_COUNT) {
        at = (int)REACH_COUNT - 1;
    }

    d->reach = (uint8_t)at;
}
/* }}} */

/* {{{ void dial_cycle_choice */
void dial_cycle_choice(struct dial *d, uint32_t party_size)
{
    /*
     * Walks: everybody, then each member in turn, then everybody again. One key,
     * and the whole party is a position on the same dial rather than a separate
     * mode -- which is what makes "point at all four and say go" as few
     * keystrokes as "point at one and say stay".
     */
    if (party_size == 0) {
        dial_choose_whole_party(d);
        return;
    }

    if (d->choosing == CHOOSING_WHOLE_PARTY) {
        d->choosing = CHOOSING_ONE;
        d->which = 0;
        return;
    }

    d->which++;

    if (d->which >= party_size) {
        dial_choose_whole_party(d);
    }
}
/* }}} */

/* {{{ void dial_choose_whole_party */
void dial_choose_whole_party(struct dial *d)
{
    d->choosing = CHOOSING_WHOLE_PARTY;
    d->which = 0;
}
/* }}} */

/* {{{ void dial_choose_one */
void dial_choose_one(struct dial *d, uint32_t which)
{
    d->choosing = CHOOSING_ONE;
    d->which = which;
}
/* }}} */

/* {{{ void dial_resolve */
void dial_resolve(const struct dial *d, wcoord from_x, wcoord from_y,
                  wcoord *to_x, wcoord *to_y)
{
    uint8_t aim = (d->aim < AIM_COUNT) ? d->aim : AIM_NORTH;
    uint8_t reach = (d->reach < REACH_COUNT) ? d->reach : REACH_NEAR;
    int64_t metres = (int64_t)reach_metres[reach];

    /*
     * Integers throughout, like everything else in the simulation. The unit
     * vector is already in world units, so this is a multiply and a shift rather
     * than anything that needs a floating point number to exist.
     */
    *to_x = from_x + (wcoord)((int64_t)compass[aim].x * metres);
    *to_y = from_y + (wcoord)((int64_t)compass[aim].y * metres);
}
/* }}} */

/* {{{ uint32_t reach_in_metres */
uint32_t reach_in_metres(uint8_t reach)
{
    if (reach >= REACH_COUNT) {
        return 0;
    }
    return reach_metres[reach];
}
/* }}} */

/* {{{ const char *aim_name */
const char *aim_name(uint8_t aim)
{
    if (aim >= AIM_COUNT) {
        return "(not a direction)";
    }
    return aim_names[aim];
}
/* }}} */

/* {{{ const char *reach_name */
const char *reach_name(uint8_t reach)
{
    if (reach >= REACH_COUNT) {
        return "(not a distance)";
    }
    return reach_names[reach];
}
/* }}} */

/* {{{ const char *act_name */
const char *act_name(uint8_t act)
{
    if (act >= ACT_COUNT) {
        return "(not an action)";
    }
    return act_names[act];
}
/* }}} */

/*
 * Seven by seven, with you in the middle.
 *
 * Odd on both axes so there IS a middle. Seven because the far reach needs three
 * cells of line to look further than the near one, and three cells either side of
 * a centre is seven.
 */
#define DIAGRAM_SIZE 7
#define DIAGRAM_MIDDLE 3

/* {{{ const char *dial_diagram */
const char *dial_diagram(const struct dial *d, char *into, uint32_t capacity)
{
    char grid[DIAGRAM_SIZE][DIAGRAM_SIZE];
    uint8_t aim = (d->aim < AIM_COUNT) ? d->aim : AIM_NORTH;
    uint8_t reach = (d->reach < REACH_COUNT) ? d->reach : REACH_NEAR;
    int steps = (int)reach + 1;    /* close 1, near 2, far 3 */
    uint32_t cursor = 0;
    int row;
    int step;

    memset(grid, ' ', sizeof(grid));

    /* You. */
    grid[DIAGRAM_MIDDLE][DIAGRAM_MIDDLE] = 'o';

    /* The line, and the mark at the end of it. Drawn FROM THE DIAL rather than
     * from a copy, so it cannot disagree with the state it is showing. */
    for (step = 1; step <= steps; step++) {
        int x = DIAGRAM_MIDDLE + compass[aim].cell_x * step;
        int y = DIAGRAM_MIDDLE + compass[aim].cell_y * step;

        if (x < 0 || x >= DIAGRAM_SIZE || y < 0 || y >= DIAGRAM_SIZE) {
            continue;
        }

        grid[y][x] = (step == steps) ? 'X' : compass[aim].stroke;
    }

    for (row = 0; row < DIAGRAM_SIZE; row++) {
        int column;

        for (column = 0; column < DIAGRAM_SIZE; column++) {
            if (cursor + 2u >= capacity) {
                into[cursor] = '\0';
                return into;
            }
            into[cursor] = grid[row][column];
            cursor++;
        }

        if (cursor + 2u >= capacity) {
            break;
        }
        into[cursor] = '\n';
        cursor++;
    }

    into[cursor] = '\0';
    return into;
}
/* }}} */

/* {{{ const char *dial_sentence */
const char *dial_sentence(const struct dial *d, uint32_t party_size,
                          char *into, uint32_t capacity)
{
    if (d->choosing == CHOOSING_WHOLE_PARTY) {
        snprintf(into, capacity, "all %u, %s, %s (%u m)",
                 (unsigned)party_size, aim_name(d->aim), reach_name(d->reach),
                 (unsigned)reach_in_metres(d->reach));
    } else {
        snprintf(into, capacity, "number %u of %u, %s, %s (%u m)",
                 (unsigned)(d->which + 1u), (unsigned)party_size,
                 aim_name(d->aim), reach_name(d->reach),
                 (unsigned)reach_in_metres(d->reach));
    }

    return into;
}
/* }}} */
