# Issue 409: Frame-Based Pathfinding Storage

**Phase:** 4
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 403 (A* pathfinding), render-architecture.md (frame encoding)

---

## Current Behavior

The A* pathfinding system (src/runtime/pathfinding/astar.lua) stores paths as
sequences of `{x, y}` coordinate pairs:

```lua
path = {
    { x = 10, y = 5 },
    { x = 11, y = 5 },
    { x = 12, y = 6 },
    ...
}
```

Direction vectors are stored as `{dx, dy, cost}` triplets in CARDINAL_DIRS and
DIAGONAL_DIRS tables.

## Intended Behavior

Paths can alternatively be stored as frame sequences - describing the *shape*
of the path rather than the absolute positions visited.

```lua
-- Coordinate path: "here are the places you visit"
path_coords = {
    { x = 10, y = 5 },
    { x = 11, y = 5 },
    { x = 12, y = 6 },
}

-- Frame path: "here is the shape of the journey, starting from here"
path_frames = {
    start = { x = 10, y = 5 },
    frames = { 0xCC, 0xCC, 0x33, 0x33, 0x0F, ... },  -- E, E, NE, NE, N, ...
}
```

This is NOT compression - it's a different representation with different affordances:

| Representation | Describes | Enables |
|----------------|-----------|---------|
| Coordinates | Places visited | Exact reconstruction |
| Frames | Shape of journey | Pattern matching, gesture recognition, shape blending |

**What frame paths enable that coordinates don't:**

1. **Position-independent shapes** - "This is a zigzag" regardless of where it starts
2. **Gesture recognition** - "These two paths have the same shape"
3. **Shape interpolation** - Blend between two path shapes smoothly
4. **Pattern libraries** - Store reusable movement templates
5. **Approximate matching** - "This path is *similar to* that patrol route"

Like the difference between:
- A list of GPS waypoints (coordinates)
- An SVG path command: `M 0 0 L 10 0 C 15 5 ...` (shape instructions)
- A signature gesture (the *form* of the movement)

### Frame Direction Mapping

Map the 8 directions to frame bytes using the quadrant system:

```
Direction    Frame         Quadrants (Far/Near)
─────────────────────────────────────────────────
North        00 00 11 11   Q1,Q2 far, Q3,Q4 near
South        11 11 00 00   Q1,Q2 near, Q3,Q4 far
East         11 00 11 00   Q1,Q3 near, Q2,Q4 far
West         00 11 00 11   Q1,Q3 far, Q2,Q4 near
NE           11 00 11 11   Q2 far, others mixed
NW           00 11 11 11   Q1 far, others mixed
SE           11 11 11 00   Q4 far, others mixed
SW           11 11 00 11   Q3 far, others mixed
```

### A* as Idea-Space Exploration

A* exploration IS the frame convergence pattern:

```
         ┌────────────────────────────────────────┐
         │     POSSIBILITY SPACE                  │
         │                                        │
    S ───┼──→ probe ──→ probe ──→ WALL            │
         │         ╲                              │
         │          ╲ backtrack (reverse, reduce) │
         │           ╲                            │
         │            → probe ──→ probe ──→ G     │
         └────────────────────────────────────────┘

Each probe = a frame direction
Hit wall = overshoot (0x00 boundary)
Backtrack = reverse direction, reduced priority (halved momentum)
Converge = path found (0xFF arrival)
```

Like riding a roller coaster through the search space - you probe outward,
hit boundaries, curve back with dampened momentum, until you arrive.

### Path Curve Analysis

With frame storage, paths become curves that can be Fourier-analyzed:

```lua
-- Decompose path into directional spectrum
local spectrum = curve_decompose(path.frames)

-- spectrum.magnitude[0x31] = count of eastward steps
-- spectrum.magnitude[0xC3] = count of northward steps
-- etc.

-- Reconstruct approximate path (same distribution, possibly smoothed)
local smoothed = curve_reconstruct(spectrum, target_length)
```

Straight paths: one direction dominates
Zigzag paths: opposing directions balance
Spiral paths: directions cycle through quadrants

## Suggested Implementation Steps

1. **Create frame direction LUT** (src/runtime/pathfinding/frames.lua)
   - DIR_TO_FRAME[8]: map direction index to frame byte
   - FRAME_TO_DIR[256]: map frame byte to nearest direction
   - encode_direction(dx, dy) → frame byte
   - decode_direction(frame) → dx, dy

2. **Add frame path storage** (update astar.lua)
   - Option: `options.frame_output = true`
   - Return `{ start = {x,y}, frames = {...} }` instead of waypoint array
   - Reconstruction function: `frames_to_path(frame_path) → waypoint_path`

3. **Create path curve analysis** (src/runtime/pathfinding/curve.lua)
   - path_to_spectrum(frames) → MomentumStatic-style histogram
   - spectrum_to_path(spectrum, length) → approximated frames
   - path_curvature(frames) → curvature signal
   - path_smoothness(frames) → 0.0 (jagged) to 1.0 (straight)

4. **Add path compression utilities**
   - compress_path(waypoints) → frame_path
   - decompress_path(frame_path) → waypoints
   - estimate_path(frame_path, precision) → approximated waypoints

5. **Integrate with movement system** (update 404)
   - Store unit paths as frame sequences
   - Interpolate between frames for smooth movement
   - Allow path approximation for distant units (LOD)

6. **Update tests**
   - Test direction encoding/decoding roundtrip
   - Test path compression/decompression preserves endpoints
   - Test curve analysis identifies path characteristics

## Acceptance Criteria

- [x] Frame encoding captures all 8 movement directions
- [x] Frame paths describe shape independently of starting position
- [x] Same frame sequence can be applied from different origins
- [x] Path shapes can be compared/matched (similarity metric)
- [ ] Curve analysis identifies path characteristics (straight, curved, zigzag)
- [x] Movement system can follow frame-encoded paths

## Related Documents

- `docs/render-architecture.md` - Frame encoding specification
- `src/runtime/pathfinding/astar.lua` - Current A* implementation
- `src/runtime/pathfinding/smooth.lua` - Path smoothing (related)

## Notes

### The Roller Coaster Metaphor

Picture riding the splines in Sim Theme Park or Planet Coaster. The path
computation IS the ride - you're processing one bit more of the exploratory
perspective through idea-space. Step by step, every time you pass the target,
you turn around and go a bit slower. Until the value is concluded.

The A* priority queue is the "momentum counter" - higher f-scores mean more
momentum toward that direction. When a path probe hits a wall, it's like
hitting 0x00 (overshoot) - you reverse and try a different direction with
reduced priority (halved momentum in the queue).

### Beyond Physical Paths

This same encoding can represent:
- LLM attention patterns (which tokens "look at" which)
- Relationship graphs (affinity directions between entities)
- Emotional trajectories (mood changes over time)
- Decision trees (which choices lead where)

The frame system is general-purpose direction encoding. A* just happens to
explore 2D grids, but the exploration pattern applies to any space where
you're probing toward a goal.

### ASCII Art Path Encoding

Paths can be visualized as ASCII direction sequences:

```
Path: →→↗↗↑↑↑←←↙
Frames: 31 31 33 33 C3 C3 C3 C4 C4 CC

Or as a single line of directional "code":
>>^^|||<<\

The path IS the program. The directions ARE the data.
```

This enables "code-is-data" pathfinding where the path representation is both
human-readable and machine-executable.

## Implementation Notes

### Files Created/Modified

1. **src/runtime/pathfinding/frames.lua** (NEW)
   - Core frame direction encoding module
   - Cardinal frames: NORTH=0x0F, SOUTH=0xF0, EAST=0xCC, WEST=0x33
   - Ordinal frames: NE=0x4C, NW=0x1C, SE=0xC4, SW=0xC1
   - Boundary frames: ORIGIN=0xFF (arrived), OVERSHOOT=0x00 (reverse)
   - Functions: frame_to_vector, vector_to_frame, path_to_frames, frames_to_path
   - Momentum structure with direction + count separation
   - ASCII visualization with arrow glyphs (↑↓←→↗↖↘↙○×)
   - Uses compat.lua for cross-version bitwise operations

2. **src/runtime/pathfinding/astar.lua** (MODIFIED)
   - Added find_path_frames() - returns frame path directly from A*
   - Added path_to_frames() / frames_to_path() wrappers
   - Added path_to_ascii() for visualization
   - Added compare_paths() similarity metric

3. **src/runtime/orders/init.lua** (MODIFIED)
   - Added orders.move_frames() - issue move order from frame choreography
   - Added orders.get_path_shape() - get ASCII art of current movement
   - Added orders.get_momentum() - get Momentum object for entity
   - Added orders.apply_force() - apply directional force
   - Added orders.shapes table with preset patterns (CIRCLE, ZIGZAG, RETREAT)
   - Fixed forward declaration bug for execute_move_frames

4. **src/tests/test_frames.lua** (NEW)
   - 67 tests covering all frame operations
   - Tests roundtrip conversions, position independence, momentum

### Key Design Decisions

1. **Compat layer usage**: frames.lua requires compat.lua for bitwise ops,
   making it work with both LuaJIT and Lua 5.3+

2. **Lazy loading in astar/orders**: Frame module loaded on first use to
   avoid circular dependencies

3. **Direction + Magnitude separation**: Momentum stores frame byte (which way)
   separate from count (how much), enabling physics without floating point

4. **Position-independent shapes**: Frame paths describe movement shape, not
   absolute coordinates - same shape can be applied from any origin

### Remaining Work

- [ ] Curve analysis module (src/runtime/pathfinding/curve.lua)
  - path_to_spectrum() for Fourier-style decomposition
  - path_curvature() and path_smoothness() metrics
  - This is tracked separately and can be added in a future iteration
