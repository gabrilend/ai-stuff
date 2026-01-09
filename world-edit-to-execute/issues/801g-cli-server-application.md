# Issue 801g: CLI Server Application

**Phase:** 7 - Multiplayer & Networking
**Type:** Implementation
**Priority:** High
**Dependencies:** Issue 801b (server core), Issue 801f (asset mirror)
**Parent:** Issue 801 (Matchmaking Server)

---

## Current Behavior

No command-line tool for running matchmaking server.

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
