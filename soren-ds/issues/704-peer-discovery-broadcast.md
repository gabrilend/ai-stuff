# 704 — Peer discovery broadcast

## Current behavior

The device has an IP address (703) but no way to find other
devices on the same network. Without discovery, sending a
message requires the sender to know the recipient's IP
beforehand — impractical for the use case.

## Intended behavior

Every device broadcasts a small "I am here, my name is X" UDP
datagram to the IP broadcast address (`169.254.255.255`) every
few seconds (the default cadence is 5 seconds). The datagram
contains:

- The device's chosen friendly name (from `/settings/name`,
  defaulting to a short hash of the MAC if not set).
- The device's MAC.
- The device's IP.
- A monotonically-increasing sequence number.
- A protocol version field for future-proofing.

Every device also listens on the same broadcast port. When a
broadcast arrives:

1. Parse the datagram. Drop malformed or wrong-protocol-version
   datagrams.
2. Look up the announcing MAC in the peer table (705). If
   present, update its last-seen timestamp and refresh its IP
   (it may have moved). If new, add it.
3. Emit a `peer-discovered` event downstream so apps can react
   (the messenger uses this to populate its peer list, the
   address book sees a new peer arrive).

Discovery is best-effort. Broadcasts can be lost; consumers see
"we haven't heard from this peer in too long" through the aging
mechanism (705), not through explicit "peer-gone" announcements.
A device that wants to gracefully announce its departure
broadcasts a final "I am leaving" variant before turning off the
radio.

The broadcast is unencrypted and unauthenticated at the radio
level — anyone in range knows the device exists. This is
intentional; the alternative (cryptographically authenticated
discovery) requires a key exchange protocol that doesn't fit
the "two devices in a room" use case.

## Suggested implementation steps

1. The broadcast datagram format documentation in
   `notes/networking/000-discovery-format.md`.
2. `discovery_broadcast_box()` — fires every 5 seconds.
3. `discovery_receive_box()` — handles incoming datagrams.
4. `peer-discovered` event box.

## Related documents

- `docs/006-transport-and-networking.md`.

## Blocked by

703.

## Blocks

705, 709.
