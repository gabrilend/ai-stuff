# Render Architecture

## Overview

The rendering system uses a staged threading model where computation is pushed as far
toward worker threads as possible, leaving the render thread with minimal work: iterate
a stable list and dispatch to GPU.

**Core principle**: Workers compute, workers clean. Render thread only reads.

---

## Threading Model

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  ┌──────────────┐                                    ┌──────────────┐       │
│  │   Updater    │ (sleeps when no input)             │    Sync      │       │
│  │   Thread     │                                    │   Thread     │       │
│  └──────┬───────┘                                    └──────┬───────┘       │
│         │                                                   │               │
│         │  populates input buffers                          │ swaps         │
│         │  (player input, network packets)                  │ pointers      │
│         ▼                                                   ▼               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   ┌─────────────┐       │
│  │  Worker A   │  │  Worker B   │  │  Worker C   │   │   Primary   │       │
│  │             │  │             │  │             │   │   Buffer    │──────▶│
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │   │             │ Draw  │
│  │ │  input  │ │  │ │  input  │ │  │ │  input  │ │   │ (render-    │ Thread│
│  │ │ buffer  │ │  │ │ buffer  │ │  │ │ buffer  │ │   │  visible)   │       │
│  │ └────┬────┘ │  │ └────┬────┘ │  │ └────┬────┘ │   └──────▲──────┘       │
│  │      │      │  │      │      │  │      │      │          │               │
│  │      ▼      │  │      ▼      │  │      ▼      │          │               │
│  │  [process]  │  │  [process]  │  │  [process]  │          │               │
│  │      │      │  │      │      │  │      │      │          │               │
│  │      ▼      │  │      ▼      │  │      ▼      │          │               │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │          │               │
│  │ │ output  │ │  │ │ output  │ │  │ │ output  │ │──────────┘               │
│  │ │ buffer  │ │  │ │ buffer  │ │  │ │ buffer  │ │   (merge)                │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │                          │
│  └─────────────┘  └─────────────┘  └─────────────┘                          │
│         ▲                ▲                ▲                                 │
│         └────────────────┴────────────────┘                                 │
│                  (always processing)                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Thread Responsibilities

| Thread | Work | Sleep Condition |
|--------|------|-----------------|
| **Updater** | Populates worker input buffers from external sources | No new input/packets |
| **Workers** | Heavy computation (transforms, culling, animation) | Never - always processing |
| **Sync** | Swaps output pointers into primary buffer | No new outputs ready |
| **Render** | Iterates primary buffer, dispatches to GPU | N/A (runs at frame rate) |

### Why This Model

If workers produced *commands* instead of *results*, computation would migrate to
the sync thread (interpreting commands) or render thread (executing them). This
defeats parallelism.

Instead, workers produce **GPU-ready data**:
- Pre-transformed positions (world → screen already done)
- Pre-computed colors (lighting already applied)
- Pre-determined visibility (culling already done)

The sync thread does near-zero work: pointer swaps.
The render thread does near-zero work: iterate list, issue draw calls.

---

## Output Buffer Structure

Worker output buffers contain **final computed values**, not deltas or commands.

```c
/* {{{ RenderSlot - GPU-ready data for one renderable entity */
typedef struct render_slot {
    float pos[3];           // final screen/world position
    float scale;            // final scale
    unsigned char rgba[4];  // final color with lighting
    bool visible;           // culling result
    int mesh_id;            // which mesh to draw
    int material_id;        // which material to use
} RenderSlot;
/* }}} */
```

The primary buffer is a **stable list** - same slots frame-to-frame. The GPU receives
essentially the same draw list each frame, with values updated incrementally as the
game state changes.

Structure changes (spawn/destroy) are rare compared to value changes (movement, animation).

---

## Component Slot System

Each component slot is self-cleaning: the setter handles both pointing to new data
and freeing old data in one atomic operation.

### Core Structure

```c
/* {{{ ComponentSlot - self-cleaning storage with dispatch-ready function pointers */
typedef struct component_slot {
    void* data;                                    // current data pointer
    void (*set)(struct component_slot*, void*);    // point to new + free old
    void (*free_fn)(void*);                        // type-specific cleanup
} ComponentSlot;
/* }}} */
```

### Setter Pattern: Mise en Place

"Mise en place" - French for "everything in its place." The setter is not complete
until the old data is cleaned up. Cleanup is built into the act of setting, not
a separate step to remember.

```c
/* {{{ position_set - atomic swap with immediate cleanup */
void position_set(ComponentSlot* self, void* new_data) {
    void* old = self->data;

    // Point to new (render thread sees this atomically)
    self->data = new_data;

    // Mise en place - clean the old immediately
    // "Do it right the first time" - cleanup is part of the set, not deferred
    if (old && self->free_fn) {
        self->free_fn(old);
    }
}
/* }}} */
```

**Key insight**: The setter *is* the cleanup. Not "set then remember to free."
Workers create, workers clean. Clear ownership. Render thread never allocates or frees.

### Dispatch Table Usage

Because `set` is a function pointer on the struct, component slots can be stored
in arrays and processed uniformly:

```c
/* {{{ Worker dispatch loop - process assigned slots */
ComponentSlot components[COMPONENT_COUNT];

void worker_update(Worker* worker) {
    for (int i = 0; i < worker->slot_count; i++) {
        ComponentSlot* slot = &components[worker->slots[i]];

        // Heavy computation happens here
        void* new_state = worker->compute(slot);

        // Point + clean in one motion
        slot->set(slot, new_state);
    }
}
/* }}} */
```

The dispatch table maps component types to their setter functions. Each component
type can have specialized set/free behavior while maintaining a uniform interface.

---

## Numeric Representation

### No Division, No Zero

Game calculations cannot use division. Zero does not exist as a value - instead,
quantities are represented as distances from 0 to 1 (percentage/proportion).

Rationale: Division implies reduction in magnitude, which cannot exist without
maintaining momentum through spacetime - essentially requiring two degrees of
calculation rather than one.

### Fourier-Style Bitfield Encoding

Instead of signed integers or floating point, distances and directions are encoded
as bitfield sequences representing directional approximations.

#### Frame Structure

Each "frame" is minimum 8 bits. Every 2 bits encodes one directional component:

| Bits | Meaning |
|------|---------|
| `00` | Distant |
| `01` | Right   |
| `10` | Left    |
| `11` | Close   |

One byte (8 bits) contains 4 sequential direction frames:

```
Byte: [D1][D2][D3][D4]
       ▲   ▲   ▲   ▲
       │   │   │   │
       │   │   │   └── 4th direction (bits 0-1)
       │   │   └────── 3rd direction (bits 2-3)
       │   └────────── 2nd direction (bits 4-5)
       └────────────── 1st direction (bits 6-7)
```

#### Combining Values

To combine two directional values, tally how many of each direction appear:

```
Value A: [right][close][left][distant]  = 01 11 10 00
Value B: [close][right][right][left]    = 11 01 01 10

Tally:
  distant: 1
  right:   3
  left:    2
  close:   2
```

The result is a histogram of directional tendency, which can be normalized or
used directly for pathfinding, physics, or spatial reasoning.

### Negative Numbers and Higher Dimensions

Negative numbers imply higher-dimensional spaces. If a "backward" direction exists
and is calculatable, it represents movement in a dimension orthogonal to the
primary calculation axis.

Rather than `-5`, represent as `5 in the opposite-facing direction frame sequence`.
The directionality is encoded, not signed.

---

## Memory Lifecycle

### Allocation Ownership

| Thread | Allocates | Frees |
|--------|-----------|-------|
| Workers | New component data | Old component data (via setter) |
| Sync | Nothing | Nothing |
| Render | Nothing | Nothing |
| Updater | Input buffer contents | Old input buffer contents |

### Spawn/Destroy Handling

Entity spawn: Worker claims a free slot from the slot pool, populates it.
Entity destroy: Worker sets slot data to an "empty" marker, frees old data.

The slot itself remains allocated (slot pool is fixed-size). Only the data pointer
changes. This maintains the stable-list property for the render thread.

---

## Design Rationale Summary

1. **Push computation to workers** - They have parallelism, use it
2. **Minimize sync/render work** - They are serial bottlenecks
3. **Setter owns cleanup** - No orphaned allocations, no deferred GC
4. **Stable render list** - GPU sees same structure, different values
5. **No division/zero** - Directional bitfields for spatial math
6. **Function pointers in dispatch tables** - Uniform interface, specialized behavior

---

## Related Documents

- `notes/vision` - Project philosophy
- `docs/roadmap.md` - Development phases
- `issues/501-create-abstract-render-interface.md` - Implementation issues
- `issues/500-dual-interface-rendering-considerations.md` - Dual-interface design
