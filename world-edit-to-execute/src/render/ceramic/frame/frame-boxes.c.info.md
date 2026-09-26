# frame-boxes.c

The fabricated frame's boxes. `run-frame.sh` appends them to
`pose-boxes.c` (with its value types spliced in), and all three ways run
these same functions.

**Types** (all plain numbers):
- `tick {frame, seed}`;
- `sim_state {frame, hash}`;
- `lane_req {frame, lane}`;
- `lane_out {frame, lane, hash}`;
- `job {frame, id, rounds}`;
- `done {frame, id, hash}`.

**Boxes:**

| Box | Cost | Notes |
|---|---|---|
| `simulate(tick) -> sim_state` | `SIM_US` | |
| `fog(sim_state, int player) -> done` | `fog_us` | the player is a static constant in the map |
| `pose_lane(lane_req, sim_state) -> lane_out` | 256 units of pose math, folded | a join |
| `cull(lane_out) -> done` | `CULL_US` | |
| `pathfind(job) -> done` | the job's rounds | |
| `decode(job) -> done` | the job's rounds | background |
