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
4. Wire the box surface into 208's descriptor table.

## Related documents

- `docs/006-transport-and-networking.md` — the peer abstraction
  section.

## Blocked by

703, 704, 705, 706, 707.

## Blocks

710, 711.
