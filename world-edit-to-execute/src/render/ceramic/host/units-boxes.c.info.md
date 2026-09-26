# units-boxes.c

The host loop's boxes (issues 515b, 515c). `run-host.sh` splices the lane's answer
type (`lane_units`, 256 × `unit`) in at the marker.

- **Types:**
  - `unit`: position `x, y, z`, velocity `vx, vy, vz` (units a second),
    `facing` and `anim` (radians), all `float`, and `color` (`unsigned
    int`, 0xRRGGBBAA): 36 bytes;
  - `tick {frame, time}`;
  - `frame_clock {frame, time}`;
  - `lane_req {frame, lane}`.
- **`unit_place(id, t, *out)`** (private): the unit's ring, speed, bob and
  team colour, with the position's exact rate of change as the velocity.
  Both the box and the host's check call it.
- **`advance(tick) -> frame_clock`:** the frame's clock, fanned out to
  every lane.
- **`move(lane_req, frame_clock) -> lane_units`:** one lane's 256 units. A
  join.
- **Sizes:** `UNIT_LANES` (8), `UNITS_PER_LANE` (256), `UNIT_COUNT`.
