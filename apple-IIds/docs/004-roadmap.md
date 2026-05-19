---
name: roadmap
status: draft (planning phase, 2026-05-19)
---

# roadmap

Phases are organized by **functional cluster**, not by chronology.
Lower-numbered phases are foundational; higher-numbered phases assume
the earlier ones are stable.

The roadmap spans **the staging ground** (phases 1–10, running on Linux
with GSplus emulators) and **the destination** (phases 11–12, bare-metal
Apple IIds with soramech-editor self-hosting). Phase 13+ is applications,
which can be developed any time after roughly phase 5.

## phase 1 — foundation

Goal: one Apple //gs, booting GS/OS, on one of the two RG DS screens,
mousable by touch, with a buildable copy of GS/OS source.

- 101 — source and toolchain (acquire GSplus, set up RK3568 cross-compile)
- 102 — project build system (one command produces a deployable artifact)
- 103 — single-screen boot (GSplus runs GS/OS to the Finder on screen A)
- 104 — touch as mouse (digitizer drives the IIgs cursor)
- 105 — disk image management (insert/eject .2mg images at runtime)
- 106 — GS/OS source toolchain (build GS/OS from Apple's release)
- 120 — phase 1 demo

## phase 2 — dual instance

Goal: two IIdses, one per screen, independently usable.

- 201 — second emulator instance on screen B
- 202 — independent input routing (touches on B go to B, on A go to A)
- 203 — focus model (which screen receives stick/button input; mediated
  by the duplicated Start/Select pairs)
- 220 — phase 2 demo

## phase 3 — the broker kernel

Goal: the two emulators share a filesystem and a clipboard, and can
speak to each other through IPC.

- 301 — shared backing filesystem (single source of truth under the broker)
- 302 — file locking (option A: second opener gets an error)
- 303 — shared clipboard (copy on A, paste on B; rides on Scrap Manager)
- 304 — AppleTalk-style IPC channel between the two emulators
- 305 — conflict resolution (last-writer-wins on file commits, audit log)
- 320 — phase 3 demo

## phase 4 — input systems (broker-side)

Goal: full keyboard alternative via the radial dual-stick system, plus
gyro and stylus refinements. Implemented at the **broker** level —
events get injected into the emulators through emulated ADB.

- 401 — stick quantization and dead-zone tuning
- 402 — radial overlay renderer (on the **inactive** screen)
- 403 — last-input target tracking (screen + window + program)
- 404 — character emission via ADB key events into the active emulator
- 405 — modifier keys (shift, command, option, control; L3/R3 layers)
- 406 — training mode (overlay always visible on inactive screen)
- 407 — wedge count and layout calibration (hardware-in-hand)
- 408 — stylus-vs-finger differentiation (right-click equivalent)
- 409 — one-handed mode (stylus tap on the radial menu commits)
- 410 — vibration tactile feedback on character commit
- 420 — phase 4 demo

## phase 5 — polish and integration

Goal: the device feels like a finished product. Boot once, use forever.

- 501 — boot configuration (auto-start broker, pick startup disks)
- 502 — application library curation (preloaded software set)
- 503 — settings UI (visible to the user, not just config files)
- 504 — documentation site at `docs/HTML/`
- 505 — **suspend to RAM** (Hall sleep switch pauses both emulators; on
  wake, they resume from in-memory state — never written to SD card)
- 506 — **SD-card write minimization** (RAM-backed scratch, write
  coalescing, periodic flush only when necessary; see issue
  `pending/iigs-write-frequency-analysis.md` for the upstream
  GS/OS-side analysis that informs this work)
- 507 — audio mixer (each emulated program owns its own stereo channel
  in software; broker mixes both Ensoniqs and pans per program)
- 508 — boot chime once (broker plays the //gs chime once on power-on
  and suppresses the second emulator's chime for ~2 seconds during boot)
- 520 — phase 5 demo

## phase 6 — first native subsystem rewrites *(pending soramech)*

Goal: begin cutting the emulator-to-native seam. Each rewrite runs on
its own thread under soramech. Issue files here are placeholders for
planning, not started until upstream threading primitives at
`/home/ritz/programs/sora/soramech/` stabilize.

- 601 — Scrap Manager native (clipboard, easiest seam)
- 602 — File Manager native (shared FS without virtual-disk fiction)
- 603 — Event Manager native (radial input flows through native events)
- 604 — QuickDraw II native (the big one; split 604a–604e by API surface)
- 620 — phase 6 demo

## phase 7 — GS/OS modification foundation

Goal: the second OS-level modification (after the About-string proof
from issue 106) lands, establishing the cross-surface coordinated-patch
pipeline as production-ready.

- 701 — broker virtual peripheral infrastructure (the generic mechanism
  for the broker to expose virtual peripherals to GS/OS)
- 702 — **Broker Input device** (the second OS-level mod: GSplus virtual
  peripheral + GS/OS Device Manager driver + Event Manager extension;
  see `issues/pending/702-broker-input-device.md`)
- 703 — Broker Filesystem device (replaces virtual-disk fiction with a
  first-class GS/OS device)
- 704 — Finder dual-desktop awareness
- 720 — phase 7 demo

## phase 8 — input liberation

Goal: touch, stylus, radial keyboard, and gyro all flow through the
Broker Input device (issue 702) as native GS/OS event sources. ADB
emulation is no longer carrying any modern-hardware input — it remains
only for compatibility with software that polls ADB directly.

- 801 — touch and stylus as native GS/OS mouse events (no ADB)
- 802 — radial keyboard as native GS/OS key events (no ADB)
- 803 — gyro as a native GS/OS input source (fine cursor mode, optional)
- 804 — inactive-screen overlay rendered by a GS/OS desk accessory rather
  than the broker (deeper integration, optional polish)
- 820 — phase 8 demo

## phase 9 — multithreading by default *(pending soramech)*

Goal: GS/OS becomes preemptively multitasking. The Toolbox becomes
reentrant. Cross-thread Scrap and File Manager. **All threading work is
in 65C816 assembly during staging, ARM assembly post-bare-metal.**
Soramech's primitives are lifted wholesale (scheduler, locks, channels);
its language-spec system is not lifted.

- 901 — scheduler primitives in 65C816 assembly
- 902 — locks and atomic operations
- 903 — channels and message passing
- 904 — Toolbox reentrancy audit (which routines hold shared state?)
- 905 — Toolbox reentrancy fixes (pass 1: the easy half)
- 906 — Toolbox reentrancy fixes (pass 2: the hard half)
- 907 — preemptive task switching in GS/OS Event Manager
- 920 — phase 9 demo

## phase 10 — Toolbox ROM patches

Goal: where source-level mods cannot reach, patch the Toolbox ROM
directly. Reserved narrowly — only patches the source approach
genuinely cannot achieve.

- 1001 — Toolbox disassembly and patch infrastructure
- 1002 — specific patches (TBD based on what's blocking phase 7/8/9)
- 1020 — phase 10 demo

## phase 11 — bare-metal port (the destination)

Goal: Apple IIds runs natively on the RK3568. No Linux. No GSplus
emulator. The 65C816 assembly of phases 1–10 has been ported,
translated, or selectively rewritten in ARM assembly. This phase is
**core** to the project, not aspirational, and is realistically
multi-year. It is its own substantial undertaking.

Three approaches that can be combined:

- **Static recompilation.** Translate 65C816 binaries to ARM binaries
  ahead of time. Some routines work cleanly; others (self-modifying
  code, jumps through unknown addresses) don't.
- **Module-by-module rewrite.** Pick a GS/OS module and reimplement it
  natively in ARM assembly with the same API. Replace the old module
  in the build.
- **Selective dynamic recompilation.** Keep a small JIT in ARM
  assembly that translates 65C816 to ARM on the fly for the routines
  that can't be statically translated. Last resort.

- 1101 — bare-metal boot (RK3568 boots into our bootloader, not Linux)
- 1102 — hardware abstraction layer in ARM assembly (split 1102a–1102i
  per device: SD card, panels, digitizers, sticks, buttons, audio,
  Hall switch, gyro, vibration)
- 1103 — first module ported (smallest GS/OS subsystem)
- 1104 — Apple //gs Toolbox in ARM assembly (the multi-year subproject;
  split 1104a–1104n per Toolbox manager)
- 1105 — threading primitives in ARM assembly (re-port of phase 9
  routines from 65C816)
- 1106 — broker becomes a kernel component, not a Linux process
- 1120 — phase 11 demo

## phase 12 — soramech editor as in-device IDE

Goal: programs for Apple IIds can be written **on the device** using
soramech's editor. ARM assembly is the only programming language. This
is the moment the device becomes self-hosting.

- 1201 — soramech editor cross-ported to Apple IIds
- 1202 — assembly toolchain (assembler + linker) running on the device
- 1203 — debugger
- 1204 — sample project: write a small Apple IIds program entirely on
  the device, save it, run it, the device hosts its own development
- 1220 — phase 12 demo

## phase 13+ — applications

Goal: software written **for** Apple IIds, exploiting its dual-screen,
radial-input, modified-OS, threading-by-default nature. Every
"dual-screen" application is a **coordinated pair** (one program per
screen, talking through the broker IPC).

Candidate pairings:

- **a game pair**: map + action view
- **a music pair**: keyboard + sequencer (two Ensoniqs in stereo)
- **a journal pair**: page + radial-keyboard reference
- **a sketch pair**: canvas + palette

Single-screen apps belong here too — a text editor using the radial
keyboard doesn't need a second screen at all to be valuable.

Specific issue files for phase 13+ will be written as ideas firm up.
Apps can begin development any time after roughly phase 5, when the
device is usable; they don't have to wait for bare-metal.

## demos as deliverables

Each phase ends with a runnable demo in `issues/completed/demos/phase-N/`.
The demos are part of the product, not throwaway test programs. A
top-level `run-demo.sh` script accepts a phase number and launches the
matching demo.

Demos are **continually updated** — when phase 4 lands the radial
keyboard, the phase 1 demo gets the radial keyboard too. They are a
living showcase, not a snapshot of "what was new in this phase."
