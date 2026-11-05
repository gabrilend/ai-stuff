/*
 * null_render.h - the headless renderer (issue 501c)
 *
 * Reads the render slots the raylib renderer reads (slots.h), draws
 * nothing, and reports what it would have drawn: how many items of each
 * kind, which are outside the map, which have no model (placeholders),
 * and a checksum of the frame. For tests and the ceramic benchmarks
 * (515), which check a frame's contents without a display. Needs neither
 * raylib nor Lua. When the page (page.h, issue 501) replaces the slots,
 * the same report is taken over the page.
 */

#ifndef NULL_RENDER_H
#define NULL_RENDER_H

#include <stddef.h>
#include <stdint.h>
#include "slots.h"

/* {{{ The kinds the renderer has a model for: the bridge's mesh ids */
#define NULL_RENDER_KINDS 4      /* 0 circle, 1 cube, 2 triangle, 3 cylinder */
/* }}} */

/* {{{ NullBounds - the map's extent on the ground (x, y), inclusive */
typedef struct null_bounds {
    float min_x, min_y, max_x, max_y;
} NullBounds;
/* }}} */

/* {{{ NullReport - what one frame would have drawn */
typedef struct null_report {
    int active;                       /* slots in use */
    int drawn;                        /* in use, holding data, visible */
    int hidden;                       /* in use but not drawn */
    int by_kind[NULL_RENDER_KINDS];   /* drawn items of each kind */
    int placeholders;                 /* drawn items of a kind with no model */
    int outside;                      /* drawn items outside the map's bounds */
    int selected;                     /* drawn items showing a selection ring */
    uint64_t checksum;                /* FNV-1a over every drawn item, in slot order */
} NullReport;
/* }}} */

/* {{{ Functions */

/* Reads every slot of `slots` into `out`. `map` may be NULL (no item is
 * then outside). Returns out->drawn. */
int null_render_slots(SlotArray* slots, const NullBounds* map, NullReport* out);

/* The checksum of one item, folded into `hash` (start from
 * NULL_RENDER_FNV_START): the entity id and every field the renderer
 * draws from, written byte by byte in a fixed order, floats as their
 * bits, so the same frame gives the same number on any machine. */
#define NULL_RENDER_FNV_START 0xcbf29ce484222325ULL
uint64_t null_render_hash_item(uint64_t hash, int entity_id, const RenderSlot* item);

/* The report as text, a line each, into `buf` (at most `size` bytes,
 * always ended). Returns the length the whole text needs. */
int null_report_format(const NullReport* report, char* buf, size_t size);

/* }}} */

#endif /* NULL_RENDER_H */
