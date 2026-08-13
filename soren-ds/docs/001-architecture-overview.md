# Architecture overview

Soren DS is a handheld operating system for the Anbernic RG DS — a
dual-touchscreen ARM device with a D-pad and trigger buttons on the
left, ABXY and trigger buttons on the right, four center buttons in
a row across the bottom of the lower screen, two clickable analog
sticks, USB-C, WiFi, and an SD card slot. The vision document at
`notes/vision/000-vision.md` describes the apps the system runs;
this document describes the shape of the system itself.

## The two layers

Below the waterline, Soren DS is a small C kernel. Above the
waterline, Soren DS is a soramech map.

The kernel handles only what a kernel must: hardware bring-up,
memory, threads, device drivers, and the storage and network
primitives that let things outside the device be reached. Everything
visible — every app, the compositor that draws pixels, the input
router that delivers events, the file abstraction that reads and
writes SD card paths — is a soramech map composed of boxes. The
kernel doesn't know what an app is. It knows about threads and
wires.

This is a deliberate bet. Most of the system above the kernel can
be the same primitive (a soramech box) applied to a different
surface. Drivers are boxes. Compositors are boxes. Apps are boxes.
The cost of this bet is paid in phase 2, where the threading core
has to be excellent. The dividend is paid in every phase after.

## The C bottom and the soramech everything-else

The C kernel covers exactly the things soramech cannot host
itself: hardware bring-up, the boot and exception vectors, the
threading core's atomic primitives, the per-cell state machine
that makes a value's arrival safe on ARM, the page allocator that
hands out memory the boxes will live in, and the absolute lowest
USB-C and display register pokes that have to happen before
anything else can. That set is the substrate soramech runs on; trying to express
it in soramech would be circular.

Everything else is a soramech map from launch. The device
drivers above their register-poke leaves, the SD card's FAT layer
above the block driver, the input router that turns polled
button states into events, the compositor that owns surfaces, the
filesystem boxes, the four launch apps — all maps. The kernel
image at boot includes the statically-linked C functions for the
leaf boxes (register pokes, atomic ops, etc.); the programs that
wire them together live as text files the runtime reads at boot
and after. Compiling on the device lets the user write new boxes
there, and `012-soramech-runtime.md` describes how one takes over
from another — a new station, the arrows moved to it, the old one
left inert — without restarting the app that depends on it.

We do not write a C kernel and migrate it to soramech later.
Designing the form correctly the first time is cheaper than
designing it twice. The only C in the system is the substrate the
runtime needs to exist at all.

## Hardware in scope

Two touch-capable LCD panels, stacked. A button cluster on each
side of the bottom screen — D-pad and two triggers on the left,
ABXY and two triggers on the right. Four center buttons in a row
across the bottom of the lower screen, in the order
`[start1][select1][select2][start2]`. Two clickable analog sticks.
A USB-C connector for power and data. A WiFi radio. An SD card
slot. Speakers and a headphone jack.

The system is designed for one human at a time, holding the device.

## Software in scope at launch

Four apps, described in detail in `008-apps-overview.md`. They are
built in the order their dependencies allow, and the paint program
is built last because pictochat's image-attachment feature depends
on it:

- A soramech-style programming environment with an on-device
  editor served over HTTP.
- A dual-pane text editor with vim-flavored modes and radial-menu
  chord input.
- A pictochat-style messenger over the ad-hoc radio, built on
  rmail. Its text features land first; its image-attachment
  features wait on the paint program.
- A paint program with stylus input and chord-controlled tools,
  whose drawings become the attachments the messenger sends.
  Required, built last.

All four are soramech maps composed of boxes the kernel and earlier
phases provide.

A fifth app, the **modeller**, is documented in `010-modeller.md`
and ships after the launch system is complete. It exists to prove
the platform can host apps the architects didn't pre-bake.

## Navigation between apps

There is no app switcher and no back button. Apps reach each
other through inter-app links: every app exposes a small set of
exits, each named for the app it goes to and typed with the
value it carries forward. Following an exit replaces the current
screen's foreground with the linked app; the linked app receives
the carried value. Coming back to a previous app is not a
separate mechanic — it is another forward link, exposed by the
destination app, that happens to point at the app the user came
from. App pairs that need round trips cross-link both
directions, like a doubly-linked list. Background apps keep
their state, so following a link back to an app the user was in
earlier resumes that app where they left it — no history stack,
no ring buffer, no path-tracking. Details in
`008-apps-overview.md` and the input flow in
`004-input-model.md`.

The four center buttons across the bottom of the lower screen do
not open an app switcher. They open **drawers** — overlay menus
that slide in from a screen's left or right edge with the utilities
the user needs at that moment. Two buttons per screen by default;
an option swaps which pair drives which screen. Details in
`005-display-and-compositor.md`.

## What's not in scope

Anything router-based. Lua running anywhere in the kernel. Running
the device's stock OS, ever. Multi-user accounts. App stores. A
general-purpose browser. An app switcher of any kind. Most of what
we think of as a modern OS. The explicit list, with reasoning,
lives in `009-deferred-work.md`.
