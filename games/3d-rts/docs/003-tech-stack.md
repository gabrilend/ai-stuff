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
- `Image`/`Mesh` for the heightmap (raylib has heightmap helpers — use them).
- `DrawCube`/`DrawCubeWires` for units, `DrawCylinderEx` for javelins.

If raylib is missing something we need (e.g. picking a point on a
heightmap from a screen ray), we write a small helper, not a fork.

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

## Build

A hand-written `Makefile` is the primary build. It must:

- Have a hard-coded `${DIR}` at the top set to the project root, with an
  override mechanism so the file works when invoked from any directory.
- Build, clean, run, and run-with-debug targets.
- Compile with `-Wall -Wextra -Wpedantic`, treat warnings seriously, and
  link against raylib and pthread.
- Place objects in a separate `build/` directory so `src/` stays clean.

The Phase 1 build script lives at `scripts/build.sh` and is itself a
thin wrapper around `make` that respects the same `${DIR}` convention
required of all scripts in this mono-repo.

## What we do not use

- No CMake, no Bazel, no Meson — they are larger than the project.
- No Python in the build path.
- No external scripting layer in the game itself.
- No SDL, no GLFW, no OpenGL directly. raylib is the boundary.
