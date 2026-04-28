# 101 — Build System & raylib Bootstrap

## Status

TODO

## Current behavior

There is no build configuration. `src/` is empty. The project cannot
produce a binary. No raylib link is wired up.

## Intended behavior

A `make` invocation from any directory builds a binary at
`build/3d-rts` that, when run, opens a raylib window titled "3d-rts" with
a clear color and a single line of HUD text confirming the link to raylib
worked. Closing the window exits cleanly. A `scripts/build.sh` script
wraps `make` with the mono-repo's `${DIR}` convention so a user can run
the build from anywhere.

## Suggested implementation steps

1. Create `src/001-main.c` with the smallest raylib program that opens a
   window, draws "raylib OK" each frame, and exits on window close.
2. Create `Makefile` at the project root with:
   - Hard-coded `DIR ?= /mnt/mtwo/programming/ai-stuff/games/3d-rts` at
     the top, overridable by environment.
   - `all` target that compiles `$(DIR)/src/*.c` to `$(DIR)/build/3d-rts`
     with `-Wall -Wextra -Wpedantic -std=c11 -lraylib -lpthread -lm`.
   - `clean` target removing `$(DIR)/build`.
   - `run` target depending on `all` then executing the binary.
3. Create `scripts/build.sh` per mono-repo convention: hard-coded `DIR`
   at the top, optional positional argument override, then `make -C $DIR`.
4. Add a `.gitignore` excluding `build/` and any editor cruft.
5. Verify locally that `bash scripts/build.sh` produces a window.

## Related documents

- `docs/003-tech-stack.md` — language/build choices.
- `docs/004-architecture.md` — module index this issue creates the first
  file for.

## Notes

Future issues add files to `src/`. The Makefile uses a wildcard so new
files are picked up without editing it. If raylib is missing on the
system the link error is the right failure — do not add fallbacks.
