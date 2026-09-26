# renderer_link.lua

The renderer's side of the connection, run by the C renderer's receiving
thread (issue 804). Starts the server on its own thread with the crossing
game and plays two players: this one (0), whose messages go to C, and a
stand-in (1) that only says "heard".

- **`link.start(dir) -> rows, cell, unit_radius`:** the map.
- **`link.poll() -> list of byte strings`:** this player's messages due
  now; sends both players' heard beats every 16 ms (the stand-in's only
  while it isn't silenced).
- **`link.disturb(delay_ms, jitter_ms, loss)`:** this player's connection,
  both ways, live.
- **`link.silence_stand_in(on)`**, **`link.tolerance(ms)`**,
  **`link.vote(player)`**, **`link.stop() -> ticks`.**
