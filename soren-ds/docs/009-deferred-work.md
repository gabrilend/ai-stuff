# Deferred work

Decisions we made *not* to build, with the reasoning preserved so
that a future reader (or future us) doesn't try to relitigate them
without new information.

## Running the device's stock OS

Never, not even once. The stock OS has to behave as if we are not
on its device. This rules out one of the friendlier paths for
confirming the chip's recovery mode is reachable from outside the
case (the ADB-through-Android chain described in
`notes/safety/000-bricking-and-recovery.md`), and forces us to
confirm recovery-mode access through the other paths — a PCB
button accessible from outside the case, or a u-boot shell over
USB. Phase 1's hardware research issue carries the open question.

## A general-purpose app switcher

Not in scope. Apps reach each other through inter-app links, not
through a switcher: each app exposes named exits with a value
each exit carries forward, and the user only ever moves forward.
Coming back to a previous app is another forward link exposed by
the destination. There is no back button, no history stack, no
ring buffer — background apps keep their state, and that is all
the round-trip mechanism the system needs. See
`008-apps-overview.md` and `004-input-model.md`.

## Router-based LAN networking

Not in scope. The device's networking is ad-hoc only: devices form
local peer groups directly with each other over the radio. This
sidesteps the substantial complexity of WiFi station mode
(associating with an access point, DHCP, NAT traversal, the entire
configuration surface of IP routing).

If a future use case requires reaching the broader internet from
the device, this is the gate to revisit. Until then, "two devices
in the same room can chat" is sufficient.

## Full virtual memory

Not in scope at launch. We turn the MMU on in protection-only mode
in phase 9, which gives us crash isolation between apps without
the engineering cost of address translation, page tables,
fault-driven paging, or swap. See `007-memory-model.md` for the
graduated path.

Full VM is the answer to "more apps than fit in RAM" or "apps need
private address spaces for reasons other than isolation." We are
not facing either of those problems yet.

## Encapsulated sub-maps

Soramech proper supports encapsulating a sub-map into a single
box, so a complex graph can be reused as a building block. We
defer this feature because it requires nailing down the sub-map
calling convention, which is its own design problem. The four
launch apps can be built without it. Re-evaluate when the modeller
arrives in phase 10, because the modeller's model-merge operation
is the first thing in the project that actually wants this.

## Lua in the kernel

Not in scope, ever. Soramech proper supports Lua, C, and Bash box
functions. In our kernel, box functions are C only. Lua brings a
runtime, a garbage collector, and a memory model that don't belong
below the soramech runtime layer. If a user wants to write boxes
in Lua on top of our system, that is a userland choice for a later
phase — but the kernel itself is C.

## JSONL audit logging

Soramech proper writes a detailed JSONL log of every box firing,
every wire transfer, every value. This is invaluable for debugging
on a desktop and prohibitively expensive on a battery-powered
handheld with limited storage. We keep an in-RAM ring buffer of
the last N events for crash diagnosis but do not write the full
log to disk.

## A launcher screen

The device boots straight into whichever app was foregrounded when
it was last powered off, on each screen independently. There is no
separate launcher screen and no home screen. App switching happens
through inter-app links, not through a launcher.

## A general-purpose browser

The editor renders in a browser-like view, but the device does not
ship a general web browser. The HTTP server on the device serves
the editor and the laptop client; that is all. A browser is a
multi-month project of its own and not on the path to the launch
apps.
