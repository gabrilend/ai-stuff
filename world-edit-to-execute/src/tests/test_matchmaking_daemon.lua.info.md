# test_matchmaking_daemon.lua

Checks the matchmaking server over real sockets (issue 801b), in a network
of its own (`netns.lua`, needs `unshare -rn`): the daemon
(`src/cli/matchmaking-serve.lua`) on a port it chose, a host and two
players through a whole lobby, the host going, fifty connections at once,
a client sending rubbish, the log, `--seconds`, `--quiet` and bad options;
then the socket layer inside the test, a message cut in two, and `stop()`
telling a lobby's members.

- **Usage:** `luajit src/tests/test_matchmaking_daemon.lua [DIR]`; exits 1
  on a failure, or when it can't have a network of its own.
