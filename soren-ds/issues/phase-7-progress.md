# Phase 7 progress — Ad-hoc radio, USB transport, rmail

Phase 7 makes the device reachable from outside itself. By the
end of the phase, the WiFi radio is up in IBSS (ad-hoc) mode,
link-local IP addresses are assigned, peer-discovery broadcasts
let devices in the same room find each other, the USB-C cable
presents the device as a virtual ethernet adapter AND a mass
storage device with an inbox/outbox split, the transport
abstraction lets apps name peers instead of transports, and
rmail runs above all of it as the universal "send something to a
peer" layer.

The launch system's messenger (phase 8) sends rmail messages.
The painter (also phase 8) sends rmail attachments. The remote-
file feature sends rmail deliveries to a paired laptop's inbox.
All three use cases drop onto the abstraction layer this phase
builds.


## The story of the phase

1. `701-wifi-controller-bring-up.md` — clocks, power, register
   initialization for the WiFi radio.
2. `702-ibss-mode-and-association.md` — join or create an
   ad-hoc network on a known channel.
3. `703-link-local-addressing.md` — pick a `169.254.x.x`
   address that doesn't collide with any peer we already see.
4. `704-peer-discovery-broadcast.md` — "I am here, my name is
   X" broadcast every few seconds; receive and table peers.
5. `705-peer-table-and-aging.md` — the in-RAM table of known
   peers and their last-seen transports; aging so stale peers
   disappear.
6. `706-usb-c-virtual-ethernet.md` — present the device as a
   USB CDC-NCM (or ECM) ethernet adapter when a laptop is
   plugged in.
7. `707-usb-mass-storage-inbox-outbox.md` — present the
   inbox/outbox directories as a USB MSC volume the laptop
   sees as a drive.
8. `708-usb-inbox-watcher.md` — react when the laptop drops a
   file in the inbox; dispatch to the right app.
9. `709-transport-abstraction.md` — the peer-named send/receive
   surface above WiFi and USB-C-as-IP.
10. `710-rmail-port.md` — rmail recompiled against the
    transport abstraction.
11. `711-phase-7-demo.md` — two devices find each other,
    exchange a message; a laptop joins by USB-C and sees the
    same conversation.

## Completed issues

Built against the **stand-in link**: `src/system/115-link.h` is a seam
of four calls that everything in this phase sends and receives frames
through. On the twin it is two queues per link that a test plays the
far end of (`twin/117-link-twin.c`); on the device it says "no link"
until the radio (701, 702) and the cable (706) are up. It is not a
radio, a cable or a simulation of either.

- **703** a link-local address per link, claimed as RFC 3927 says
  (first guess from the hardware address, three probes, two
  announcements, one defence), and ARP, IPv4 and UDP above it: listeners
  by port, sending to everyone or to an address, asking first when its
  owner is not known. Polled every 10 ms by `src/maps/net.map`.

`src/system/118-net.c`. Test: `twin/tests/120` (37 checks).

- **704** "I am here, my name is X" every five seconds on each link with
  an address (`notes/networking/000-discovery-format.md`), and
- **705** the peer table that hearing it fills: one entry per name, each
  link aging on its own (alive 20 s, stale to 5 minutes, then gone), and
  events to subscribed stations when a peer is found or a link changes.

`src/system/121-peers.c`, ticked once a second by `src/maps/peers.map`.
Test: `twin/tests/123` (28 checks).

- **709** sending to a peer by name over whichever link reaches it (the
  cable before the radio, alive before stale), and hearing a bound port
  with the sender's name. Nothing above it names a link or an address.

`src/system/124-transport.c`, the `send_to_peer` and `received` boxes in
`src/boxes/125-transport.c`. Test: `twin/tests/126` (18 checks).

## Open issues

All of 701 through 711.

## Phase demo

`issues/completed/demos/phase-7/run.sh` will exist once the
phase closes. The script orchestrates a three-device test: two
handhelds and one laptop. The script flashes both handhelds,
waits for peer discovery to converge, sends a test message from
one to the other through rmail, asserts receipt, then plugs the
laptop in by USB-C, asserts the laptop sees the device's
virtual ethernet adapter and the USB mass-storage volume, sends
a message through the laptop's rmail client, asserts receipt on
both handhelds.
