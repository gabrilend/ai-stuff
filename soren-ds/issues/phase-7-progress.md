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


## The engine beneath this phase changed

Phases 2 and 3 were rewritten against the ceramic design; the old
issues are in `issues/superseded/`, with a README explaining what
moved where. In this phase, 709, 710 still describe the older
engine and have not been converted yet. Read them knowing that boxes
come from a generated catalogue rather than a hand-maintained
descriptor table.

A reference to an issue numbered 2xx or 3xx in those files points at
the superseded issue of that number, not at the one holding that
number today.

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

None yet.

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
