/*
 * Entity Render Slots Implementation (Issue 508b)
 *
 * Fixed-size slot array with free list for O(1) allocation.
 * Self-cleaning setters implement "mise en place" pattern:
 * when new data arrives, point to it and immediately free old.
 */

#include "slots.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* {{{ slot_free_default
 * Default cleanup function for RenderSlot.
 * Simply frees the malloc'd memory. */
void slot_free_default(RenderSlot* data) {
    if (data) {
        free(data);
    }
}
/* }}} */

/* {{{ slot_set_default
 * Default setter - atomic swap with immediate cleanup (mise en place).
 * Draw thread sees the swap atomically; old data freed immediately. */
void slot_set_default(ComponentSlot* self, RenderSlot* new_data) {
    RenderSlot* old = self->data;

    /* Point to new (draw thread sees this atomically) */
    self->data = new_data;

    /* Mise en place - clean the old immediately */
    if (old && self->free_fn) {
        self->free_fn(old);
    }
}
/* }}} */

/* {{{ slot_set
 * Wrapper that calls the slot's set function pointer.
 * Allows custom setters per slot if needed. */
void slot_set(ComponentSlot* self, RenderSlot* new_data) {
    if (self && self->set) {
        self->set(self, new_data);
    }
}
/* }}} */

/* {{{ init_component_slot
 * Initialize a single component slot with defaults. */
static void init_component_slot(ComponentSlot* slot) {
    slot->data = NULL;
    slot->set = slot_set_default;
    slot->free_fn = slot_free_default;
    slot->entity_id = -1;
    slot->in_use = false;
}
/* }}} */

/* {{{ slot_array_create
 * Creates a new slot array with all slots on the free list.
 * Returns NULL on allocation failure. */
SlotArray* slot_array_create(void) {
    SlotArray* arr = (SlotArray*)malloc(sizeof(SlotArray));
    if (!arr) {
        fprintf(stderr, "[slots] Failed to allocate SlotArray\n");
        return NULL;
    }

    /* Initialize all slots */
    for (int i = 0; i < MAX_SLOTS; i++) {
        init_component_slot(&arr->slots[i]);
    }

    /* Build free list (stack order: 0 at top) */
    for (int i = 0; i < MAX_SLOTS; i++) {
        arr->free_list[i] = MAX_SLOTS - 1 - i;
    }
    arr->free_count = MAX_SLOTS;
    arr->active_count = 0;

    /* Initialize mutex */
    if (pthread_mutex_init(&arr->alloc_lock, NULL) != 0) {
        fprintf(stderr, "[slots] Failed to initialize mutex\n");
        free(arr);
        return NULL;
    }

    return arr;
}
/* }}} */

/* {{{ slot_array_destroy
 * Frees all slot data and the array itself. */
void slot_array_destroy(SlotArray* arr) {
    if (!arr) return;

    /* Free all slot data */
    for (int i = 0; i < MAX_SLOTS; i++) {
        ComponentSlot* slot = &arr->slots[i];
        if (slot->data && slot->free_fn) {
            slot->free_fn(slot->data);
            slot->data = NULL;
        }
    }

    pthread_mutex_destroy(&arr->alloc_lock);
    free(arr);
}
/* }}} */

/* {{{ slot_allocate
 * Allocates a slot from the free list.
 * Returns slot index, or -1 if pool is exhausted.
 * Thread-safe via mutex. */
int slot_allocate(SlotArray* arr) {
    if (!arr) return -1;

    pthread_mutex_lock(&arr->alloc_lock);

    if (arr->free_count == 0) {
        pthread_mutex_unlock(&arr->alloc_lock);
        return -1;  /* Pool exhausted */
    }

    /* Pop from free list stack */
    int index = arr->free_list[arr->free_count - 1];
    arr->free_count--;
    arr->active_count++;

    /* Mark as in use */
    arr->slots[index].in_use = true;
    arr->slots[index].entity_id = -1;

    pthread_mutex_unlock(&arr->alloc_lock);

    return index;
}
/* }}} */

/* {{{ slot_release
 * Returns a slot to the free list.
 * Frees any associated data via the slot's free_fn.
 * Thread-safe via mutex. */
void slot_release(SlotArray* arr, int index) {
    if (!arr || index < 0 || index >= MAX_SLOTS) return;

    pthread_mutex_lock(&arr->alloc_lock);

    ComponentSlot* slot = &arr->slots[index];

    if (!slot->in_use) {
        /* Already free - avoid double-free */
        pthread_mutex_unlock(&arr->alloc_lock);
        return;
    }

    /* Free slot data if present */
    if (slot->data && slot->free_fn) {
        slot->free_fn(slot->data);
        slot->data = NULL;
    }

    /* Reset slot state */
    slot->in_use = false;
    slot->entity_id = -1;

    /* Push back onto free list stack */
    arr->free_list[arr->free_count] = index;
    arr->free_count++;
    arr->active_count--;

    pthread_mutex_unlock(&arr->alloc_lock);
}
/* }}} */

/* {{{ slot_get
 * Returns pointer to slot at index.
 * Returns NULL for invalid index. Does not check in_use. */
ComponentSlot* slot_get(SlotArray* arr, int index) {
    if (!arr || index < 0 || index >= MAX_SLOTS) {
        return NULL;
    }
    return &arr->slots[index];
}
/* }}} */

/* {{{ slot_find_by_entity
 * Finds slot linked to given entity_id.
 * Returns slot index, or -1 if not found.
 * O(n) scan - for frequent lookups, maintain a separate map. */
int slot_find_by_entity(SlotArray* arr, int entity_id) {
    if (!arr || entity_id < 0) return -1;

    for (int i = 0; i < MAX_SLOTS; i++) {
        if (arr->slots[i].in_use && arr->slots[i].entity_id == entity_id) {
            return i;
        }
    }
    return -1;
}
/* }}} */

/* {{{ slot_link_entity
 * Links a slot to an entity_id.
 * Used when creating render representation for a game entity. */
void slot_link_entity(SlotArray* arr, int slot_index, int entity_id) {
    ComponentSlot* slot = slot_get(arr, slot_index);
    if (slot && slot->in_use) {
        slot->entity_id = entity_id;
    }
}
/* }}} */

/* {{{ slot_unlink_entity
 * Unlinks a slot from its entity.
 * Slot remains allocated but no longer associated with an entity. */
void slot_unlink_entity(SlotArray* arr, int slot_index) {
    ComponentSlot* slot = slot_get(arr, slot_index);
    if (slot && slot->in_use) {
        slot->entity_id = -1;
    }
}
/* }}} */

/* {{{ slot_get_active_count
 * Returns number of slots currently in use. */
int slot_get_active_count(SlotArray* arr) {
    if (!arr) return 0;
    return arr->active_count;
}
/* }}} */

/* {{{ slot_foreach_active
 * Iterates over all active (in_use) slots.
 * Callback receives: slot pointer, slot index, userdata. */
void slot_foreach_active(SlotArray* arr, void (*callback)(ComponentSlot*, int, void*), void* userdata) {
    if (!arr || !callback) return;

    for (int i = 0; i < MAX_SLOTS; i++) {
        if (arr->slots[i].in_use) {
            callback(&arr->slots[i], i, userdata);
        }
    }
}
/* }}} */

/* {{{ slot_allocate_for_entity
 * Convenience: allocate a slot and link it to an entity in one call.
 * Returns slot index, or -1 if allocation failed. */
int slot_allocate_for_entity(SlotArray* arr, int entity_id) {
    int index = slot_allocate(arr);
    if (index >= 0) {
        slot_link_entity(arr, index, entity_id);
    }
    return index;
}
/* }}} */

/* {{{ slot_release_by_entity
 * Convenience: find slot by entity_id and release it.
 * No-op if entity not found. */
void slot_release_by_entity(SlotArray* arr, int entity_id) {
    int index = slot_find_by_entity(arr, entity_id);
    if (index >= 0) {
        slot_release(arr, index);
    }
}
/* }}} */
