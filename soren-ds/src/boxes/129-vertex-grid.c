/*
 * 129-vertex-grid.c — the vertex grid, as boxes see it (issue 1001).
 *
 * General description: a box cannot remember, so the grid lives in the
 * system (128) and the boxes name it by number on every request. Each box
 * answers with the cell it was asked about and what happened, so a map
 * can wire the answer on without carrying the question beside it.
 *
 * The three boxes are placed together by src/maps/vertex-grid.map, the
 * grid's own small program, which a modeller's map places inside itself
 * as one station. The grid's memory is its app's, through the STAND-IN
 * for 902 (src/engine/127-app-memory.h).
 */
#include <stdint.h>
#include "../system/128-vertex-grid.h"

/* A cell of a grid: which grid, and where. */
struct cell {
    int32_t grid;
    int32_t x, y, z;
};

/* The cell asked about, and what became of it: 1 placed or removed or
 * there, 0 unchanged or empty, -1 no such grid, -2 outside the cube,
 * -3 out of memory. `faces` is the vertex's face count when it is there. */
struct cell_answer {
    int32_t grid;
    int32_t x, y, z;
    int32_t answer;
    int32_t faces;
};

/* {{{ answer_for */
static struct cell_answer answer_for(struct cell c, int answer, int faces)
{
    struct cell_answer a;
    a.grid = c.grid;
    a.x = c.x;
    a.y = c.y;
    a.z = c.z;
    a.answer = answer;
    a.faces = faces;
    return a;
}
/* }}} */

/* {{{ place_vertex */
struct cell_answer place_vertex(struct cell at)
{
    return answer_for(at, vertex_grid_place(at.grid, at.x, at.y, at.z), 0);
}
/* }}} */

/* {{{ remove_vertex */
struct cell_answer remove_vertex(struct cell at)
{
    return answer_for(at, vertex_grid_remove(at.grid, at.x, at.y, at.z), 0);
}
/* }}} */

/* {{{ vertex_in */
struct cell_answer vertex_in(struct cell at)
{
    struct vertex v;
    int found = vertex_grid_at(at.grid, at.x, at.y, at.z, &v);
    return answer_for(at, found, found == 1 ? v.face_count : 0);
}
/* }}} */
