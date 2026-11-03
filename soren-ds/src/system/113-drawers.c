/*
 * 113-drawers.c — the four drawers that slide over a screen (issue 606).
 *
 * General description: see 113-drawers.h. Four records behind one lock.
 * A drawer's pixels are taken from the engine's pool the first time it
 * opens and kept: there are only ever four, and a drawer that is opened
 * once is opened again.
 */
#include <stdint.h>
#include <stddef.h>
#include "../engine/025-platform.h"
#include "../engine/027-primitives.h"
#include "../engine/031-engine.h"
#include "113-drawers.h"

struct drawer {
    int       state;
    int       progress;              /* 0 .. DRAWER_SLIDE_FRAMES */
    int       redraw;                /* moved or marked since last drawn */
    uint32_t *pixels;                /* width × height, rows `width` apart */
};

static struct drawer drawers[PLATFORM_SCREEN_COUNT][2];
static spin_lock_t   lock = SPIN_LOCK_INIT;

/* {{{ geometry */
struct geometry {
    int open_x, y, width, height;   /* the open drawer */
    int screen_width;
};

static struct geometry geometry_of(int screen, int edge)
{
    struct platform_screen sc = platform_screen(screen);
    struct geometry g;
    int margin_x = sc.width * DRAWER_MARGIN_PERCENT / 100;
    int margin_y = sc.height * DRAWER_MARGIN_PERCENT / 100;
    g.width = sc.width * DRAWER_WIDTH_PERCENT / 100;
    g.height = sc.height - 2 * margin_y;
    g.y = margin_y;
    g.open_x = edge == DRAWER_LEFT ? margin_x : sc.width - margin_x - g.width;
    g.screen_width = sc.width;
    return g;
}

/* Where the drawer's left edge is at `progress`: wholly off its edge at 0,
 * in place at DRAWER_SLIDE_FRAMES, an even step between. */
static int x_at(const struct geometry *g, int edge, int progress)
{
    if (edge == DRAWER_LEFT) {
        return -g->width + (g->open_x + g->width) * progress / DRAWER_SLIDE_FRAMES;
    }
    return g->screen_width - (g->screen_width - g->open_x) * progress / DRAWER_SLIDE_FRAMES;
}

/* The part of the screen the drawer covers at `progress`. */
static struct surface_rect visible_at(const struct geometry *g, int edge, int progress)
{
    struct surface_rect r = { 0, 0, 0, 0 };
    if (progress <= 0) {
        return r;
    }
    int x = x_at(g, edge, progress);
    int x0 = x < 0 ? 0 : x;
    int x1 = x + g->width > g->screen_width ? g->screen_width : x + g->width;
    if (x0 >= x1) {
        return r;
    }
    r.x = x0;
    r.y = g->y;
    r.width = x1 - x0;
    r.height = g->height;
    return r;
}
/* }}} */

/* {{{ valid */
static int valid(int screen, int edge)
{
    return screen >= 0 && screen < PLATFORM_SCREEN_COUNT && (edge == DRAWER_LEFT || edge == DRAWER_RIGHT);
}
/* }}} */

/* {{{ blank_panel */
/* An empty drawer: the panel colour with a rule around it. */
static void blank_panel(uint32_t *pixels, int width, int height)
{
    struct canvas c = { pixels, width, height, width };
    draw_fill(c, COLOUR_PANEL);
    draw_frame(c, 0, 0, width, height, COLOUR_RULE);
}
/* }}} */

/* {{{ slide */
/* Start a slide toward `toward` (DRAWER_OPENING or DRAWER_CLOSING). */
static int slide(int screen, int edge, int toward)
{
    if (!valid(screen, edge)) {
        return DRAWER_NO_SUCH;
    }
    struct geometry g = geometry_of(screen, edge);
    uint32_t *fresh = NULL;
    if (toward == DRAWER_OPENING) {
        spin_lock(&lock);
        int have = drawers[screen][edge].pixels != NULL;
        spin_unlock(&lock);
        if (!have) {
            fresh = engine_memory_take((size_t)g.width * (size_t)g.height * sizeof *fresh);
            if (!fresh) {
                return DRAWER_NO_MEMORY;
            }
            blank_panel(fresh, g.width, g.height);
        }
    }
    spin_lock(&lock);
    struct drawer *d = &drawers[screen][edge];
    if (fresh && !d->pixels) {
        d->pixels = fresh;
        fresh = NULL;
    }
    if (toward == DRAWER_OPENING && d->state != DRAWER_OPEN) {
        d->state = DRAWER_OPENING;
    } else if (toward == DRAWER_CLOSING && d->state != DRAWER_CLOSED) {
        d->state = DRAWER_CLOSING;
    }
    spin_unlock(&lock);
    if (fresh) {
        engine_memory_retire(fresh);     /* another opening got there first */
    }
    return DRAWER_OK;
}
/* }}} */

/* {{{ drawer_open, drawer_close */
int drawer_open(int screen, int edge)
{
    return slide(screen, edge, DRAWER_OPENING);
}

int drawer_close(int screen, int edge)
{
    return slide(screen, edge, DRAWER_CLOSING);
}
/* }}} */

/* {{{ drawer_state, drawer_progress, drawer_rect */
int drawer_state(int screen, int edge)
{
    if (!valid(screen, edge)) {
        return DRAWER_NO_SUCH;
    }
    spin_lock(&lock);
    int state = drawers[screen][edge].state;
    spin_unlock(&lock);
    return state;
}

int drawer_progress(int screen, int edge)
{
    if (!valid(screen, edge)) {
        return DRAWER_NO_SUCH;
    }
    spin_lock(&lock);
    int progress = drawers[screen][edge].progress;
    spin_unlock(&lock);
    return progress;
}

struct surface_rect drawer_rect(int screen, int edge)
{
    struct surface_rect none = { 0, 0, 0, 0 };
    if (!valid(screen, edge)) {
        return none;
    }
    struct geometry g = geometry_of(screen, edge);
    return visible_at(&g, edge, drawer_progress(screen, edge));
}
/* }}} */

/* {{{ drawer_canvas, drawer_mark_dirty */
struct canvas drawer_canvas(int screen, int edge)
{
    struct canvas c = { NULL, 0, 0, 0 };
    if (!valid(screen, edge)) {
        return c;
    }
    struct geometry g = geometry_of(screen, edge);
    spin_lock(&lock);
    c.pixels = drawers[screen][edge].pixels;
    spin_unlock(&lock);
    if (c.pixels) {
        c.width = c.stride = g.width;
        c.height = g.height;
    }
    return c;
}

int drawer_mark_dirty(int screen, int edge)
{
    if (!valid(screen, edge)) {
        return DRAWER_NO_SUCH;
    }
    spin_lock(&lock);
    drawers[screen][edge].redraw = 1;
    spin_unlock(&lock);
    return DRAWER_OK;
}
/* }}} */

/* {{{ drawers_advance */
void drawers_advance(int screen)
{
    if (screen < 0 || screen >= PLATFORM_SCREEN_COUNT) {
        return;
    }
    for (int edge = 0; edge < 2; edge++) {
        struct geometry g = geometry_of(screen, edge);
        struct surface_rect left = { 0, 0, 0, 0 };
        spin_lock(&lock);
        struct drawer *d = &drawers[screen][edge];
        int was = d->progress;
        if (d->state == DRAWER_OPENING) {
            if (++d->progress >= DRAWER_SLIDE_FRAMES) {
                d->progress = DRAWER_SLIDE_FRAMES;
                d->state = DRAWER_OPEN;
            }
        } else if (d->state == DRAWER_CLOSING) {
            if (--d->progress <= 0) {
                d->progress = 0;
                d->state = DRAWER_CLOSED;
            }
        }
        if (d->progress != was) {
            d->redraw = 1;
            left = visible_at(&g, edge, was);
        }
        spin_unlock(&lock);
        /* Everything it covered before this step is painted again, then
         * the drawer is drawn where it is now: simpler than working out
         * the strip it uncovered, and never wrong. */
        if (left.width > 0) {
            surface_expose(screen, left.x, left.y, left.width, left.height);
        }
    }
}
/* }}} */

/* {{{ drawers_draw */
int drawers_draw(int screen, struct platform_screen sc, const struct surface_rect *drawn, int n_drawn)
{
    int count = 0;
    if (screen < 0 || screen >= PLATFORM_SCREEN_COUNT) {
        return 0;
    }
    for (int edge = 0; edge < 2; edge++) {
        struct geometry g = geometry_of(screen, edge);
        spin_lock(&lock);
        struct drawer *d = &drawers[screen][edge];
        int progress = d->progress;
        int redraw = d->redraw;
        uint32_t *pixels = d->pixels;
        struct surface_rect r = visible_at(&g, edge, progress);
        for (int i = 0; !redraw && i < n_drawn; i++) {
            redraw = r.width > 0 && drawn[i].width > 0 && r.x < drawn[i].x + drawn[i].width &&
                     drawn[i].x < r.x + r.width && r.y < drawn[i].y + drawn[i].height && drawn[i].y < r.y + r.height;
        }
        d->redraw = 0;
        spin_unlock(&lock);
        if (!redraw || r.width == 0 || !pixels) {
            continue;
        }
        /* The visible part, taken from the drawer's own pixels at the
         * offset its slide has put off the screen. */
        int from_col = r.x - x_at(&g, edge, progress);
        for (int row = 0; row < r.height; row++) {
            bytes_copy(sc.pixels + (size_t)(r.y + row) * (size_t)sc.stride + (size_t)r.x,
                       pixels + (size_t)row * (size_t)g.width + (size_t)from_col,
                       (size_t)r.width * sizeof *pixels);
        }
        count++;
    }
    return count;
}
/* }}} */
