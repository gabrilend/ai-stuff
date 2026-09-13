# 805 — The handheld build

| | |
| --- | --- |
| Phase | 8 — The Handheld |
| Blocked by | 801 |
| Blocks | 707, 806 |
| Reads | [the handheld](../docs/012-the-handheld.md) |
| Open questions | none |

## Current behavior

`./compile --target handheld` exists and **refuses, by name**, while any of three
things is absent: the ceramic core engine in `libs/900-cera.c`, the aarch64
cross-toolchain that the sibling project's build-deps script installs under its
own `libs/cross/`, and a `maps/` directory holding the simulation as a map. It
says which of the three is missing and where each comes from, and it exits
non-zero either way, because even with all three present nothing yet knows how
to use them. The computer target parses every Lua file and packages a `.love`
archive into the RAM tier.

The engine is pinned by commit in `input/dependencies`, and
`./install-dependencies` copies its two files out of the sibling repository's
history at that pin into `libs/`, numbered into the 900 band.

## Intended behavior

The handheld target grows the steps that turn a map and its boxes into
something the sibling system runs, each step a function the compile script
dispatches to in order, each refusing by name when its input is missing:

1. **Install.** The engine's files are present at the pinned commit, or the
   step says to run `./install-dependencies`.
2. **Generate.** The engine's generator reads the box sources in `src/boxes/`
   and the map in `maps/`, asks the C compiler for every size, and emits the
   construction calls the map describes. The map mentions no types; every size
   the engine runs on is one the compiler evaluated.
3. **Cross-compile.** The engine, the generated construction, and every box
   source are compiled with the sibling's aarch64 compiler for a bare
   Cortex-A55 — no libc assumed — into one object the sibling kernel's runtime
   loads as a program.
4. **Package.** The program object and the map text land in the RAM tier's
   build directory beside the `.love` archive, with a manifest naming the engine
   pin, the toolchain version, and the git commit of this project, so a build
   on a device can be traced to its sources.
5. **Verify on the desktop first.** The same map and boxes are built with the
   host compiler through the engine's own build and run for a fixed number of
   ticks, and the hash printed is compared with the Lua's for the same seed. A
   handheld build whose desktop twin disagrees with the Lua is not packaged.

How the packaged program reaches the device — the sibling project's SD-card
image, its push-to-USB script, or its on-device compile — is that project's
business and is called from here rather than reimplemented. The compile script
already carries the target dispatch table; this issue adds rows to it.

## Suggested implementation steps

1. Read `../compile` and its handheld function; keep its refusals and replace
   its final "nothing knows how to use this" with the five steps as functions,
   dispatched in order.
2. Add the engine's generator invocation, run in the project directory through
   `env --chdir` as the archiver already is, writing into the RAM tier.
3. Add the cross-compile step, reading the toolchain path from
   `../input/dependencies` rather than hard-coding it twice.
4. Add the desktop twin step and the hash comparison against the headless
   runner's output for the same seed; refuse to package on a mismatch.
5. Add the manifest to the packaged output.
6. Add the sibling project's install path as the last step, behind a flag, so a
   build never touches a device unless asked.

## Related documents and tools

- [The handheld](../docs/012-the-handheld.md) — the build section
- `../compile` — the script this issue grows
- `../input/dependencies` — the engine pin and the toolchain
- `tests/026-the-handheld.lua`

## Still open

- Whether the boxes can be compiled with the host compiler for the desktop
  twin and the cross-compiler for the device from one source set with no
  conditional compilation. The engine promises a box is a plain C function;
  the transport boxes of issue 707 are the ones most likely to break the
  promise.
