# Issue 801h: Matchmaking Integration Tests

**Phase:** 8 - Multiplayer & Networking
**Type:** Testing
**Priority:** High
**Dependencies:** 801a, 801b, 801c, 801d, 801e, 801f, 801g (the other matchmaking sub-issues; this line used the old Phase 7 numbering until 2026-09-26)
**Parent:** Issue 801 (Matchmaking Server)

---

## Current Behavior

No integration tests exist for the matchmaking system.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #312 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- The test starts a real server with no `--seconds` limit and nothing catches a crash, so any failure mid-run leaves the server running forever in its private network and leaves the temp folder (the sibling test passes `--seconds 60` for this).
- The client library waits on select() before sending what is queued, so every blocking call loses about 10 ms first; the "about 11 ms" baseline recorded in this issue measures that delay, not the server. Send queued output before the select. (The fix belongs in 801c's client library.)
- "Can't open a second lobby on one connection" only checks the client's own guard; the server's rejection is never reached.
- The late-join check depends on the join landing within the one-second countdown; on a loaded machine it fails with "the game has started".
- The log check for the ignored START_GAME searches the whole log, so an earlier line satisfies it.
- A dead branch reads a field the client never sets (`close_reason`).
- The utility block is copied from `test_matchmaking_cli.lua`; six matchmaking tests now keep their own quote, wait and spawn helpers.
- Current Behavior still says no integration tests exist; fixed run numbers are written into the issue.

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

- 801a-801g (testing integration of all components)

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

## Decisions (2026-11-05)

Made without the owner, each one theirs to overturn. Question Q-1 (reuse
803's message layer) doesn't change these tests: they go through the
client library and the operator's tool, so if the codec changes, they
stay as they are.

1. **One file, `src/tests/test_matchmaking_integration.lua`**, not a
   `src/tests/matchmaking/` folder with `run_all.lua`. The project's
   runners already find `test_*.lua` in `src/tests`:
   `run-net-tests.sh` and `src/cli/run-tests.sh -d DIR matchmaking`
   are the "run all".
2. **The server is started as an operator starts it**: `serve --config
   FILE` (801g), with its reflector, mirror and a one-second countdown.
   It runs in a network of its own (`unshare -rn`, `netns.lua`) instead
   of Docker, so copies can run side by side.
3. **NAT traversal mixes real and simulated** (step "mock NAT
   behaviour"): the lobby's messages go over real TCP to the real
   server, and the UDP goes through `natsim.lua`'s routers on a
   simulated clock, since a loopback has no NAT. The issue's pair
   (restricted cone host, port-restricted player) punches through. A
   port-restricted host and a symmetric player are told it failed: there
   is no relay (801d decision 3). The real reflector on real UDP is
   checked too (open).
4. **Test 3, "the client downloads the pack", is the advertisement
   only**: the server tells players which packs the mirror holds and the
   library plans mirror against host. Transfers go over rmail (801f)
   and aren't built, so there is no download to wait for.
5. **Abrupt disconnects close the socket with no goodbye**, for a host
   (its lobby closes for everyone) and for a player (seen to leave).
6. **Error texts are the server's own** ("no such game", "the lobby is
   full", "the game is starting"), and a player's START_GAME sent past
   the library's own check is shown to be ignored by the server.
7. **Baselines are checked for the lobby's messages only** (median
   open, join, chat against 50, 100 and 20 ms) and printed. The punch
   time is simulated, so it shows the logic's speed, not a network's.
   Asset download speed isn't measurable (point 4). "100+ lobbies
   without degradation" is checked at fifty lobbies with a hundred
   players, as the issue's own Test 4 has it.
8. **Not done here:** CI (this repo has none for the project; the
   runners are what a CI job would call), a coverage figure (no Lua
   coverage tool is installed, and none was added), and load or soak
   tests beyond fifty lobbies.

## What happened (2026-11-05)

- `src/tests/test_matchmaking_integration.lua` with its info page: 62
  checks covering the six scenarios, the baselines, the operator's tool,
  no leftover connections or lobbies, and a clean SIGTERM. It takes
  about 6 seconds and passed three copies run at once. Measured here:
  opening a lobby and joining take a median of about 11 ms (the
  library's waiting step), a chat line about 1.3 ms, and a punch 0.12
  simulated seconds.
- It is in `run-net-tests.sh`, and `src/cli/run-tests.sh -d DIR
  matchmaking` runs and counts it.
- Mutation check: 21 mutants across the server, the library, the NAT
  session, the pack plan, the daemon and the tool, with `ulimit -f`, run
  against this test alone. 20 were caught at first. The survivor (a join
  during the countdown was refused for another reason) is caught now
  that the reason is checked.

**Left for the owner:** CI, a coverage tool if one is wanted, a run
against real NATs and a public STUN server (801d), and the download
scenario once rmail transfers exist (801f).
