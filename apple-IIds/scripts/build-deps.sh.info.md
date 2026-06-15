# scripts/build-deps.sh

Fetches the project's external dependencies as project-local artifacts.
Replaces "install these packages on your host system" with a single
self-contained command that pulls everything into `libs/`. Every
dependency it installs is gitignored — this script is the history of
how to acquire them.

## what it installs

| target                          | role                                 |
|---------------------------------|--------------------------------------|
| `libs/gsplus/`                  | the IIgs emulator we patch           |
| `libs/luajit/`                  | the broker's runtime                 |
| `libs/toolchain/aarch64/`       | ARM aarch64 cross-compiler           |

Each gets a `SOURCE.md` recording origin URL, pinned version, and
license summary.

## invocation

| invocation                              | effect                                       |
|-----------------------------------------|----------------------------------------------|
| `./scripts/build-deps.sh`               | idempotent fetch — skip what's already there |
| `./scripts/build-deps.sh --clean`       | wipe `libs/` deps and refetch                |
| `./scripts/build-deps.sh /custom/dir`   | override the project DIR                     |
| `./scripts/build-deps.sh --help`        | usage                                        |

## requirements

`git`, `curl`, `tar`, `xz`, `make` on the host. The aarch64 cross-
toolchain it downloads is a pre-built binary; nothing on the host
is compiled by this script.

## what it does not do

- Does not cross-compile anything. `build.sh` handles cross-compilation.
- Does not fetch the user's IIgs ROM or `.2mg` boot image — both are
  non-redistributable and supplied separately.
- Does not install the 65C816 cross-assembler (Merlin32 / ca65) yet;
  that arrives with issue 106.
