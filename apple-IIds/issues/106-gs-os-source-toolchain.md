---
name: GS/OS modification toolchain
phase: 1
status: pending
blockedBy: [101]
---

# 106 — GS/OS modification toolchain

Establish the workflow for modifying GS/OS without rebuilding it from
source. Two complementary surfaces: byte-level binary patches against a
working copy of the user-supplied GS/OS disk image, and from-scratch
65C816 assembly modules (Device Manager drivers, CDevs, startup files)
that we author and inject onto the patched image.

## current behavior

We can run GS/OS in GSplus from a binary disk image the user supplies.
We have no workflow for modifying it. Apple never officially released
GS/OS source — the well-known 2013 leak archived publicly cannot be
used as a build input under the project's license posture (see
`docs/001-architecture-overview.md` operational constraints). The
leaked source is permitted as a **research reference only**: read to
understand ABIs and call structures, never assembled or shipped from.

## intended behavior

- A 65C816 cross-assembler is installed into the project's toolchain
  area (`libs/toolchain/`, gitignored) and documented in
  `docs/006-iigs-toolchain.md` (new doc; add to TOC on completion).
  Likely **Merlin32** — actively maintained, matches Apple's source
  style, cross-platform. `ca65` from cc65 is the fallback.
- Disk-image manipulation tooling is installed alongside it — `cadius`
  is the canonical choice for reading and writing ProDOS-format `.2mg`
  images from the host.
- The project gains a `src/gsos-addons/` directory. Each subdirectory
  is one piece of authored functionality (a Device Manager driver, a
  CDev, a startup file), numbered to share a prefix with related
  patches and broker modules. Source is 65C816 assembly we wrote.
- The project gains a `patches/*.gsos.bin.patch` convention — byte
  patches against the user-supplied GS/OS `.2mg`. The build stage in
  issue 102 applies these to a *copy* of the user's image, never the
  original.
- A `build-gsos-addons.sh` script (or a stage in the main `build.sh`)
  assembles every addon under `src/gsos-addons/` and produces one
  binary per addon ready to be injected.
- The build stage that produces the bootable image:
    1. copies the user's `assets/disks/gsos-boot.2mg` to `tmp/build/`
    2. applies all `patches/*.gsos.bin.patch` to the copy
    3. injects every assembled addon onto the copy at the correct path
       (drivers go in `*:System:Drivers:`, CDevs in `*:System:CDevs:`,
       etc.)
    4. validates the result boots in GSplus on the host
- The first deliverable modification is a trivial one: a startup file
  that prints a project string to the boot log. The point is to prove
  the inject-and-boot pipeline works end-to-end. Real OS-level changes
  begin in phase 7.

## suggested implementation steps

1. Pick the 65C816 cross-assembler. Install into `libs/toolchain/`
   alongside the aarch64 cross-compiler from issue 101. Document the
   choice in `docs/006-iigs-toolchain.md`.
2. Install `cadius` (or equivalent) under `libs/toolchain/`. It must
   be able to list, extract, and add files inside a ProDOS `.2mg`.
3. Stand up `src/gsos-addons/` with a placeholder addon — the simplest
   thing that proves the inject path works (a trivial startup file
   that emits an identifying string at boot).
4. Wire a build stage that copies `gsos-boot.2mg` to `tmp/build/`,
   applies binary patches (none yet — the patch list can be empty for
   this first pass), and injects the assembled addons.
5. Boot the resulting image in GSplus on the host machine. Confirm the
   addon's identifying string appears.
6. Document the workflow for a developer who wants to author a binary
   patch against the `.2mg`: extract the relevant block with `cadius`,
   edit in a hex editor against a copy in `tmp/`, capture the diff
   with a small helper script that produces a `.gsos.bin.patch` file.

## related documents

- `docs/001-architecture-overview.md` — modification surfaces
- `docs/005-patch-conventions.md` — patch naming, apply/revert
- `notes/vision/000-vision.md` — staging-ground OS-modification posture
- `docs/004-roadmap.md` — phase 7 builds on this foundation

## related tools

- **Merlin32** (https://brutaldeluxe.fr/products/crossdevtools/merlin/)
  — 65C816 cross-assembler, mature, cross-platform.
- **ca65** (https://cc65.github.io/) — alternative 65C816 assembler.
- **cadius** (https://brutaldeluxe.fr/products/crossdevtools/cadius/)
  — ProDOS disk image manipulation from the host.
- The leaked GS/OS 6.0.1 source on the Internet Archive
  (https://archive.org/details/GSOS_6.0.1_source) — **reference only**,
  never a build input.
- GSplus from issue 101 — used to validate the produced image.

## license note

The user supplies their own `.2mg` (not redistributable). The leaked
GS/OS source is reference material only and is **not** committed to
the project, **not** assembled, and **not** shipped. Anything in
`src/gsos-addons/` is code we wrote from scratch; it carries the
project's chosen permissive license. Binary patches in
`patches/*.gsos.bin.patch` describe specific byte changes — these are
edits, not redistribution of Apple's binary.

## why this is in phase 1, not later

The vision says OS-level modification is *the* differentiating
capability of this port. If we cannot modify GS/OS at all, every later
phase that depends on it (phase 7's broker-as-device, phase 6's native
subsystem rewrites, the radial-keyboard-as-native-event-source plan)
is hypothetical. Proving in phase 1 that we can patch and inject
into the boot image — even if the only modification is a trivial
startup string — converts the rest of the roadmap from "hopefully"
to "yes, the pipeline is real, here is the next step."
