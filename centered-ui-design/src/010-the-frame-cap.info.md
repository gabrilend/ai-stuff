<!-- written by Claude (Opus 5.5), 2026-10-10, for the first renderer slice: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 010-the-frame-cap

Holding frames to the player's cap (0..240, 0 = none).

| Offers | Gives |
|---|---|
| `frame_budget(cap)` | seconds per frame, or nil for no cap |
| `clamp_cap(cap)` | a whole number within 0..240 |
| `next_deadline(last, budget, now)` | the next slot's end; restarts from now after a stall |
| `wait_until(deadline, get_time, sleep)` | sleeps most of the way, watches the clock for the last 2 ms |
