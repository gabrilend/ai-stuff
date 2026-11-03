/*
 * 113-drawers.h — the four drawers that slide over a screen (issue 606).
 *
 * General description: a drawer is the system's, not any app's: a panel
 * the full height of its screen less a margin top and bottom, 40% of its
 * width, that slides in from its edge — the left or right of the top or
 * bottom screen — in six frames, sits there over whatever the foreground
 * shows, and slides back out the same way. There are four, made once,
 * for the life of the system.
 *
 * A drawer is not in the surface table (601): a surface must be wholly on
 * its screen, and a drawer spends its slide half off it. The compositor
 * (603) moves each drawer one step at the start of a frame and draws it
 * last, over everything, clipped to the screen. Wherever a drawer has
 * just been and no longer is, it is exposed (surface_expose), so the
 * frame paints the background and copies back the foreground's surfaces
 * there: the cover lifts onto whatever the app has drawn meanwhile.
 *
 * The contents are a canvas of the drawer's own size, which the
 * foreground app's drawer contents (608) will fill; until then each
 * drawer is an empty panel with a rule around it.
 */
#ifndef SOREN_DRAWERS_H
#define SOREN_DRAWERS_H

#include <stdint.h>
#include "../engine/025-platform.h"
#include "058-draw.h"
#include "104-surfaces.h"

enum drawer_edge {
    DRAWER_LEFT  = 0,
    DRAWER_RIGHT = 1,
};

enum drawer_state {
    DRAWER_CLOSED  = 0,
    DRAWER_OPENING = 1,
    DRAWER_OPEN    = 2,
    DRAWER_CLOSING = 3,
};

/* Answers, beside a state. */
#define DRAWER_OK          0
#define DRAWER_NO_SUCH    (-1)        /* no such screen or edge */
#define DRAWER_NO_MEMORY  (-2)        /* the pool could not give its pixels */

/* Frames from shut to open, and back: fast, but every one of them seen. */
#define DRAWER_SLIDE_FRAMES 6

/* Geometry, in hundredths of the screen (005-display-and-compositor.md). */
#define DRAWER_MARGIN_PERCENT 5       /* top, bottom and its own edge */
#define DRAWER_WIDTH_PERCENT  40

/* Start sliding it in, or out. From part way through a slide, the other
 * way goes back from where it is. Opening one that is open, or closing
 * one that is closed, changes nothing. */
int drawer_open(int screen, int edge);
int drawer_close(int screen, int edge);

/* Where it stands: a drawer_state, or DRAWER_NO_SUCH. */
int drawer_state(int screen, int edge);
/* How far open, from 0 (shut) to DRAWER_SLIDE_FRAMES (open). */
int drawer_progress(int screen, int edge);
/* The part of the screen it covers now (width 0 when shut). */
struct surface_rect drawer_rect(int screen, int edge);

/* The contents, a canvas the size of the open drawer; empty until the
 * drawer is first opened. Mark it after writing, as a surface is marked. */
struct canvas drawer_canvas(int screen, int edge);
int drawer_mark_dirty(int screen, int edge);

/* For the compositor (603), once a frame per screen, in this order: move
 * every sliding drawer one step, exposing where each has left (before the
 * surfaces are gathered); then, after the surfaces are copied, draw every
 * drawer that is not shut and that moved, was marked, or lies over
 * anything painted or copied this frame (`drawn`). Answers how many were
 * drawn. */
void drawers_advance(int screen);
int  drawers_draw(int screen, struct platform_screen sc, const struct surface_rect *drawn, int n_drawn);

#endif
