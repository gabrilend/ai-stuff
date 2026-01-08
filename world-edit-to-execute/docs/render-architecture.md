# Render Architecture

> **Note (2025-12-31):** This document describes the **prototype** threading model
> implemented in issue 508a. A significant architecture revision is planned in
> issue 512. See `docs/render-threading-v2.md` for the **target** architecture
> specification which addresses scalability, load balancing, and adaptive spawning.

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
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   ┌─────────────┐        │
│  │  Worker A   │  │  Worker B   │  │  Worker C   │   │   Primary   │        │
│  │             │  │             │  │             │   │   Buffer    │──────▶ │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │   │             │ Draw   │
│  │ │  input  │ │  │ │  input  │ │  │ │  input  │ │   │ (render-    │ Thread │
│  │ │ buffer  │ │  │ │ buffer  │ │  │ │ buffer  │ │   │  visible)   │        │
│  │ └────┬────┘ │  │ └────┬────┘ │  │ └────┬────┘ │   └──────▲──────┘        │
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

|   Thread    |                      Work                            |     Sleep Condition       |
|-------------|------------------------------------------------------|---------------------------|
| **Updater** | Populates worker input buffers from external sources | No new input/packets      |
| **Workers** | Heavy computation (transforms, culling, animation)   | Never - always processing |
|  **Sync**   | Swaps output pointers into primary buffer            | No new outputs ready      |
| **Render**  | Iterates primary buffer, dispatches to GPU           | N/A (runs at frame rate)  |

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

Instead of signed integers or floating point, directions are encoded as bitfield
sequences representing compass quadrant approximations of a normalized 3D vector.

#### Core Concept: Quadrant-Based Vector Approximation

A single byte (8 bits) encodes one normalized direction vector using 4 compass
quadrants. Each quadrant contributes 2 bits describing how "present" that direction
is in the final vector.

The quadrants map to a 2D plane with symbolic compass orientation (clockwise from top-left):

```
        (-1,+1)        (+1,+1)
             ╲   +Y    ╱
              ╲   │   ╱
               ╲  │  ╱
      Q1        ╲ │ ╱        Q2
    (top-left)   ╲│╱    (top-right)
       -X ───────(0,0)─────── +X  ← NEAR (00) = toward here
                 ╱│╲
      Q4        ╱ │ ╲        Q3
   (btm-left)  ╱  │  ╲   (btm-right)
              ╱   │   ╲
             ╱   -Y    ╲
        (-1,-1)       (+1,-1)

NEAR (00) = toward origin     FAR (11) = toward corners
```

Each 2-bit value describes the quadrant's contribution:

| Bits | Meaning | Interpretation |
|------|---------|----------------|
| `00` | Near    | Target is ahead in this quadrant's view (toward origin) |
| `01` | Right   | Fine-tuning: biased toward +X axis |
| `10` | Left    | Fine-tuning: biased toward -X axis |
| `11` | Far     | Target is behind in this quadrant's view (toward corner) |

The sign and orientation are stored in the quadrant position, not the data itself.
The same value (e.g., `11`) means "maximum outward" in every quadrant, but each
quadrant's corner points in a different direction.

This mapping aligns with Cartesian coordinates: when a quadrant is `11` (Far),
it contributes its corner value to the direction vector:

| Quadrant | Position | Far (11) corner |
|----------|----------|-----------------|
| Q1 | top-left     | (-1, +1) |
| Q2 | top-right    | (+1, +1) |
| Q3 | bottom-right | (+1, -1) |
| Q4 | bottom-left  | (-1, -1) |

#### Cardinal Direction Patterns

Pure axis-aligned directions use patterns where same-side quadrants vote "far" (11)
while opposite-side quadrants vote "near" (00). The perpendicular components cancel.

| Direction | Frame | Pattern | Far Quadrants |
|-----------|-------|---------|---------------|
| **North** (+Y) | `0xF0` | `11 11 00 00` | Q1,Q2 (top row, both have +Y corners) |
| **South** (-Y) | `0x0F` | `00 00 11 11` | Q3,Q4 (bottom row, both have -Y corners) |
| **East** (+X)  | `0x3C` | `00 11 11 00` | Q2,Q3 (right column, both have +X corners) |
| **West** (-X)  | `0xC3` | `11 00 00 11` | Q1,Q4 (left column, both have -X corners) |

The Y components cancel while X reinforces (or vice versa). These are the most
common frames in gameplay - axis-aligned movement dominates.

**Fine-tuning with intermediate values:**

For East (+X) with slight +Y bias, Q2/Q3 might be `01`/`10` (pointing along X axis)
while Q1 could be `00` and Q4 could be `10` (slight downward bias to add Y offset).
This allows encoding 2D vector approximations with high fidelity in a single byte.

Ordinal directions (NE, SW, etc.) have asymmetric patterns where one quadrant
dominates and others provide secondary contribution.

#### Byte Layout

```
Byte: [Q1][Q2][Q3][Q4]
       ▲   ▲   ▲   ▲
       │   │   │   │
       │   │   │   └── Q4: bottom-left quadrant  (bits 0-1)
       │   │   └────── Q3: bottom-right quadrant (bits 2-3)
       │   └────────── Q2: top-right quadrant    (bits 4-5)
       └────────────── Q1: top-left quadrant     (bits 6-7)

Quadrant order in the byte is clockwise from top-left: Q1 → Q2 → Q3 → Q4.
```

#### Example: Encoding a Direction

To encode a vector pointing roughly northeast (+0.7, +0.7):

- Q1 (top-left, corner at -1,+1): Right (01) - gives pure +Y
- Q2 (top-right, corner at +1,+1): Far (11) - vector aligns exactly with corner
- Q3 (bottom-right, corner at +1,-1): Left (10) - gives pure +X
- Q4 (bottom-left, corner at -1,-1): Near (00) - vector fully opposes this corner

Result: `01 11 10 00` = `0x78`

```
Contribution breakdown:
  Q1 Right (01): toward (0, +1) → contributes +Y
  Q2 Far   (11): toward (+1, +1) → contributes +X, +Y
  Q3 Left  (10): toward (+1, 0) → contributes +X
  Q4 Near  (00): toward origin → no contribution

Net: +X from Q2,Q3 and +Y from Q1,Q2 → northeast
```

**Left/Right reference for each quadrant:**

| Quadrant | Far (11) | Left (10) | Right (01) |
|----------|----------|-----------|------------|
| Q1 | (-1, +1) | (-1, 0) = -X | (0, +1) = +Y |
| Q2 | (+1, +1) | (0, +1) = +Y | (+1, 0) = +X |
| Q3 | (+1, -1) | (+1, 0) = +X | (0, -1) = -Y |
| Q4 | (-1, -1) | (0, -1) = -Y | (-1, 0) = -X |

Left (10) and Right (01) are 45° rotations from the Far vector:
- Left (10) = 45° counterclockwise from Far
- Right (01) = 45° clockwise from Far

Using Q2 as reference (standard trigonometry orientation):
- Far (11) at 45°, Left (10) at 90°, Right (01) at 0°

All four value-directions rotate together around the compass as you move
through quadrants, maintaining their 45° angular relationships.

#### Boundary Frames: Navigation Signals

The two extreme frame values act as control signals during curve calculation:

**`0x00` - All Near (Target Ahead)**

When all quadrants are "Near" (`00 00 00 00` = `0x00`), all quadrants report
the target is toward the origin from their perspective. If every quadrant says
"it's near me," the target must be directly ahead. This frame indicates the
current trajectory is correct - continue forward.

**`0xFF` - All Far (Overshoot)**

When all quadrants are "Far" (`11 11 11 11` = `0xFF`), all quadrants report
the target is toward their respective corners - away from origin. If every
quadrant says "it's behind me," you've passed the target. This triggers:
1. Reverse direction
2. Halve the momentum counter

The halved momentum dampens oscillation, causing convergence rather than
endless ping-ponging past the target.

```
Approach:   frame values trending, momentum = 8
Overshoot:  frame hits 0xFF (all far)
Reverse:    flip direction, momentum = 4
Approach:   frame values trending toward 0x00
Converge:   frame near 0x00 (all near), momentum → 0
```

This self-correcting behavior provides natural bounds without explicit clamping.

#### Combining Vectors

To combine two direction encodings, tally the contribution from each quadrant:

```
Vector A: [near][far][left][right]   = 00 11 10 01
Vector B: [near][right][far][left]   = 00 01 11 10

Per-quadrant tally (treating as 0-3 scale):
  Q1: 0 + 0 = 0 → 0 (near)
  Q2: 3 + 1 = 4 → 4 mod 4 = 0 (near)
  Q3: 2 + 3 = 5 → 5 mod 4 = 1 (right)
  Q4: 1 + 2 = 3 → 3 (far)

Result: [near][near][right][far] = 00 00 01 11 = 0x07
```

The modular arithmetic provides natural normalization - vectors can be summed
repeatedly without explicit normalize() calls.

#### Curve Calculation Process

Curves are computed as sequences of frames, where each frame represents a
differential steering instruction. The process is iterative:

**1. Initialization**

```
Start at origin (0, 0, 0) or context-dependent position
Initial orientation: context-dependent (often "up" or "forward")
The starting position implies nothing about initial trajectory
```

**2. Frame Application Loop**

```
For each frame in the sequence:
  1. Decode frame into direction adjustment (consensus of 4 quadrants)
  2. Apply adjustment to current orientation
  3. Generate normalized vector (length = 1) in new direction
  4. Transform: move origin to new position
  5. New orientation follows the vector just traveled
```

**3. Overshoot Detection**

When a frame evaluates to `0xFF` (all quadrants "far"), the curve has passed
its target. The system responds:

```
1. Reverse direction (flip orientation 180°)
2. Halve momentum counter (dampen oscillation)
3. Continue calculating with reversed frames
```

**4. Curve Simplification**

The reversed frames attempt to "collapse" the curve - reducing redundant steps.
For stationary targets, this converges naturally as momentum decays toward zero.
For moving targets, the collapse process follows the target heuristically.

**Semantic Interpretation:**

| Frame Value | Meaning During Calculation |
|-------------|----------------------------|
| `0x00` | Target directly ahead - trajectory is correct |
| `0xFF` | Target behind - overshot, reverse course |
| Other | Adjust heading toward target |

The curve is not stored as coordinates (where you visited) but as frames
(how you moved). This enables:
- Applying the same curve from different starting positions
- Comparing curve shapes for similarity
- Blending between curves
- Building reusable movement pattern libraries

#### LUT-Based Frame Operations (FPGA-Style)

Rather than computing transformations at runtime, frame operations use precomputed
lookup tables. The choice of *which LUT to invoke* carries the sign/axis information,
not the data itself.

```c
/* {{{ Frame LUTs - directional physics encoded in table structure */

// Each LUT is 256x256 → 256 (byte in, byte in, byte out)
// The relationship between inputs is baked into the table

static uint8_t LUT_add_x[256][256];    // combine frames along +X axis
static uint8_t LUT_add_y[256][256];    // combine frames along +Y axis
static uint8_t LUT_add_z[256][256];    // combine frames along +Z axis (elevation)
static uint8_t LUT_sub_x[256][256];    // inverse relationship for -X
static uint8_t LUT_sub_y[256][256];    // inverse relationship for -Y
static uint8_t LUT_sub_z[256][256];    // inverse relationship for -Z

/* }}} */
```

**Getter/Setter pattern for frame access:**

```c
/* {{{ frame_get_* / frame_set_* - operation choice encodes directionality */

// "Getting" a frame projection onto an axis
uint8_t frame_get_x(uint8_t frame) { return LUT_project_x[frame]; }
uint8_t frame_get_y(uint8_t frame) { return LUT_project_y[frame]; }
uint8_t frame_get_z(uint8_t frame) { return LUT_project_z[frame]; }

// "Setting" a frame by combining with directional input
uint8_t frame_set_toward(uint8_t frame, uint8_t target) {
    return LUT_toward[frame][target];  // move frame closer to target
}
uint8_t frame_set_away(uint8_t frame, uint8_t target) {
    return LUT_away[frame][target];    // move frame away from target
}

/* }}} */
```

**Why this works:**

1. **No signed arithmetic** - The "negative" of an operation is a different LUT,
   not a sign bit. `sub_x` is not `add_x` with negation; it's a distinct table
   encoding the inverse physical relationship.

2. **3D from 2D quadrants** - The Z axis emerges from dedicated LUTs that interpret
   quadrant patterns as elevation. Opposing quadrants voting "away" might map to
   upward motion in `LUT_add_z`.

3. **FPGA compatibility** - LUT-based logic maps directly to FPGA block RAM.
   No ALU needed for spatial calculations - just table lookups.

4. **Approximate physics** - The tables encode "good enough" approximations.
   Precision is gained by using more bytes (more quadrant samples), not by
   switching to floating point.

**Table generation (offline):**

```lua
-- {{{ generate_lut_add_x
-- Generate LUT for combining two frames along +X axis
local function generate_lut_add_x()
    local lut = {}
    for a = 0, 255 do
        lut[a] = {}
        for b = 0, 255 do
            -- Extract quadrant contributions, weight by X component
            -- Q1(-1,+1), Q2(+1,+1), Q3(-1,-1), Q4(+1,-1)
            local result = compute_x_combination(a, b)
            lut[a][b] = result
        end
    end
    return lut
end
-- }}}
```

The tables are generated once at build time (or loaded from disk), not computed
per-frame. Runtime cost is a single array index operation per transformation.

#### Direction vs Magnitude: Frame + Counter

Since frames are always normalized (implied length of 1), multiplication and
combination are equivalent operations. This allows a clean separation:

| Concern | Storage | Type |
|---------|---------|------|
| **Direction** | frame byte | `uint8_t` (which way) |
| **Magnitude** | counter | `uint16_t` (how much) |

```c
/* {{{ Momentum - direction frame + application counter */
typedef struct momentum {
    uint8_t  direction;    // normalized frame (which way)
    uint16_t count;        // how many times applied (magnitude)
} Momentum;
/* }}} */
```

**Traditional approach:**
```c
// velocity = direction * speed
// acceleration = force / mass
// position += velocity * dt
// Requires: multiplication, division, floating point
```

**Frame approach:**
```c
/* {{{ apply_force - combine direction, increment counter */
void apply_force(Momentum* velocity, uint8_t force_direction) {
    // Combine directions (normalized * normalized = normalized)
    velocity->direction = LUT_combine[velocity->direction][force_direction];

    // Increment magnitude (force was applied once)
    velocity->count++;
}
/* }}} */

/* {{{ apply_velocity - step position by momentum */
void apply_velocity(uint8_t* position, Momentum* velocity) {
    // Apply direction 'count' times (or use LUT for batch application)
    for (uint16_t i = 0; i < velocity->count; i++) {
        *position = LUT_step[*position][velocity->direction];
    }
    // Decay momentum (friction) - decrease counter, not direction
    if (velocity->count > 0) velocity->count--;
}
/* }}} */
```

**Why this works:**

1. **No multiplication** - Combining normalized directions is a LUT lookup,
   not `a * b`. The frame system absorbs what would be directional multiplication.

2. **No division** - Mass/friction are counter operations (decrement, shift),
   not `force / mass`. Heavy objects have slower counter increment rates.

3. **Magnitude is discrete** - Instead of `velocity = 3.7`, you have
   `count = 3` or `count = 4`. Precision comes from tick rate, not float bits.

4. **Momentum accumulates naturally** - Each `apply_force` call adds to the
   direction (via combination) and the magnitude (via counter). No need to
   track velocity as a separate vector.

```
Frame:     [away][right][near][left] = direction
Counter:   5                         = magnitude
Together:  "5 units of motion in this direction"

Apply force [away][away][right][near]:
  New frame: LUT_combine[old_frame][force_frame]
  New count: 6

The direction shifts toward the force, magnitude increases.
```

#### Momentum Storage: Static vs Dynamic

Two storage strategies depending on memory constraints:

**1. Static Storage (FPGA / Fixed Memory)**

When allocation is impossible or expensive, pre-allocate a counter for every
possible direction. 256 directions × counter size = fixed footprint.

```c
/* {{{ MomentumStatic - counter for every possible frame direction */
typedef struct momentum_static {
    uint16_t magnitude[256];  // counter per direction (512 bytes total)
} MomentumStatic;
/* }}} */

/* {{{ momentum_static_apply - add force to a direction's counter */
void momentum_static_apply(MomentumStatic* m, uint8_t direction, uint16_t force) {
    m->magnitude[direction] += force;
}
/* }}} */

/* {{{ momentum_static_decay - reduce all counters (friction) */
void momentum_static_decay(MomentumStatic* m, uint16_t amount) {
    for (int i = 0; i < 256; i++) {
        if (m->magnitude[i] > amount) {
            m->magnitude[i] -= amount;
        } else {
            m->magnitude[i] = 0;
        }
    }
}
/* }}} */

/* {{{ momentum_static_dominant - find direction with highest magnitude */
uint8_t momentum_static_dominant(MomentumStatic* m, uint16_t* out_magnitude) {
    uint8_t best_dir = 0;
    uint16_t best_mag = 0;
    for (int i = 0; i < 256; i++) {
        if (m->magnitude[i] > best_mag) {
            best_mag = m->magnitude[i];
            best_dir = (uint8_t)i;
        }
    }
    if (out_magnitude) *out_magnitude = best_mag;
    return best_dir;
}
/* }}} */

/* {{{ momentum_static_resolve - combine all directions into net momentum */
uint8_t momentum_static_resolve(MomentumStatic* m, uint16_t* out_magnitude) {
    // Weight each direction by its magnitude, combine via LUT
    uint8_t net_direction = 0x00;  // start at origin (all near)
    uint16_t total_magnitude = 0;

    for (int i = 0; i < 256; i++) {
        if (m->magnitude[i] == 0) continue;

        // Apply this direction 'magnitude' times to net
        // (or use weighted combination LUT)
        for (uint16_t j = 0; j < m->magnitude[i]; j++) {
            net_direction = LUT_combine[net_direction][(uint8_t)i];
        }
        total_magnitude += m->magnitude[i];
    }

    if (out_magnitude) *out_magnitude = total_magnitude;
    return net_direction;
}
/* }}} */
```

**Characteristics:**
- Fixed 512 bytes per entity (256 × 2-byte counters)
- O(1) force application
- O(256) decay and resolution (but predictable, no branching on data)
- FPGA-friendly: no allocation, fixed memory layout, parallelizable loops

---

**2. Dynamic Storage (CPU / Variable Memory)**

Only allocate storage when a direction is first activated. Grows as the
"curvature" of the momentum relationship becomes realized through actual forces.

```c
/* {{{ MomentumEntry - single direction-magnitude pair */
typedef struct momentum_entry {
    uint8_t  direction;
    uint16_t magnitude;
} MomentumEntry;
/* }}} */

/* {{{ MomentumDynamic - sparse storage, grows on demand */
typedef struct momentum_dynamic {
    MomentumEntry* entries;   // allocated array of active directions
    uint8_t count;            // how many directions currently active
    uint8_t capacity;         // allocated size (grows as needed)
} MomentumDynamic;
/* }}} */

/* {{{ momentum_dynamic_init - start empty */
void momentum_dynamic_init(MomentumDynamic* m) {
    m->entries = NULL;
    m->count = 0;
    m->capacity = 0;
}
/* }}} */

/* {{{ momentum_dynamic_find - locate entry for direction, or NULL */
static MomentumEntry* momentum_dynamic_find(MomentumDynamic* m, uint8_t direction) {
    for (uint8_t i = 0; i < m->count; i++) {
        if (m->entries[i].direction == direction) {
            return &m->entries[i];
        }
    }
    return NULL;
}
/* }}} */

/* {{{ momentum_dynamic_grow - expand capacity when needed */
static void momentum_dynamic_grow(MomentumDynamic* m) {
    uint8_t new_cap = (m->capacity == 0) ? 4 : m->capacity * 2;
    if (new_cap > 256) new_cap = 256;  // max possible directions

    MomentumEntry* new_entries = realloc(m->entries, new_cap * sizeof(MomentumEntry));
    if (new_entries) {
        m->entries = new_entries;
        m->capacity = new_cap;
    }
}
/* }}} */

/* {{{ momentum_dynamic_apply - add force, creating entry if new direction */
void momentum_dynamic_apply(MomentumDynamic* m, uint8_t direction, uint16_t force) {
    MomentumEntry* entry = momentum_dynamic_find(m, direction);

    if (entry) {
        // Direction already realized - add to existing magnitude
        entry->magnitude += force;
    } else {
        // New curvature realized - allocate storage for this direction
        if (m->count >= m->capacity) {
            momentum_dynamic_grow(m);
        }
        if (m->count < m->capacity) {
            m->entries[m->count].direction = direction;
            m->entries[m->count].magnitude = force;
            m->count++;
        }
    }
}
/* }}} */

/* {{{ momentum_dynamic_decay - reduce magnitudes, remove zeroed entries */
void momentum_dynamic_decay(MomentumDynamic* m, uint16_t amount) {
    uint8_t write_idx = 0;

    for (uint8_t i = 0; i < m->count; i++) {
        if (m->entries[i].magnitude > amount) {
            m->entries[i].magnitude -= amount;
            // Compact: copy to write position
            if (write_idx != i) {
                m->entries[write_idx] = m->entries[i];
            }
            write_idx++;
        }
        // else: magnitude went to zero, entry removed (not copied forward)
    }
    m->count = write_idx;
}
/* }}} */

/* {{{ momentum_dynamic_resolve - combine active directions into net momentum */
uint8_t momentum_dynamic_resolve(MomentumDynamic* m, uint16_t* out_magnitude) {
    uint8_t net_direction = 0x00;
    uint16_t total_magnitude = 0;

    for (uint8_t i = 0; i < m->count; i++) {
        // Weight by magnitude - apply direction 'magnitude' times
        for (uint16_t j = 0; j < m->entries[i].magnitude; j++) {
            net_direction = LUT_combine[net_direction][m->entries[i].direction];
        }
        total_magnitude += m->entries[i].magnitude;
    }

    if (out_magnitude) *out_magnitude = total_magnitude;
    return net_direction;
}
/* }}} */

/* {{{ momentum_dynamic_free - release allocated memory */
void momentum_dynamic_free(MomentumDynamic* m) {
    free(m->entries);
    m->entries = NULL;
    m->count = 0;
    m->capacity = 0;
}
/* }}} */
```

**Characteristics:**
- Starts at 0 bytes, grows only as directions are activated
- Typical entity might use 4-16 entries (12-48 bytes) vs 512 fixed
- O(n) find where n = active directions (usually small)
- Compacts automatically on decay - unused directions deallocate
- Represents actual momentum "shape" - only stores realized curvature

---

**Comparison:**

| Aspect | Static | Dynamic |
|--------|--------|---------|
| Memory (idle) | 512 bytes | 0 bytes |
| Memory (active) | 512 bytes | 3 bytes × active directions |
| Apply force | O(1) array index | O(n) search + possible alloc |
| Decay | O(256) always | O(n) with compaction |
| FPGA suitable | Yes | No (allocation) |
| CPU suitable | Yes (wasteful) | Yes (efficient) |
| Represents | All possible directions | Only realized directions |

**Hybrid approach:**

For CPU with predictable access patterns, use a small static array for "hot"
directions (the 8-16 most common movement angles) with dynamic overflow:

```c
/* {{{ MomentumHybrid - fixed hot slots + dynamic overflow */
typedef struct momentum_hybrid {
    uint16_t hot[16];         // counters for 16 common directions (32 bytes)
    uint8_t  hot_map[16];     // which frame each hot slot represents
    MomentumDynamic overflow; // rare directions spill here
} MomentumHybrid;
/* }}} */
```

### Curve Representation: Frame-Based Fourier

Traditional Fourier decomposes a signal into sine/cosine frequencies. The frame
system decomposes curves into directional components - each unique frame is a
"frequency bin" and its magnitude counter is the amplitude.

#### Curve as Direction Sequence

A curve is a path through space. At each point, the curve has a tangent direction.
Sample the curve at regular intervals and encode each tangent as a frame:

```
Curve:    ╭───────╮
         ╱         ╲
        ╱           ╲
       ╱             ╲

Samples:  →  ↗  ↑  ↖  ←

Frames:   [0x3C] [0x7C] [0xF0] [0xE1] [0xC3]
          (east) (NE)   (north) (NW)  (west)

Cardinal values: East=0x3C, North=0xF0, West=0xC3, South=0x0F
Ordinal values are intermediate blends between adjacent cardinals.
```

The sequence of frames **is** the curve, discretized into directional samples.

#### Frequency = Rate of Direction Change

| Curve Type | Direction Change | Frame Pattern |
|------------|------------------|---------------|
| Straight line | None | Same frame repeated |
| Gentle curve | Slow | Adjacent frames similar |
| Sharp corner | Sudden | Adjacent frames very different |
| Circle | Constant | Frames cycle through all quadrants evenly |

**Low frequency** = direction changes slowly = gentle curves
**High frequency** = direction changes rapidly = sharp corners

#### Decomposition via MomentumStatic

To analyze a curve's "frequency content," feed its frame sequence into a
MomentumStatic accumulator:

```c
/* {{{ curve_decompose - Fourier-like decomposition of curve into direction spectrum */
void curve_decompose(uint8_t* frames, int count, MomentumStatic* spectrum) {
    // Zero the spectrum
    memset(spectrum->magnitude, 0, sizeof(spectrum->magnitude));

    // Accumulate: each frame votes for its direction
    for (int i = 0; i < count; i++) {
        spectrum->magnitude[frames[i]]++;
    }
}
/* }}} */
```

The resulting `spectrum->magnitude[256]` array shows which directions dominate:

```
Straight line east:
  spectrum[0x3C] = 100    (100% east)
  all others = 0

Quarter circle (east to north):
  spectrum[0x3C] = 25     (25% east)
  spectrum[0x7C] = 25     (25% NE)
  spectrum[0xF0] = 25     (25% north)
  spectrum[0xF4] = 25     (25% almost-north)

Chaotic scribble:
  spectrum[*] ≈ uniform   (all directions equally represented)
```

#### Curvature = Frame Difference

The **curvature** at a point is how much the direction changes. This is the
"difference" between adjacent frames - computed via LUT:

```c
/* {{{ LUT_curvature - how different are two directions? */
// Returns 0-255: 0 = identical, 255 = opposite
static uint8_t LUT_curvature[256][256];
/* }}} */

/* {{{ curve_curvature - extract curvature signal from frame sequence */
void curve_curvature(uint8_t* frames, int count, uint8_t* curvature_out) {
    for (int i = 0; i < count - 1; i++) {
        curvature_out[i] = LUT_curvature[frames[i]][frames[i+1]];
    }
}
/* }}} */
```

The curvature signal is itself a sequence that can be decomposed:
- Constant curvature = circle/arc
- Zero curvature = straight line
- Spike in curvature = corner
- Oscillating curvature = wavy line

#### Reconstruction from Spectrum

To reconstruct a curve from its directional spectrum, sample proportionally:

```c
/* {{{ curve_reconstruct - rebuild curve from direction spectrum */
int curve_reconstruct(MomentumStatic* spectrum, uint8_t* frames_out, int max_frames) {
    int write_idx = 0;
    uint16_t total = 0;

    // Sum total magnitude
    for (int i = 0; i < 256; i++) {
        total += spectrum->magnitude[i];
    }
    if (total == 0 || max_frames == 0) return 0;

    // Emit frames proportionally
    for (int i = 0; i < 256 && write_idx < max_frames; i++) {
        // How many frames of direction i?
        int emit_count = (spectrum->magnitude[i] * max_frames) / total;
        for (int j = 0; j < emit_count && write_idx < max_frames; j++) {
            frames_out[write_idx++] = (uint8_t)i;
        }
    }
    return write_idx;
}
/* }}} */
```

This reconstructs a curve with the same directional distribution, though not
necessarily in the same order. Order preservation requires storing the sequence,
not just the spectrum.

#### Hierarchical Curves: Multi-Resolution

For complex curves, use multiple bytes per sample for precision:

```
1 byte per sample:  256 possible directions (coarse)
2 bytes per sample: 65536 possible directions (fine)
4 bytes per sample: ~4 billion directions (very fine)
```

Or use hierarchical decomposition - first byte is coarse direction, subsequent
bytes refine within that quadrant:

```
Byte 1: [Q1][Q2][Q3][Q4]     → which quadrant (4 possibilities dominant)
Byte 2: [q1][q2][q3][q4]     → sub-quadrant within dominant
Byte 3: [s1][s2][s3][s4]     → sub-sub-quadrant...

Like: "Northwest... more west... slightly south of that"
```

This is analogous to wavelets - coarse structure first, then progressive detail.

#### Comparison to Traditional Fourier

| Aspect | Traditional Fourier | Frame Fourier |
|--------|---------------------|---------------|
| Basis functions | sin/cos waves | Directional quadrants |
| Frequency bins | Continuous Hz | 256 discrete directions |
| Amplitude | Float magnitude | Integer counter |
| Phase | Angle offset | Implicit in frame bits |
| Decomposition | FFT (O(n log n)) | Counting (O(n)) |
| Reconstruction | IFFT | Proportional sampling |
| Precision | Float bits | More bytes per sample |

**Key advantage:** Frame Fourier uses only counting and table lookups.
No floating point. No trigonometry. FPGA-friendly.

**Key tradeoff:** Less precise than true Fourier, but "good enough" for
game physics where approximate curves are acceptable.

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
