# test_net_server.lua

Runs the server (issue 803) against a made-up game and clock and checks its
rules: 62.5 ticks a second with a state per player per tick; orders
answered, kept or refused, effective next tick; a silent player pausing
everyone, orders refused while paused, and play resuming from the paused
tick; the strictest slider in force and off-slider values refused; the
drop vote (needed counts, the countdown, no self-votes, one vote per voter,
the drop ending the pause); refusal of garbage and server-only messages.

- **Usage:** `luajit src/tests/test_net_server.lua [DIR]`; exits 1 on a
  failure.
