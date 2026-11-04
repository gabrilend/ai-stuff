/*
 * 107-compositor.c — copying surfaces onto the screens, once a frame
 * (issue 603).
 *
 * General description: see 107-compositor.h. Everything one frame copies
 * is decided from one gather (104), so a frame sees one moment of the
 * surface table. What changes during the copy — a mark, a move, a release
 * — is in the table for the next frame, and nothing is lost.
 */
#include <stdint.h>
#include "../engine/025-platform.h"
#include "../engine/027-primitives.h"
#include "../engine/031-engine.h"
#include "104-surfaces.h"
#include "107-compositor.h"

/* {{{ overlaps */
static int overlaps(int x, int y, int w, int h, const struct surface_rect *r)
{
    return r->width > 0 && x < r->x + r->width && r->x < x + w && y < r->y + r->height && r->y < y + h;
}
/* }}} */

/* {{{ paint_background */
static void paint_background(struct platform_screen sc, const struct surface_rect *r)
{
    for (int row = r->y; row < r->y + r->height; row++) {
        uint32_t *line = sc.pixels + (size_t)row * (size_t)sc.stride;
        for (int col = r->x; col < r->x + r->width; col++) {
            line[col] = COMPOSITOR_BACKGROUND;
        }
    }
}
/* }}} */

/* {{{ copy_surface */
/* Rows of the surface's buffer into the screen at its position, bounded
 * by the screen's edges (601 grants only rectangles wholly on the screen,
 * so the bound only matters if that ever changes). */
static void copy_surface(struct platform_screen sc, const struct surface_view *v)
{
    int cols = v->width;
    if (v->x + cols > sc.width) cols = sc.width - v->x;
    int rows = v->height;
    if (v->y + rows > sc.height) rows = sc.height - v->y;
    if (v->x < 0 || v->y < 0 || cols <= 0 || rows <= 0 || !v->pixels) {
        return;
    }
    for (int r = 0; r < rows; r++) {
        bytes_copy(sc.pixels + (size_t)(v->y + r) * (size_t)sc.stride + (size_t)v->x,
                   v->pixels + (size_t)r * (size_t)v->width, (size_t)cols * sizeof *v->pixels);
    }
}
/* }}} */

/* {{{ compositor_screen */
struct compositor_frame compositor_screen(int screen)
{
    struct compositor_frame f = { 0, 0 };
    struct surface_view   views[SURFACE_MAX];
    struct surface_rect   drawn[SURFACE_MAX + 1];
    struct surface_rect   uncovered;
    int n_drawn = 0;
    int n = surface_gather(screen, views, SURFACE_MAX, &uncovered);
    struct platform_screen sc = platform_screen(screen);

    if (uncovered.width > 0) {
        paint_background(sc, &uncovered);
        drawn[n_drawn++] = uncovered;
        f.painted++;
    }
    /* Back to front: a surface is copied if it changed, or if anything
     * behind it was painted or copied where it lies. */
    for (int i = 0; i < n; i++) {
        const struct surface_view *v = &views[i];
        int copy = v->dirty;
        for (int d = 0; !copy && d < n_drawn; d++) {
            copy = overlaps(v->x, v->y, v->width, v->height, &drawn[d]);
        }
        if (!copy) {
            continue;
        }
        copy_surface(sc, v);
        drawn[n_drawn].x = v->x;
        drawn[n_drawn].y = v->y;
        drawn[n_drawn].width = v->width;
        drawn[n_drawn].height = v->height;
        n_drawn++;
        f.copied++;
    }
    if (n_drawn > 0) {
        platform_screen_present(screen);
    }
    return f;
}
/* }}} */

/* {{{ compositor_frame */
struct compositor_frame compositor_frame(void)
{
    struct compositor_frame total = { 0, 0 };
    for (int s = 0; s < PLATFORM_SCREEN_COUNT; s++) {
        struct compositor_frame f = compositor_screen(s);
        total.copied += f.copied;
        total.painted += f.painted;
    }
    return total;
}
/* }}} */

/* {{{ compositor_start */
int compositor_start(struct compositor *c, struct map_report *report)
{
    c->program = -1;
    c->timer = -1;
    int program = program_load(COMPOSITOR_MAP, report);
    if (program < 0) {
        return -1;
    }
    if (program_bring_up(program, report) != 0) {
        program_remove(program);
        return -1;
    }
    /* The tick goes straight into the station behind the argument door
     * (its port 0). The input frame's program_argument_every (501) does
     * the same once it is merged. */
    int64_t tick = 1;
    int timer = engine_timer(program_station(program, "composite"), 0, &tick, sizeof tick,
                             platform_now_ns() + COMPOSITOR_FRAME_NS, COMPOSITOR_FRAME_NS);
    if (timer < 0) {
        text_format(report->text, sizeof report->text,
                    "%s: the frame's timer could not be armed (%d)\n", COMPOSITOR_MAP, timer);
        report->problems = 1;
        program_remove(program);
        return -1;
    }
    c->program = program;
    c->timer = timer;
    return program;
}
/* }}} */

/* {{{ compositor_stop */
void compositor_stop(struct compositor *c)
{
    if (c->timer >= 0) {
        engine_timer_cancel(c->timer);
        c->timer = -1;
    }
}
/* }}} */
