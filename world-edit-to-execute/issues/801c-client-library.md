# Issue 801c: Matchmaking Client Library

**Phase:** 7 - Multiplayer & Networking
**Type:** Implementation
**Priority:** Critical
**Dependencies:** Issue 801a (protocol), Issue 801b (server core - for testing)
**Parent:** Issue 801 (Matchmaking Server)

---

## Current Behavior

No client library for matchmaking exists.

## Intended Behavior

A client-side library that provides:
1. Connection to matchmaking server
2. Game listing and filtering
3. Lobby creation (host mode)
4. Lobby joining (client mode)
5. Lobby chat and events
6. Connection state management

### API Design

```lua
local matchmaking = require("matchmaking.client")

-- Connect to server
local conn = matchmaking.connect({
    host = "matchmaking.wc3engine.org",
    port = 8080,
    timeout = 5000,  -- connection timeout ms
})

-- HOST: Create lobby
local lobby = conn:create_lobby({
    map_name = "Castle Defense v1.3",
    map_hash = "sha256:abc123...",
    asset_packs = {
        { id = "medieval-pack-v1", hash = "sha256:def456..." },
    },
    max_players = 4,
    game_mode = "co-op",
    region = "us-west",
})

-- CLIENT: List available games
local games = conn:list_games({
    region = "us-west",
    max_latency_ms = 100,
})

-- CLIENT: Join a game
local lobby = conn:join_game(games[1].id)

-- Event handlers (both host and client)
lobby:on("player_join", function(player)
    print(player.name .. " joined!")
end)

lobby:on("player_leave", function(player)
    print(player.name .. " left!")
end)

lobby:on("player_ready", function(player, ready)
    print(player.name .. (ready and " is ready!" or " not ready"))
end)

lobby:on("chat", function(player, message)
    print(player.name .. ": " .. message)
end)

lobby:on("game_start", function(connections)
    -- connections = [ { ip, port }, ... ]
    print("Game starting!")
end)

-- Send lobby chat
lobby:send_chat("Hello everyone!")

-- Toggle ready status
lobby:set_ready(true)

-- HOST ONLY: Start game
lobby:start_game()

-- Leave lobby
lobby:leave()

-- Disconnect from matchmaking server
conn:disconnect()
```

## Suggested Implementation Steps

1. Create `src/matchmaking/client.lua`
2. Implement connection management (connect, disconnect, reconnect)
3. Implement message sending with protocol encoding
4. Implement message receiving with protocol decoding
5. Implement lobby object with event emitter
6. Implement game listing (request and parse response)
7. Implement lobby creation (host mode)
8. Implement lobby joining (client mode)
9. Implement chat system
10. Add keepalive/ping mechanism
11. Add error handling and reconnection logic
12. Create unit tests with mock server

## Acceptance Criteria

- [ ] Can connect to matchmaking server
- [ ] Can list available games
- [ ] Can create lobby as host
- [ ] Can join lobby as client
- [ ] Event handlers fire correctly
- [ ] Chat messages sent and received
- [ ] Game start triggered properly
- [ ] Handles server disconnection gracefully
- [ ] Reconnection works after temporary disconnect
- [ ] All API functions documented

## Related Documents

- Issue 801a - Protocol specification
- Issue 801b - Server core (server to test against)
- Issue 801e - Lobby UI (consumer of this library)

## Notes

- Keep the API simple and event-driven
- Use non-blocking sockets to avoid freezing game
- Consider connection pooling if multiple lobbies supported
- Add debugging/logging mode for troubleshooting
- Handle all error cases (network errors, server errors, protocol errors)
