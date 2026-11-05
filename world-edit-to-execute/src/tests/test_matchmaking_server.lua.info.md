# test_matchmaking_server.lua

Checks the matchmaking server's core (issue 801b) with no network, on a
clock the test moves: settings; registering and its refusals; listing and
each filter; joining, leaving and their refusals; ready marks, chat and NAT
endpoints reaching the right members with the sender's id; starting,
updating and unregistering, by the host only; the keepalive and the
server's own messages ignored; bytes that are not messages closing the
connection; the rate, output and connection limits; the idle and lobby
timeouts; the statistics; and twenty closed lobbies leaving nothing held.

- **Usage:** `luajit src/tests/test_matchmaking_server.lua [DIR]`; exits 1
  on a failure.
