# 709 — Transport abstraction

## Current behavior

The radio (702–705) and USB-C virtual ethernet (706) both carry
IP packets, both have peer tables, and both speak UDP. But apps
above this layer should not have to choose between them — an app
should name a peer by friendly name, and the system should pick
whichever transport currently reaches that peer.

## Intended behavior

A small `transport_t` abstraction sits above the radio and the
USB-C IP stack:

- `transport_send(peer_name, port, bytes)` — send to a peer's
  named UDP port. The implementation:
  1. Looks up the peer in the table (705) by name.
  2. Walks the peer's transports in priority order — USB-C
     before radio if both reachable (USB-C is higher
     bandwidth and lower latency).
  3. Sends the UDP datagram through the picked transport's IP
     send path.
  4. If neither transport is reachable, returns an error.
- `transport_receive_box(port)` — a soramech receive box for
  named ports. Datagrams arriving on the named port from any
  transport fire the box with the bytes and the originating
  peer's friendly name as the inputs.

Apps express their networking as boxes wired against
`transport_send` and `transport_receive_box`. The messenger
sends through the abstraction; rmail (710) sits on top. Nothing
above this layer mentions WiFi or USB-C by name.

A transport switch — the user unplugs the USB cable while a
conversation is mid-stream — is invisible to the app. The peer
table's `peer-state-changed` event fires when the USB-C
transport's last-seen ages out; subsequent sends to the same
peer fall through to the radio transport. The app sees no
notification; outgoing messages just keep flowing.

## Suggested implementation steps

1. `struct transport_t` — fields recording each transport's
   reachability per peer.
2. `transport_send()`, `transport_receive_box()`.
3. Priority resolution helper (USB-C first when reachable).
4. Nothing to register — the transport boxes are box sources like any
   others, catalogued by the generator because of where they live.

## Open questions

- *Blocked by 706 and 707?* The cable is not a USB Ethernet adapter yet,
  and its mass storage is not this issue's concern.
- *What is "reachable"?* The peer table has alive, stale and gone.
- *From which port of ours?*
- *How does a box in an app's map come to hear a port?* A map has no
  syntax for "bind this station to port 6000".
- *A datagram from a device the table does not know?*
- *Retries, queueing, acknowledgements?*

### Proposed answers (UNVERIFIED)

Each one is Claude's call, open for Ritz.

1. *Built on the STAND-IN LINK* (`src/system/115-link.h`).
   - The cable is link 1 of the seam. On the twin the test plays it; on
     the device it says "no link" until 706.
   - 707 (mass storage) does not touch this layer.
2. *The cable before the radio, alive before stale:* cable-alive,
   radio-alive, cable-stale, radio-stale; gone is no route. A link of
   ours with no address is no route either. So an unplugged cable ages
   to stale and the next send goes by radio, without the app being told.
3. *The same port as the destination,* so a reply goes back to where the
   message came from without a second number.
4. *In C, by whoever starts the app,* as `net_start` and `peers_start`
   are: `transport_listen(port, station, in_port)` binds a station of the
   `received` box (or any box taking a `struct message`). Binding from
   the map itself is left for when maps grow a word for it.
5. *Dropped and counted.* A message is handed on with its sender's name,
   and an unannounced device has none.
6. *None here:* one datagram per send, up to 1 472 bytes. Retries and
   acknowledgements are rmail's (710).

The box-side types (`struct outgoing`, `struct message` in
`src/boxes/125-transport.c`) are checked byte for byte against the
system's.

## What happened

Built on 703–705, over the STAND-IN LINK:

- `src/system/124-transport.c` and `.h`: `transport_send`,
  `transport_route`, `transport_listen` and `transport_unlisten`.
- `src/boxes/125-transport.c`: `send_to_peer` and `received`.

`twin/tests/126-test-transport.c` (18 checks):

- Sending by cable while it is alive, by radio once the cable is stale,
  stale-cable-first when both are stale, nowhere when both are gone.
- No route over our own link with no address; no peer for an unknown
  name; too big refused.
- Arrivals by either link named "beta"; an unknown device's dropped.
- `send_to_peer` from a map answering the link, or no such peer.

## Related documents

- `docs/006-transport-and-networking.md` — the peer abstraction
  section.

## Blocked by

703, 704, 705, 706, 707.

## Blocks

710, 711.
