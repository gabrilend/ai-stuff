# world-edit-matchmaking.lua

The matchmaking server's command-line tool (issue 801g): runs the server
from a configuration file or flags, and answers questions about one that
is running. A running server writes a state file every few seconds
(`daemon.lua`); `status`, `lobbies` and `lobby` read that file, so they
need no connection to the server. Needs LuaJIT and LuaSocket (for
`serve`).

**Usage:** `luajit src/cli/world-edit-matchmaking.lua COMMAND [options]`;
every command takes `--help`.

| Command | Does |
|---|---|
| `serve` | runs the server until SIGTERM or Ctrl-C (then every lobby is told it closed); prints `listening IP PORT` (and `nat IP PORT ALT`). Flags: `--config FILE`, `--bind`, `--nat-port`, `--nat-alt-ip`, `--mirror-contact`, `--packs-dir`, `--countdown`, `--log-file`, `--state-file`, `--state-interval`, `--seconds`, `-q`, `-v`. Flags win over the file. SIGHUP has the mirror read its folder again |
| `status` | lobbies, players, connections, uptime, traffic per second, NAT and mirror |
| `lobbies` | a table of lobbies: id, map, host, players, state |
| `lobby ID` | one lobby: map and hash, host, each player and whether ready, state (with the countdown), age, asset packs |
| `logs` | the log's last lines (`-n N`); `--follow` keeps watching (`--seconds N` stops it) |
| `assets list` | the packs in the mirror's folder (`--packs-dir DIR`, or the configuration's): id, size, hash |
| `assets add FILE [ID]` | copies a pack file in (ID: the file's name without `.pack`) |
| `assets remove ID` | deletes a pack from the folder |
| `validate-config FILE` | lists every problem in a configuration file, or what it sets |

Most commands take `--config FILE` (to find the state file, the log and
the packs folder) or `--state FILE`, `--json` (machine-readable), and
`--no-color`; colour is used only on a terminal and with `NO_COLOR`
unset. After `assets add` or `remove`, a running server named by
`--config` or `--state` is sent SIGHUP so it reads the folder again.

Exit codes: 0 done, 1 an error or the server isn't running, 2 a bad
command or flag.
