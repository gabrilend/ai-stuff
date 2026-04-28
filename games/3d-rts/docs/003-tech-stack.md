# 003 — Tech Stack

The vision is explicit: **C, raylib, pthreads.** This document records why
each choice fits and what to avoid in service of those choices.

## Language: C

C was chosen by the vision. The mono-repo otherwise prefers Lua (LuaJIT
syntax), but the vision overrides this for this project. Notes on style:

- C99 or C11 — pick whichever raylib's headers compile cleanly under and
  hold to it. Do not mix.
- No C++ headers, no `extern "C"` shenanigans.
- `static` for any function not used outside its translation unit.
- One job per translation unit. The simulation, render, input, terrain,
  factory, and order modules each get their own `.c`/`.h` pair.

Comments explain *why*, never *what*. If a constant is the way it is because
of an observed bug or a deliberate trade-off, that reasoning lives in a
comment next to the constant.

## Renderer: raylib

raylib gives us a 3D camera, mesh rendering, basic shape primitives,
input, and a window — exactly what is needed and not much more. We use
raylib's existing helpers wherever they exist; we do not write our own
matrix code unless raylib's coverage is missing.

Specific uses:

- `rlgl`-level access only when a built-in primitive is missing.
- `Camera3D` for the player's view.
- `Image`/`Mesh` for the heightmap. raylib's `GenMeshHeightmap`
  assumes Y-up and so is **not** used; the mesh is built by hand.
- `DrawCube`/`DrawCubeWires` for units, `DrawCylinderEx` for
  javelins.

If raylib is missing something we need (e.g. picking a point on a
heightmap from a screen ray), we write a small helper, not a fork.

raylib is **vendored**: the source is fetched from upstream at the
version pinned in `libs/sources` and built locally into
`libs/raylib/src/libraylib.a`. Linking is against that explicit
archive path — never `-lraylib`, which would risk picking up a
system copy at a different version. The fetch + build flow is
orchestrated by `scripts/build.sh` calling
`scripts/deps/fetch-raylib.sh` and `scripts/deps/build-raylib.sh`.

Why vendor: same source on every machine means every developer hits
the same raylib bugs (or doesn't), so misbehaviors are about *our*
code, not about whose system raylib is which. See the addendum on
issue 101 for the full validation strategy.

## Threading: pthreads

We use POSIX threads, not C11 threads, to match the vision. The threading
model is documented in `004-architecture.md`. Key constraints raised here
because they shape every other decision:

- Game state is owned by the simulation thread. The render thread reads
  a published snapshot. Input events are pushed to a queue the simulation
  thread drains.
- No global mutable state outside this snapshot/queue boundary.
- Mutexes guard the snapshot publication and the input queue. Nothing
  else needs locks if the boundary is respected.

**pthreads cannot be vendored.** It is part of glibc on Linux —
`libpthread.so` ships with the system C library and ultimately
delegates to the kernel's `clone()` syscall. There is no upstream
"pthreads project" to pin, so we link `-lpthread` from the system
and treat the system libc as part of the platform. raylib is
vendored; pthreads cannot be.

The in-tree task-pool library (under `libs/`, currently the
threading work in flight) is *additional* to pthreads, not a
replacement for it. Its build is wired up in
`scripts/deps/build-task-pool.sh` (placeholder until the source
stabilises).

## Build

A hand-written `Makefile` is the primary build. It must:

- Have a hard-coded `${DIR}` at the top set to the project root, with an
  override mechanism so the file works when invoked from any directory.
- Build, clean, run, and run-with-debug targets.
- Compile with `-Wall -Wextra -Wpedantic`, treat warnings seriously, and
  link against the **vendored** raylib archive (explicit path) plus
  the system `-lpthread -lm -lGL -ldl -lrt -lX11`.
- Place build artifacts in `tmp/` (which is a symlink to volatile
  scratch storage) so `src/` stays clean and a reboot is a hard reset.

`scripts/build.sh` is the entry point: it runs each dependency
fetch + build in turn, then invokes `make`. Each step lives in its
own script under `scripts/deps/` so the orchestration in
`build.sh` is a flat list — easy to read, easy to extend.

## What we do not use

- No CMake, no Bazel, no Meson — they are larger than the project.
- No Python in the build path.
- No external scripting layer in the game itself.
- No SDL, no GLFW, no OpenGL directly. raylib is the boundary.
