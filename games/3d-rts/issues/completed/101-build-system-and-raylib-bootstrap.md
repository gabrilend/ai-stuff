# 101 — Build System & raylib Bootstrap

## Status

DONE — completed 2026-04-27.

## Current behavior

There is no build configuration. `src/` is empty. The project cannot
produce a binary. No raylib link is wired up.

## Intended behavior

A `make` invocation from any directory builds a binary at
`tmp/3d-rts` that, when run, opens a raylib window titled "3d-rts"
with a clear color and a status line confirming the link to raylib
worked. Closing the window exits cleanly. A `scripts/build.sh` script
wraps `make` with the mono-repo's `${DIR}` convention so a user can
run the build from anywhere. A top-level `run` script builds (if
needed) then launches the binary.

The build output lives in `tmp/`, which on this machine is a symlink
to `/tmp/3d-rts/`. Build artifacts are intentionally in volatile
storage so a reboot wipes them and there is no chance of accidentally
committing a binary.

The program also obeys the mono-repo input/output lifecycle: at
startup it reads `<DIR>/input/` (Phase 1 has nothing to consume —
the read just enumerates and reports a count), and at exit it writes
`<DIR>/output/goodbye.txt`. The call sites are in place so future
phases can hook in without changing program lifecycle.

## Suggested implementation steps

1. Create `src/001-main.c` with the smallest raylib program that
   opens a window, draws a status line confirming the bootstrap, and
   exits on window close. Wrap it with the input-read / output-goodbye
   lifecycle.
2. Create `Makefile` at the project root with:
   - Hard-coded `DIR ?= /mnt/mtwo/programming/ai-stuff/games/3d-rts`
     at the top, overridable on the command line or in the
     environment.
   - `all` target that compiles `$(DIR)/src/*.c` to `$(DIR)/tmp/3d-rts`
     with `-Wall -Wextra -Wpedantic -std=c11`, linking against
     `-lraylib -lpthread -lm`.
   - `-DGAME_DIR="$(DIR)"` baked into the binary so it can resolve
     `input/` and `output/` regardless of launch directory.
   - `clean` target removing only the binary, not the rest of `tmp/`.
   - `run` target depending on `all` then executing the binary.
3. Create `scripts/build.sh` per mono-repo convention: hard-coded
   `DIR` at the top, optional positional argument override (with empty
   first arg falling back to default), then `make -C $DIR "$@"`.
4. Create top-level `run` script: same `DIR` convention, calls
   `make all` then `exec`s the binary.
5. Replace the `tmp/` directory with a symlink to `/tmp/3d-rts/`.
   Move any pre-existing scratch files into the new target.
6. Add a `.gitignore` excluding the `tmp` symlink and editor cruft.
7. Verify locally that `bash scripts/build.sh` from a non-project
   directory produces the binary, and that `./run` from any directory
   builds-then-launches.

## Related documents

- `docs/003-tech-stack.md` — language/build choices.
- `docs/004-architecture.md` — module index this issue creates the
  first file for.

## Notes

Future issues add files to `src/`. The Makefile uses a wildcard so
new files are picked up without editing it. If raylib is missing on
the system the link error is the right failure — do not add
fallbacks.

On this machine raylib is installed as a static archive at
`/usr/local/lib/libraylib.a`, so `ldd` on the produced binary does
not list `libraylib.so` — raylib code is baked directly into the
binary. The Makefile does not need to know about this; `-lraylib`
finds either form.

## Completion log

### What was implemented

- `src/001-main.c` — raylib hello-world with input-read + goodbye
  lifecycle. Functions wrapped in vimfolds per mono-repo convention.
- `Makefile` — `all` / `clean` / `run`, `DIR ?=` override,
  `-DGAME_DIR` define, output to `tmp/`.
- `scripts/build.sh` — DIR override + extra arg forwarding to
  `make -C`.
- `run` (project root) — incremental build then `exec` of the binary.
- `tmp/` replaced with symlink to `/tmp/3d-rts/`. The pre-existing
  `test-coroutine-pool` and `test-coroutine-pool.c` from the
  coroutine pool library were moved to the new target unchanged.
- `.gitignore` updated: `tmp` and `tmp/` ignored; the obsolete
  `build/` line removed.

### What was tested

- Build from `/tmp` via `scripts/build.sh` (non-project directory).
  Compiled with no warnings under `-Wall -Wextra -Wpedantic -std=c11`.
- Build from project root via `make all`.
- Incremental rebuild: `touch src/001-main.c` triggers rebuild; a
  second `make all` reports "Nothing to be done."
- `scripts/build.sh "" clean` — verifies empty-DIR fallback and
  forwarding of extra args to `make`.
- `clean` target removes only the binary; `test-coroutine-pool`
  and `test-coroutine-pool.c` survive in `tmp/`.
- Binary properties: ELF 64-bit, dynamically linked against libc/libm
  (raylib is statically linked), `GAME_DIR` string visible in
  `strings` output.
- `run` script (visual): user confirmed the 800×600 window opens
  with the status text and exits cleanly on close.

### What was not tested

- The `output/goodbye.txt` write was not visually inspected by the
  user post-close. The code path is straightforward (an `fopen`/
  `fputs`/`fclose`) but a regression here would not show until
  someone reads the file. Worth a quick check on the next run.
- Behavior on a system without raylib installed. Per the issue
  contract, link failure is the expected outcome — explicitly not a
  case requiring fallback.
- Behavior with non-empty `input/`. Phase 1 does nothing with input
  contents yet; the `count_input_files` path was exercised only for
  the empty case.
- Headless launch (no `xvfb-run` available on the machine). Not a
  defect — the bootstrap is a graphical program and only needs to
  run with a display.
