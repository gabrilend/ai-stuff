# 703 — Link-local IP addressing

## Current behavior

The radio is associated in IBSS mode (702) but the device has no
IP address. Without one, packets above the link layer have
nowhere to come from or go to.

## Intended behavior

The device picks a link-local IPv4 address in the `169.254.x.x`
range using the standard automatic-private-IP-addressing dance:

1. Pick a candidate address randomly from the link-local pool.
   The seed for the random pick is the device's MAC so the
   first guess is consistent across reboots; subsequent guesses
   are randomised.
2. Send a few ARP probes for the candidate. If any peer
   responds claiming the address, pick another candidate and
   re-probe.
3. After a few probes without conflict, claim the address by
   sending an ARP announcement.
4. Configure the IP stack with the chosen address and a
   `/16` netmask.

The IP stack itself is small: just enough to handle the ARP
exchange, the IP header parsing, and the UDP transport rmail
will run over (no TCP at launch — UDP plus rmail's own
acknowledgement layer is sufficient). The IP stack also runs
over the USB-C virtual ethernet adapter (706) using the same
IPv4 protocol logic and a different MAC.

The stack delivers received UDP datagrams into a soramech
receive-port box keyed by destination port. Outgoing UDP
datagrams are sent through the matching transport (radio or
USB-C, whichever has a route to the destination).

## Suggested implementation steps

1. `pick_link_local()` — MAC-seeded random pick.
2. `arp_probe()`, `arp_announce()`.
3. Minimal IP / UDP stack — header parse, checksum, dispatch.
4. `udp_receive_port` and `udp_send` boxes.

## Related documents

- `docs/006-transport-and-networking.md`.

## Blocked by

702.

## Blocks

704, 709.
