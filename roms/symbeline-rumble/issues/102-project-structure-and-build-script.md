# 102 — Project structure and build script

**Phase:** 1
**Blocked by:** 101 (toolchain).
**Blocks:** 103, 107, 108.

## Current behavior

The project directory scaffold exists (`src/`, `libs/`, `assets/`,
`patches/`, `scripts/`, etc.) but contains no source files and no build
orchestration. The two profiles `nds` and `native` are declared
architecturally but cannot yet be invoked.

## Intended behavior

A developer can run:

```
scripts/symbeline-build nds
scripts/symbeline-build native
scripts/symbeline-build both
```

…and have the appropriate artifact produced under `build-nds/` or
`build-native/`. Each invocation:

1. Sources the appropriate env (`scripts/env-nds.sh` for NDS).
2. Calls `apply_patches_begin` for the profile (from
   `patches/patches.sh`; see issue 103).
3. Runs the underlying build (`make` for NDS via libnds's Makefile
   convention; `cmake --build` for native).
4. Calls `unapply_patches_begin` to restore the trunk, regardless of
   success.
5. Calls `apply_patches_end` for post-build setup if any.
6. Reports a build summary to stdout and to
   `tmp/build-<profile>-<timestamp>.log`.

A companion script `scripts/symbeline-run <profile>` boots the last build.
For `nds` this means launching `melonDS` (preferred) or `desmume` against
`build-nds/symbeline.nds`. For `native` this means running
`build-native/symbeline`.

## Suggested implementation steps

1. Decide build system per profile:
   - `nds`: GNU Make + the standard libnds `Makefile` template (because
     fighting libnds's example Makefile creates more divergence than it
     saves).
   - `native`: CMake + raylib's `find_package(raylib)`.
2. Write `Makefile.nds` (template-based on libnds examples) and
   `CMakeLists.txt` (native-only build, in trunk; raylib linkage).
3. Write `scripts/symbeline-build`:
   - Honor the `${DIR}` argument convention.
   - Parse profile argument; dispatch via associative array of
     profile → builder function, not if-chain.
   - Wrap apply/unapply patches around the builder.
   - On failure: still unapply patches, then return non-zero.
4. Write `scripts/symbeline-run` with the same shape; emulator/binary
   chosen by profile via dispatch table.
5. Add a `.gitignore` excluding `build-*/`, `tmp/*` (the symlink is
   tracked, contents are not), `*.elf`, `*.o`, `*.nds`.
6. Initially the trunk has no real source — the build will fail until
   issues 107/108 land. That is expected; the script harness is what
   this issue delivers.

## Deliverable artifacts

- `Makefile.nds` (root of project; libnds-style template).
- `CMakeLists.txt` (root of project; for native).
- `scripts/symbeline-build`
- `scripts/symbeline-run`
- `.gitignore`

## Related documents

- `docs/004-architecture.md` — build entry-point spec.
- `docs/005-divergence-grid.md` — to be referenced from the build summary
  output (which divergences are active in this build).
