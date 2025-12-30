# Issue 508b: Entity Render Slots

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Critical
**Dependencies:** 508a (threading infrastructure)

---

## Current Behavior

The rotating cube demo uses a single `Entity` struct. No system for managing
multiple renderable objects with proper lifecycle.

---

## Intended Behavior

Implement the **Component Slot** system from `docs/render-architecture.md`:

Each renderable entity gets a slot in a fixed-size array. Slots contain:
- GPU-ready render data (position, color, etc.)
- Function pointers for self-cleaning setters
- Lifecycle management (allocate/free)

### Mise en Place Pattern

The setter owns cleanup. When new data is set:
1. Point to new data
2. Immediately free old data

No orphaned allocations. Workers create, workers clean.

---

## Suggested Implementation Steps

### 1. Define RenderSlot

```c
/* {{{ RenderSlot - GPU-ready data for one entity */
typedef struct render_slot {
    // Position (world coords, transformed by worker)
    float x, y, z;

    // Visual properties
    float scale;
    unsigned char r, g, b, a;

    // State
    bool visible;
    bool selected;

    // Mesh reference
    int mesh_id;  // 0 = circle, 1 = square, 2 = triangle, etc.

    // Team color override
    int team_id;  // -1 = no team color
} RenderSlot;
/* }}} */
```

### 2. Define ComponentSlot (Self-Cleaning Wrapper)

```c
/* {{{ ComponentSlot - self-cleaning storage with dispatch-ready function pointers */
typedef struct component_slot {
    RenderSlot* data;                                    // Current render data
    void (*set)(struct component_slot*, RenderSlot*);    // Point + free old
    void (*free_fn)(RenderSlot*);                        // Type-specific cleanup
    int entity_id;                                       // Link to game entity
    bool in_use;                                         // Slot allocation state
} ComponentSlot;
/* }}} */
```

### 3. Implement Mise en Place Setter

```c
/* {{{ slot_set - atomic swap with immediate cleanup */
void slot_set(ComponentSlot* self, RenderSlot* new_data) {
    RenderSlot* old = self->data;

    // Point to new (draw thread sees this atomically)
    self->data = new_data;

    // Mise en place - clean the old immediately
    if (old && self->free_fn) {
        self->free_fn(old);
    }
}
/* }}} */
```

### 4. Create Slot Array and Free List

```c
/* {{{ SlotArray - fixed-size array with free list */
#define MAX_SLOTS 1024

typedef struct slot_array {
    ComponentSlot slots[MAX_SLOTS];
    int free_list[MAX_SLOTS];  // Stack of free indices
    int free_count;
    pthread_mutex_t alloc_lock;
} SlotArray;

SlotArray* slot_array_create(void);
int slot_allocate(SlotArray* arr);          // Returns slot index, -1 if full
void slot_free(SlotArray* arr, int index);  // Returns slot to free list
ComponentSlot* slot_get(SlotArray* arr, int index);
/* }}} */
```

### 5. Integrate with Threading

Workers process their assigned slots:

```c
/* {{{ worker_process_slots */
void worker_process_slots(WorkerContext* ctx) {
    for (int i = 0; i < ctx->slot_count; i++) {
        int slot_idx = ctx->assigned_slots[i];
        ComponentSlot* slot = slot_get(ctx->slots, slot_idx);

        if (!slot->in_use) continue;

        // Compute new render data
        RenderSlot* new_data = compute_render_data(slot->entity_id, ctx->game_state);

        // Mise en place: set + cleanup
        slot->set(slot, new_data);
    }
}
/* }}} */
```

### 6. Draw Thread Iteration

```c
/* {{{ draw_slots - iterate and render all visible slots */
void draw_slots(SlotArray* arr) {
    for (int i = 0; i < MAX_SLOTS; i++) {
        ComponentSlot* slot = &arr->slots[i];

        if (!slot->in_use || !slot->data || !slot->data->visible) {
            continue;
        }

        RenderSlot* r = slot->data;

        // Draw based on mesh_id
        Color c = (Color){ r->r, r->g, r->b, r->a };
        switch (r->mesh_id) {
            case 0:  // Circle (units)
                DrawCircle3D((Vector3){r->x, r->y, r->z}, r->scale,
                             (Vector3){0,1,0}, 0, c);
                break;
            case 1:  // Cube (buildings)
                DrawCube((Vector3){r->x, r->y, r->z},
                         r->scale, r->scale, r->scale, c);
                break;
            // ... more mesh types
        }

        // Selection indicator
        if (r->selected) {
            DrawCircle3D((Vector3){r->x, r->y + 0.1f, r->z},
                         r->scale * 1.2f, (Vector3){0,1,0}, 0, WHITE);
        }
    }
}
/* }}} */
```

---

## Files to Create

- `src/render/slots.h` - RenderSlot, ComponentSlot, SlotArray structs
- `src/render/slots.c` - Implementation

---

## Acceptance Criteria

- [ ] RenderSlot holds all GPU-ready data
- [ ] ComponentSlot wraps with self-cleaning setter
- [ ] SlotArray manages fixed pool with free list
- [ ] Allocation returns valid index or -1 if full
- [ ] Freeing returns slot to pool
- [ ] Setter atomically swaps and frees old data
- [ ] Draw thread iterates and renders visible slots
- [ ] Workers can update slots via setter
- [ ] No memory leaks (old data always freed)

---

## Notes

The fixed-size array (1024 slots) is intentional for:
- Predictable memory usage
- No runtime allocations during gameplay
- Cache-friendly iteration

If more entities are needed, increase MAX_SLOTS at compile time.

---

## Related Documents

- `docs/render-architecture.md` - Component slot pattern
- `issues/508a-threading-infrastructure.md` - Threading this integrates with
