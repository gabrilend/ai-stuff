# Binary Vector Frame System

A comprehensive guide to encoding directions and rotations using quadrant voting
with binary vector frames.

---

## 1. Core Concept: Quadrant Voting

A binary vector frame encodes direction through **quadrant voting**. Each frame
byte contains 4 quadrants, each contributing 2 bits (8 bits total = 1 byte).

```
Quadrant layout (Cartesian plane):

       Q1 (top-left)     Q2 (top-right)
       corner: NW        corner: NE
       (-1,+1)           (+1,+1)
              \   +Y    /
               \   |   /
                \  |  /
       -X ───────(0,0)─────── +X
                /  |  \
               /   |   \
              /   -Y    \
       Q4 (bottom-left)  Q3 (bottom-right)
       corner: SW        corner: SE
       (-1,-1)           (+1,-1)

Byte layout: [Q1:2bits][Q2:2bits][Q3:2bits][Q4:2bits]
             bits 7-6   bits 5-4   bits 3-2   bits 1-0
```

---

## 2. Bit Values: The Four Votes

Each quadrant votes with one of four values:

| Bits | Name  | Angle from Far | Direction Contribution |
|------|-------|----------------|------------------------|
| 00   | Near  | N/A            | Toward origin (no contribution) |
| 01   | Right | -45° from Far  | Clockwise axis from corner |
| 10   | Left  | +45° from Far  | Counter-clockwise axis from corner |
| 11   | Far   | 0°             | Toward corner (diagonal) |

---

## 3. Per-Quadrant Angle Mapping

Each quadrant's votes map to specific angles:

| Quadrant | Right (01) | Far (11) | Left (10) |
|----------|------------|----------|-----------|
| Q2 (NE)  | 0° (+X)    | 45° (NE) | 90° (+Y)  |
| Q1 (NW)  | 90° (+Y)   | 135° (NW)| 180° (-X) |
| Q4 (SW)  | 180° (-X)  | 225° (SW)| 270° (-Y) |
| Q3 (SE)  | 270° (-Y)  | 315° (SE)| 0° (+X)   |

**Key insight:** Adjacent quadrants share axis boundaries with no gaps:
- Q3 Left (0°) = Q2 Right (0°) → +X axis
- Q2 Left (90°) = Q1 Right (90°) → +Y axis
- Q1 Left (180°) = Q4 Right (180°) → -X axis
- Q4 Left (270°) = Q3 Right (270°) → -Y axis

The four quadrants tile 360° continuously.

---

## 4. Cardinal Directions

Cardinals use **Left/Right pairs** from adjacent quadrants, not Far:

| Direction | Frame | Pattern | Contributing Quadrants |
|-----------|-------|---------|------------------------|
| NORTH (+Y)| 0x60  | 01 10 00 00 | Q1 Right (+Y), Q2 Left (+Y) |
| EAST (+X) | 0x18  | 00 01 10 00 | Q2 Right (+X), Q3 Left (+X) |
| SOUTH (-Y)| 0x06  | 00 00 01 10 | Q3 Right (-Y), Q4 Left (-Y) |
| WEST (-X) | 0x81  | 10 00 00 01 | Q1 Left (-X), Q4 Right (-X) |

Why Left/Right instead of Far? Cardinals are **axis-aligned**. Far points to
corners (diagonals). Left/Right project onto pure axes.

---

## 5. Ordinal Directions

Ordinals use a single **Far vote** pointing to the corner:

| Direction | Frame | Pattern | Contributing Quadrant |
|-----------|-------|---------|----------------------|
| NORTHEAST | 0x30  | 00 11 00 00 | Q2 Far (NE) |
| NORTHWEST | 0xC0  | 11 00 00 00 | Q1 Far (NW) |
| SOUTHEAST | 0x0C  | 00 00 11 00 | Q3 Far (SE) |
| SOUTHWEST | 0x03  | 00 00 00 11 | Q4 Far (SW) |

---

## 6. Boundary Frames

Two special frames act as control signals:

**0xFF (All Far)** - Overshoot
- All quadrants say "target is behind me toward my corner"
- Interpretation: We've passed the target
- Response: Reverse direction, halve momentum

**0x00 (All Near)** - Arrived
- All quadrants say "target is ahead toward origin"
- Interpretation: We're at the target
- Response: Stop, convergence complete

### Geometric Definition of Far/Near Threshold

**Far (11)** means the target is closer to the corner than to the midpoint:
- Closer to (1, 1) × quadrant_sign than to (0.5, 0.5) × quadrant_sign
- The 45° diagonal is the decision boundary

**Near (00)** means the target is closer to the origin than to the midpoint:
- Closer to (0, 0) than to (0.5, 0.5) × quadrant_sign

**Left/Right (10/01)** occupy the middle band, biased toward one axis.

---

## 7. Curve Characteristics: Sharp vs Stabilized

The **same direction** can be encoded multiple ways with different curve behavior:

| Encoding | Frame | Curve Type |
|----------|-------|------------|
| NORTH (sharp) | 0x60 = 01 10 00 00 | Tight turn, aggressive steering |
| NORTH (stabilized) | 0xF0 = 11 11 00 00 | Wide arc, damped approach |

**Far values create wider, stabilized curves.**
**Left/Right values create sharper turns.**

This is because Far implies "slowing down / orbiting wide" while Left/Right
implies "direct steering correction."

---

## 8. Combining Frames

Frames combine via **per-quadrant mod 4 arithmetic**:

```
Frame A: 01 10 00 11
Frame B: 10 01 11 00
         ─────────────
Sum:     11 11 11 11  (each quadrant: (a + b) mod 4)
         = 3  3  3  3
         = 0xFF (overshoot!)
```

No explicit normalization needed. Modular arithmetic naturally wraps.

---

## 9. Figure-Eight Convergence

Binary vector frames approximate values through **orbital convergence**, similar
to calculus limits approaching asymptotes.

### The Convergence Pattern

```
1. Initial estimate → coarse direction
2. Travel toward target
3. Overshoot (0xFF) → reverse, halve momentum
4. Travel back with reduced speed
5. Approach from opposite side
6. Repeat until momentum = 0
```

Each pass halves the error. The orbit spirals inward toward the true value.

### Why Figure-Eights?

A figure-eight provides **two samples per revolution** from perpendicular axes:

```
        ╭───────╮
       ╱         ╲
      │  Loop A   │    Samples Q1/Q3 diagonal
       ╲         ╱
        ╲       ╱
         ╳─────╳  ← Center crossing (measurement point)
        ╱       ╲
       ╱         ╲
      │  Loop B   │    Samples Q2/Q4 diagonal
       ╲         ╱
        ╰───────╯
```

Benefits over circular orbits:
- 2x samples per revolution
- Orthogonal perspectives triangulate position
- Like stereo vision or I/Q quadrature sampling

### The Diagonal Tension Pattern

`Far Near Far Near` (11 00 11 00) and `Near Far Near Far` (00 11 00 11) create
figure-eight behavior:

```
11 00 11 00 → Q1,Q3 Far (NW/SE tension) → swing toward one diagonal
00 00 00 00 → cross center (momentary "on target")
00 11 00 11 → Q2,Q4 Far (NE/SW tension) → swing toward other diagonal
00 00 00 00 → cross center again
repeat with halved amplitude...
```

The system oscillates between diagonal attractors, crossing center twice per
cycle, converging on the true value.

### Complement Oscillation as Success Signal

When frames alternate between complements:
```
Far Near Far Near  (11 00 11 00)
Near Far Near Far  (00 11 00 11)
Far Near Far Near  (11 00 11 00)
...
```

This repeated oscillation between diametrically opposite patterns indicates
we're orbiting the target - convergence achieved. Treat this as a success
condition and mark the orbit center as the destination.

### 180° Flip Handling

For antipodal rotations (e.g., +Z to -Z):
```
Frame 1: 11 11 11 11 (all Far) → complete 180° flip
Frame 2: 00 00 00 00 (all Near) → heading toward target
Frame 3+: converge normally with halving momentum
```

No special case needed - the all-Far frame naturally triggers a full reversal.

---

## 10. Edge Cases and Special Patterns

### Pinwheel (All Right or All Left)

`01 01 01 01` (all Right) - Clockwise rotation, net (0,0)
`10 10 10 10` (all Left) - Counter-clockwise rotation, net (0,0)

Circular orbit around origin. May encode rotation/spin rather than direction.

### Three Agree, One Dissents

`11 11 11 00` (Q1,Q2,Q3 Far, Q4 Near)

Three quadrants push away, one pulls toward. Creates turning toward the
"quiet" quadrant. Like a spaceship with three thrusters firing - it drifts
toward the silent one.

Net result: (+1, +1) = NE (toward the "hole" in the Far pattern)

### Opposing Cardinals

`10 10 01 01`:

- Q1 Left = -X
- Q2 Left = +Y
- Q3 Right = -Y
- Q4 Right = -X

Y cancels (+1 - 1 = 0), X reinforces (-1 - 1 = -2).
Result: Pure West with double weight.

---

## 11. The 90° Quantum

Each binary vector has a **90° capacity for expression**:

- Far sits at 45° from the origin (corner)
- Right is 45° clockwise from Far (0° from corner reference)
- Left is 45° counterclockwise from Far (90° from corner reference)

So each quadrant spans exactly 90° of angular space:
- Q2: 0° to 90°
- Q1: 90° to 180°
- Q4: 180° to 270°
- Q3: 270° to 360°

Four quadrants × 90° = 360° with no gaps or overlaps.

---

## 12. Extension to 3D Rotations

**Goal:** Encode 3D rotations as "binary vector frames" using the same principles.

**Approach:**
- 2D uses 4 quadrants (2² = 4) with 2 bits each = 8 bits
- 3D uses 8 octants (2³ = 8) with 2 bits each = 16 bits

```
3D Octants:
  O1: (-1,+1,+1) = top-back-left
  O2: (+1,+1,+1) = top-back-right
  O3: (+1,+1,-1) = top-front-right
  O4: (-1,+1,-1) = top-front-left
  O5: (-1,-1,+1) = bottom-back-left
  O6: (+1,-1,+1) = bottom-back-right
  O7: (+1,-1,-1) = bottom-front-right
  O8: (-1,-1,-1) = bottom-front-left
```

Each octant votes Near/Right/Left/Far toward its corner. Combine votes to get
3D direction. Same convergence patterns apply.

**Advantages over quaternions:**
- Integer-only arithmetic (no floating point)
- LUT-based operations (FPGA-friendly)
- Progressive precision (add more bytes for more accuracy)
- Natural convergence through figure-eight orbiting

---

## 13. Complement Rules

The complement of a frame swaps:
- Far (11) ↔ Near (00)
- Left (10) ↔ Right (01)

Repeated complement oscillation indicates convergence on the target.

---

## 14. Genetic Algorithm Operations

For evolutionary path optimization:

- **Single-quadrant mutation:** Change one quadrant's vote (e.g., Q3: Left → Far)
- **Single-bit mutation:** Flip one bit (Near → Right, or Far → Left)
- **Crossover:** Take Q1,Q2 from parent A; Q3,Q4 from parent B

All three mutation types are valid operators.

---

## Related Documents

- `src/runtime/pathfinding/frames.lua` - 2D frame implementation
- `docs/render-architecture.md` - Frame encoding in render context
- `issues/512-3d-rotation-frames.md` - 3D extension implementation

---

## Revision History

| Date | Change |
|------|--------|
| 2026-01-01 | Initial documentation from brainstorming session |
