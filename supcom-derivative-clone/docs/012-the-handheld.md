# 012 — The Handheld

The vision names the target: playable on the two-screen handheld that a sibling
project, Soren DS, is building an operating system for. This document describes
what that device is, what its system expects a program to look like, and how
this game is shaped so that it can become one.

## The device

A clamshell with two four-inch touch screens stacked vertically, each of them
six hundred and forty pixels by four hundred and eighty. A directional pad and
two triggers on the left, four face buttons and two triggers on the right, two
clickable analogue sticks, and **four centre buttons in a row** along the bottom
of the lower screen. Four ARM cores, three gigabytes of memory, a WiFi radio, a
USB-C port. It runs the sibling project's own operating system, not the one it
shipped with.

## What a program is, there

Below the waterline the system is a small C kernel. Above it, **everything is a
map of boxes**: a box is a plain C function that takes arguments and returns a
value and is forbidden to remember anything between calls; a map is a text file
saying which boxes exist and what feeds what. A box runs when, and only when,
every one of its inputs holds a value, and every run is a task on a pool of
workers across the four cores. There is no sequential mode, no thread a program
writes, and no lock it can hold wrongly.

That runtime is the sibling of another project in the monorepo — the ceramic
core engine — which builds and runs the same maps on a desktop, and which this
project pins as a dependency so that the handheld's program can be run and
tested on a computer before it is ever flashed.

The kernel's boxes are C only. The system's own documents say Lua in the kernel
is out of scope forever, and that a Lua userland is a possible later phase of
that project, not a promise.

## Why this game already fits

The [tick document](003-the-tick-and-the-timers.md) describes a simulation that
is an ordered table of systems, each a pure function over flat arrays, with
every periodic effect a derivation from three integers and every cross-slice
write buffered and applied later. That is not a coincidence. Each system is the
shape of a box: inputs in, a value out, nothing remembered. The tick's dispatch
table is a map file with the arrows drawn in the same order. The buffered
damage is a wire. The thread pool that slices the tick on a computer is the
worker pool that runs the map on the handheld, and the rule the pool enforces —
write only your own slice — is the rule a box cannot break because it has no
slice to write.

The vision's own words for the timer design were "perfect for soramech," and
the reason is the one above: a periodic effect that is a pair of integers is a
box; a periodic effect that walks a list is not.

## The three ways it could be built

How the simulation, written in LuaJIT for the computer, becomes C boxes for the
handheld is the largest [open question](016-open-questions.md) this project
carries, and the three answers are:

1. **Hand-ported boxes.** Each system is transcribed to a C function, and the
   map file is written from the tick's dispatch table. The Lua stays the
   reference; a test runs both on the same seed and compares the hash. The
   monorepo has a skill for keeping several implementations of one program in
   one source file with exactly one active, which is the discipline this would
   use.
2. **A Lua userland on the handheld.** Wait for the sibling project to host Lua
   boxes above its kernel, and run the same source. Nothing to port, and nothing
   to run until that phase exists there.
3. **Generate the boxes.** The systems are simple enough — integer arithmetic
   over flat arrays — that a subset of Lua could be translated to C by a tool.
   The most work and the most reward, and the one most in the spirit of the
   monorepo's rule that things are made by tools.

The working ruling is the first, because it is the only one that produces a
running handheld build without waiting on another project or writing a
compiler, and because the reproducibility test makes the port checkable system
by system. The phase-eight issues are written against it.

## The two screens

The system gives each screen its own foreground app, and a program draws into
**surfaces** it asks the compositor for. This game asks for both screens and
splits the [lenses](010-the-views.md) across them. The working ruling:

- **Top screen**: a wide lens on the field, switchable to the cloud window.
- **Bottom screen**: a close lens on the field, where the stylus draws patterns
  and picks factory cells, and where the roster and territory are shown.

The system's four centre buttons open **drawers** — overlay menus sliding in from
a screen's edges — and its input model turns direction-plus-face-button chords
into a radial menu. The energy menu's four buttons are the natural tenants of
one drawer's radial menu, or of the four directions of the pad; which is
[open](016-open-questions.md), and it is a question for a person holding the
device rather than one that can be argued.

## The wire

The handheld reaches its peers through the system's transport abstraction, and
what is and is not known about that is in [other players](011-other-players.md).
The short version: the model is settled and the numbers are pending the sibling
project's radio work.

## The build

`./compile --target handheld` is where the handheld build is invoked, and today
it refuses, naming what it lacks: the pinned engine in `libs/`, the sibling's
cross-toolchain, and a `maps/` directory with the simulation written as a map.
Each of those is a phase-eight issue, and the compile script grows the steps as
the issues close.

Related: [the tick](003-the-tick-and-the-timers.md) · [the views](010-the-views.md) ·
[other players](011-other-players.md)
