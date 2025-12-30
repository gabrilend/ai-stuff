/*
 * Entity Render Slots (Issue 508b)
 *
 * Implements the Component Slot system from docs/render-architecture.md:
 * - Fixed-size array of render slots for predictable memory
 * - Self-cleaning setters (mise en place pattern)
 * - Free list for O(1) allocation/deallocation
 *
 * Workers produce RenderSlots; draw thread consumes them.
 */

#ifndef SLOTS_H
#define SLOTS_H

#include <pthread.h>
#include <stdbool.h>

/* {{{ Configuration */
#define MAX_SLOTS 1024   /* Fixed array size - adjust at compile time if needed */
/* }}} */

/* {{{ RenderSlot - GPU-ready data for one entity
 * This is what workers produce and draw thread consumes.
 * Contains all data needed to render without accessing game state. */
typedef struct render_slot {
    /* Position (world coordinates) */
    float x, y, z;

    /* Orientation (degrees) */
    float rotation;       /* Clock-face rotation (around view axis) */
    float spin;           /* In-place spin (around Y axis) */
    float facing;         /* Direction entity is facing (for sprites) */

    /* Visual properties */
    float scale;
    unsigned char r, g, b, a;

    /* State flags */
    bool visible;         /* False = skip during draw */
    bool selected;        /* Show selection indicator */

    /* Mesh/sprite reference */
    int mesh_id;          /* 0 = circle, 1 = cube, 2 = sprite, etc. */

    /* Team color */
    int team_id;          /* -1 = no team color, 0-15 = team index */

    /* Animation state (for future use) */
    int anim_frame;
    float anim_time;
} RenderSlot;
/* }}} */

/* {{{ ComponentSlot - self-cleaning wrapper with dispatch-ready function pointers
 * Wraps a RenderSlot with lifecycle management.
 * The setter atomically swaps data and frees the old immediately. */
typedef struct component_slot {
    RenderSlot* data;                                    /* Current render data */
    void (*set)(struct component_slot*, RenderSlot*);    /* Point + free old */
    void (*free_fn)(RenderSlot*);                        /* Type-specific cleanup */
    int entity_id;                                       /* Link to game entity (-1 = unlinked) */
    bool in_use;                                         /* Slot allocation state */
} ComponentSlot;
/* }}} */

/* {{{ SlotArray - fixed-size array with free list
 * Manages allocation/deallocation of slots.
 * Thread-safe allocation via mutex. */
typedef struct slot_array {
    ComponentSlot slots[MAX_SLOTS];
    int free_list[MAX_SLOTS];     /* Stack of free indices */
    int free_count;               /* Number of items in free_list */
    int active_count;             /* Number of slots in use */
    pthread_mutex_t alloc_lock;   /* Protects allocation operations */
} SlotArray;
/* }}} */

/* {{{ Function Declarations */

/* SlotArray lifecycle */
SlotArray* slot_array_create(void);
void slot_array_destroy(SlotArray* arr);

/* Slot allocation */
int slot_allocate(SlotArray* arr);              /* Returns slot index, -1 if full */
void slot_release(SlotArray* arr, int index);   /* Returns slot to free list */
ComponentSlot* slot_get(SlotArray* arr, int index);

/* Slot data operations */
void slot_set(ComponentSlot* self, RenderSlot* new_data);
void slot_set_default(ComponentSlot* self, RenderSlot* new_data);
void slot_free_default(RenderSlot* data);

/* Entity linking */
int slot_find_by_entity(SlotArray* arr, int entity_id);
void slot_link_entity(SlotArray* arr, int slot_index, int entity_id);
void slot_unlink_entity(SlotArray* arr, int slot_index);

/* Iteration helpers */
int slot_get_active_count(SlotArray* arr);
void slot_foreach_active(SlotArray* arr, void (*callback)(ComponentSlot*, int, void*), void* userdata);

/* Convenience: allocate and link in one call */
int slot_allocate_for_entity(SlotArray* arr, int entity_id);
void slot_release_by_entity(SlotArray* arr, int entity_id);

/* }}} */

#endif /* SLOTS_H */
