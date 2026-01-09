# Issue 609: Matchmaking Server

**Phase:** 6
**Type:** Implementation
**Priority:** High
**Dependencies:** Issue 603 (asset download protocol), Issue 607 (file server)

---

## Current Behavior

No matchmaking system exists. Players must:
- Manually share IP addresses to host/join games
- Connect directly via LAN or port forwarding
- Have no way to discover available custom maps
- Manually distribute asset packs via file sharing

## Intended Behavior

A lightweight matchmaking server that:
1. Lists available hosted games (custom maps)
2. Facilitates NAT traversal (hole punching) for peer-to-peer connections
3. Distributes common community asset packs
4. Provides lobby chat and player presence
5. Runs as a public service or self-hosted for communities

**Design Philosophy:** Minimal, stateless where possible, no accounts/authentication required for basic functionality.

---

## Architecture

```
                    MATCHMAKING SERVER
                    ┌────────────────┐
                    │                │
                    │  Game Listing  │
         ┌──────────│  NAT Traversal │──────────┐
         │          │  Asset Mirror  │          │
         │          │  Lobby Chat    │          │
         │          └────────────────┘          │
         │                  │                   │
         │                  │                   │
    HOST CLIENT        GAME DATA           JOINING CLIENT
    ┌─────────┐            │                ┌──────────┐
    │         │            │                │          │
    │ Create  │────register game────▶       │ Browse   │
    │ Lobby   │                              │ Games    │
    │         │                              │          │
    │ Host    │◀───────NAT punch────────────│ Join     │
    │ Game    │                              │ Game     │
    │         │                              │          │
    └─────────┘                              └──────────┘
         │                                        │
         └────────── P2P Game Traffic ───────────┘
                   (direct connection)
```

**Key Point:** Matchmaking server facilitates discovery and connection, but **game traffic is peer-to-peer** (not relayed through server).

---

## Features

### 1. Game Listing

Hosts register games with:
- Map name and hash
- Required asset packs (with hashes)
- Current players / max players
- Game mode (melee, custom scenario, etc.)
- Host location (region hint for latency)

Clients query and filter:
- By map name
- By player count
- By game mode
- By latency region

### 2. NAT Traversal

Uses UDP hole punching to establish direct P2P connections:
1. Host and client both connect to matchmaking server
2. Server shares external IP:port of both parties
3. Both attempt simultaneous UDP packets to each other's external endpoint
4. NAT devices create temporary mappings, allowing direct connection

**Fallback:** If hole punching fails (symmetric NATs), server can optionally relay game traffic (at cost of bandwidth).

### 3. Asset Mirror

Matchmaking server can host common asset packs:
- Players download once, use across many games
- Reduces bandwidth burden on individual hosts
- Curated community packs with quality standards

### 4. Lobby System

Simple text-based lobby for coordination:
- Pre-game chat
- Player list with ready status
- Host can kick/start game
- Countdown before game start

---

## API Design

### Host API

```lua
local matchmaking = require("matchmaking.client")

-- Connect to matchmaking server
matchmaking.connect("matchmaking.wc3engine.org", 8080)

-- Create lobby
local lobby = matchmaking.create_lobby({
    map_name = "Castle Defense v1.3",
    map_hash = "sha256:abc123...",
    asset_packs = {
        { id = "medieval-pack-v1", hash = "sha256:def456..." },
    },
    max_players = 4,
    game_mode = "co-op",
    region = "us-west",
})

-- Wait for players to join
lobby:on("player_join", function(player)
    print(player.name .. " joined!")
end)

-- Start game when ready
lobby:start_game()

-- Get direct P2P connections to clients
local clients = lobby:get_connections()
-- [ { ip = "1.2.3.4", port = 6112 }, ... ]
```

### Client API

```lua
local matchmaking = require("matchmaking.client")

-- Connect to matchmaking server
matchmaking.connect("matchmaking.wc3engine.org", 8080)

-- List available games
local games = matchmaking.list_games({
    region = "us-west",
    max_latency_ms = 100,
})

-- Join a game
local lobby = matchmaking.join_game(games[1].id)

-- Download required assets (if needed)
lobby:on("asset_required", function(pack)
    print("Downloading " .. pack.id .. "...")
end)

lobby:on("game_start", function()
    -- Get connection to host
    local host = lobby:get_host_connection()
    -- { ip = "1.2.3.4", port = 6112 }
end)
```

---

## Protocol Specification

### Message Types

| Message | Direction | Purpose |
|---------|-----------|---------|
| `REGISTER_GAME` | Host → Server | Create lobby |
| `UNREGISTER_GAME` | Host → Server | Close lobby |
| `LIST_GAMES` | Client → Server | Query available games |
| `GAME_LIST` | Server → Client | List of games |
| `JOIN_GAME` | Client → Server | Join specific lobby |
| `JOIN_ACK` | Server → Client | Join accepted |
| `LOBBY_UPDATE` | Server ↔ All | Player join/leave/ready |
| `START_GAME` | Host → Server | Begin game |
| `NAT_PUNCH` | Server ↔ All | Exchange external endpoints |
| `CHAT_MSG` | Client ↔ All | Lobby chat |

### Wire Format

Binary protocol for efficiency:

```
Header (8 bytes):
  [2 bytes] Magic: 0x5743 ("WC")
  [2 bytes] Message Type
  [4 bytes] Payload Length

Payload:
  [variable] MessagePack-encoded data
```

---

## Suggested Implementation Steps

1. **Design wire protocol** - Message types, encoding
2. **Implement server** - `src/matchmaking/server.lua`
   - Game registry (in-memory, simple)
   - NAT traversal logic
   - Asset mirror integration
3. **Implement client** - `src/matchmaking/client.lua`
   - Connect, list, join, host
   - Lobby state management
4. **Implement NAT punch** - `src/matchmaking/nat.lua`
   - UDP hole punching
   - STUN-like endpoint detection
5. **Add asset mirror** - Integrate with Issue 607 file server
6. **Create CLI tool** - `src/cli/matchmaking-server.lua`
   - Run server
   - Monitor lobbies
   - View statistics
7. **Test NAT scenarios**
   - Full cone, restricted cone, symmetric NATs
   - Success rate measurement

---

## Deployment

### Public Matchmaking Server

```bash
# Run public server
./world-edit-matchmaking serve --bind 0.0.0.0:8080 --assets ./community-packs/

# With monitoring
./world-edit-matchmaking serve --bind 0.0.0.0:8080 --web-dashboard :8081
```

### Self-Hosted (Community Servers)

```bash
# Private server for a clan/community
./world-edit-matchmaking serve --bind 0.0.0.0:8080 --private --whitelist clan-members.txt
```

### Configuration

```lua
-- matchmaking-server.conf.lua
return {
    bind = "0.0.0.0:8080",

    -- NAT traversal
    enable_nat_punch = true,
    enable_relay = false,  -- Disable relay (bandwidth expensive)

    -- Asset mirroring
    asset_mirror = {
        enabled = true,
        packs_dir = "./community-packs/",
        bandwidth_limit_mbps = 100,
    },

    -- Limits
    max_lobbies = 1000,
    max_players_per_lobby = 12,
    lobby_timeout_seconds = 3600,  -- Auto-close after 1hr

    -- Monitoring
    web_dashboard = {
        enabled = true,
        bind = "0.0.0.0:8081",
        auth = "admin:password",  -- Basic auth
    },
}
```

---

## Acceptance Criteria

- [ ] Server starts and listens on configured port
- [ ] Hosts can register games
- [ ] Clients can list available games
- [ ] Clients can join lobbies
- [ ] Lobby chat works (pre-game coordination)
- [ ] NAT hole punching succeeds (>80% success rate on tested NAT types)
- [ ] Asset packs can be mirrored and downloaded
- [ ] Game start triggers P2P connection establishment
- [ ] Lobbies auto-close when host disconnects
- [ ] Web dashboard shows active games and statistics

---

## Related Documents

- Issue 603 - Asset download protocol (used for asset mirror)
- Issue 607 - File server (asset distribution)
- `docs/wc3-engine-architecture.md` - Overall system design

---

## Open Questions

1. **Authentication:** Do we want optional accounts for:
   - Player reputation/trust scores
   - Friends lists
   - Persistent player names
   - Ban management

2. **Region servers:** Should we run multiple matchmaking servers per region, or one global server with region hints?

3. **Relay fallback:** If NAT punch fails, do we:
   - Reject connection (P2P only)
   - Relay through server (expensive)
   - Suggest port forwarding to user

4. **Discovery:** How do clients find matchmaking servers?
   - Hardcoded list
   - DNS-based discovery
   - Community-maintained registry

---

## Notes

- Keep it simple: no complex lobby systems, just the basics
- Privacy-focused: no telemetry, minimal data collection
- Self-hostable: communities should be able to run their own servers
- Stateless where possible: server restart shouldn't break existing games (they're P2P)
- Consider WebRTC for future NAT traversal (more complex, but better success rates)
