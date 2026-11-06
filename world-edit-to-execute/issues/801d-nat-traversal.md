# Issue 801d: NAT Traversal System

**Phase:** 8 - Multiplayer & Networking
**Type:** Implementation
**Priority:** High
**Dependencies:** Issue 801a (protocol), Issue 801b (server core)
**Parent:** Issue 801 (Matchmaking Server)
**Blocks:** 801h (the integration tests)

---

## Current Behavior

No NAT traversal mechanism exists. Players behind NAT cannot host games without port forwarding.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #308 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- The "open" test compares the outside address with the socket's own, which is `0.0.0.0` when bound to all addresses, so a machine with no NAT is reported as restricted cone.
- The reflector binds its second socket on the same port as a wildcard main socket, which always fails with "address in use" in the recommended `--bind 0.0.0.0` setup; replies from a two-address host can also come from the wrong address.
- The host ignores a repeated punch request while its own punch is established, so a player whose punch failed can never retry; a moved port also discards a working punch.
- The reflector's sockets aren't in the server's select; the loop instead ticks at 100 Hz while idle (`r:sockets()` exists and is unused).
- The second port is computed as bound+1 with no range check, and `--nat-port` accepts fractions and values above 65535.
- Tokens are `game_id*4096 + player_id`, but player ids come from one counter for the server's life; past 4096 joins, tokens of different games collide, and both ids are public.
- The default token comes from an unseeded random generator, so every client's first detection uses the same token.
- Game data arriving while the receiving side is still "punching" is dropped silently.
- Every datagram is decoded once per punch plus once more.

## Intended Behavior

A UDP hole punching system that enables peer-to-peer connections between:
- Full Cone NAT ↔ Any NAT (easy)
- Restricted Cone ↔ Restricted Cone (medium)
- Port-Restricted Cone ↔ Port-Restricted Cone (hard)
- Symmetric NAT ↔ Symmetric NAT (very hard, may fail)

**Target success rate:** >80% for common NAT types

### How UDP Hole Punching Works

```
HOST (behind NAT)          SERVER              CLIENT (behind NAT)
     │                         │                      │
     ├─── register: 1.2.3.4:X ─▶                     │
     │                         │                      │
     │                         │◀── join: need host ──┤
     │                         │                      │
     │◀──── host at 1.2.3.4:X ─┤                      │
     │                         ├─ client at 5.6.7.8:Y▶│
     │                         │                      │
     ├─── UDP to 5.6.7.8:Y ────┼──────────────────────┤
     │    (creates NAT mapping)│   UDP to 1.2.3.4:X ──┤
     │                         │   (creates NAT mapping)
     │                         │                      │
     │◀────── DIRECT P2P CONNECTION ─────────────────▶│
     │                         │                      │
```

**Key:** Both sides send UDP packets simultaneously, creating NAT mappings that allow direct communication.

### NAT Types and Success Rates

| Host NAT Type | Client NAT Type | Success Rate | Notes |
|---------------|-----------------|--------------|-------|
| Full Cone | Any | 100% | Easiest case |
| Restricted Cone | Restricted Cone | 95% | Very common |
| Port-Restricted | Port-Restricted | 80% | Timing critical |
| Symmetric | Symmetric | 30% | May require relay |

### Implementation Architecture

```lua
-- src/matchmaking/nat.lua

local nat = require("matchmaking.nat")

-- Detect own NAT type (STUN-like)
local nat_type = nat.detect_type({
    stun_server = "stun.l.google.com:19302"
})
-- Returns: "full_cone", "restricted_cone", "port_restricted", "symmetric", "open"

-- Initiate hole punch (host side)
local punch = nat.create_punch({
    remote_ip = "5.6.7.8",
    remote_port = 54321,
    local_port = 6112,
})

-- Send keepalive packets
while not punch:established() do
    punch:send_probe()
    sleep(0.1)
end

-- Connection established!
local udp_socket = punch:get_socket()
```

## Suggested Implementation Steps

1. Create `src/matchmaking/nat.lua`
2. Implement STUN-like NAT type detection
   - Send UDP packets to external server
   - Observe which packets get through
   - Classify NAT type based on results
3. Implement UDP hole punch coordinator (server-side)
   - Exchange external endpoints between peers
   - Coordinate simultaneous packet sending
4. Implement UDP hole punch client (game-side)
   - Send probe packets to remote endpoint
   - Listen for incoming probes
   - Detect when connection established
5. Add timeout and retry logic
6. Add fallback detection (punch failed)
7. Create test suite with various NAT types (simulated)

## Acceptance Criteria

- [ ] NAT type detection works (tested with public STUN server)
- [ ] Hole punch succeeds for Full Cone ↔ Any (100% in tests)
- [ ] Hole punch succeeds for Restricted Cone ↔ Restricted Cone (>90% in tests)
- [ ] Hole punch succeeds for Port-Restricted ↔ Port-Restricted (>70% in tests)
- [ ] Failure detected within reasonable timeout (5 seconds)
- [ ] Server coordinates endpoint exchange correctly
- [ ] Established connections remain stable (keepalive works)
- [ ] Documentation includes NAT compatibility matrix

## Related Documents

- Issue 801a - Protocol specification (NAT_PUNCH message type)
- Issue 801b - Server core (coordinator)
- Issue 801c - Client library (initiates punch)

## Open Questions

1. **Relay fallback:** If hole punch fails, do we:
   - Reject connection entirely (P2P only)
   - Relay through matchmaking server (expensive)
   - Suggest port forwarding to user

2. **Symmetric NAT:** Do we attempt predictive hole punching (complex, low success rate)?

3. **IPv6:** Should we support IPv6 (no NAT, but may have firewall)?

## Notes

- UDP hole punching is timing-sensitive - both sides must send simultaneously
- Some ISPs/firewalls block this technique (rare, but possible)
- STUN servers are free public infrastructure (Google, Cloudflare provide)
- Consider adding UPnP/NAT-PMP as alternative for compatible routers
- Document user-facing error messages ("Connection failed - check firewall/router")

---

## Decisions (2026-11-05)

Made without the owner, each one theirs to overturn. Question Q-1
(`issues/CRITICAL-PATH.md`) is still open.

1. **Our own reflector, not a public STUN server.** The issue's example
   asks Google's STUN server; nothing here sends anything to an outside
   service, so the matchmaking daemon runs a small UDP reflector of its
   own (`matchmaking-serve.lua --nat-port P`, ports P and P+1, and a
   second address with `--nat-alt-ip`). The players already trust that
   server. Its packets are this module's own, not STUN's (RFC 5389): a
   STUN client is a later piece if the owner wants public servers.
2. **The detection asks four questions** (where am I; answer from your
   other address; answer from your other port; where am I, at your other
   port), the classic order of RFC 3489 with one change: the
   other-port answer is asked before anything is sent to the other port,
   or a port-restricted router passes for a restricted one. Without a
   second address a full cone reads as restricted (they punch alike).
3. **No relay** (open question 1): a punch that fails is reported within
   five seconds and the game says so ("Couldn't reach the host directly.
   One of you may need to forward a port on the router."). Relaying
   through the matchmaking server costs its bandwidth and is the owner's
   call.
4. **No port prediction for symmetric routers** (open question 2). A
   symmetric side still opens with any cone that isn't port-restricted,
   because the punch moves to the port the other side's probes really
   come from. Symmetric with symmetric or port-restricted fails, as the
   issue expects.
5. **IPv4 only** (open question 3): the packets carry four-byte
   addresses; an IPv6 path would need its own kind of BOUND.
6. **Endpoints, not sockets.** Every piece works on anything with `send`,
   `receive` and `local_address`, so the same code runs on LuaSocket UDP
   (`nat.udp`) and on the simulated routers of `src/tests/natsim.lua`,
   where every kind of NAT can be tried in one run with no network.
7. **Open on an answer, not on a probe.** A side counts the path open when
   an ACK to its own probe comes back (both ways work), not when the
   other side's probe arrives (only one way known).
8. **Tokens keep punches apart:** each punch's packets carry a token made
   from the game id and the player's id, so the host's punches to several
   players share one UDP socket, and a stray or old packet is ignored.
9. **Keepalive every 15 s, lost after 45 s of silence.** Home routers
   commonly forget a UDP mapping after 30 s or more; the simulation's
   lapse at 30 s is kept open by the keepalives. A lost path keeps
   sending keepalives and is open again when heard.
10. **The endpoints travel in the existing NAT_PUNCH message** (801a,
    801b): no new matchmaking message. A player without a detected
    address sends an empty one and the server fills in the address it
    sees; the port is then the socket's own, right for an open machine or
    a router that keeps ports.
11. **The packets are separate from the matchmaking messages** because
    they ride UDP, not the TCP stream: if Q-1 brings in 803's message
    layer, only `nat.encode` and `nat.decode` would change.

## What happened (2026-11-05)

- `src/matchmaking/nat.lua` with its info page (the packets, the
  detection's questions, the punch, the lobby session, and the table of
  which kinds of NAT punch through).
- `src/cli/matchmaking-serve.lua` runs the reflector with `--nat-port P`
  (and `--nat-alt-ip IP`), printing `nat IP PORT ALT_PORT`.
- `src/tests/natsim.lua`: simulated routers of every kind, with mapping
  lapses and seeded loss.
- `src/tests/test_matchmaking_nat.lua` (116 checks, no network): packets;
  the reflector; every kind detected, within five seconds, through 30%
  loss; the punch for all 25 pairs of kinds (symmetric with symmetric or
  port-restricted fails within 5 s, every other pair opens in under a
  second); rates at 20% loss (full cone with any kind: all; restricted
  pairs and port-restricted pairs: 100% of 20 runs each, against the
  issue's 90% and 70%); 90 s of keepalives holding 30 s mappings open;
  lost after 45 s of silence and back when heard; a lobby's session
  through the matchmaking server's core with three and four players.
- `src/tests/test_matchmaking_nat_net.lua` (13 checks, under
  `unshare -rn`, against the daemon): the reflector over real UDP, from
  its second address and port; this machine found open; blocked where
  nothing answers; a host and a player punching through each other over
  real UDP via the server, and game datagrams both ways.
- Both are in `run-net-tests.sh`, and `src/cli/run-tests.sh -d DIR
  matchmaking` runs and counts them.
- Mutation check: 46 mutants of `nat.lua` and the daemon's reflector
  lines, with `ulimit -f`. All 46 are caught, seven of them only after
  checks were added (half the "WN" mark, an address part of 256, a game
  datagram bringing a lost path back, a failed punch still answering,
  tokens alike for two players, data put down to the wrong player, a
  closed session still listening). A 47th, the 32-bit wrap in `u32`, was
  equivalent (every byte is already taken modulo 256); the redundant line
  was removed.

**Left for the owner:** the acceptance check "tested with public STUN
server" needs a STUN (RFC 5389) client and a datagram to an outside
service, neither done here; the three open questions (relay, symmetric
prediction, IPv6) are answered "no" for now in the decisions above. So the
issue stays open.
