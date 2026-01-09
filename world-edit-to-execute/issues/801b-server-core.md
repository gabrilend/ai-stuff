# Issue 801b: Matchmaking Server Core

**Phase:** 7 - Multiplayer & Networking
**Type:** Implementation
**Priority:** Critical
**Dependencies:** Issue 801a (protocol specification)
**Parent:** Issue 801 (Matchmaking Server)

---

## Current Behavior

No matchmaking server implementation exists.

## Intended Behavior

A robust server application that:
1. Manages active game lobbies (in-memory registry)
2. Handles client connections (non-blocking sockets)
3. Routes messages between clients in same lobby
4. Implements lobby lifecycle (create, join, start, close)
5. Cleans up stale lobbies (timeout after 1 hour)

### Core Components

```
Server Architecture:
┌─────────────────────────────────────┐
│     Matchmaking Server              │
│  ┌──────────────────────────────┐   │
│  │   Connection Manager         │   │
│  │  - Accept new connections    │   │
│  │  - Maintain client list      │   │
│  │  - Handle disconnects        │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │   Lobby Registry             │   │
│  │  - Active lobbies (map)      │   │
│  │  - Players per lobby         │   │
│  │  - Lobby metadata            │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │   Message Router             │   │
│  │  - Decode incoming messages  │   │
│  │  - Route to handlers         │   │
│  │  - Broadcast to lobby        │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

### Lobby Lifecycle

```
CREATE → WAITING → STARTING → IN_PROGRESS → CLOSED
   ↓         ↓         ↓            ↓
   └─────────┴─────────┴────────────┴──→ TIMEOUT/ERROR → CLOSED
```

### API Design

```lua
local server = require("matchmaking.server")

-- Create server instance
local srv = server.new({
    bind = "0.0.0.0:8080",
    max_lobbies = 1000,
    max_players_per_lobby = 12,
    lobby_timeout_seconds = 3600,
})

-- Start server (non-blocking)
srv:start()

-- Main loop
while running do
    srv:tick()  -- Process pending events
    sleep(0.01)
end

-- Shutdown
srv:stop()

-- Get statistics
local stats = srv:stats()
-- {
--     lobbies_active = 42,
--     players_online = 123,
--     messages_per_second = 50,
--     uptime_seconds = 3600,
-- }
```

## Suggested Implementation Steps

1. Create `src/matchmaking/server.lua`
2. Implement connection manager (LuaSocket TCP)
3. Implement lobby registry (Lua table with GC)
4. Implement message router (decode, dispatch)
5. Implement lobby handlers (register, join, leave, start)
6. Implement broadcast functions (send to all in lobby)
7. Implement timeout/cleanup logic
8. Add logging (connection events, lobby lifecycle)
9. Add statistics tracking
10. Create integration tests (mock clients)

## Acceptance Criteria

- [ ] Server starts and listens on configured port
- [ ] Accepts multiple concurrent client connections
- [ ] Lobbies created successfully
- [ ] Clients can join lobbies
- [ ] Messages routed correctly to lobby members
- [ ] Lobby closes when host disconnects
- [ ] Stale lobbies cleaned up after timeout
- [ ] Handles client disconnects gracefully
- [ ] Statistics accurate and up-to-date
- [ ] No memory leaks (lobbies properly garbage collected)

## Related Documents

- Issue 801a - Protocol specification
- Issue 801c - Client library (test client)
- Issue 801g - CLI server application (wrapper)

## Notes

- Use non-blocking sockets to avoid thread per connection
- Consider using epoll/kqueue on Linux/BSD for better performance
- Keep lobby registry simple (no persistence needed - server restart = lobbies lost)
- Log all lobby lifecycle events for debugging
- Rate limit message handling to prevent spam
