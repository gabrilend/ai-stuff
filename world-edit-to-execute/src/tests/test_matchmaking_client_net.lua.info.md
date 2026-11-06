# test_matchmaking_client_net.lua

Checks the matchmaking client library over real sockets (issue 801c), in a
network of its own (`netns.lua`, needs `unshare -rn`), against the daemon
(`src/cli/matchmaking-serve.lua`): refused, unreachable and never-answering
servers; a host and a player through a lobby, polled as a game would; the
server killed and brought back, the clients closing their lobbies,
retrying further apart, and reconnecting by themselves; a lobby of 900
asset packs; half a million pings to a server not reading, held back and
then all arriving in order; and `disconnect()` never reconnecting.

- **Usage:** `luajit src/tests/test_matchmaking_client_net.lua [DIR]`;
  exits 1 on a failure, or when it can't have a network of its own.
