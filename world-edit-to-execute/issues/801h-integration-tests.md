# Issue 801h: Matchmaking Integration Tests

**Phase:** 7 - Multiplayer & Networking
**Type:** Testing
**Priority:** High
**Dependencies:** All other 701 sub-issues
**Parent:** Issue 801 (Matchmaking Server)

---

## Current Behavior

No integration tests exist for the matchmaking system.

## Intended Behavior

Comprehensive integration tests that verify:
1. End-to-end lobby creation and joining
2. NAT traversal success rates
3. Asset mirror distribution
4. Server stability under load
5. Error handling and edge cases

### Test Scenarios

#### Test 1: Basic Lobby Flow

```lua
-- Test: Create lobby, join, chat, start game

local server = start_test_server()
local host = create_test_client()
local client = create_test_client()

-- Host creates lobby
local lobby_host = host:create_lobby({
    map_name = "Test Map",
    max_players = 4,
})

-- Client lists games
local games = client:list_games()
assert(#games == 1)
assert(games[1].map_name == "Test Map")

-- Client joins
local lobby_client = client:join_game(games[1].id)

-- Verify both see each other
assert(lobby_host:get_player_count() == 2)
assert(lobby_client:get_player_count() == 2)

-- Send chat
lobby_client:send_chat("Hello!")
assert(lobby_host:wait_for_chat() == "Hello!")

-- Start game
lobby_host:start_game()
assert(lobby_client:wait_for_game_start())

cleanup(server, host, client)
```

#### Test 2: NAT Traversal

```lua
-- Test: Verify hole punching works

local server = start_test_server()
local host = create_test_client({ nat_type = "restricted_cone" })
local client = create_test_client({ nat_type = "port_restricted" })

local lobby_host = host:create_lobby({ map_name = "NAT Test" })
local lobby_client = client:join_game(lobby_host.id)

-- Start game triggers NAT punch
lobby_host:start_game()

-- Wait for P2P connection
local connections = lobby_client:wait_for_game_start()
assert(connections[1].ip ~= nil)

-- Verify direct connection works
local udp_host = lobby_host:get_p2p_socket()
local udp_client = lobby_client:get_p2p_socket()

udp_host:send("ping")
assert(udp_client:receive() == "ping")

cleanup(server, host, client)
```

#### Test 3: Asset Mirror

```lua
-- Test: Client downloads asset from mirror

local server = start_test_server({ asset_mirror_enabled = true })
add_test_asset_pack(server, "test-pack-v1", "./test-assets/")

local client = create_test_client()
local lobby = client:join_game_requiring_assets({
    asset_packs = { "test-pack-v1" },
})

-- Client should download asset automatically
wait_for_asset_download(client, "test-pack-v1")
assert(client:has_asset_pack("test-pack-v1"))

cleanup(server, client)
```

#### Test 4: Concurrent Lobbies

```lua
-- Test: Server handles multiple simultaneous lobbies

local server = start_test_server()
local lobbies = {}

for i = 1, 50 do
    local host = create_test_client()
    local lobby = host:create_lobby({ map_name = "Lobby " .. i })
    table.insert(lobbies, { host = host, lobby = lobby })
end

-- Verify all lobbies exist
local games = create_test_client():list_games()
assert(#games == 50)

-- Join each lobby with a client
for i, lobby_info in ipairs(lobbies) do
    local client = create_test_client()
    client:join_game(lobby_info.lobby.id)
    assert(lobby_info.lobby:get_player_count() == 2)
end

cleanup_all(server, lobbies)
```

#### Test 5: Disconnection Handling

```lua
-- Test: Lobby closes when host disconnects

local server = start_test_server()
local host = create_test_client()
local client = create_test_client()

local lobby_host = host:create_lobby({ map_name = "Disconnect Test" })
local lobby_client = client:join_game(lobby_host.id)

-- Host disconnects abruptly
host:disconnect(graceful = false)

-- Client should be notified
assert(lobby_client:wait_for_lobby_closed())

-- Lobby should no longer exist
local games = create_test_client():list_games()
assert(#games == 0)

cleanup(server, client)
```

#### Test 6: Error Handling

```lua
-- Test: Invalid operations handled correctly

local server = start_test_server()
local client = create_test_client()

-- Try to join non-existent lobby
local success, err = pcall(function()
    client:join_game("invalid-lobby-id")
end)
assert(not success)
assert(err:match("Lobby not found"))

-- Try to start game as non-host
local host = create_test_client()
local lobby_host = host:create_lobby({ map_name = "Permission Test" })
local lobby_client = client:join_game(lobby_host.id)

local success, err = pcall(function()
    lobby_client:start_game()  -- Client is not host!
end)
assert(not success)
assert(err:match("Permission denied") or err:match("not host"))

cleanup(server, host, client)
```

## Suggested Implementation Steps

1. Create `src/tests/matchmaking/` directory
2. Implement test utilities
   - `start_test_server()` - Start server on random port
   - `create_test_client()` - Mock client with configurable NAT
   - `cleanup()` - Graceful shutdown of test components
3. Implement Test 1 (basic flow)
4. Implement Test 2 (NAT traversal)
5. Implement Test 3 (asset mirror)
6. Implement Test 4 (concurrent lobbies)
7. Implement Test 5 (disconnection)
8. Implement Test 6 (error handling)
9. Add performance tests (latency, throughput)
10. Create CI integration (run tests on every commit)

## Acceptance Criteria

- [ ] All 6 test scenarios pass
- [ ] Tests run in <60 seconds total
- [ ] Tests cleanup resources properly (no leaked sockets/processes)
- [ ] Tests can run in parallel (isolated from each other)
- [ ] CI runs tests automatically on pull requests
- [ ] Test coverage >80% for matchmaking code
- [ ] Performance tests establish baseline metrics
- [ ] Flaky tests identified and fixed or marked

## Related Documents

- All 701 sub-issues (testing integration of all components)

## Test Environment Setup

```bash
# Run all matchmaking tests
lua src/tests/matchmaking/run_all.lua

# Run specific test
lua src/tests/matchmaking/test_basic_flow.lua

# Run with verbose output
lua src/tests/matchmaking/run_all.lua --verbose

# Run performance tests
lua src/tests/matchmaking/test_performance.lua

# Run NAT traversal tests (requires specific network setup)
lua src/tests/matchmaking/test_nat.lua
```

## Performance Baselines

Establish performance metrics:
- Lobby creation latency: <50ms
- Join lobby latency: <100ms
- Chat message latency: <20ms
- NAT punch completion: <3s
- Asset download speed: >10 MB/s (local network)
- Concurrent lobbies: 100+ without degradation
- Players per lobby: 12 simultaneous

## Notes

- Consider using Docker for isolated test environments
- Mock NAT behavior for repeatable tests
- Test both success and failure paths
- Include load testing for production readiness
- Document how to run tests in different network configurations
