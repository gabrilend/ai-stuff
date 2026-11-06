# Issue 801g: CLI Server Application

**Phase:** 8 - Multiplayer & Networking
**Type:** Implementation
**Priority:** High
**Dependencies:** Issue 801b (server core), Issue 801f (asset mirror)
**Parent:** Issue 801 (Matchmaking Server)
**Blocks:** 801h (the integration tests)

---

## Current Behavior

No command-line tool for running matchmaking server.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #311 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- After `assets add` or `assets remove` the tool sends SIGHUP to the process number in the state file, checking only that some process with that number is alive. If the server crashed and the number was reused, an unrelated program is killed (SIGHUP's default). `status` also reports it as running. Check `/proc/PID/cmdline` or store the start time.
- The JSON writer turns empty lists into `{}`; scripts expecting arrays break.
- Non-whole numbers are written with 6 significant digits, so server-clock times like 1793000123.456 come out as `1.793e+09`.
- `--nat-alt-ip` is ignored when NAT comes from the config file rather than `--nat-port`, silently disabling full-cone detection.
- The reload signal is sent even when the running server mirrors a different folder or none, while the tool says it reloaded.
- `logs --follow` never notices the log was truncated (as logrotate's copytruncate, which the PR recommends, does).
- `serve` accepts and ignores `--state` and `--json`; its flag is `--state-file`, so the state lands in the wrong place.
- Flag overrides are applied after the config is checked, so most flags skip validation (`--nat-port 70000` fails later as a socket error).
- The script can't be given its project folder as an argument, and falls back to a hard-coded path; the daemon keeps running without signal handling when it can't block signals, so SIGTERM leaves stale state and SIGHUP kills it.

## Intended Behavior

A user-friendly CLI application for:
1. Starting matchmaking server
2. Configuring server settings
3. Monitoring active lobbies
4. Viewing statistics
5. Managing mirrored asset packs

### CLI Interface

```bash
# Start server with default config
./world-edit-matchmaking serve

# Start with custom config
./world-edit-matchmaking serve --config ./my-server.conf.lua

# Start with inline settings
./world-edit-matchmaking serve --bind 0.0.0.0:8080 --assets ./packs/

# Show server status (requires running server)
./world-edit-matchmaking status
# Lobbies: 12 active
# Players: 47 online
# Uptime: 3h 24m
# Bandwidth: 2.5 MB/s (download)

# List active lobbies
./world-edit-matchmaking lobbies
# ID    MAP NAME                 HOST        PLAYERS  STATE
# a1b2  Castle Defense v1.3      Player123   3/4      WAITING
# c3d4  DotA Allstars 6.88       XxProxX     8/10     STARTING
# e5f6  Tower Defense Elite      NoobMaster  2/8      WAITING

# Show detailed lobby info
./world-edit-matchmaking lobby a1b2
# Lobby: a1b2
# Map: Castle Defense v1.3 (sha256:abc123...)
# Host: Player123
# Players: 3/4
#   - Player123 (host) [ready]
#   - FriendlyGuy [ready]
#   - NewPlayer [not ready]
# State: WAITING
# Created: 5 minutes ago

# Manage asset mirror
./world-edit-matchmaking assets list
# PACK ID               SIZE    DOWNLOADS  LAST USED
# medieval-v1           45 MB   234        2 min ago
# fantasy-v2            120 MB  89         1 hour ago
# sci-fi-v1            67 MB   12         5 hours ago

./world-edit-matchmaking assets add ./new-pack/
# Added: custom-pack-v1 (78 MB)

./world-edit-matchmaking assets remove sci-fi-v1
# Removed: sci-fi-v1

# Show server logs
./world-edit-matchmaking logs
# [2026-01-08 14:23:45] Client connected: 1.2.3.4:54321
# [2026-01-08 14:23:46] Lobby created: a1b2 (Castle Defense v1.3)
# [2026-01-08 14:24:01] Player joined: a1b2 (FriendlyGuy)
# ...

./world-edit-matchmaking logs --follow  # tail -f style

# Validate configuration
./world-edit-matchmaking validate-config ./my-server.conf.lua
# ✓ Configuration valid
# - Bind: 0.0.0.0:8080
# - Max lobbies: 1000
# - Asset mirror: enabled (7878)

# Show help
./world-edit-matchmaking --help
./world-edit-matchmaking serve --help
```

### Configuration File

```lua
-- matchmaking-server.conf.lua
return {
    bind = "0.0.0.0:8080",

    -- Lobby limits
    max_lobbies = 1000,
    max_players_per_lobby = 12,
    lobby_timeout_seconds = 3600,

    -- NAT traversal
    enable_nat_punch = true,
    enable_relay = false,

    -- Asset mirroring
    asset_mirror = {
        enabled = true,
        port = 7878,
        packs_dir = "./community-packs/",
        bandwidth_limit_mbps = 100,
    },

    -- Logging
    log_file = "./matchmaking.log",
    log_level = "info",  -- "debug", "info", "warn", "error"

    -- Monitoring
    stats_file = "./stats.json",  -- Updated every 60s
    web_dashboard = {
        enabled = false,
        bind = "0.0.0.0:8081",
        auth = nil,  -- "user:pass" for basic auth
    },
}
```

## Suggested Implementation Steps

1. Create `src/cli/matchmaking-server.lua`
2. Implement argument parsing (use lua-argparse or similar)
3. Implement `serve` command
   - Load configuration
   - Start server
   - Handle signals (SIGTERM, SIGINT for graceful shutdown)
4. Implement `status` command (connect to running server via IPC)
5. Implement `lobbies` command
6. Implement `lobby <id>` command
7. Implement `assets` subcommands (list, add, remove)
8. Implement `logs` command (read from log file)
9. Implement `validate-config` command
10. Add colored output (green for success, red for errors)
11. Create man page / help documentation
12. Add shell completion scripts (bash, zsh)

## Acceptance Criteria

- [ ] `serve` command starts server successfully
- [ ] Configuration file loaded and validated
- [ ] `status` command shows accurate statistics
- [ ] `lobbies` command lists active lobbies
- [ ] `lobby <id>` shows detailed lobby info
- [ ] `assets` commands manage asset mirror
- [ ] `logs` command displays server logs
- [ ] `validate-config` detects configuration errors
- [ ] Graceful shutdown on SIGTERM/SIGINT
- [ ] Help text clear and comprehensive
- [ ] Error messages helpful and actionable

## Related Documents

- Issue 801b - Server core (backend)
- Issue 801f - Asset mirror (asset commands)

## UX Notes

- **Colors:** Use colored output for better readability
  - Green: success, running status
  - Yellow: warnings, not ready
  - Red: errors, failed status
  - Blue: info, neutral status
- **Progress:** Show progress bars for long operations (starting server, downloading)
- **Verbosity:** Support `-v` flag for verbose output
- **Quiet mode:** Support `-q` flag for minimal output (scripts)
- **JSON output:** Support `--json` flag for machine-readable output

## Deployment Notes

```bash
# Systemd service (Linux)
cat > /etc/systemd/system/wc3-matchmaking.service <<EOF
[Unit]
Description=WC3 Engine Matchmaking Server
After=network.target

[Service]
Type=simple
User=matchmaking
ExecStart=/usr/local/bin/world-edit-matchmaking serve --config /etc/wc3-matchmaking.conf.lua
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable wc3-matchmaking
sudo systemctl start wc3-matchmaking
```

## Notes

- Consider adding `--daemon` flag for background execution
- IPC for `status`/`lobbies` commands: Unix socket or HTTP endpoint?
- Log rotation: integrate with logrotate or implement internally?
- Crash recovery: save lobby state periodically for restart?

## Decisions (2026-11-05)

Made without the owner, each one theirs to overturn. Question Q-1 (reuse
803's message layer) doesn't touch this tool: it reads the server's state
file, not its messages.

1. **The tool is `src/cli/world-edit-matchmaking.lua`,** with commands
   `serve`, `status`, `lobbies`, `lobby ID`, `logs`, `assets
   list|add|remove`, `validate-config` and `--help` for each, as the
   issue shows. `src/cli/matchmaking-serve.lua` stays, with the same
   flags and output, and now runs on the same loop (`daemon.lua`).
2. **`status`, `lobbies` and `lobby` read a state file** (open question:
   IPC by socket or HTTP?). The server writes it every 2 seconds
   (`state_interval`, `--state-interval`), whole, through a `.part` file
   renamed, as Lua read back with no globals. No socket or port to open,
   it works for any user who can read the file, and it stays readable
   after the server stopped (it says when and why). It also serves the
   issue's `stats_file` and part of crash recovery: what was running is
   on disk.
3. **Signals through a signalfd** (LuaJIT's FFI, Linux): TERM, INT and
   HUP are blocked and read between ticks, so a stop never lands in the
   middle of a message. SIGTERM and SIGINT stop the server cleanly: every
   lobby's members are told the lobby closed, and the state file says
   `stopped_by`. **This changed the client test's expectation**
   (`test_matchmaking_client_net.lua`): a SIGTERM'd server now tells its
   lobbies they closed, instead of dropping the connection.
4. **SIGHUP has the mirror read its folder again;** `assets add` and
   `assets remove` send it to a running server named by `--config` or
   `--state`, so a pack added shows in the next advertisement.
5. **The configuration file is Lua returning a table,** run with no
   globals (it can't call anything), paths taken from its own folder.
   Every problem is listed, not only the first, each saying what to do.
   Its settings are the server's own (`bind`, `max_lobbies`,
   `max_players_per_lobby`, the timeouts, `countdown_seconds`, ...),
   `nat = { enabled, port, alt_ip }`, `asset_mirror = { enabled,
   contact, packs_dir }`, `log_file`, `state_file`, `state_interval`.
   Flags win over the file.
6. **Not built, and the file says so when it meets them:** a relay
   (`enable_relay`; 801d decided against one), the web dashboard (`status
   --json` gives the numbers), log levels (there is one), the mirror's
   port 7878 and bandwidth limit (packs go over rmail, 801f), a list of
   packs (the folder is the list), `stats_file` (the state file).
7. **`assets add` takes one `.pack` file** (801f decision 2: a pack is
   one file), not a folder; the id is the file's name or a given one.
   `assets list` shows id, size and hash: there are no download counts
   or last-used times, since the transfers are rmail's.
8. **Output:** colour only on a terminal with `NO_COLOR` unset (green
   running/ready, yellow not ready/countdown/warnings, red errors, blue
   in progress and notes); `--json` for scripts; `-q` and `-v`. Exit
   codes: 0 done, 1 an error or not running, 2 a bad command or flag.
   No progress bars: nothing here takes long enough.
9. **No `--daemon` flag, no log rotation, no shell completion or man
   page:** systemd (the issue's own unit) runs it in the background, the
   log is a plain appended file that logrotate's `copytruncate` handles,
   and `--help` on every command is the documentation. Completion is a
   small later addition if wanted.
10. **The test makes its folders with `mktemp -d`** under `$TMPDIR` when
    set, and runs the servers in a network of its own (`unshare -rn`).

## What happened (2026-11-05)

- `src/matchmaking/daemon.lua` (the loop, signals, the state file) and
  `src/matchmaking/config.lua` (reading and checking a configuration),
  each with an info page; `src/cli/world-edit-matchmaking.lua` with its
  info page; `matchmaking-serve.lua` now runs on `daemon.lua`. The
  server's `lobby_list` also gives each lobby's creation time, asset
  packs and countdown end.
- `src/tests/test_matchmaking_cli.lua` (96 checks): configurations good
  and bad (every error at once, the hints, paths, no globals), the state
  file and signals, and the tool end to end against two real servers:
  `validate-config`, `status`, `lobbies`, `lobby`, `logs` (and
  `--follow`), `assets`, `--json`, exit codes, a countdown, SIGTERM and
  SIGINT stops, and a server that vanished without saying so. In
  `run-net-tests.sh`; `src/cli/run-tests.sh -d DIR matchmaking` runs and
  counts it (10 of 10 files).
- Mutation check: 50 mutants of the configuration, the daemon, the tool
  and the server's lobby list, with `ulimit -f`; 48 caught at first. The
  two survivors (a state file read with globals, and the daemon's own
  check of the packs folder) are caught after two checks were added.

**Left for the owner:** whether the state file is the right way for
`status` to ask (rather than a socket), the systemd unit's install, and
shell completion if wanted. The tool's acceptance criteria are met here,
so the issue could close on the owner's look.
