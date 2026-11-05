# Issue 801b: Matchmaking Server Core

**Phase:** 8 - Multiplayer & Networking
**Type:** Implementation
**Priority:** Critical
**Dependencies:** Issue 801a (protocol specification)
**Parent:** Issue 801 (Matchmaking Server)
**Blocks:** 801h (the integration tests), 801c, 801d, 801f, 801g

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

- [x] Server starts and listens on configured port
- [x] Accepts multiple concurrent client connections
- [x] Lobbies created successfully
- [x] Clients can join lobbies
- [x] Messages routed correctly to lobby members
- [x] Lobby closes when host disconnects
- [x] Stale lobbies cleaned up after timeout
- [x] Handles client disconnects gracefully
- [x] Statistics accurate and up-to-date
- [x] No memory leaks (lobbies properly garbage collected)

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

---

## Decisions (2026-11-05)

Made without the owner, each one theirs to overturn. Question Q-1
(`issues/CRITICAL-PATH.md`: should matchmaking reuse 803's message layer?)
is still open and could reshape this along with 801a.

1. **LuaSocket underneath, kept to one layer.** The issue names it, and it
   is the well-known library already on the machine (nothing installed).
   The core knows connections only as numbers and bytes, so every rule is
   tested without a network; `start`/`tick`/`stop` put LuaSocket under it
   and load it only when called. One `select()` a tick; `epoll` (the
   issue's note) waits until a server needs more than the 1,000
   connections `select()` allows (`max_connections`).
2. **Loopback unless told:** the default `bind` is `127.0.0.1:8080`; a
   public server says `0.0.0.0:PORT` itself.
3. **Registering answers with a JOIN_ACK** (the new game id, the host as
   its first player), since 801a has no register answer; a refused
   register is a JOIN_REJECT with game id 0. The host's name rides in a
   new optional field, `REGISTER_GAME.host_name` (801a decision 4 allows
   it), "host" when left out.
4. **A connection is in at most one lobby**, as its host or a player.
5. **The server trusts the connection, not the message:** a ready mark,
   chat line or NAT endpoint carries the sender's player id whatever the
   message says. Players mark themselves with LOBBY_UPDATE "ready" or
   "unready"; join and leave events are the server's.
6. **Who hears what:** a joiner gets JOIN_ACK and the others LOBBY_UPDATE
   "join"; a leave goes to those left; ready marks and chat go to every
   member, the sender too, so all see one order; START_GAME from the host
   sends GAME_START to every member with the host's address as the server
   sees it and the port it registered. NAT_PUNCH from a player goes to the
   host, from the host to the player it names, an empty ip filled with the
   sender's address (801d builds on this).
7. **A closing lobby sends UNREGISTER_GAME** to every member left,
   whatever closed it (its host unregistering, leaving or going, the
   timeout, the server stopping).
8. **No countdown here:** the lobby passes through STARTING to
   IN_PROGRESS as GAME_START goes out; a countdown is 801e's. A started
   lobby is no longer listed and refuses joins, and stays until its host
   goes or the timeout.
9. **Stale means quiet:** a lobby with no lobby message (register, update,
   join, leave, ready, chat, start, NAT) for `lobby_timeout_seconds` (an
   hour) is closed; pings keep a connection, not a lobby. A connection
   that sends nothing for `idle_timeout_seconds` (120) is closed, so
   clients ping (801c).
10. **Refusals:** a lobby holds 1 to `max_players_per_lobby` (12); names
    are 1 to 64 bytes; the host may raise or lower `max_players` before
    the start, never below the players there. UPDATE_GAME's `players`
    count is not used: the server counts its own members.
11. **Listing:** waiting games only, by id; the map name matches any part
    in any case, mode and region exactly, `free_slots` at least;
    `max_latency_ms` is ignored here, since only the client can measure it.
12. **What is ignored and what drops:** a message the sender may not send
    (not its lobby, not the host, after the start, a server's message) is
    ignored and logged; bytes that are not a message (801a decision 6),
    more than 50 messages a second beyond a burst of 100, or more than
    4 MiB of unread output close the connection.
13. **`messages_per_second` is the last whole second's count**, so it is
    exact rather than averaged; `players_online` counts connections, and
    `players_in_lobbies` those in lobbies.
14. **The daemon is a small runner, not 801g:**
    `src/cli/matchmaking-serve.lua` listens (`--bind`, port 0 takes a free
    one and prints it), logs to standard error with UTC times, and can stop
    by itself (`--seconds`). Configuration files, status and lobby
    commands stay with 801g.
15. **Socket tests run in a network of their own:** `src/tests/netns.lua`
    reruns the test under `unshare -rn` and switches the loopback on
    through LuaJIT's FFI, so no `ip` command is needed and nothing can
    reach another network; without `unshare` the test fails saying so.

## What happened

- `src/matchmaking/server.lua` (core and socket layer) and
  `src/cli/matchmaking-serve.lua` (the daemon), with info pages;
  `REGISTER_GAME.host_name` added to `protocol.lua`.
- `src/tests/test_matchmaking_server.lua` (109 checks, no network): every
  message's rules and refusals, broken bytes, the rate, output and
  connection limits, both timeouts on a hand-moved clock, the statistics,
  and twenty closed lobbies collected by the garbage collector.
- `src/tests/test_matchmaking_daemon.lua` (30 checks, under `unshare -rn`):
  the daemon on loopback through a whole lobby, fifty connections at once,
  a client sending rubbish, its log and options; the socket layer in the
  test's own process, a message cut in two, more output than the socket
  takes at once, and `stop()` telling the members.
- `test_matchmaking_protocol.lua`: 3 more checks for the host's name (188).
- Both new tests are in `run-net-tests.sh`; every net test passes but
  `test_net_hosted`, which needs effil and failed the same before.
- Mutation check: 36 mutants of the server and daemon, run with
  `ulimit -f`. All 36 are caught, two of them (a partly sent message's
  tail dropped, one connection accepted a tick) only after checks were
  added for them.
