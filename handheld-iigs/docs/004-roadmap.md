---
name: roadmap
status: draft (planning phase, 2026-05-19)
---

# roadmap

Phases are organized by **functional cluster**, not by chronology. Lower-
numbered phases are foundational; higher-numbered phases assume the
earlier ones are stable.

## phase 1 — foundation

Goal: one Apple IIgs, booting GS/OS, on one of the two RG DS screens,
mousable by touch, with a buildable copy of GS/OS source.

- 101 — source and toolchain (acquire GSplus, set up RK3568 cross-compile)
- 102 — project build system (one command produces a deployable artifact)
- 103 — single-screen boot (GSplus runs GS/OS to the Finder on screen A)
- 104 — touch as mouse (digitizer drives the IIgs cursor)
- 105 — disk image management (insert/eject .2mg images at runtime)
- 106 — GS/OS source toolchain (build GS/OS from Apple's release)
- 120 — phase 1 demo (runnable demo in `issues/completed/demos/`)

## phase 2 — dual instance

Goal: two IIgses, one per screen, independently usable.

- 201 — second emulator instance on screen B
- 202 — independent input routing (touches on B go to B, on A go to A)
- 203 — focus model (which screen receives stick/button input; mediated by
  the duplicated Start/Select pairs)
- 220 — phase 2 demo

## phase 3 — the broker kernel

Goal: the two emulators share a filesystem and a clipboard, and can speak
to each other through IPC.

- 301 — shared backing filesystem (single source of truth under the broker)
- 302 — shared clipboard (copy on A, paste on B; rides on Scrap Manager)
- 303 — AppleTalk-style IPC channel between the two emulators
- 304 — conflict resolution policy (last-writer-wins, with audit log)
- 320 — phase 3 demo

## phase 4 — input systems

Goal: full keyboard alternative via the radial dual-stick system, plus the
gyro and stylus refinements.

- 401 — stick quantization and dead-zone tuning
- 402 — radial overlay renderer on the bottom panel
- 403 — character emission as ADB key events into the active emulator
- 404 — modifier keys (shift, command, option, control; L3/R3 layers)
- 405 — training mode (overlay always visible)
- 406 — wedge count and layout calibration (hardware-in-hand)
- 407 — stylus vs finger differentiation (right-click equivalent)
- 408 — vibration tactile feedback on character commit
- 420 — phase 4 demo

## phase 5 — polish and integration

Goal: the device feels like a finished product. Boot once, use forever.

- 501 — boot configuration (auto-start broker, pick startup disks)
- 502 — application library curation (preloaded software set)
- 503 — settings UI (visible to the user, not just config files)
- 504 — documentation site at `docs/HTML/`
- 505 — power management (Hall sleep switch, battery indicator)
- 520 — phase 5 demo

## phase 6 — first native subsystem rewrites (pending soramech)

Goal: begin cutting the emulator-to-native seam. Each rewrite runs on its
own thread under soramech. **Pending soramech** — issue files in this
phase are placeholders for planning, not started until upstream
threading primitives at `/home/ritz/programs/sora/soramech/` stabilize.

- 601 — Scrap Manager native (clipboard, easiest seam)
- 602 — File Manager native (shared FS without virtual-disk fiction)
- 603 — Event Manager native (radial input flows through native events)
- 604 — QuickDraw II native (the big one)
- 620 — phase 6 demo

## phase 7 — GS/OS modification

Goal: ship a forked GS/OS that knows about the broker as a first-class
device, and the second screen as a real thing.

- 701 — broker-as-device driver in GS/OS (replaces virtual-disk fiction)
- 702 — second-screen awareness (Finder, Window Manager extensions)
- 703 — radial-keyboard awareness at the OS level
- 704 — modified Finder with dual-desktop coordination
- 720 — phase 7 demo

## phase 8 — Toolbox ROM patches

Goal: where source-level mods can't reach, patch the Toolbox ROM directly.
This is the deepest modification surface and is scoped narrowly — only
patches that the source approach genuinely cannot achieve.

- 801 — Toolbox disassembly and patch infrastructure
- 802 — specific patches (TBD based on what's blocking phase 7)
- 820 — phase 8 demo

## phase 9+ — applications and games

Goal: software written **for** this OS, exploiting its dual-screen,
radial-input, modified-GS/OS nature. Per the architectural rule that no
single program spans both screens, every "dual-screen" application in
this phase is actually a **coordinated pair of programs** — one
ordinary IIgs application per screen, talking through the broker IPC.

Candidate pairings:

- **a game pair**: map + action view. The map program runs on one screen
  showing the world overview and unit positions; the action program runs
  on the other showing the close-up combat. They exchange unit state
  and player input through the broker. Each is a normal IIgs program
  to its own GS/OS.
- **a music pair**: keyboard + sequencer. The keyboard program runs on
  one screen rendering a piano keyboard you tap with the stylus; the
  sequencer program runs on the other screen recording and editing.
  Two Ensoniq 5503 chips means real polyphonic layering between them.
- **a journal pair**: page + radial keyboard reference. The page program
  shows the current entry; the reference program (on the other screen)
  shows the radial-keyboard layout in training mode, plus snippets and
  a thesaurus.
- **a sketch pair**: canvas + palette. The canvas program holds the
  drawing; the palette program holds the color picker, tool selection,
  and layer list. The stylus on the canvas screen does the drawing; the
  stylus on the palette screen does the configuration.

Single-screen applications also belong here — a text editor that uses
the radial keyboard as its primary input doesn't need a second screen
at all to be valuable. The dual-screen capability is an option, not a
requirement.

Specific issue files for phase 9+ will be written as ideas firm up.

## demos as deliverables

Each phase ends with a runnable demo in `issues/completed/demos/phase-N/`.
The demos are part of the product, not throwaway test programs. A top-level
`run-demo.sh` script will accept a phase number and launch the corresponding
demo. The demo for phase N exercises the new functionality of phase N in
combination with everything from phases 1..N-1.

Demos are **continually updated** — when phase 4 lands the radial keyboard,
the phase 1 demo gets the radial keyboard too. They are a living showcase,
not a snapshot of "what was new in this phase."
