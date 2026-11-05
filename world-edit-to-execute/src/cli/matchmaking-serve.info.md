# matchmaking-serve.lua

Runs the matchmaking server (`src/matchmaking/server.lua`, issue 801b) as a
daemon until it is killed or its time is up. Once listening it prints
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

Exits 1 when it can't listen, 2 on a bad option. The full tool (status,
lobby lists, configuration files, asset packs) is issue 801g.
