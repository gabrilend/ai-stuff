# Issue 801a: Matchmaking Protocol Specification

**Phase:** 8 - Multiplayer & Networking
**Type:** Design/Implementation
**Priority:** Critical
**Dependencies:** None (foundation for all other 801 sub-issues)
**Parent:** Issue 801 (Matchmaking Server)

---

## Current Behavior

No matchmaking protocol exists. We need to define the wire format and message types for host-server and client-server communication.

## Intended Behavior

A well-defined binary protocol that supports:
1. Game registration and discovery
2. Lobby join/leave operations
3. NAT traversal endpoint exchange
4. Lobby chat
5. Game start coordination

### Wire Format

```
Header (8 bytes):
  [2 bytes] Magic: 0x5743 ("WC")
  [2 bytes] Message Type
  [4 bytes] Payload Length

Payload:
  [variable] MessagePack-encoded data
```

### Message Types

| ID | Name | Direction | Purpose |
|----|------|-----------|---------|
| 0x01 | `REGISTER_GAME` | Host → Server | Create lobby |
| 0x02 | `UNREGISTER_GAME` | Host → Server | Close lobby |
| 0x03 | `UPDATE_GAME` | Host → Server | Update lobby state |
| 0x04 | `LIST_GAMES` | Client → Server | Query available games |
| 0x05 | `GAME_LIST` | Server → Client | List of games |
| 0x06 | `JOIN_GAME` | Client → Server | Join specific lobby |
| 0x07 | `JOIN_ACK` | Server → Client | Join accepted |
| 0x08 | `JOIN_REJECT` | Server → Client | Join rejected |
| 0x09 | `LEAVE_GAME` | Client → Server | Leave lobby |
| 0x0A | `LOBBY_UPDATE` | Server ↔ All | Player join/leave/ready |
| 0x0B | `START_GAME` | Host → Server | Begin game |
| 0x0C | `GAME_START` | Server → All | Game starting |
| 0x0D | `NAT_PUNCH` | Server ↔ All | Exchange external endpoints |
| 0x0E | `CHAT_MSG` | Client ↔ All | Lobby chat |
| 0x0F | `PING` | Client ↔ Server | Keepalive |
| 0x10 | `PONG` | Server ↔ Client | Keepalive response |

## Suggested Implementation Steps

1. Create `src/matchmaking/protocol.lua`
2. Implement message encoding/decoding functions
3. Define message structure for each type (MessagePack schemas)
4. Create validation functions (check required fields, types)
5. Write protocol documentation
6. Create unit tests for encoding/decoding
7. Add protocol versioning support

## Acceptance Criteria

- [ ] All message types defined with clear structures
- [ ] Encoding functions work for all message types
- [ ] Decoding functions work for all message types
- [ ] Invalid messages rejected with clear error messages
- [ ] Protocol documentation complete
- [ ] Unit tests pass (100% coverage of message types)
- [ ] Protocol version field included for future compatibility

## Related Documents

- Issue 801 - Matchmaking Server (parent)
- Issue 801b - Server core (consumer of protocol)
- Issue 801c - Client library (consumer of protocol)

## Notes

- Use MessagePack for payload encoding (efficient, cross-language)
- Keep protocol simple and extensible
- Consider forward/backward compatibility from the start
- Magic number 0x5743 ("WC") helps identify protocol packets
