/*
 * null_render.c - the headless renderer (issue 501c)
 *
 * See null_render.h. Walks the slot array as the draw thread does, skips
 * what the draw thread skips (a slot not in use, with no data, or not
 * visible), and counts and hashes the rest instead of drawing it.
 */

#include "null_render.h"
#include <stdio.h>
#include <string.h>

/* {{{ FNV-1a, 64-bit */
#define FNV_PRIME 0x100000001b3ULL

static uint64_t fnv_byte(uint64_t hash, unsigned char byte) {
    return (hash ^ byte) * FNV_PRIME;
}

static uint64_t fnv_u32(uint64_t hash, uint32_t v) {
    for (int i = 0; i < 4; i++) hash = fnv_byte(hash, (unsigned char)(v >> (8 * i)));
    return hash;
}

static uint64_t fnv_float(uint64_t hash, float f) {
    uint32_t bits;
    memcpy(&bits, &f, sizeof bits);
    return fnv_u32(hash, bits);
}
/* }}} */

/* {{{ null_render_hash_item */
uint64_t null_render_hash_item(uint64_t hash, int entity_id, const RenderSlot* s) {
    hash = fnv_u32(hash, (uint32_t)entity_id);
    hash = fnv_u32(hash, (uint32_t)s->mesh_id);
    hash = fnv_float(hash, s->x);
    hash = fnv_float(hash, s->y);
    hash = fnv_float(hash, s->z);
    hash = fnv_float(hash, s->rotation);
    hash = fnv_float(hash, s->spin);
    hash = fnv_float(hash, s->facing);
    hash = fnv_float(hash, s->scale);
    hash = fnv_byte(hash, s->r);
    hash = fnv_byte(hash, s->g);
    hash = fnv_byte(hash, s->b);
    hash = fnv_byte(hash, s->a);
    hash = fnv_byte(hash, s->selected ? 1 : 0);
    hash = fnv_u32(hash, (uint32_t)s->team_id);
    hash = fnv_u32(hash, (uint32_t)s->anim_frame);
    hash = fnv_float(hash, s->anim_time);
    return hash;
}
/* }}} */

/* {{{ null_render_slots */
int null_render_slots(SlotArray* slots, const NullBounds* map, NullReport* out) {
    memset(out, 0, sizeof *out);
    out->checksum = NULL_RENDER_FNV_START;
    if (!slots) return 0;
    for (int i = 0; i < MAX_SLOTS; i++) {
        ComponentSlot* slot = &slots->slots[i];
        if (!slot->in_use) continue;
        out->active++;
        RenderSlot* s = slot->data;
        if (!s || !s->visible) { out->hidden++; continue; }
        out->drawn++;
        if (s->mesh_id >= 0 && s->mesh_id < NULL_RENDER_KINDS) out->by_kind[s->mesh_id]++;
        else out->placeholders++;
        if (map && (s->x < map->min_x || s->x > map->max_x || s->y < map->min_y || s->y > map->max_y)) out->outside++;
        if (s->selected) out->selected++;
        out->checksum = null_render_hash_item(out->checksum, slot->entity_id, s);
    }
    return out->drawn;
}
/* }}} */

/* {{{ null_report_format */
int null_report_format(const NullReport* r, char* buf, size_t size) {
    return snprintf(buf, size,
        "null renderer: %d slots in use, %d drawn, %d hidden\n"
        "  circle %d, cube %d, triangle %d, cylinder %d, placeholders %d\n"
        "  outside the map %d, selected %d\n"
        "  checksum %016llx\n",
        r->active, r->drawn, r->hidden,
        r->by_kind[0], r->by_kind[1], r->by_kind[2], r->by_kind[3], r->placeholders,
        r->outside, r->selected, (unsigned long long)r->checksum);
}
/* }}} */
