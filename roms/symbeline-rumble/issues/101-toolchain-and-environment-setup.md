# 101 — Toolchain and environment setup

**Phase:** 1
**Blocks:** every other issue in phase 1.

## Current behavior

There is no toolchain configured. `scripts/` is empty. The build profiles
`nds` and `native` are declared in `docs/004-architecture.md` but no
compiler has been validated against either.

## Intended behavior

A developer on a clean machine can run a single setup script and end up
with:

- **For `nds`:** devkitPro pacman installed; the `nds-dev` group installed
  (includes devkitARM, libnds, libfat, examples). The environment variables
  `DEVKITPRO`, `DEVKITARM`, and the toolchain's `bin/` on `PATH` are
  exported from a sourceable file (`scripts/env-nds.sh`).
- **For `native`:** a host C/C++ compiler (gcc or clang), `make`, `cmake`,
  `pkg-config`. The native rendering backend is **raylib** (chosen for
  consistency with the 3d-rts project in the same workspace); installed via
  pacman or built from `libs/raylib/`. SDL2 may be added later if raylib
  cannot service touchscreen input adequately on Anbernic-class devices.
- **Verification:** `scripts/check-toolchains` prints versions and returns
  non-zero if any tool is missing.

## Suggested implementation steps

1. Write `scripts/install-toolchain.sh`:
   - Detect distro (`/etc/os-release`).
   - For Arch-family: invoke `pacman -S` for `devkitpro-pacman`, then
     `dkp-pacman -S nds-dev`. Install `raylib`, `base-devel`, `cmake`.
   - For other distros: print the equivalent instructions and exit.
   - Honor the `${DIR}` argument convention (global rule).
2. Write `scripts/env-nds.sh` to be `source`d before NDS builds. Sets
   `DEVKITPRO`, `DEVKITARM`, prepends toolchain `bin/` to `PATH`.
3. Write `scripts/check-toolchains.sh`: a list of tools and a probe per
   tool. Use a dispatch table (associative array of `tool → probe-cmd`),
   not an if-chain.
4. Verify by running `scripts/check-toolchains` on both an Arch host and
   the existing dev box. Capture output into `tmp/toolchain-check.log`.

## Notes on language choice

The global preference is Lua/LuaJIT. The DS rules that out for the runtime
(no JIT, paid-for memory). Lua remains the preferred language for *build-
time tools* and asset emitters; runtime code is C across both profiles to
preserve trunk shape. This trade was committed in the project memory on
2026-05-13.

## Related documents

- `docs/004-architecture.md` — build entry points.
- `docs/008-fixed-point-math.md` — informs which math headers we need from
  libnds.

## Deliverable artifacts

- `scripts/install-toolchain.sh`
- `scripts/env-nds.sh`
- `scripts/check-toolchains.sh`
- `tmp/toolchain-check.log` (sample run, in `tmp/` so RAM-backed).
