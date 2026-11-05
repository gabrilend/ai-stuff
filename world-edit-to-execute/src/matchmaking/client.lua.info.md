# client.lua

The matchmaking client library (issue 801c): what a game uses to reach the
matchmaking server (`server.lua`). Event-driven and non-blocking: the game
calls `conn:poll()` once a frame, and what arrived fires the handlers set
with `:on(event, fn)` (`:off(event, fn)` takes one away). Two layers, as in
the server: a core that knows the server only as bytes, and a LuaSocket
layer under it.

**Connecting**

- **`client.connect(options) -> conn`**, or nil and why: the one call that
  waits, up to `timeout` ms. Options over `client.DEFAULTS`: `host`
  ("127.0.0.1"), `port` (8080), `timeout` (5000 ms, also how long a call
  waits for an answer), `name` ("player", joined and hosted under),
  `ping_interval` (30 s), `reconnect` (true), `reconnect_min` (1 s) and
  `reconnect_max` (30 s); also `clock`, `log` (a function taking a line) and `codec`
  (`encode`, `read_frame`; `protocol.lua` by default, the seam for question
  Q-1, as in the server).
  An unknown option, or one of the wrong kind, is refused.
- **`conn:poll(wait)`**: once a frame; waits up to `wait` seconds (default
  0), reads, handles, writes what the socket will take (keeping the rest),
  pings, and reconnects when it is time.
- **`conn:disconnect()`**: ends it for good: the lobby closes, no reconnect.
- **`conn.state`**: "connecting", "connected", "disconnected", "closed".
- **Events:** `disconnect(why)`, `reconnect()`, `pong(latency_ms)`.
  `conn.latency_ms` is the last ping's round trip.

**Asking.** Each takes an optional callback: given one, it returns at once
and the callback gets the answer (or nil and why); without one, it waits
for the answer and returns it (or nil and why).

- **`conn:list_games(filter, cb) -> games`**: the waiting games; `filter`
  any of `map_name` (any part, any case), `game_mode`, `region`,
  `free_slots`, `max_latency_ms` (passed on; nothing measures a game's
  latency yet). Each game: `game_id` (also `id`), `map_name`, `map_hash`,
  `asset_packs`, `game_mode`, `region`, `players`, `max_players`.
- **`conn:create_lobby(game, cb) -> lobby`**: hosts one. `game`: `map_name`,
  `map_hash`, `asset_packs` (default none), `max_players`, `game_mode`,
  `region`, `host_port` (default 6112), `host_name` (default the
  connection's name).
- **`conn:join_game(game, name, cb) -> lobby`**: `game` an id or a listed
  game; `name` defaults to the connection's.
- **`conn:ping()`**: a ping now (the keepalive sends one every interval).

A connection is in at most one lobby: asking for a second raises.

**The lobby**

- **Fields:** `game_id`, `player_id` (ours), `is_host`, `state` ("opening",
  "waiting", "in_progress", "closed"), `players` (`player_id`, `name`,
  `ready`), `host_id` (the host's player id: always the first player),
  `game` (the game it was opened or joined from, when known),
  `host_connection` once started.
- **`lobby:send_chat(text)`**, **`lobby:set_ready(bool)`**,
  **`lobby:leave()`** (a host's lobby is unregistered),
  **`lobby:start_game()`** and **`lobby:set_max_players(n)`** (the host
  only; raise otherwise), **`lobby:punch(ip, port, player_id)`** (a NAT
  endpoint, issue 801d: a player's goes to the host, the host's to the
  player named; an empty or missing ip asks the server to fill in the
  address it sees), **`lobby:get_players()`**,
  **`lobby:get_host_connection() -> {ip, port}`**, and (801e)
  **`lobby:kick(player_id)`** and **`lobby:cancel_start()`** (the host
  only), **`lobby:starting_in() -> seconds`** (nil with no countdown),
  **`lobby:missing_packs(have) -> list`** (801f: the lobby's packs not in
  `have`, `{ [id] = hash }` or a registry of `packs.lua`, each `{ id,
  hash, from = "mirror" or "host", size }`; nil and why when joined by id
  alone).
  Sending in a lobby that
  is not waiting or in progress raises.
- **Events:** `player_join(player)`, `player_leave(player, how)` (as it
  was before it left; how is "left" or "kicked"), `countdown(seconds)`,
  `countdown_cancel(player)` (who stopped it), `player_ready(player, ready)`, `chat(player, text)`,
  `game_start({ip, port})` (where the host is), `nat_punch({player_id, ip,
  port})`, `asset_packs({contact, packs})` (801f: the lobby's packs the
  server's mirror holds; also kept as `lobby.mirror`), `closed(why)`: "left", "kicked by the host", "the lobby closed" (its host closed it
  or the server timed it out) or "disconnected".

**The core**, for tests and other transports: **`client.new(options)`** (a
connection with no socket; `options.pump(wait)`, if given, moves bytes when
a call waits), **`conn:feed(bytes)`** (what arrived; bytes that are not a
message drop the connection), **`conn:output() -> bytes`** (what to send,
taken), **`conn:lost(why)`** (the connection went: answers waited for
fail, the lobby closes, `disconnect` fires, a reconnect is planned),
**`conn:tick()`** (the keepalive), **`conn:wait(done)`**.

After a reconnect the server has forgotten the old lobby (game ids
change), so the game opens or joins again.
