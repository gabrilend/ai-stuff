# pose-boxes.c

The benchmark's work, written as ceramic boxes (plain C functions). The same
pose math is used by every way of running it.

- **Value types.** `mat4` (16 floats), `pose` (30 `mat4`, 1920 bytes) and
  `chunk_pose` (64 poses) are written as named fields by `pose-types.lua` and
  spliced in at the marker, because the engine's value types can't hold
  number arrays.
- **Request types.** `pose_request {unit, time}` and `chunk_request {first,
  time}`.
- **`pose_unit(pose_request) -> pose`**: one unit's 30 bone matrices. Each
  bone is a turn from the time, the bone and the unit, composed onto its
  parent.
- **`pose_chunk(chunk_request) -> chunk_pose`**: 64 units' poses in one
  value.
- **`pose_into(unit, time, pose *)`** (private): the shared math.
