---
name: project build system
phase: 1
status: pending
blockedBy: [101]
---

# 102 — project build system

A single command builds the project end-to-end and produces an artifact
ready to copy to the device. The build orchestrates the patch surfaces
defined in `docs/005-patch-conventions.md` with the apply/unapply
discipline that keeps upstream pristine between stages.

## current behavior

`scripts/build-deps.sh` from issue 101 fetches GSplus, LuaJIT, and the
aarch64 cross-toolchain into `libs/`. There is no top-level build that
produces a deployable artifact.

## intended behavior

- A top-level `build.sh` that:
    - has `${DIR}` hard-coded at the top
    - accepts `${DIR}` as the first argument
    - applies + cross-compiles + reverts per layer (see stages below)
    - bundles the result into `tmp/build/`
    - emits a manifest listing every produced file with its size and
      SHA-256 hash (the manifest is the deliverable's table of contents)
- A top-level `develop.sh` for interactive sessions on the patched
  source: `develop.sh gsplus` keeps GSplus patches applied for hours
  of editing; `develop.sh freeze` captures the new diff back into the
  patch files; `develop.sh revert` returns the tree to pristine.
- A top-level `deploy.sh` that copies `tmp/build/` to the RG DS over
  ssh. Skeleton until the device is in hand; the actual ssh target
  comes from a `tmp/device.conf` the user creates locally.

## build stages

Following `docs/005-patch-conventions.md`:

1. **GSplus stage**
    - apply `patches/*.gsplus.patch` (to `libs/gsplus/`)
    - cross-compile GSplus to aarch64
    - revert `patches/*.gsplus.patch`
2. **GS/OS addon stage** (assemble custom drivers/CDevs/startup files
   we author under `src/gsos-addons/`)
3. **GS/OS disk-image stage**
    - copy the user-supplied `assets/disks/gsos-boot.2mg` to
      `tmp/build/`
    - apply `patches/*.gsos.bin.patch` to the *copy*
    - inject every assembled addon onto the copy at the correct path
4. **Broker stage** — no patches; bundle `src/broker/` as-is
5. **LuaJIT stage** — cross-compile LuaJIT for aarch64
6. **Bundle stage** — assemble everything into `tmp/build/`, emit the
   manifest

## suggested implementation steps

1. Write `build.sh` skeleton matching the global convention.
2. Implement the **apply / unapply discipline** with a sentinel file
   in `tmp/.applied`. Every apply writes the sentinel listing exactly
   which patch files are currently applied; every revert clears it.
   A crashed build leaves the sentinel behind; the next invocation
   detects it and reverts before starting fresh.
3. Implement each stage in order. Each one must succeed independently
   (run only the GSplus stage; run only the disk-image stage). The
   one-shot full build is the chain of all of them.
4. Cross-compile LuaJIT for aarch64. If cross-compilation breaks,
   create a follow-up issue with the failure — **do not silently fall
   back to vanilla Lua**.
5. Write the manifest emitter as a Lua script under `src/build-tools/`. It
   walks `tmp/build/` after every stage and produces
   `tmp/build/manifest.txt` listing path, size, and SHA-256 of every
   file.
6. Write `develop.sh` per the interactive workflow in
   `docs/005-patch-conventions.md`.
7. Write `deploy.sh`. Until the device is in hand, the round-trip
   test is: `build.sh` produces `tmp/build/`, `deploy.sh --dry-run`
   prints the rsync plan against `tmp/device.conf`. The real round
   trip (edit locally → see change on device) is exercised in issue
   120's demo.

## related documents

- `docs/001-architecture-overview.md`
- `docs/002-hardware-target.md` — two USB-C ports; deploy.sh may use
  either depending on which is host-mode
- `docs/005-patch-conventions.md` — the authoritative source for how
  patches are laid out, named, and applied
- global convention: scripts must have hard-coded `${DIR}` and accept
  an override argument

## known fallbacks (warnings — treat as errors)

- If LuaJIT cannot be cross-compiled for aarch64, **do not** silently
  fall back to vanilla Lua. Stop the build with a loud error and
  create a follow-up issue.
- If GSplus's upstream build system resists cross-compilation cleanly,
  do not paper over it with shell hacks. Stop the build, propose a
  proper patch, capture it in `patches/`.
- If the user-supplied `.2mg` is missing or unreadable, the
  disk-image stage stops with a clear pointer to the docs that
  explain where to obtain a GS/OS boot image. No silent skip.
