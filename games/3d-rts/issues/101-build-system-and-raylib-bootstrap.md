# 101 — Build System & raylib Bootstrap

## Status

RE-OPENED 2026-05-02. The original bootstrap (window opens, raylib
links, lifecycle reads input/ and writes goodbye) shipped 2026-04-27
and is captured in the completion log below. Two new requirements
landed during the architecture walkthrough — incremental
compilation, and strict input/ handling — both described in the
"Re-opened: 2026-05-02" section at the bottom of this file.

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

## Addendum (2026-04-27): Vendored, deterministic build

### Why

The original 101 leaned on the system-installed raylib at
`/usr/local/lib/libraylib.a`, which means a build is only as
reproducible as the user's machine state. Two developers with
different raylib versions can hit different bugs that look
identical in our source code. The fix is to **vendor** raylib at a
pinned upstream version, build it locally, and link against that
local archive — so every developer compiles against the same code.

pthreads cannot be vendored. It is not an independent library; on
Linux it is part of glibc and ultimately the kernel's `clone()`
syscall. We continue linking `-lpthread` from the system and
document the fact in `docs/003-tech-stack.md`.

The task-pool library at `libs/900-task-pool.{h,c}` (the threading
work in flight elsewhere) is acknowledged but not built into the
game yet — placeholder only.

### What changes

- A new manifest file `libs/sources` lists every vendored library
  with its pinned version. The build system reads this as the
  source of truth for "what version we want."
- `scripts/deps/fetch-raylib.sh` clones (or fetches into an
  existing checkout) raylib at the pinned tag and writes
  `libs/raylib/.installed-version` plus a content hash
  `libs/raylib/.installed-hash` of the source tree.
- `scripts/deps/build-raylib.sh` rebuilds raylib if and only if
  `libs/raylib/build-stamp` does not match the installed
  version + hash. The hash check catches manual edits to vendored
  sources that the version pin alone would not.
- `scripts/build.sh` orchestrates: fetch deps → build deps →
  build game.
- `Makefile` links the local archive `libs/raylib/src/libraylib.a`
  directly (no `-lraylib` lookup), with raylib's required system
  libs (`-lGL -lpthread -lm -ldl -lrt -lX11`) named explicitly.
- `scripts/deps/build-task-pool.sh` is a stub awaiting the
  threading work landing in `libs/`.
- `.gitignore` excludes `libs/raylib/` (vendored, not source).

### Validation strategy

For "as deterministic as we can make it":

1. **Pinned version** — `libs/sources` tag is the single source
   of truth. Bumping it triggers a refetch + rebuild.
2. **Content hash** — every fetch records a SHA-256 of the
   sorted source file tree. A `build-stamp` mismatch (different
   version *or* different hash) triggers a rebuild.
3. **No system raylib** — the linker is given an explicit archive
   path, not `-lraylib`. The system copy is ignored even if
   present.

Things still outside our control: compiler version, host CPU
flags, glibc version, X11 / OpenGL drivers. Those would need
container or toolchain pinning to address — out of scope for
this addendum.

### What was implemented (Phase 1 build infra)

- `libs/sources` — pinned-version manifest.
- `scripts/deps/fetch-raylib.sh` — version-aware fetch +
  source-hash record.
- `scripts/deps/build-raylib.sh` — stamp-based skip/rebuild.
- `scripts/deps/build-task-pool.sh` — placeholder stub.
- Updated `scripts/build.sh` and `Makefile` accordingly.
- `.gitignore` updated.
- `docs/003-tech-stack.md` updated with vendoring notes.

### What was tested

- Cold build (no `libs/raylib/`): fetch + raylib build + game
  build all run from a clean state.
- Warm rebuild: `scripts/build.sh` after a successful cold build
  is a no-op for raylib (build-stamp matches).
- Source tampering: editing a raylib source file changes the
  hash and triggers a raylib rebuild.
- Version bump: changing the tag in `libs/sources` triggers a
  refetch.
- Resulting binary's `ldd` does not list `libraylib` — confirms
  the local static archive is in use.

### What was not tested

- Cross-machine reproducibility (same source → same binary on a
  different host). Compiler flags and host libc differences make
  this very unlikely to be bit-identical even with vendored
  raylib; out of scope for this addendum.
- Behavior on a system without `git` available. Fetch fails
  loudly — the user's mono-repo expects git.

## Task pool integration (added retroactively)

**Not applicable.** Build infrastructure runs at compile time;
the task pool only exists at game runtime. The Makefile must
ensure `libs/900-task-pool.c` is compiled and linked when the
game adopts the pool, but that's a one-line addition (a wildcard
already picks it up if libs/ is in the source path).

## Re-opened: 2026-05-02 — Incremental compile + strict input/

Both requirements surfaced during the Phase 1 architecture
walkthrough. Captured here rather than in new issue files so the
build-system bootstrap stays a single coherent topic — the
foundational issue that everything else stands on.

### Requirement A — Incremental compilation

#### Why

Current behavior: every source touch triggers a full rebuild of
all C files in `src/` plus `libs/900-task-pool.c`. That's fine
with five files, but the tree is growing (selection, orders,
projectiles, factory, rally, demo, plus future sound and AI),
and a "touch one file → rebuild everything" loop becomes the
slowest step in the iteration cycle.

#### Intended behavior

`make` rebuilds only the C files whose source — or whose
transitively-included headers — changed since the last build.
A header change recompiles every file that includes it; an
unrelated `.c` file that doesn't include the changed header is
not recompiled. The first build from a clean tree compiles
everything once. Subsequent builds compile the minimum.

#### Suggested implementation steps

1. Per-file `.o` outputs under `tmp/obj/` (volatile scratch,
   matches the existing `tmp/` convention so a reboot wipes
   stale objects).
2. `%.o: %.c` pattern rule with `-MMD -MP` so gcc emits a
   per-object `.d` file listing the headers it included.
3. `-include $(OBJS:.o=.d)` so make picks up those header
   dependencies on subsequent builds. Missing `.d` files are
   benign on a first build (the `-` prefix on `-include`
   suppresses the warning).
4. Final link rule depends on `$(OBJS)`, not `$(SRCS)`.
5. `clean` removes `tmp/obj/` and `tmp/3d-rts`.
6. Verify: `touch src/050-units.c` rebuilds only that one
   `.o` plus the link; `touch src/020-terrain.h` rebuilds
   every `.o` that includes it (and only those); a clean
   build still works end-to-end.

#### Notes

- Object files going into `tmp/obj/` (rather than next to the
  sources) keeps `src/` clean and follows the existing pattern
  of "all build artifacts are volatile."
- The wildcard source discovery stays — adding a new `.c`
  file is still zero-config.
- This is a Makefile-only change. No source files move or
  rename.

### Requirement B — Strict input/ handling

#### Why

`count_input_files()` currently returns -1 if `<DIR>/input` is
missing or unreadable, and `main()` prints
`"note: input/ not readable at %s; proceeding"` and continues.
That's a fallback. Per the project's "prefer error messages and
breaking functionality over fallbacks" rule, a missing input
directory should be a hard error that aborts the run.

`GAME_DIR` is baked at compile time, so a missing `input/`
means either the project root never had one, or the binary is
being run against a relocated tree. Both are setup bugs that
deserve a loud failure, not a silent shrug.

#### Intended behavior

If `<GAME_DIR>/input/` cannot be opened, the program prints a
clear error to stderr (path attempted + `strerror(errno)`) and
exits with a non-zero status before opening any window or
allocating any pool. No raylib initialization, no goodbye write
— the run is aborted at the lifecycle's earliest stage.

The success path is unchanged: opening the directory, counting
non-hidden entries, printing the count, proceeding. Phase 1
still does nothing with input contents, so an empty `input/`
remains valid (count = 0).

#### Suggested implementation steps

1. `count_input_files()` keeps its return-on-error contract,
   but `main()` treats the -1 as fatal:
   ```c
   if (input_count < 0) {
       fprintf(stderr, "error: cannot read %s/input: %s\n",
               root, strerror(errno));
       return 1;
   }
   ```
2. The error happens *before* `InitWindow`, so there's no
   GPU/window cleanup needed on the abort path.
3. Drop the existing "proceeding" fallback comment from
   `count_input_files`; the contract is now "missing input/ is
   a setup bug."
4. Verify: removing `input/` from the project root and running
   the binary prints the error and exits with status 1; an
   empty `input/` still allows the program to start; a populated
   `input/` reports the file count as before.

#### Notes

- `errno` from `opendir` reaches `main` cleanly because
  `count_input_files` is the only thing between them and
  doesn't clobber it on the error path. If a future change
  inserts other syscalls between, capture the errno into the
  return path explicitly.
- This is independent of Requirement A and can land in either
  order.
