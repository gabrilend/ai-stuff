# test_matchmaking_integration.lua

The matchmaking pieces together, end to end (issue 801h). The test runs in
a network of its own (`netns.lua`, needs `unshare -rn`). It starts the
server the way an operator would: `world-edit-matchmaking.lua serve
--config FILE`, with the NAT reflector, the asset mirror and a one-second
countdown. Then it plays the issue's six scenarios against that server,
using client libraries polled as a game polls them:

1. A lobby from opening to game start: list, join, chat both ways, ready,
   the countdown, a late join refused, the game start with the host's
   address, and the operator's `lobbies` and `lobby` views.
2. NAT traversal: the server's own reflector finds the machine open. Then
   lobbies run over real TCP while the UDP goes through simulated home
   routers (`natsim.lua`). A restricted cone host and a port-restricted
   player punch through and trade datagrams. A port-restricted host and a
   symmetric player are both told the punch failed; there is no relay.
3. The asset mirror: the host and players are told what the mirror holds,
   and which packs come from the mirror and which from the host. A pack
   added with `assets add` reaches the running server through SIGHUP.
4. Fifty lobbies at once, each joined, counted by the server.
5. A host whose socket just goes: its players are told the lobby closed.
   A player who goes the same way is seen to leave.
6. What is refused: a lobby that isn't there, a player starting or
   kicking (also a START_GAME sent past the library's own check), a
   second lobby on one connection, a full lobby. A kicked player is told.

It prints the median times for opening a lobby, joining and a chat line,
and checks them against the issue's baselines (50, 100 and 20 ms). It
ends with no connection or lobby left on the server, and a SIGTERM that
tells the last lobby it closed.

Its folder comes from `mktemp -d`, under `$TMPDIR` when set, and is
removed at the end. Several copies can run at once, since each has its
own network and folder.

- **Usage:** `luajit src/tests/test_matchmaking_integration.lua [DIR]`.
  Exits 1 on a failure, or when it can't have a network of its own.
