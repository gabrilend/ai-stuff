# config.lua

The matchmaking server's configuration file, read and checked (issue
801g). A configuration file is Lua that returns a table:

```lua
return {
    bind = "0.0.0.0:8080",
    max_lobbies = 1000, max_players_per_lobby = 12,
    lobby_timeout_seconds = 3600, idle_timeout_seconds = 120,
    countdown_seconds = 5,
    nat = { enabled = true, port = 3478, alt_ip = "203.0.113.2" },
    asset_mirror = { enabled = true, contact = "mirror@example.org", packs_dir = "./community-packs/" },
    log_file = "./matchmaking.log",
    state_file = "./matchmaking.state", state_interval = 2,
}
```

The file runs with no globals, so it can hold only plain Lua. Paths in it
are taken from the file's own folder. Every problem is reported, not
only the first, each saying what to do instead; the settings the issue's
sample has and this server doesn't (`enable_relay`, `enable_nat_punch`,
`web_dashboard`, `stats_file`, `log_level`, `asset_mirror.port`,
`asset_mirror.bandwidth_limit_mbps`, `asset_mirror.packs`) are named with
what to write instead (`config.HINTS`).

- **`config.load(path) -> settings, problems`**: settings is nil when any
  problem is an error; each problem is `{ level = "error" | "warning",
  text }`.
- **`config.check(t, base) -> settings, problems`**: the same for a
  table, with paths taken from folder `base`.
- `settings` is what `daemon.run` takes: `server` (server.lua's
  settings), `nat` or nil, `mirror` or nil, `log_file`, `state_file`
  (default `matchmaking.state`), `state_interval` (default 2).
