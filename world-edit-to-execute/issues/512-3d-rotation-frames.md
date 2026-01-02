# Issue 512: 3D Rotation Frames

**Phase:** 5/6 - Rendering / Advanced Features
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 409 (Frame-based pathfinding), 508 (Render system)

---

## Current Behavior

The frame-based direction encoding system (src/runtime/pathfinding/frames.lua)
encodes 2D directions using quadrant voting with a single byte (4 quadrants × 2 bits).

Rotations in the render system use floating-point angles or quaternions, which
require floating-point arithmetic and normalization.

---

## Intended Behavior

Extend the binary vector frame encoding to 3D rotations using octant voting:
- 8 octants (2³ = 8) with 2 bits each = 16 bits (2 bytes)
- Same convergence patterns (figure-eight orbiting, complement oscillation)
- Integer-only arithmetic (FPGA/embedded friendly)
- Progressive precision (add more bytes for higher accuracy)

### 3D Octant Layout

```
Octants (corners of unit cube):
  O1: (-1,+1,+1) = top-back-left      O2: (+1,+1,+1) = top-back-right
  O3: (+1,+1,-1) = top-front-right    O4: (-1,+1,-1) = top-front-left
  O5: (-1,-1,+1) = bottom-back-left   O6: (+1,-1,+1) = bottom-back-right
  O7: (+1,-1,-1) = bottom-front-right O8: (-1,-1,-1) = bottom-front-left

Byte layout: [O1:2][O2:2][O3:2][O4:2] [O5:2][O6:2][O7:2][O8:2]
             high byte                 low byte
```

### Key Properties

- **Identity rotation:** 0x0000 (all Near = straight ahead)
- **180° flip:** 0xFFFF (all Far = complete reversal)
- **Convergence:** Complement oscillation detection (same as 2D)
- **Gimbal lock:** Avoided (no privileged axis in octant voting)

---

## Suggested Implementation Steps

### 512a: Core 3D Frame Encoding

1. Create `src/runtime/rotation/frames3d.lua`
2. Define 8 octant constants with corner coordinates
3. Implement `frame3d_to_vector3(frame)` - 16-bit to (x,y,z)
4. Implement `vector3_to_frame3d(x,y,z)` - (x,y,z) to 16-bit
5. Define 3D cardinal directions (UP, DOWN, NORTH, SOUTH, EAST, WEST)
6. Add 3D ordinal support (8 corners)

### 512b: Integrate with Render System

1. Update render slot rotation storage to use 3D frames
2. Convert between quaternion/euler and 3D frames for compatibility
3. Test with rotating cubes in demo

### 512c: Dynamic Precision Scaling

1. Implement variable-length frame encoding (2, 4, 8 bytes)
2. Add precision scaling based on A* path deviation
3. Cap precision when units stay on path

### 512d: Convergence Detection

1. Port 2D complement detection to 3D
2. Implement 3D figure-eight (spherical Lissajous) convergence
3. Detect FF-00-FF-00 oscillation patterns in 3D

---

## Acceptance Criteria

- [ ] 3D frame encoding captures all spatial directions
- [ ] Combine_frames works with mod 4 arithmetic in 3D
- [ ] Convergence detection works for 3D rotations
- [ ] No gimbal lock or "stuck" orientations
- [ ] Demo shows rotation comparison (quaternion vs frame)
- [ ] Integer-only arithmetic (no floating point in core)

---

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `src/runtime/rotation/frames3d.lua` | Create | 3D frame encoding module |
| `src/render/main.c` | Modify | Integrate 3D frames for rotation |
| `src/tests/test_frames3d.lua` | Create | 3D frame unit tests |

---

## Sub-Issues

| ID | Description | Priority |
|----|-------------|----------|
| 512a | Core 3D frame encoding | High |
| 512b | Render system integration | Medium |
| 512c | Dynamic precision scaling | Medium |
| 512d | Convergence detection | Medium |

---

## Notes

### Advantages Over Quaternions

1. **Integer arithmetic:** No floating-point rounding errors
2. **LUT-based:** All operations can be precomputed lookup tables
3. **Progressive precision:** Add bytes for more accuracy
4. **Natural convergence:** Figure-eight orbiting finds targets naturally
5. **FPGA/embedded friendly:** Fixed-point, deterministic

### Open Questions

- What precision level is sufficient for game-level rotation? (16-bit baseline)
- Should momentum be a single counter or per-axis?
- How to handle smooth interpolation for animation?

### Related Documents

- `docs/binary-vector-frames.md` - Full frame encoding specification
- `src/runtime/pathfinding/frames.lua` - 2D frame implementation
- `docs/render-architecture.md` - Render system architecture
