---
name: GS/OS source toolchain
phase: 1
status: pending
blockedBy: [101]
---

# 106 — GS/OS source toolchain

Acquire the publicly-released Apple GS/OS system software source code,
stand up a 65C816 assembler toolchain that can compile it, and produce a
bootable GS/OS disk image from source.

## current behavior

We can run GS/OS in GSplus only from a binary disk image acquired
elsewhere. We cannot rebuild GS/OS from source, so we cannot modify it.
This blocks the entire OS-level modification surface that the project's
vision depends on.

## intended behavior

- A clone of the public GS/OS source release lives under `libs/gsos-src/`
  (or symlinked to the shared library tree). Document the exact source
  version, its origin URL, and Apple's release license in
  `libs/gsos-src/SOURCE.md`.
- A 65C816 assembler / linker toolchain is installed and documented in
  `docs/006-iigs-toolchain.md` (new doc; add to TOC on completion).
  Candidates:
  - **Merlin32** — a cross-platform Merlin-compatible assembler, mature,
    actively maintained.
  - **ca65** (from cc65) — well-known 6502/65C816 assembler, widely
    available on Linux.
  - Apple's own ORCA/M and APW assemblers — historically accurate but
    require running on a IIgs (or in a IIgs emulator); not viable for
    a host-side toolchain.
  Pick one (Merlin32 is the most likely choice given its modern
  cross-platform support and its match to Apple's released source style).
- A `build-gsos.sh` script that:
  - assembles every source module
  - links the resulting object files
  - packages the result into a bootable `.2mg` disk image
  - runs the image in GSplus on the host (not yet on the device) and
    confirms it boots to the Finder
- The build is reproducible: the same source produces the same `.2mg`
  byte-for-byte (modulo timestamps), which is important for proving that
  modifications are intentional rather than accidental rebuilds.

## suggested implementation steps

1. Locate the GS/OS source release. Apple put it out via the Computer
   History Museum and various IIgs preservation archives; the canonical
   URL and which release version we target need to be recorded.
2. Pick the assembler. Install it on the host. Document in
   `docs/006-iigs-toolchain.md`.
3. Write a minimal `build-gsos.sh` that assembles **just one** GS/OS
   module first (the smallest one), to confirm the toolchain works.
4. Extend the build script to handle every module, then to link, then to
   package into `.2mg`.
5. Validate by booting the resulting image in GSplus **on the host
   machine** (not the device — that's issue 120's job). Confirm it
   reaches the Finder identically to the stock GS/OS disk used in
   issue 103.
6. Make a deliberate trivial source modification (change a Finder string,
   e.g. the "About" dialog text) and rebuild. Confirm the modification
   appears in the running OS. This is the moment OS-level modification
   becomes real for this project.

## related documents

- `notes/vision/000-vision.md` — "OS-level modification, not just emulation"
- `docs/001-architecture-overview.md` — "two parallel modification surfaces"
- `docs/004-roadmap.md` — phase 7 builds on this foundation

## related tools

- The GS/OS source release (URL and version to be confirmed during step 1)
- Merlin32 (https://brutaldeluxe.fr/products/crossdevtools/merlin/) or ca65
- GSplus from issue 101 (used to validate the built image)

## license note

Apple's release of GS/OS source carries specific license terms — verify
those terms permit modification and redistribution of derived works
**before** the project becomes anything resembling a public release.
Document the terms in `libs/gsos-src/SOURCE.md` alongside the source.

## why this is in phase 1, not later

The vision says OS-level modification is *the* differentiating capability
of this port. If we cannot build GS/OS from source, every later phase
that talks about modifying GS/OS (phase 6's native subsystem rewrites,
all of phase 7, the broker-as-real-device story) is hypothetical. Proving
the source-build pipeline works in phase 1, even if the only modification
we make is changing a string, converts the rest of the roadmap from
"hopefully" to "yes, the pipeline is real, here is the next step."
