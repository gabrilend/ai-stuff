# daemon.lua

The loop that runs the matchmaking server until it is told to stop (issue
801g), shared by `src/cli/matchmaking-serve.lua` and
`src/cli/world-edit-matchmaking.lua serve`. It starts the server (801b),
the NAT reflector (801d) and the asset mirror (801f) when asked, writes a
state file every few seconds, and stops cleanly on SIGTERM or SIGINT.

- **`daemon.run(o) -> 0, stopped_by`**, or nil and why when it couldn't
  start. `o`: `server` (server.lua's settings), `nat` (`port`, `alt_ip`)
  or nil, `mirror` (`contact`, `packs_dir`) or nil, `log(line)`,
  `state_file`, `state_interval` (seconds, default 2), `seconds` (stop
  after this long), `signals` (true: take TERM, INT and HUP),
  `on_listen(ip, port, reflector)`.
- On SIGTERM or SIGINT the server stops (every lobby's members are told
  the lobby closed), the state file is written once more with
  `running = false` and `stopped_by = "SIGTERM"` (or "SIGINT", or "time
  up"), and `run` returns. SIGHUP has the mirror read its folder again.
- **`daemon.signals(names)`**: blocks those signals for the process and
  reads them through a signalfd (Linux, LuaJIT's FFI), so a signal is
  taken between ticks and never in the middle of a message. `:take()`
  gives one that came, or nil; `:close()` unblocks them.
- **The state file** is Lua (`return { ... }`): `pid`, `running`,
  `stopped_by`, `started`, `updated`, `uptime_seconds`, `bind`, `stats`
  (server.lua's), `bytes_in_per_second`, `bytes_out_per_second`,
  `lobbies` (server.lua's `lobby_list`), `now` (the server's clock, for
  countdowns), `nat` and `mirror` when they run.
  **`daemon.write_state(path, state)`** writes it whole to `path.part`
  and renames it, so a reader never sees half of one;
  **`daemon.read_state(path)`** reads it with no globals at all;
  **`daemon.serialize(v)`** turns plain data into Lua source.
- **`daemon.pid()`**: this process's id.
