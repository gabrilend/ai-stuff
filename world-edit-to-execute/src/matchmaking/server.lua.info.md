# server.lua

The matchmaking server's core (issue 801b): the open lobbies, kept in
memory, and the answers to every message of `protocol.lua`. Two layers: a
core that knows connections only as numbers and bytes (tested with no
network), and a socket layer that puts LuaSocket under it, every
connection non-blocking, one `select()` a tick. LuaSocket is loaded only by
`start()`.

- **`server.new(config) -> server`:** settings over `server.DEFAULTS`
  (an unknown setting or one of the wrong kind is refused): `bind`
  ("127.0.0.1:8080"), `max_lobbies` (1000), `max_players_per_lobby` (12),
  `max_connections` (1000; `select()` takes at most 1024 sockets),
  `lobby_timeout_seconds` (3600), `idle_timeout_seconds` (120),
  `rate_per_second` (50) and `rate_burst` (100) messages, `max_output_bytes`
  (4 MiB unsent), `max_name` (64 bytes). Also `clock` (seconds) and `log`
  (a function taking one line), and `codec` (`encode`, `read_frame`;
  `protocol.lua` by default: the seam for question Q-1, should matchmaking
  speak 803's message layer).

The core:

- **`server:accept(ip, port) -> id`**, or nil past `max_connections`.
- **`server:receive(id, bytes) -> kept`:** handles every whole message;
  false when the connection was closed for them (not a message, too many,
  output not read).
- **`server:output(id) -> bytes`:** what waits to be sent, taken.
- **`server:close(id, why)`:** ends a connection; a host's lobby closes.
- **`server:sweep()`:** closes connections silent past the idle timeout
  and lobbies with no lobby message past the lobby timeout.
- **`server:stats()`:** `lobbies_active`, `players_online` (connections),
  `players_in_lobbies`, `messages_per_second` (those of the last whole
  second), `uptime_seconds`, and the counts `messages_in`, `messages_out`,
  `bytes_in`, `bytes_out`, `connections`, `lobbies_created`,
  `lobbies_closed`, `dropped`, `ignored`, `refused_connections`.
- **`server:lobby_list()`:** a copy of every lobby: id, map, mode, region,
  `state` ("waiting", "in_progress"), host address, players.

The socket layer: **`server:start()`** (port 0 takes a free one; raises if
it can't listen), **`server:address() -> ip, port`**, **`server:tick(wait)`**
(waits up to `wait` seconds, then accepts, reads, writes, sweeps),
**`server:stop()`** (tells every lobby's members it closed, then closes
everything).

Who may do what:

| Message in | From | Answer |
|---|---|---|
| REGISTER_GAME | a connection in no lobby | JOIN_ACK (new game id, the host as player 1), or JOIN_REJECT with game id 0 |
| UNREGISTER_GAME | the host | UNREGISTER_GAME to every member, the host too |
| UPDATE_GAME | the host, before the start | none; `max_players` changes (not below the players there) |
| LIST_GAMES | anyone | GAME_LIST of waiting games, by id; map name matches any part, any case; `max_latency_ms` is the client's to apply |
| JOIN_GAME | a connection in no lobby | JOIN_ACK to it, LOBBY_UPDATE "join" to the others; or JOIN_REJECT |
| LEAVE_GAME | a member | LOBBY_UPDATE "leave" to the others; the host leaving closes the lobby |
| LOBBY_UPDATE "ready"/"unready" | a member, before the start | LOBBY_UPDATE to every member; the player is the sender |
| START_GAME | the host, once | GAME_START to every member: the host's address as seen here, its registered port |
| NAT_PUNCH | a member | to the host (from a player) or the named player (from the host), the sender's id stamped, an empty ip filled with the sender's address |
| CHAT_MSG | a member, not empty | CHAT_MSG to every member, the sender's id stamped |
| PING | anyone | PONG with its nonce |

Anything else a client may send is ignored and logged; GAME_LIST,
JOIN_ACK, JOIN_REJECT, GAME_START and PONG are the server's to send. A
closing lobby sends UNREGISTER_GAME to every member left.
