# Roadmap

Ten phases, ordered by what blocks what. Each phase ends in a demo
that shows the device doing the thing the phase named. Phase
numbers correspond to clusters of functionality, not calendar
time. It is fine for the final issue completed in this project to
live in phase 1 or 2. Phases 1 through 9 build the launch system;
phase 10 is the first post-launch app, sketched now so the
platform is designed to host it.

## Phase 1 — Hardware bring-up

The smallest kernel that can iterate on itself over USB. Boot from
the device's firmware, set the stack and interrupt vectors, hand
control to C, drive the two LEDs as the earliest-stage diagnostic
signal, bring up the USB controller in device mode, expose a
virtual serial port over USB CDC-ACM for live debug streaming, run
a flat-memory allocator, bring up the shared display controller,
configure both its output paths so the top screen and the bottom
screen are both being scanned out, and draw a bright pixel on each
screen. No MMU configured yet. The heaviest single piece of work
is the USB device-mode bring-up, because without it the
development loop requires either an SD card reader or a roundtrip
through the stock OS — neither of which we want, and the stock OS
we never run at all.

Phase 1 demonstrates the hardware, and the hardware has two
screens. Both light up before the phase closes.

The phase demo flashes the kernel via the chip's ROM recovery
mode, streams the debug output over USB, and confirms a visible
pixel on each screen. Everything later in the project is iterated
against this loop.

## Phase 2 — Threading core

The scheduler, the worker pool, the ring-buffered task struct with
unique return slots, the atomic gathering primitive that decides
when a box is ready to fire, the release/acquire memory ordering
that makes the firing decision safe on ARM. This is the foundation
everything above leans on, and the most important phase in the
project. The demo is a torture test: spin up millions of tiny tasks
across all cores and prove zero races, zero lost fires, zero
double-fires. Not visual but load-bearing.

## Phase 3 — Display and input drivers

Two framebuffers already up from phase 1; phase 3 adds the layer
on top. A 60Hz polling loop reads the buttons, the analog sticks,
and the two touch panels. The event boxes emit button-down events
on press, button-up events on release with the press duration
attached, and the radial-menu chord events that the editor and
the drawers depend on. The demo lets you touch the screens and
push buttons and see something change.

## Phase 4 — Filesystem

SD card driver, FAT-compatible reader and writer, a file
abstraction exposed as soramech boxes that read and write paths.
Persistent state becomes possible — the device can remember which
app was last open on each screen. The demo writes a file, reboots
the device, reads it back.

## Phase 5 — Soramech runtime

The box loader reads JSON box files from the SD card. The wire
connector links them. The task instantiator turns a fired box into
a task struct on the thread pool's work queue. Now you can drop a
soramech map onto an SD card and the device runs it. The demo runs
the original soramech "hello, world" map from the handheld instead
of from a desktop.

## Phase 6 — Compositor, drawers, and inter-app linkage

The display layer that lets multiple boxes draw into named
surfaces, with rules about who owns which surface on which screen.
The drawer overlay system from `005-display-and-compositor.md`
lives here — pressing a center button slides a drawer in from the
appropriate edge with the foreground app's utilities inside.

This is also the phase that builds the inter-app linkage system:
the named-exit declaration boxes, the value each exit carries
forward, the foreground swap that happens when a link is taken.
The system has no back button and no history mechanism — round
trips are made of two forward links, one in each app, and the
background-app state that phase 9 makes durable is what makes the
round trip feel like a return. By the end of phase 6, two trivial
apps can cross-link across screens and the user can walk back and
forth between them through their two forward links.

The demo runs two trivial maps side by side, one on each screen,
with a center-button drawer popping over each and an inter-app
link bouncing focus between them.

## Phase 7 — Ad-hoc radio and rmail

WiFi driver in IBSS mode. Link-local addressing. A small
"I am here, my name is X" peer-discovery broadcast. The transport
abstraction that hides whether a peer is reached over USB-C or
radio. rmail recompiled against this stripped network stack. The
demo puts two handhelds side by side and shows them finding each
other and exchanging a message; then plugs a laptop in by USB-C
and shows the same conversation flowing over the cable.

## Phase 8 — The four apps

The programming environment, the dual-pane text editor, the
pictochat-style messenger (text features first), and the paint
program (last). By this point each one is mostly a soramech map
composed of boxes already shipped by earlier phases. The
messenger's text features ship before paint; once paint ships, the
messenger's image-attachment exit lights up and the four-app
launch system is complete.

The demo is each app actually used for its actual purpose — write
a short program in the editor, type a paragraph, paint a picture,
send a text message and then send the painted picture between two
devices. The paint-to-messenger flow is the proof that the
inter-app linkage system from phase 6 carries real return values
between real apps.

## Phase 9 — Memory protection and background-app lifecycle

The MMU turned on in protection-only mode. Each app gets a region
of memory it's allowed to touch; stray writes trap into a handler
instead of corrupting the kernel. On top of that, the
background-app lifecycle: an app can be foreground (drawn,
running), backgrounded (running, not drawn), or asleep (not
running, not drawn, woken on a signal). The capstone demo is an
extra app written on the device itself — watched as it crashes,
repaired in the on-device editor, watched as it runs again — while
the other four apps keep running in the background unaffected.

Phase 9 closes the launch system. Everything described in the
vision is, by the end of this phase, in the user's hands.

## Phase 10 — The modeller

The first post-launch app, sketched in `010-modeller.md`. On-device
3D modelling, vertex grid editing, face coloring through the
radial menu, dynamic merging of models. Phase 10 exists to prove
the platform can host a complex app that depends on every preceding
phase. If the modeller falls out cleanly as a soramech map plus a
few new primitives, the architecture has done its job; if it
demands something the launch phases didn't build, that demand is
the next thing the architecture has to grow.

The demo builds a small model from a blank grid, colors its faces
through the radial menu, saves it to the SD card, and merges it
with a second model to make a third.

## Shape of the work

Phases 1 and 2 are the load-bearing walls. Phases 3 through 8 are
mostly composition of what phases 1 and 2 already gave us: drivers
are threads, the filesystem is a driver, the runtime is a thread
pool with a loader, the apps are maps. Phase 9 is the gate for a
genuinely user-extensible system. Phase 10 is the first proof that
extension actually works.

The phase that ships the launch apps is phase 8; the phase that
makes Soren DS a platform rather than a product is phase 9; the
phase that proves the platform is phase 10.
