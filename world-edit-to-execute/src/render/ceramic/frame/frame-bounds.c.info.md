# frame-bounds.c

The floor under every way, from the plan: per frame, the longest chain
(simulation, then the slowest of fog, a pose lane plus its culling, or one
path) and the total work. The best possible frame is the larger of the chain
and the total spread over CORES. A pose lane is timed on a warm core.

- **Usage:** `./frame-bounds FRAMES CORES`.
- **Output:** chain, work, best and pose lane, in microseconds.
