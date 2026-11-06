# Issue 801c: Matchmaking Client Library

**Phase:** 8 - Multiplayer & Networking
**Type:** Implementation
**Priority:** Critical
**Dependencies:** Issue 801a (protocol), Issue 801b (server core - for testing)
**Parent:** Issue 801 (Matchmaking Server)
**Blocks:** 801h (the integration tests), 801e

---

## Current Behavior

No client library for matchmaking exists.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #306 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- When a blocking create or join times out, the client closes the lobby locally but sends nothing to undo it; the server's late acceptance leaves the connection in an orphan lobby, and every later create or join is refused "already in lobby".
- Join acceptances and refusals are applied to whatever lobby is opening without checking the game id, so a late answer to an earlier request settles a later one.
- The reconnect wait resets as soon as TCP connects, so a full server that accepts and closes is retried every second forever; the waits also go 1,1,2,4 instead of 1,2,4.
- A lobby still "opening" can't be left, and callback requests have no timeout, so a lost answer locks the connection until disconnect.
- Unsent output piles up without limit, and each partial send copies the whole remainder.
- poll() waits for input before writing queued output, so every request is held back by the poll's wait (see also 801h).
- Every failed connect is reported as "refused", whatever the real error was.
- Without LuaSocket the clock silently falls back to whole seconds.
- Most functions lack their own folds.

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

- [x] Can connect to matchmaking server
- [x] Can list available games
- [x] Can create lobby as host
- [x] Can join lobby as client
- [x] Event handlers fire correctly
- [x] Chat messages sent and received
- [x] Game start triggered properly
- [x] Handles server disconnection gracefully
- [x] Reconnection works after temporary disconnect
- [x] All API functions documented

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

---

## Decisions (2026-11-05)

Made without the owner, each one theirs to overturn. Question Q-1
(`issues/CRITICAL-PATH.md`) is still open and could reshape this along
with 801a and 801b.

1. **Two layers, as in the server:** a core that knows the server only as
   bytes (`client.new`, `feed`, `output`, `lost`), so every rule is tested
   against the server's core with no network, and LuaSocket under it
   (`client.connect`, `poll`).
2. **The game polls:** `conn:poll()` once a frame does all the network
   work and fires the handlers; nothing runs on a thread of its own, so
   handlers run inside the game's frame. Only `client.connect` waits (up
   to `timeout`, as the issue's API has it); reconnecting never waits.
3. **Waiting or not, the caller's choice:** `list_games`, `create_lobby`
   and `join_game` take an optional callback. With one they return at
   once; without one they poll until the answer comes or `timeout`
   passes, as the issue's examples read (`local games = conn:list_games()`).
4. **One lobby a connection**, as the server has it: asking for a second
   raises here before anything is sent.
5. **A dropped connection closes the lobby** ("closed" with
   "disconnected"), since the server has already dropped it; answers
   still waited for fail with the reason. **Reconnecting** waits
   `reconnect_min` (1 s), then twice as long each failure up to
   `reconnect_max` (30 s), and never after `disconnect()`. A lobby is not
   reopened by itself after a reconnect: its game id would change, so the
   game decides ("reconnect" tells it when).
6. **Keepalive:** a ping every 30 seconds (the server closes a connection
   silent for 120); its round trip is `conn.latency_ms`.
7. **Events** are the issue's (`player_join`, `player_leave`,
   `player_ready`, `chat`, `game_start`) plus `nat_punch` (for 801d) and
   `closed(why)` on the lobby, and `disconnect`, `reconnect` and `pong` on
   the connection. `game_start` gives `{ip, port}` of the host, for the
   host too: in the host-runs-the-game model (801) players connect to the
   host, so a host has no list of connections to make.
8. **Listed games carry `id`** as well as `game_id`, as the issue's
   examples use `games[1].id`. `max_latency_ms` is passed on, but nothing
   measures a game's latency yet; 801d's probing could.
9. **A host's `leave()` unregisters the lobby** (UNREGISTER_GAME), the
   message 801a gives the host.
10. **Logging** is the `log` option, a function taking a line, as in the
    server; nothing is printed unless the game asks.

## What happened

- `src/matchmaking/client.lua` with its info page (every call, field and
  event).
- `src/tests/test_matchmaking_client.lua` (67 checks, no network): the
  library against the server's core, bytes passed by hand.
- `src/tests/test_matchmaking_client_net.lua` (23 checks, under
  `unshare -rn`, against the daemon): refused, unreachable and
  never-answering servers; a whole lobby over sockets; the server killed
  and brought back, the clients reconnecting by themselves with growing
  waits; a lobby of 900 asset packs; half a million pings to a server
  not reading, held back and then all arriving in order.
- Both are in `run-net-tests.sh`; every net test passes but
  `test_net_hosted`, which needs effil and failed the same before.
- Mutation check: 42 mutants of the library, run with `ulimit -f`. All 42
  are caught, nine of them only after checks were added for them (a
  handler never taken off, another lobby's messages taken for ours, a
  wait without its timeout, a host leaving as a player, an empty NAT
  address, no wait between reconnects, a connection never given up on,
  the unsent tail dropped, the reconnect event lost). One path that
  could not be reached on loopback (a connection made at once) was
  folded into the other.

## Decisions, second round (2026-11-05)

11. **The message codec is an option** (`codec`, `protocol.lua` by
    default), as in the server, so question Q-1 can be answered by a codec
    over 803's message layer without touching the library.
12. **The tests find their project** from their own path when given none
    and end with a `Tests: N passed, M failed` line, so
    `src/cli/run-tests.sh` runs and counts them.

The library's tests are 69 checks now (two for the codec).
