# Issue 801a: Matchmaking Protocol Specification

**Phase:** 8 - Multiplayer & Networking
**Type:** Design/Implementation
**Priority:** Critical
**Dependencies:** None (foundation for all other 801 sub-issues)
**Parent:** Issue 801 (Matchmaking Server)
**Blocks:** 801h (the integration tests), 801b, 801c, 801d

---

## Current Behavior

No matchmaking protocol exists. We need to define the wire format and message types for host-server and client-server communication.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #304 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- 64-bit whole numbers are summed as floats before the 2^53 check, so a value just past 2^53 is rounded to 2^53 instead of refused (confirmed with the branch's files); the test only tries 2^54+1. Check the high 32 bits first.
- Every port field allows up to 2^32-1, so impossible ports pass the wire check and fail later at connect. Add a port kind (0–65535).
- The lobby event field accepts any text though only four words are allowed; add an allowed-values kind.
- The decoder accepts NaN and infinity, which the encoder refuses; a NaN map key crashes with a raw Lua error that leaks file paths.
- Encode refuses depth >= 32 while decode refuses only > 32, so a decoded value can't be written back.
- The version rule contradicts itself: decode refuses any version other than 1, yet the header says later versions may add optional fields without breaking older readers.
- A map with a repeated key silently keeps the last copy.
- Reading frames from a buffer re-parses each header and copies the whole remaining buffer per message (quadratic on bursts).
- Functions lack their own folds; the decoder is a 30-branch if/else chain where a table indexed by type byte would do.

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

---

## Decisions (2026-11-05)

Made without the owner, each one theirs to overturn.

1. **MessagePack, written here.** The issue chose it; no MessagePack
   library is in the project and nothing is installed, so
   `src/matchmaking/msgpack.lua` carries the part needed (nil, booleans,
   numbers, strings, lists, maps). Whole numbers are exact up to 2^53, the
   most a Lua number holds. Map keys are written sorted, so a message
   always gives the same bytes.
2. **The header is in network byte order** (big-endian), so the magic
   0x5743 reads "WC" on the wire, as the issue names it, and matches
   MessagePack's own order.
3. **The version rides in every payload** as the field `v` (1), since the
   issue's header has no room for it. A message of another version is
   refused naming both. Within a version, a field the reader doesn't know
   is dropped, so later versions may add optional fields; encoding
   refuses a field the description lacks, so a misspelt field is caught
   where it is written.
4. **Fields follow issue 801's API.** Registering carries the map's name
   and hash, its asset packs (id and hash), the most players, the game
   mode, the region and the host's game port; the list carries each game's
   id with the same, and the players there. Listing takes any of map name,
   game mode, region, latency and free slots. Joins carry the player's
   name, answers carry a player id and who is in the lobby, a lobby
   update names its event ("join", "leave", "ready", "unready"), game
   start carries the host's address, NAT punching an endpoint, chat a
   line of text, and the keepalive a number echoed back. 801b, 801c and
   801d may add optional fields under decision 3.
5. **Limits:** whole numbers 0 to 2^32-1, text at most 1,024 bytes, a
   list at most 4,096 records, a payload at most 1 MiB (a list of a
   thousand lobbies fits several times over). A header claiming more is
   refused before its payload is waited for, so a stream gone wrong is
   dropped early.
6. **Errors are raised, naming the message and field**, as the gameplay
   messages do (`src/net/messages.lua`); the server and client wrap
   decoding in `pcall` and drop the sender's connection on a refusal.
7. **The documentation is the module's header and its info page**
   (`src/matchmaking/protocol.lua.info.md`, a table of every message's
   fields), as for the gameplay messages, rather than a separate page.

## What happened

- `src/matchmaking/msgpack.lua` and `src/matchmaking/protocol.lua`, each
  with an info page.
- `src/tests/test_matchmaking_protocol.lua` (185 checks), in
  `run-net-tests.sh`: MessagePack against the bytes other programs write
  for each kind of value; all sixteen messages there and back, the same
  bytes again, their headers and versions; three messages on a stream cut
  at every byte; every refusal.
- Mutation check: 58 mutants of the two modules. 56 are caught, three of
  them only after checks were added for the survivors (2^53 written as a
  whole number, a map key of the wrong kind read, a payload past the
  limit written). The other two are equivalent: a negative high half
  written either way gives the same bytes under Lua's modulo, and the
  length's top byte is always 0 under the 1 MiB limit.
