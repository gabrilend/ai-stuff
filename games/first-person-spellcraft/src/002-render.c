/* 002-render.c — the first-person renderer.
 *
 * How it works, for a general reader: before the game runs, we walk the map once
 * and build, for each room, a little pile of flat panels — floor tiles, ceiling
 * tiles, and walls wherever open floor meets stone or a step up. Each panel
 * remembers its four corners, which way it faces, and two colours (a fill and a
 * brighter edge). Every frame we point a camera out of the player's eyes and
 * hand all the panels to the graphics card; the card sorts out what hides behind
 * what. The edges are drawn as bright lines so the room reads as built shapes.
 */
#include "002-render.h"
#include "../libs/platform/platform.h"

#include <stdlib.h>

/* {{{ face_t / mesh_t / struct scene */
/* A face's corners are stored already mapped into raylib space (x, y-up, z). */
typedef struct {
    float   x[4], y[4], z[4];
    float   nx, ny, nz;        /* surface normal (for later lighting/culling) */
    uint8_t fill[3], edge[3];
} face_t;

typedef struct { face_t *f; int n, cap; } mesh_t;   /* one room's geometry */

struct scene { mesh_t *rooms; int n_rooms; };
/* }}} */

/* {{{ local push_face() — append a quad (raylib-space corners) to a mesh */
static void push_face(mesh_t *m,
                      float x0, float y0, float z0, float x1, float y1, float z1,
                      float x2, float y2, float z2, float x3, float y3, float z3,
                      float nx, float ny, float nz,
                      uint8_t fr, uint8_t fg, uint8_t fb,
                      uint8_t er, uint8_t eg, uint8_t eb)
{
    if (m->n == m->cap) {
        int nc = m->cap ? m->cap * 2 : 32;
        face_t *g = realloc(m->f, (size_t)nc * sizeof *g);
        if (!g) return;   /* out of memory: this face is simply not built */
        m->f = g; m->cap = nc;
    }
    face_t *f = &m->f[m->n++];
    f->x[0]=x0; f->y[0]=y0; f->z[0]=z0;  f->x[1]=x1; f->y[1]=y1; f->z[1]=z1;
    f->x[2]=x2; f->y[2]=y2; f->z[2]=z2;  f->x[3]=x3; f->y[3]=y3; f->z[3]=z3;
    f->nx=nx; f->ny=ny; f->nz=nz;
    f->fill[0]=fr; f->fill[1]=fg; f->fill[2]=fb;
    f->edge[0]=er; f->edge[1]=eg; f->edge[2]=eb;
}
/* }}} */

/* colours: floors tint by room so the two rooms read apart; edges a bright cyan
 * so the built shapes pop. */
#define EDGE 90, 200, 230
/* {{{ local push_floor_ceiling() */
/* A horizontal quad (floor or ceiling) filling cell (cx,cy) at height h. Corners
 * wind around the cell; raylib map is (wx, h, wy). */
static void push_floor_ceiling(mesh_t *m, int cx, int cy, float h, int is_floor,
                               uint8_t fr, uint8_t fg, uint8_t fb)
{
    float x0 = cx, x1 = cx + 1, y0 = cy, y1 = cy + 1;
    float ny = is_floor ? 1.0f : -1.0f;    /* floor faces up, ceiling faces down */
    push_face(m, x0, h, y0, x1, h, y0, x1, h, y1, x0, h, y1,
              0, ny, 0, fr, fg, fb, EDGE);
}
/* }}} */

/* {{{ local push_wall() — a vertical quad along a cell edge, zlo..zhi */
static void push_wall(mesh_t *m, float ex0, float ey0, float ex1, float ey1,
                      float zlo, float zhi, float nx, float nz)
{
    /* Corners: bottom edge (ex0,ey0)->(ex1,ey1), then up to zhi. */
    push_face(m, ex0, zlo, ey0, ex1, zlo, ey1, ex1, zhi, ey1, ex0, zhi, ey0,
              nx, 0, nz, 58, 60, 78, EDGE);
}
/* }}} */

/* {{{ local build_cell() — floor/ceiling + boundary walls for one open cell */
static void build_cell(const world_t *w, mesh_t *m, int cx, int cy)
{
    const cell_t *c = world_cell(w, cx, cy);
    float f = c->floor_h, ce = c->ceil_h;

    /* floor tint by room (room 1 reads a touch lighter), ceiling darker */
    uint8_t fg = (c->room_id == 1) ? 74 : 50;
    push_floor_ceiling(m, cx, cy, f,  1, 30, fg, 40);
    push_floor_ceiling(m, cx, cy, ce, 0, 20, 24, 34);

    /* Four sides. A wall rises to the ceiling where the neighbour is solid/void;
     * where the neighbour is open but a STEP higher, a short wall covers the
     * riser. Each side's normal points back into this cell. */
    struct { int dx, dy; float ex0, ey0, ex1, ey1, nx, nz; } sides[4] = {
        {  1,  0, cx+1, cy,   cx+1, cy+1, -1,  0 },   /* east  */
        { -1,  0, cx,   cy+1, cx,   cy,    1,  0 },   /* west  */
        {  0,  1, cx+1, cy+1, cx,   cy+1,  0, -1 },   /* south */
        {  0, -1, cx,   cy,   cx+1, cy,    0,  1 },   /* north */
    };
    for (int s = 0; s < 4; s++) {
        int nxp = cx + sides[s].dx, nyp = cy + sides[s].dy;
        const cell_t *nb = world_cell(w, nxp, nyp);
        if (!nb || nb->solid) {
            push_wall(m, sides[s].ex0, sides[s].ey0, sides[s].ex1, sides[s].ey1,
                      f, ce, sides[s].nx, sides[s].nz);
        } else if (nb->floor_h > f) {
            /* open, but a step up — cover the riser from our floor to theirs */
            push_wall(m, sides[s].ex0, sides[s].ey0, sides[s].ex1, sides[s].ey1,
                      f, nb->floor_h, sides[s].nx, sides[s].nz);
        }
    }
}
/* }}} */

/* {{{ scene_build() */
scene_t *scene_build(const world_t *w)
{
    scene_t *s = calloc(1, sizeof *s);
    if (!s) return NULL;
    s->n_rooms = w->n_rooms;
    s->rooms = calloc((size_t)w->n_rooms, sizeof *s->rooms);
    if (!s->rooms) { free(s); return NULL; }

    /* Every open cell contributes its floor/ceiling/walls to its room's mesh. */
    for (int y = 0; y < w->height; y++)
        for (int x = 0; x < w->width; x++) {
            const cell_t *c = world_cell(w, x, y);
            if (c->solid || c->room_id < 0 || c->room_id >= w->n_rooms) continue;
            build_cell(w, &s->rooms[c->room_id], x, y);
        }
    return s;
}
/* }}} */

/* {{{ scene_destroy() */
void scene_destroy(scene_t *s)
{
    if (!s) return;
    for (int i = 0; i < s->n_rooms; i++) free(s->rooms[i].f);
    free(s->rooms);
    free(s);
}
/* }}} */

/* {{{ scene_render() */
void scene_render(const scene_t *s, float px, float py, float pz,
                  float fx, float fy)
{
    /* Camera at the eye (raylib: x, y-up=height, z), looking one step along the
     * horizontal facing. */
    platform_begin_3d(px, pz, py, px + fx, pz, py + fy, 60.0f);

    for (int r = 0; r < s->n_rooms; r++) {
        const mesh_t *m = &s->rooms[r];
        for (int i = 0; i < m->n; i++) {
            const face_t *f = &m->f[i];
            /* Fill: two triangles across the quad. */
            platform_draw_tri3d(f->x[0], f->y[0], f->z[0],
                                f->x[1], f->y[1], f->z[1],
                                f->x[2], f->y[2], f->z[2],
                                f->fill[0], f->fill[1], f->fill[2]);
            platform_draw_tri3d(f->x[0], f->y[0], f->z[0],
                                f->x[2], f->y[2], f->z[2],
                                f->x[3], f->y[3], f->z[3],
                                f->fill[0], f->fill[1], f->fill[2]);
            /* Edges: the four sides as bright lines. */
            for (int e = 0; e < 4; e++) {
                int a = e, b = (e + 1) & 3;
                platform_draw_line3d(f->x[a], f->y[a], f->z[a],
                                     f->x[b], f->y[b], f->z[b],
                                     f->edge[0], f->edge[1], f->edge[2]);
            }
        }
    }
    platform_end_3d();
}
/* }}} */
