---
name: source and toolchain
phase: 1
status: pending
---

# 101 — source and toolchain

Stand up everything the build needs as **project-local artifacts** —
the GSplus emulator source, the aarch64 cross-toolchain, and LuaJIT —
fetched and installed by a single script under `scripts/`. All vendored
upstream sources and built dependencies are treated as build artifacts:
gitignored, recreatable from scratch by re-running the script.

## current behavior

The project directory has no source code, no toolchain, no fetcher
script. The Anbernic RG DS hardware specs are pinned in
`docs/002-hardware-target.md` but no compiler that targets it exists
inside the project.

## intended behavior

- A `scripts/build-deps.sh` at the project root fetches and installs
  every external dependency the project needs. It follows the global
  script convention: hard-coded `${DIR}` at the top, accepts an
  override as an argument, one command per line. It is idempotent:
  re-running it skips dependencies already present, and `--clean`
  removes them and starts fresh.
- The script installs into `libs/`:
    - `libs/gsplus/` — clone of GSplus upstream
      (https://github.com/digarok/gsplus), at a pinned tag or commit
    - `libs/luajit/` — clone of LuaJIT, at a pinned tag
    - `libs/toolchain/aarch64/` — ARM's pre-built `aarch64-none-linux-gnu`
      cross-toolchain, extracted from the official tarball
- A `libs/gsplus/SOURCE.md` records the exact pinned version, upstream
  URL, license summary, and re-fetch command. Same for LuaJIT and the
  toolchain.
- `.gitignore` excludes `libs/gsplus/`, `libs/luajit/`,
  `libs/toolchain/`. The project history records *how to acquire* the
  dependencies, not the dependencies themselves.
- A minimal `scripts/hello-aarch64.sh` cross-compiles a "hello world"
  C program using the in-project toolchain and stages it under
  `tmp/build/hello`. Confirms the toolchain works.
- The RG DS will eventually run that binary; the on-device test is
  deferred until issue 120 (the phase 1 demo) when the hardware is in
  hand. The toolchain is provably correct as soon as the cross-built
  binary runs through `qemu-aarch64-static` on the host as a sanity
  check.

## suggested implementation steps

1. Survey `/home/ritz/programming/ai-stuff/libs/` and
   `/home/ritz/programming/ai-stuff/my-libs/` for an existing GSplus
   or LuaJIT checkout. (Already done 2026-05-21 — neither is present
   in the shared trees.)
2. Write `scripts/build-deps.sh`. Sections:
    - argument parsing (`--clean`, optional `${DIR}` override)
    - requirement check (`git`, `curl`, `tar`, `xz`, `make`)
    - layout setup (create `libs/`, `tmp/build/`)
    - fetch + pin GSplus
    - fetch + pin LuaJIT
    - download + extract the ARM aarch64 cross-toolchain
    - emit `libs/*/SOURCE.md` for each
    - verify (binaries exist, headers exist, version queries succeed)
3. Extend `.gitignore`.
4. Write `scripts/hello-aarch64.sh` that uses the in-project toolchain
   to cross-compile a trivial program. Run it through
   `qemu-aarch64-static` if available on the host.
5. Document the toolchain choice and version in
   `docs/005-toolchain-setup.md` (new doc; add to TOC).
6. Defer the device-side open questions (`/dev/input/eventN` mapping,
   `/dev/fb*` device(s), USB-C semantics, stylus differentiation, gyro
   IIO device) to issue 120 when the device is in hand.

## related documents

- `docs/001-architecture-overview.md` — layer 1 (host) section
- `docs/002-hardware-target.md` — RG DS specs and open questions
- `docs/005-patch-conventions.md` — patch surfaces the toolchain enables
- `notes/vision/000-vision.md`

## related tools

- GSplus upstream (https://github.com/digarok/gsplus) — BSD-licensed
- LuaJIT upstream (https://github.com/LuaJIT/LuaJIT) — MIT-licensed
- ARM aarch64 cross-toolchain
  (https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads)
- `qemu-aarch64-static` (optional; host-side validation only)

## license note

GSplus is BSD-style. LuaJIT is MIT. ARM's cross-toolchain ships under
GPL-with-runtime-exception (the produced binaries are unencumbered).
The Apple IIgs ROM is **not** redistributable and is supplied by the
end user (issue 103). The GS/OS `.2mg` is also user-supplied (issue
106 covers how we modify it without rebuilding from source).

## blockers

- This issue blocks every other issue in phase 1.
