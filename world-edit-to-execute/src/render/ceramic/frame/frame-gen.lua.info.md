# frame-gen.lua

Prints `frame.map`, the frame's shape:
- `sim` fans out to `fog0..3` (each has a static player constant) and to
  port 1 of `pose0..7`;
- each `poseL` feeds `cullL`;
- `paths` and `decodes` stand alone.

**Arguments:** 0 is the tick; 1–8 are the lane requests; 9 is pathfinding;
10 is decodes. **Results:** 0–3 are fog; 4–11 are culling; 12 is
pathfinding; 13 is decodes.
