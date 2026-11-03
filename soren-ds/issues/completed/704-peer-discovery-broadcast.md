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

## Open questions

- *Blocked by 703?* It is in #233, on the stand-in link.
- *Which port, and what exactly is in the datagram?*
- *Where does the name come from?* `/settings/name` (408) is in #48,
  unmerged.
- *Keyed by MAC or by name?* This issue looks peers up by hardware
  address, while 705 keys the table by name. A peer on two links has two
  hardware addresses.
- *What is dropped as malformed?*
- *What does the sequence number do?*
- *What drives the five-second cadence?*

### Proposed answers (UNVERIFIED)

Each one is Claude's call, open for Ritz.

1. *Built on 703, over the STAND-IN LINK* (`src/system/115-link.h`); on
   the device nothing is heard until 701/702.
2. *Port 47100, 56 bytes*, laid out in
   `notes/networking/000-discovery-format.md`: magic, version, kind
   (here or leaving), sequence, hardware address, IP, and a name of up
   to 31 bytes.
3. *`peers_set_name` for now.* Until it is called, the name is `soren-`
   and four hex digits of the radio's hardware address. 408 will call
   it from `/settings/name`.
4. *By name.* A name heard on two links is one peer reached two ways.
   Two devices with one name are not told apart; the table follows the
   last one heard and counts it (`name_moved`).
5. *Anything that does not match the format exactly is dropped:*
   - shorter than 56 bytes;
   - an unknown magic, version or kind;
   - an empty name, or one with no zero inside its 32 bytes;
   - an announcement naming a hardware address or IP other than the one
     it came from.

   The device's own announcements, heard back, are ignored.
6. *It counts missed announcements; it never drops anything.* A device
   that reboots starts again from 1 and must still be heard.
7. *The peers map's once-a-second tick* announces when five seconds have
   passed since an announcement reached any link. A link that has only
   just taken its address is announced on at the next tick. Hearing
   comes through the net poll (703) by a C listener, not through boxes.

`peer-discovered` is a `struct peer_event` delivered to every subscribed
station (705), and `say_peer` is a box that says each one.

## What happened

Built with 705; see there.

## Related documents

- `docs/006-transport-and-networking.md`.

## Blocked by

703.

## Blocks

705, 709.
