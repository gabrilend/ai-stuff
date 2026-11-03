/*
 * 104-surfaces.c — rectangles of a screen that one box owns (issue 601).
 *
 * General description: see 104-surfaces.h. One table of slots for both
 * screens behind one lock, scanned in full for every question: there are
 * a handful of surfaces per screen, and a scan of 64 is cheaper than
 * keeping anything more clever right. Pixels are taken before the lock
 * and retired after it, so the lock is only ever held for the scan and
 * the copy a resize makes.
 */
#include <stdint.h>
#include <stddef.h>
#include "../engine/025-platform.h"
#include "../engine/027-primitives.h"
#include "../engine/031-engine.h"
#include "104-surfaces.h"

#define GENERATION_MASK 0xFFFFFFu   /* keeps every handle positive */
#define SLOT_BITS       7

struct slot {
    int       in_use;
    uint32_t  generation;
    int       screen;
    int       x, y, width, height;
    int32_t   owner;
    uint32_t  z;
    uint32_t *pixels;
};

static struct slot   slots[SURFACE_MAX];
static spin_lock_t   lock = SPIN_LOCK_INIT;
static uint32_t      next_z = 1;

/* {{{ handle_of */
static int32_t handle_of(int i)
{
    return (int32_t)(((slots[i].generation & GENERATION_MASK) << SLOT_BITS) | (uint32_t)(i + 1));
}
/* }}} */

/* {{{ slot_of */
/* The slot a handle names, if it still names a grant. Called holding the
 * lock. */
static struct slot *slot_of(int32_t handle)
{
    if (handle <= 0) {
        return NULL;
    }
    int i = (int)((uint32_t)handle & ((1u << SLOT_BITS) - 1)) - 1;
    uint32_t generation = (uint32_t)handle >> SLOT_BITS;
    if (i < 0 || i >= SURFACE_MAX || !slots[i].in_use || (slots[i].generation & GENERATION_MASK) != generation) {
        return NULL;
    }
    return &slots[i];
}
/* }}} */

/* {{{ on_screen */
static int on_screen(int screen, int x, int y, int width, int height)
{
    if (screen < 0 || screen >= PLATFORM_SCREEN_COUNT || width <= 0 || height <= 0 || x < 0 || y < 0) {
        return 0;
    }
    struct platform_screen s = platform_screen(screen);
    return x <= s.width - width && y <= s.height - height;
}
/* }}} */

/* {{{ taken_by_another */
/* Does any surface on `screen` owned by someone other than `owner`
 * overlap the rectangle? `self` is left out (a surface never conflicts
 * with itself). Called holding the lock. */
static int taken_by_another(int screen, int x, int y, int width, int height, int32_t owner, const struct slot *self)
{
    for (int i = 0; i < SURFACE_MAX; i++) {
        const struct slot *o = &slots[i];
        if (!o->in_use || o == self || o->screen != screen || o->owner == owner) {
            continue;
        }
        if (x < o->x + o->width && o->x < x + width && y < o->y + o->height && o->y < y + height) {
            return 1;
        }
    }
    return 0;
}
/* }}} */

/* {{{ may_change */
/* A box may change only its own surfaces; a caller outside every run
 * (boot, the system, a test) may change any. */
static int may_change(const struct slot *s)
{
    int32_t here = engine_current_station();
    return here < 0 || here == s->owner;
}
/* }}} */

/* {{{ surface_request_for */
int32_t surface_request_for(int32_t owner, int screen, int x, int y, int width, int height)
{
    if (!on_screen(screen, x, y, width, height)) {
        return SURFACE_OFF_SCREEN;
    }
    uint32_t *pixels = engine_memory_take((size_t)width * (size_t)height * sizeof *pixels);
    if (!pixels) {
        return SURFACE_NO_MEMORY;
    }
    int32_t answer = SURFACE_FULL;
    spin_lock(&lock);
    if (taken_by_another(screen, x, y, width, height, owner, NULL)) {
        answer = SURFACE_TAKEN;
    } else {
        for (int i = 0; i < SURFACE_MAX; i++) {
            struct slot *s = &slots[i];
            if (s->in_use) {
                continue;
            }
            s->generation = (s->generation + 1) & GENERATION_MASK;
            if (s->generation == 0) {
                s->generation = 1;
            }
            s->in_use = 1;
            s->screen = screen;
            s->x = x;
            s->y = y;
            s->width = width;
            s->height = height;
            s->owner = owner;
            s->z = next_z++;
            s->pixels = pixels;
            answer = handle_of(i);
            break;
        }
    }
    spin_unlock(&lock);
    if (answer < 0) {
        engine_memory_retire(pixels);
    }
    return answer;
}
/* }}} */

/* {{{ surface_request */
int32_t surface_request(int screen, int x, int y, int width, int height)
{
    int32_t here = engine_current_station();
    return surface_request_for(here >= 0 ? here : SURFACE_SYSTEM, screen, x, y, width, height);
}
/* }}} */

/* {{{ surface_release */
int surface_release(int32_t handle)
{
    uint32_t *pixels = NULL;
    int answer;
    spin_lock(&lock);
    struct slot *s = slot_of(handle);
    if (!s) {
        answer = SURFACE_NO_HANDLE;
    } else if (!may_change(s)) {
        answer = SURFACE_NOT_OWNER;
    } else {
        pixels = s->pixels;
        s->pixels = NULL;
        s->in_use = 0;
        answer = SURFACE_OK;
    }
    spin_unlock(&lock);
    engine_memory_retire(pixels);
    return answer;
}
/* }}} */

/* {{{ surface_resize */
int surface_resize(int32_t handle, int width, int height)
{
    int screen = 0, x = 0, y = 0;
    spin_lock(&lock);
    struct slot *s = slot_of(handle);
    if (s) {
        screen = s->screen;
        x = s->x;
        y = s->y;
    }
    spin_unlock(&lock);
    if (!s) {
        return SURFACE_NO_HANDLE;
    }
    if (!on_screen(screen, x, y, width, height)) {
        return SURFACE_OFF_SCREEN;
    }
    uint32_t *fresh = engine_memory_take((size_t)width * (size_t)height * sizeof *fresh);
    if (!fresh) {
        return SURFACE_NO_MEMORY;
    }
    uint32_t *old = fresh;          /* what to retire: the new buffer, unless it is used */
    int answer;
    spin_lock(&lock);
    s = slot_of(handle);            /* it may have gone or moved while the lock was down */
    if (!s) {
        answer = SURFACE_NO_HANDLE;
    } else if (!may_change(s)) {
        answer = SURFACE_NOT_OWNER;
    } else if (!on_screen(s->screen, s->x, s->y, width, height)) {
        answer = SURFACE_OFF_SCREEN;
    } else if (taken_by_another(s->screen, s->x, s->y, width, height, s->owner, s)) {
        answer = SURFACE_TAKEN;
    } else {
        int rows = height < s->height ? height : s->height;
        int cols = width < s->width ? width : s->width;
        for (int r = 0; r < rows; r++) {
            bytes_copy(fresh + (size_t)r * (size_t)width, s->pixels + (size_t)r * (size_t)s->width,
                       (size_t)cols * sizeof *fresh);
        }
        old = s->pixels;
        s->pixels = fresh;
        s->width = width;
        s->height = height;
        answer = SURFACE_OK;
    }
    spin_unlock(&lock);
    engine_memory_retire(old);
    return answer;
}
/* }}} */

/* {{{ surface_set_position */
int surface_set_position(int32_t handle, int x, int y)
{
    int answer;
    spin_lock(&lock);
    struct slot *s = slot_of(handle);
    if (!s) {
        answer = SURFACE_NO_HANDLE;
    } else if (!may_change(s)) {
        answer = SURFACE_NOT_OWNER;
    } else if (!on_screen(s->screen, x, y, s->width, s->height)) {
        answer = SURFACE_OFF_SCREEN;
    } else if (taken_by_another(s->screen, x, y, s->width, s->height, s->owner, s)) {
        answer = SURFACE_TAKEN;
    } else {
        s->x = x;
        s->y = y;
        answer = SURFACE_OK;
    }
    spin_unlock(&lock);
    return answer;
}
/* }}} */

/* {{{ surface_canvas */
struct canvas surface_canvas(int32_t handle)
{
    struct canvas c = { NULL, 0, 0, 0 };
    spin_lock(&lock);
    struct slot *s = slot_of(handle);
    if (s) {
        c.pixels = s->pixels;
        c.width = s->width;
        c.height = s->height;
        c.stride = s->width;
    }
    spin_unlock(&lock);
    return c;
}
/* }}} */

/* {{{ surface_facts */
int surface_facts(int32_t handle, struct surface_facts *out)
{
    int answer = SURFACE_NO_HANDLE;
    spin_lock(&lock);
    struct slot *s = slot_of(handle);
    if (s) {
        out->screen = s->screen;
        out->x = s->x;
        out->y = s->y;
        out->width = s->width;
        out->height = s->height;
        out->owner = s->owner;
        out->z = s->z;
        answer = SURFACE_OK;
    }
    spin_unlock(&lock);
    return answer;
}
/* }}} */

/* {{{ surface_list */
int surface_list(int screen, int32_t *out, int max)
{
    int32_t  handles[SURFACE_MAX];
    uint32_t zs[SURFACE_MAX];
    int n = 0;
    spin_lock(&lock);
    for (int i = 0; i < SURFACE_MAX; i++) {
        if (!slots[i].in_use || slots[i].screen != screen) {
            continue;
        }
        /* Insert in z order, back to front. */
        int at = n++;
        while (at > 0 && zs[at - 1] > slots[i].z) {
            zs[at] = zs[at - 1];
            handles[at] = handles[at - 1];
            at--;
        }
        zs[at] = slots[i].z;
        handles[at] = handle_of(i);
    }
    spin_unlock(&lock);
    for (int i = 0; i < n && i < max; i++) {
        out[i] = handles[i];
    }
    return n;
}
/* }}} */
