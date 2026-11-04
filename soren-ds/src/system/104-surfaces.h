/*
 * 104-surfaces.h — rectangles of a screen that one box owns (issue 601).
 *
 * General description: a surface is a rectangle of pixels on one of the
 * two screens that exactly one owner may draw into. The owner is a
 * station — the box's instance — or the system (SURFACE_SYSTEM) for what
 * no app owns. Asking for one either grants it, with a handle and a
 * buffer of pixels the owner writes and the compositor (603) reads, or
 * refuses it because another owner of the same app already holds some of
 * that rectangle on that screen. Each app has each screen to itself
 * (604): only the foreground app's surfaces are shown, so two apps may
 * hold the same rectangle, and the one in the background keeps its
 * surfaces, and keeps drawing into them, until it comes back. Moving and resizing are asked for the same way and
 * checked the same way. Surfaces on a screen stack back to front in the
 * order they were granted.
 *
 * Every surface carries a damage bit (602): the owner marks it after
 * writing pixels, and the compositor (603) takes it — reads and clears it
 * in one step — before copying the surface forward, so it copies only
 * what changed and never loses a mark made while it copies. A surface
 * starts marked, and a resize or move marks it again: each changes what
 * the screen should show.
 *
 * A handle names one grant: it carries a count that changes every time
 * its slot is reused, so a handle kept after its surface was released
 * never reaches whatever was granted in that slot next.
 *
 * The pixel buffers are the engine's memory, and a buffer replaced by a
 * resize or let go by a release is retired, not freed: a box that took
 * the pointer during its run may finish writing through it.
 */
#ifndef SOREN_SURFACES_H
#define SOREN_SURFACES_H

#include <stdint.h>
#include "058-draw.h"

#define SURFACE_MAX     64          /* across both screens */
#define SURFACE_SYSTEM  (-1)        /* the owner for what no app owns */

/* Apps (604). An owner's app is the top-level program its station was
 * placed by (program_app_of), a number from 0. Two more: */
#define SURFACE_APP_SYSTEM (-1)     /* the system's surfaces: shown on every foreground */
#define SURFACE_APP_NONE   (-2)     /* owners no program placed: one app between them */

/* Answers (negative), beside a handle (positive) or 0. */
enum surface_answer {
    SURFACE_OK          = 0,
    SURFACE_TAKEN       = -1,       /* another owner of the same app holds part of it */
    SURFACE_OFF_SCREEN  = -2,       /* not wholly on the screen, or empty, or no such screen */
    SURFACE_NO_HANDLE   = -3,       /* the handle names nothing granted now */
    SURFACE_FULL        = -4,       /* every slot is in use */
    SURFACE_NO_MEMORY   = -5,       /* the pool could not give the pixels */
    SURFACE_NOT_OWNER   = -6,       /* the handle is someone else's */
};

/* A surface as it stands, for the compositor and for tests. */
struct surface_facts {
    int      screen;
    int      x, y, width, height;
    int32_t  owner;
    int32_t  app;                   /* the owner's app (604) */
    uint32_t z;                     /* larger is nearer the front */
};

/* Ask for a rectangle of `screen` (0 top, 1 bottom), owned by the station
 * running this call, or by the system when no station is. Answers a
 * handle (> 0) or a negative surface_answer. */
int32_t surface_request(int screen, int x, int y, int width, int height);

/* The same, for a named owner: a station, or SURFACE_SYSTEM. */
int32_t surface_request_for(int32_t owner, int screen, int x, int y, int width, int height);

/* The app an owner belongs to: SURFACE_APP_SYSTEM for SURFACE_SYSTEM, the
 * top-level program of a placed station, or SURFACE_APP_NONE. Fixed at
 * the grant, as a station's program never changes. */
int32_t surface_app_of(int32_t owner);

/* Let a surface go: its pixels are no longer the owner's to write or the
 * compositor's to read, and its rectangle is free for anyone. */
int surface_release(int32_t handle);

/* Grow or shrink it in place (its top-left corner stays put), or move it,
 * under the same check as a request. A resize keeps the pixels the old
 * and new rectangles share, and the rest of the new one starts clear. */
int surface_resize(int32_t handle, int width, int height);
int surface_set_position(int32_t handle, int x, int y);

/* The pixels to draw into, as a canvas of the surface's own size (empty,
 * with no pixels, for a handle that names nothing). Valid until the
 * surface is resized or released, and through the end of the run it was
 * taken in. */
struct canvas surface_canvas(int32_t handle);

/* Facts about one surface. Answers SURFACE_OK or SURFACE_NO_HANDLE. */
int surface_facts(int32_t handle, struct surface_facts *out);

/* Every surface on `screen`, back to front: up to `max` handles into
 * `out`. Answers how many there are. */
int surface_list(int screen, int32_t *out, int max);

/* The damage bit. Mark it after writing the pixels (release: the writes
 * come before the mark for whoever sees it). Is-dirty looks without
 * clearing. Take answers whether it was marked and clears it, in one
 * step: call it before copying, never clear after, or a mark made during
 * the copy is lost. Each answers SURFACE_NO_HANDLE for a handle that
 * names nothing; is-dirty and take otherwise answer 1 or 0. */
int surface_mark_dirty(int32_t handle);
int surface_is_dirty(int32_t handle);
int surface_take_dirty(int32_t handle);

/* {{{ what the compositor reads (603) */
struct surface_rect {
    int x, y, width, height;        /* width 0: nothing */
};

/* One surface as the compositor copies it: where it is, its pixels (rows
 * `width` words apart) and whether it was marked, all read at one moment. */
struct surface_view {
    int32_t   handle;
    int       x, y, width, height;
    int32_t   owner;
    int32_t   app;
    uint32_t  z;
    uint32_t *pixels;
    int       dirty;
};

/* Say that a rectangle of `screen` must be painted again: what was there
 * has gone. A release, a move and a resize say it themselves about the
 * rectangle the surface left; the foreground (604) and the drawers (606)
 * say it when what should show changes. Clipped to the screen. */
void surface_expose(int screen, int x, int y, int width, int height);

/* Every surface on `screen`, back to front, up to `max` of them, each with
 * its damage bit taken (read and cleared, as surface_take_dirty does);
 * and in `uncovered`, the one rectangle holding everything exposed since
 * the last gather, taken too. Answers how many surfaces there are, up to
 * `max`. The pixels stay readable until the end of the caller's run: call
 * this from inside a box's run, or where nothing releases or resizes
 * surfaces at the same time. */
int surface_gather(int screen, struct surface_view *out, int max, struct surface_rect *uncovered);
/* }}} */

#endif
