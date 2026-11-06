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

## Open questions

- *Blocked by 702?* There is no radio yet.
- *One address for the device, or one per link?*
- *What timings, and what range?* The issue says "a few probes".
- *What happens when our address is challenged after we have it?*
- *What happens to a datagram for an address whose hardware address is
  not known yet?*
- *How do listeners hear?* The issue names a `udp_receive_port` box keyed
  by port.
- *What drives it?* Frames arrive whenever they like; boxes run when
  values arrive.

### Proposed answers (UNVERIFIED)

Each one is Claude's call, open for Ritz.

1. *Not on the twin, through a STAND-IN LINK.* `src/system/115-link.h`
   is a seam of four calls (`link_up`, `link_address`, `link_send`,
   `link_receive`) for two links, the radio and the cable.
   - The twin answers with queues a test plays the far end through
     (`twin/117-link-twin.c`): it is not a radio and not a cable.
   - The device answers "no link" (`src/device/116-link-device.c`) until
     701/702 and 706.
   - Everything above is the same code on both.
2. *One per link,* each claimed on its own, as RFC 3927 does per
   interface.
3. *RFC 3927's.*
   - The range is 169.254.1.0 – 169.254.254.255.
   - The first guess is an FNV-1a hash of the hardware address, so it is
     the same after every boot. Later guesses come from a per-link
     generator seeded from `platform_entropy` and the address.
   - Probing: 3 probes, the first within a second, 1–2 s apart.
   - Announcing: wait 2 s, then 2 announcements 2 s apart. The address is
     usable from the first announcement.
   - After 10 conflicts, one guess a minute.
4. *Defend once, give up on a second challenge inside ten seconds* (the
   RFC's middle choice), then guess again.
5. *Ask and answer `NET_RESOLVING`; queue nothing.* The sender tries
   again, and rmail's own acknowledgements (710) cover a loss.
   Addresses are learned from every ARP frame and every datagram heard,
   so a peer that has spoken is already known. `net_udp_send_to` takes a
   hardware address the caller already has (the peer table's, 705).
6. *A station's port, or a C function for the system's own listeners*
   (discovery, 704); one listener per port. Each datagram arrives as a
   `struct net_datagram`: sender, ports, link, whether it was broadcast,
   and up to 1 472 bytes. The app-facing boxes are 709's, which names
   peers instead of addresses, so nothing above it handles an IP
   address.
7. *A poll on its own timer:* `src/maps/net.map` calls `net_poll` every
   10 ms, one poll at a time on a loop, like the input and compositor
   frames. `net_poll` takes the clock as an argument, so a test runs ten
   seconds of probing at once. Nothing starts the map at boot yet.

The stack sends IPv4 without options, with "don't fragment" and a time
to live of one hop. It accepts options but drops fragments. It checks
both checksums and drops anything that does not add up. Unicast is
accepted only once the address is ours; broadcast is accepted any time.

## What happened

Built on the twin as answered above. The seam:

- `src/system/115-link.h`.
- `src/device/116-link-device.c`.
- `twin/117-link-twin.c` and `.h`.

The stack:

- `src/system/118-net.c` and `.h`.
- `src/boxes/119-net.c`.
- `src/maps/net.map`.

`twin/tests/120-test-link-local.c` (37 checks), playing the far end of
the stand-in on the test's own clock:

- No link, no address.
- Claiming the first guess: three probes 1–2 s apart, two announcements.
- A conflict, from an answer or from another prober, moves to a new
  guess.
- We answer who-has for our address.
- One challenge is defended; two inside ten seconds give the address up.
- Datagrams reach a listening box whole. Bad checksums, a fragment,
  other addresses and unheard ports are dropped.
- Sending to everyone, to a known address, and to an unknown one, which
  is asked for first.
- The payload limit.
- The one-a-minute wait after ten conflicts.
- The net map polling on its own timer.

## Related documents

- `docs/006-transport-and-networking.md`.

## Blocked by

702.

## Blocks

704, 709.
