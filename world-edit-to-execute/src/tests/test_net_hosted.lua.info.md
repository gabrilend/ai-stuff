# test_net_hosted.lua

Plays against the server on its own thread, in real time (about seven
seconds), issue 803: a clean connection (states at 62.5 a second, ticks
rising, a death event, an order answered); 100 ms of delay; half the
messages lost; a player's connection dropping for 1.3 s, which the
starting 2 s tolerance rides out and a 0.5 s slider turns into a pause that
resumes from the paused tick.

- **Usage:** `luajit src/tests/test_net_hosted.lua [DIR]`; exits 1 on a
  failure.
