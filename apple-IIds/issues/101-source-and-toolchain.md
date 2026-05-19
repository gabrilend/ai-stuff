---
name: source and toolchain
phase: 1
status: pending
---

# 101 — source and toolchain

Acquire the GSplus source and stand up a cross-compile environment
targeting the Anbernic RG DS (Rockchip RK3568, ARM Cortex-A55).

## current behavior

The project directory has no source code and no toolchain. The Anbernic
RG DS hardware specs are pinned in `docs/002-hardware-target.md` but the
toolchain that compiles for it has not been chosen.

## intended behavior

- A clone of the GSplus source lives in `libs/gsplus/` (or symlinked to
  the shared library tree at `/home/ritz/programming/ai-stuff/libs/` if
  the library already lives there). GSplus is BSD-licensed and descends
  from KEGS; the license permits the modifications phase 7+ requires.
- A cross-toolchain for aarch64 ARM Cortex-A55 is installed and documented
  in `docs/005-toolchain-setup.md` (new doc; add it to the TOC on this
  issue's completion).
- A `build.sh` at the project root cross-compiles a "hello world" binary
  for the RG DS and the binary runs on the device.

## suggested implementation steps

1. Survey `/home/ritz/programming/ai-stuff/libs/` and
   `/home/ritz/programming/ai-stuff/my-libs/` for an existing GSplus
   checkout. Reuse if present.
2. If not present, fetch GSplus from upstream and place under
   `libs/gsplus/`. Record the exact source version (tag or commit hash)
   in `libs/gsplus/SOURCE.md` along with the license file.
3. Install the aarch64 cross-toolchain on the host. The mainline
   `aarch64-linux-gnu-gcc` from Debian/Arch packages should work for the
   RK3568. Document the install steps in `docs/005-toolchain-setup.md`.
4. Confirm the RG DS will accept and run a binary built with the chosen
   toolchain. Probably this means ssh-ing into the device's Linux mode
   and running a trivial binary.
5. Write the minimal `build.sh` per the global convention: hard-coded
   `${DIR}` at the top, optional `${DIR}` argument override, each
   command on its own line.
6. Resolve the device-side open questions from the hardware target doc:
   `/dev/input/eventN` mapping, `/dev/fb*` device(s), USB-C DC/USB vs
   OTG semantics, stylus differentiation, gyro IIO device. Record findings
   in `docs/002-hardware-target.md` and remove the "to confirm" section.

## related documents

- `docs/001-architecture-overview.md` — layer 1 (host) section
- `docs/002-hardware-target.md` — RG DS specs and open questions
- `notes/vision/000-vision.md`

## related tools

- GSplus upstream (https://github.com/digarok/gsplus)
- KEGS upstream (https://github.com/kentdickey/kegs) — fallback if GSplus
  proves harder to retarget
- aarch64 cross-toolchain (mainline GCC works)

## license note

GSplus is BSD-style licensed; the OS-level modifications planned in
phase 7+ are permitted without redistribution restrictions. The Apple IIgs
ROM itself is **not** redistributable and must be supplied separately by
the end user (issue 103 handles ROM mounting; issue 106 handles GS/OS
source, which Apple released publicly).

## blockers

- This issue blocks every other issue in phase 1.
