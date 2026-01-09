# Issue 801d: NAT Traversal System

**Phase:** 7 - Multiplayer & Networking
**Type:** Implementation
**Priority:** High
**Dependencies:** Issue 801a (protocol), Issue 801b (server core)
**Parent:** Issue 801 (Matchmaking Server)

---

## Current Behavior

No NAT traversal mechanism exists. Players behind NAT cannot host games without port forwarding.

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
