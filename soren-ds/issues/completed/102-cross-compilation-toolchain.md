# 102 — Cross-compilation toolchain

## Current behavior

The aarch64-elf cross-toolchain is built from source and
installed at `libs/cross/`. Binutils 2.44 and GCC 16.1.0 (with
libgcc) are present, were verified against pinned SHA-512
checksums fetched from the official release infrastructure
before extraction, and pass the smoke test in
`scripts/check-toolchain` — a one-function freestanding C
program compiles end to end and `file` reports the result as a
64-bit ARM aarch64 ELF. Six parallel make jobs were used (held
under `nproc` deliberately to keep the system cool during
ambient-hot conditions); the choice is configurable in
`scripts/build-deps`.

## Intended behavior

A reproducible cross-compilation toolchain built from source
into the project tree, owned by the project rather than by the
host system. The toolchain:

- Targets the exact ARM chip identified in 101 (a Cortex-A55
  inside the Rockchip RK3568 — `aarch64-elf` as the GNU target
  triple for bare-metal ARMv8-A).
- Compiles C source to a freestanding object file (no hosted
  libc, since the kernel is freestanding).
- Links objects into an image whose entry point and load address
  are specified by a linker script under our control.
- Produces output in the format the device's bootloader
  eventually expects (we wrap it into an Android boot.img later
  in issue 110b; phase 1's earlier issues just need an ELF and
  a raw binary).

The toolchain lives under `libs/cross/` in the project tree. The
final installed compiler at
`libs/cross/bin/aarch64-elf-gcc` is the only path any other
script or build rule references. The system's compiler, package
manager, and PATH are not perturbed; nothing the developer
installs after this point can disturb the toolchain we built.

Source tarballs (binutils, GCC, plus GCC's GMP / MPFR / MPC /
ISL prerequisites) are downloaded once and cached under
`libs/sources/` so an offline rebuild needs no network. The
build itself happens in `tmp/build/` — the project's RAM-backed
work directory — so the five-gigabyte intermediate tree of
`.o`, `.a`, and Makefile droppings never touches the SSD. Only
the ~200 MB installed compiler persists, in `libs/cross/`.

Two scripts under `scripts/` carry out the work and verify it:

- **`scripts/build-deps`** does the building. It pulls each
  pinned source tarball if it isn't already cached, verifies
  its SHA-256 against the value pinned in the script, extracts
  it under `tmp/build/`, configures with the project prefix,
  builds in dependency order (binutils first, then GCC with
  its prerequisites resolved by GCC's own
  `contrib/download_prerequisites`), and installs to
  `libs/cross/`. Idempotent: rerunning it against an already-
  complete `libs/cross/` exits quickly. Progress output follows
  the same shape as `push-to-usb` (a few headline lines, a
  growing progress line per stage, color-coded `done`/`error`).
  No sudo required at any step — every path the script
  touches is owned by the developer's user.
- **`scripts/check-toolchain`** confirms the toolchain is in
  place, reports the binutils and GCC versions it found, and
  compiles a freestanding "return zero" C program end to end
  to confirm the pipeline produces an `aarch64` ELF. This is
  the smoke test other phase-1 issues lean on when they want
  to assume the toolchain works.

The host C compiler that builds binutils and GCC is the
developer's system compiler (clang or gcc). Bootstrapping the
host compiler from source is a much larger project that does
not change anything the kernel does, so it is explicitly out of
scope here. The toolchain we *ship* — the one the kernel
itself depends on — is the one we build. The toolchain we *use
to build it* is a host concern.

## Suggested implementation steps

1. Pin specific versions of binutils, GCC, and the GMP / MPFR /
   MPC / ISL prerequisites. Record each tarball's URL and
   SHA-256 checksum as variables at the top of `build-deps`,
   beside a comment naming the page they were copied from. Pin
   the binutils and GCC most recent stable major-release-of-the-
   moment unless there is a known regression.
2. Implement `scripts/build-deps`. Download to `libs/sources/`
   if missing, verify checksums against the pinned values,
   extract under `tmp/build/`, configure binutils with
   `--target=aarch64-elf --prefix=$DIR/libs/cross/
   --disable-nls --disable-werror`, build, install, then
   extract GCC, run its `contrib/download_prerequisites` to
   resolve the math libraries in-tree, configure with
   `--target=aarch64-elf --prefix=$DIR/libs/cross/
   --enable-languages=c --without-headers --disable-shared
   --disable-multilib --disable-nls`, build, install. The
   project root variable at the top is overridable by argument
   per project convention.
3. Implement `scripts/check-toolchain`. Look for
   `libs/cross/bin/aarch64-elf-gcc`. Report the binutils and
   GCC versions. Compile and link a minimal freestanding C
   program (a single function returning zero, with the
   appropriate `__attribute__((noreturn))` and entry-point
   metadata for a kernel rather than a hosted program). Confirm
   `file` reports the output as `ELF 64-bit LSB executable, ARM
   aarch64`.

## Related documents

- `docs/014-hardware-overview.md` — the SoC the toolchain
  targets.
- `docs/002-roadmap.md` — phase 1.

## Blocked by

101.

## Blocks

103, 104, every later phase 1 issue.
