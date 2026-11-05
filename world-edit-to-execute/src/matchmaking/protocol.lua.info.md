# protocol.lua

The matchmaking messages between hosts, joining players and the matchmaking
server, as bytes (issue 801a). The wire: magic `0x5743` ("WC"), the type
(two bytes), the payload's length (four), all in network byte order, then
a MessagePack map of the fields plus `v`, the protocol's version. Each
message's fields are described once in `protocol.FIELDS`.

| Type | Message | Fields |
|---|---|---|
| 0x01 | REGISTER_GAME | map_name, map_hash, asset_packs (id, hash), max_players, game_mode, region, host_port |
| 0x02 | UNREGISTER_GAME | game_id |
| 0x03 | UPDATE_GAME | game_id, players, max_players |
| 0x04 | LIST_GAMES | any of map_name, game_mode, region, max_latency_ms, free_slots |
| 0x05 | GAME_LIST | games (game_id, map_name, map_hash, asset_packs, game_mode, region, players, max_players) |
| 0x06 | JOIN_GAME | game_id, player_name |
| 0x07 | JOIN_ACK | game_id, player_id, players (player_id, name, ready) |
| 0x08 | JOIN_REJECT | game_id, reason |
| 0x09 | LEAVE_GAME | game_id |
| 0x0A | LOBBY_UPDATE | game_id, event ("join", "leave", "ready", "unready"), player_id, players |
| 0x0B | START_GAME | game_id |
| 0x0C | GAME_START | game_id, host_ip, host_port |
| 0x0D | NAT_PUNCH | game_id, player_id, ip, port |
| 0x0E | CHAT_MSG | game_id, player_id, text |
| 0x0F | PING | nonce |
| 0x10 | PONG | nonce |

Numbers are whole, 0 to 2^32-1; text is at most `MAX_TEXT` (1024) bytes; a
list at most `MAX_LIST` (4096) records; a payload at most `MAX_PAYLOAD`
(1 MiB).

- **`protocol.encode(name, message) -> bytes`**: refuses an unknown
  message, a missing field, a field the description lacks, the wrong kind,
  a number out of range or not whole, text or a list too long, a payload
  past the limit, or a `v` that is not this version.
- **`protocol.decode(bytes) -> name, message`**: one whole message;
  refuses a wrong magic, an unknown type, a length past the limit, bytes
  cut short or left over, a payload that is not a MessagePack map, another
  version, and a missing or wrong field. A field it doesn't know is
  dropped, so a later version may add optional fields.
- **`protocol.read_frame(buffer) -> name, message, rest`**: the first
  message off a stream, or `nil, nil, buffer` while it hasn't all come.
- **`protocol.frame_length(bytes)`**: a message's whole length once its
  header has come (nil before); raises on a bad header, so a stream gone
  wrong is dropped before its payload is waited for.
