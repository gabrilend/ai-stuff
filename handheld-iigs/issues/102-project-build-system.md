---
name: project build system
phase: 1
status: pending
blockedBy: [101]
---

# 102 — project build system

A single command builds the project end-to-end and produces an artifact
ready to copy to the device.

## current behavior

No build system. The `build.sh` from issue 101 only compiles a hello-world
binary, not the project itself.

## intended behavior

- A top-level `build.sh` that:
  - has `${DIR}` hard-coded at the top
  - accepts `${DIR}` as the first argument
  - cross-compiles GSplus with our patches applied
  - compiles or bundles a LuaJIT runtime for aarch64
  - bundles the result into a single directory under `tmp/build/` (the
    `tmp/` symlink keeps build artifacts in RAM)
  - emits a manifest listing every produced file with its size and hash
- A `deploy.sh` that copies `tmp/build/` to the RG DS over ssh (using the
  device's host-mode USB-C as a network bridge, or over WiFi).

## suggested implementation steps

1. Write `build.sh` skeleton matching the global convention (hard-coded
   `${DIR}`, optional argument override, every command on its own line —
   no command chaining beyond a single `&&` for success-conditioning).
2. Have it invoke the aarch64 cross-toolchain from issue 101 to compile
   GSplus without modification first; confirm the binary runs on the
   device.
3. Add a `patches/` directory at project root following the **patch
   convention defined in `docs/005-patch-conventions.md`**: flat layout,
   numbered prefixes shared across surfaces, files named like
   `NNN-feature-name.{gsplus,gsos.s,tbox}.patch`. The corresponding
   broker-side modules live at `src/broker/NNN-feature-name.lua`.
4. Implement the **apply / unapply discipline** in `build.sh`. Each
   build stage applies only the patches relevant to its layer, runs
   the layer's tool (assembler, compiler), then reverts the patches.
   Upstream trees (`libs/gsplus/`, `libs/gsos-src/`) stay pristine
   between stages. A sentinel file in `tmp/` written on apply and
   removed on revert lets the next invocation detect a crashed or
   interrupted build and clean up.
5. Write `develop.sh` for interactive sessions: `develop.sh gsplus`
   applies the GSplus patches and leaves them applied so a developer
   can edit the patched source for hours; `develop.sh freeze` captures
   the new diff back into the appropriate `patches/*.patch` file;
   `develop.sh revert` returns the tree to pristine.
6. Cross-compile LuaJIT for aarch64. Record the LuaJIT version. If
   cross-compilation proves troublesome, document the failure and create
   a new issue describing the blocker — **do not silently fall back to
   vanilla Lua**.
7. Write the manifest emitter as a small Lua script under `src/build/`.
8. Write `deploy.sh`. Test the round-trip: edit a file locally, run
   `build.sh && deploy.sh`, see the change on the device.

## related documents

- `docs/001-architecture-overview.md`
- `docs/002-hardware-target.md` — note the two USB-C ports; deploy.sh may
  use either depending on which is the host-mode port
- `docs/005-patch-conventions.md` — the authoritative source for how
  patches are laid out, named, and applied
- global convention: scripts must have hard-coded `${DIR}` and accept an
  override argument

## known fallbacks (warnings — treat as errors)

- If LuaJIT cannot be cross-compiled for aarch64, **do not** silently
  fall back to vanilla Lua. Create an issue describing why and stop the
  build with a loud error.
- If GSplus's upstream build system resists cross-compilation cleanly,
  do not paper over it with shell hacks. Create an issue, propose a
  proper patch, document the patch in `patches/`.
