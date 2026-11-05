# run-net-tests.sh

Runs the tests of issues 803, 804, 405f, 801a, 801b, 801c, 801d, 801e, 801f, 801g and 801h: messages (Lua and
the generated C unpacker), the server, the server on its own thread, the
crowd, the matchmaking messages, and the matchmaking server and client
library (their rules, then over sockets in a network of their own, which
needs `unshare -rn`), and NAT detection and hole punching (on simulated
routers, then on real UDP in a network of its own), and the lobby's
countdown, kicks and multiplayer screens, the asset mirror's packs, and
the server's command-line tool: its configuration files, state file,
signals and commands, and the issue's six scenarios with all of it
together (in folders `mktemp -d` makes, under `$TMPDIR` when set). Exits 1 if any fails. **Usage:**
`run-net-tests.sh [DIR]`.
