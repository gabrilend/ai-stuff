# test_matchmaking_client.lua

Checks the matchmaking client library (issue 801c) against the server's
core, bytes passed by hand on a clock the test moves (no network):
options; hosting, listing and their refusals, waiting and by callback;
joining and every lobby event (join, leave, ready, chat, NAT endpoints,
start, closed) reaching the right side; messages of another lobby
ignored; host-only calls refused; the keepalive and its latency; and a
connection gone wrong failing what waits, closing the lobby and planning
a reconnect.

- **Usage:** `luajit src/tests/test_matchmaking_client.lua [DIR]`; exits 1
  on a failure.
