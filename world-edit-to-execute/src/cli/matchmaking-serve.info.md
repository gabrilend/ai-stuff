# matchmaking-serve.lua

Runs the matchmaking server (`src/matchmaking/server.lua`, issue 801b) as a
daemon until SIGTERM or Ctrl-C, or its time is up; then every lobby's
members are told the lobby closed (`src/matchmaking/daemon.lua`). Once listening it prints
`listening IP PORT` on standard output (so a script that asked for port 0
learns the port); every connection and lobby event is logged to standard
error, stamped with the UTC time. Needs LuaSocket.

**Usage:** `luajit src/cli/matchmaking-serve.lua [DIR] [options]`

| Option | Does |
|---|---|
| `--bind HOST:PORT` | where to listen (default `127.0.0.1:8080`; `0.0.0.0:PORT` opens it to every network) |
| `--seconds N` | stops by itself after N seconds |
| `--quiet` | no log |
| `--max-lobbies N`, `--max-players N` | the most lobbies, the most players in one |
| `--lobby-timeout N`, `--idle-timeout N` | seconds before a quiet lobby, a silent connection, is closed |
| `--mirror-contact C`, `--packs-dir DIR` | mirror the asset packs (`*.pack` files) in DIR: whoever opens or joins a lobby needing them is told rmail contact C hands them out (issue 801f; both or neither) |
| `--countdown N` | seconds from the host's start to the game's (default 0, at once; issue 801e) |
| `--nat-port P` | also runs the NAT reflector of `nat.lua` (issue 801d) on UDP ports P and P+1 of the bind address (P 0: any two free ports), and prints a second line, `nat IP PORT ALT_PORT` |
| `--nat-alt-ip IP` | the reflector also answers from this second address of the machine, so a full cone NAT can be told apart (needs `--nat-port`) |

Exits 0 when stopped, 1 when it can't listen (or the reflector can't), 2 on a bad option. The full
tool (configuration files, status, lobby lists, logs, asset packs) is
`world-edit-matchmaking.lua` (issue 801g).
