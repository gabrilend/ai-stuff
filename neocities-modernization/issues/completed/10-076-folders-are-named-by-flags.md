# Issue 10-076: Folders Are Named By Flags, And A Stray Word Is An Error

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: High
- **Type**: Enhancement
- **Status**: Completed (2026-11-03)
- **Created**: 2026-11-02
- **Related**: 10-005 (the run script's flags; its usage line
  `./run.sh [FLAGS] [PROJECT_DIR]` is the shape this replaces), 8-014 (made
  `--dir` the assets folder for every program), 10-065 (values are given
  explicitly; its fixes to the child parsers are what this must keep intact)

## Current Behavior

**Built, 2026-11-03.** The Intended Behavior below is what the project does
now.

The two readers:
- `libs/project-dir.lua` -- `read(args, default, value_flags)` returns the
  folder from `--dir PATH` / `--dir=PATH` (or the default) and every other
  word; a word that is neither a flag nor the value of a declared value flag
  stops the program with one line naming it (an `error()` instead when
  `raise_errors` is set, for tests). `value_flags = "*"` means every flag
  takes the next word (`scripts/write-run-overrides`). `read_if_run` is for
  files that are both programs and libraries: when run, `read`; when loaded
  by another program, only that program's `--dir` (`find_dir`), judging none
  of its other words -- the old modules read the PARENT's first bare word as
  their own folder. Loaded by file path, since `package.path` is built from
  the folder it returns.
- `libs/project-dir.sh` -- `project_dir_read DEFAULT "VALUE FLAGS" "$@"` sets
  `DIR` and `PROJECT_ARGS` the same way; sourced, so its exit stops the
  script.
- Test: `libs/project-dir.test.lua` (20 checks, Lua and shell given the same
  cases).

Every program reads its folder through them: 130 programs (stages, scripts,
tests), counted by `scripts/check-folder-flags`, which lists any program that
does not CALL a reader (a mention in a comment does not count). `run.sh`
reads `--dir` with its own flag loop (it also checks every value it takes)
and says so with a "project-dir: own" comment; four files take no project
folder and say why with "project-dir: none": `libs/utils.lua` (a library,
never run), `scripts/exit-status.sh` and `scripts/stage-timing.sh` (sourced;
`stage-timing.sh` now stops when its caller set no `DIR`, where it used to
fall back to a written-in path), and `scripts/validate-output-worker.lua`
(an internal worker whose words are a width, a findings file and a batch of
page paths from `xargs`).

Operands that were bare words became flags, each with its caller:
`find-in-transcripts --phrase`, `file-screenshot --picture --name`,
`check-poem-dates --poems`, `check-rankings-match-poems --poems --cache-dir`,
`zip-extractor.lua --temp`, `extract-{fediverse,messages,notes}.lua --source`,
`extract-bluesky-data --car --output` (its first word used to be the folder OR
the archive, and when it was the folder it was also read as the archive),
`sync-external-files --source`, `generate-hope-card-pdf --input --output`,
`fsync-logger --log`, `check-inline-lua-quotes --file`,
`measure-centering-effect --model --sample` (the model is required now; it
defaulted to embeddinggemma-300m). `scripts/run-tests` hands each test
`--dir DIR`. About 110 call sites pass `--dir` (rewritten by scratch tools
that matched each program's name followed by a folder variable; the full
plan-only build and every test found the stragglers they missed).

Folder fallbacks removed:
- `utils.init_assets_root`: `--assets`, else `config.lua`
  `asset_paths.assets_root`, else an error naming both (no `<project>/assets`).
- `generate-embeddings.sh`: requires `--assets=PATH`, and uses it where it
  wrote `$DIR/assets` four times; its unused `ASSETS_ARG` is gone. `run.sh`
  passes it.
- `libs/config-loader.lua`: its own location (or the starting folder, when
  loaded through a relative `libs/?.lua`); else an error naming
  `set_project_root`. The two written-in folders (one of them where the
  project lived before it moved) and "return relative path and hope for the
  best" are gone.
- `libs/inference-server-config.lua`: its own location, not the first
  `libs/` on `package.path`; a `config.lua` that cannot be read is an error,
  where it used to be taken as empty.

Notes files: `scripts/write-info-notes` writes a program's `.info.md` from
its header and the comment above each function, never over an existing one
(a file it wrote says so on its first line). Run with `--missing`, it wrote
the 59 programs that had none; tests are left out unless `--include-tests`.

Tests: `scripts/folder-flags.test.sh` (23 checks: run.sh's flags and its
refusal of a bare word; each child run.sh starts refusing one; a loaded
library taking its parent's `--dir`; an unnamed assets folder being an
error; and `check-folder-flags` passing). Whole suite: 57 passed, 2 could not
run (no inference server). The owner's full build command, plan-only: 23
calls planned, none refused.

The old `--dir` stays in the phase-16 phone server issue, where it is that
program's own media-folder flag.

Before this issue, `run.sh` learned its two folders two different ways:

- **The project folder** (the shell variable `DIR`, a string path) is set by
  any word on the command line that has no leading dashes. Each such word
  replaces the one before, and the last one wins without a word said.
- **The assets folder** (the shell variable `ASSETS_DIR`, a string path;
  default `<project>/assets`) is set by `--dir PATH`. The flag's name is the
  project folder's variable name, so it reads as the project folder.

What that cost, 2026-11-02: the owner typed `wordcloud-poems 64` with its
two dashes missing. `wordcloud-poems` became the project folder, then `64`
replaced it, and the run stopped on
`stage-timing library not found: 64/scripts/stage-timing.sh` -- an error
about a missing library, nothing about the mistyped flag.

One level down, `run.sh` hands every child program the assets folder as
`--dir PATH` (the `ASSETS_ARG` string, and two inline Lua blocks that call
`utils.init_assets_root({'--dir', ...})`). The child parsers that read it:

- `libs/utils.lua`: `parse_assets_dir` (finds the value), and
  `parse_cli_args` / `parse_interactive_args` (skip it as a pair).
- `src/main.lua` (its own finder), `src/wordcloud-generator.lua`,
  `src/generate-word-pages.lua`, `src/generate-gallery-pages.lua` (skip it as
  a pair).
- `generate-embeddings.sh` (its own `--dir=PATH`; `run.sh` does not pass it).
- `scripts/seed-reproducibility.test.sh` passes `--dir` to the generator.

In every child, a bare word is the project folder (the house rule that a
script takes its project folder as an argument), so a `--dir PATH` that a
child no longer recognises would hand PATH to the project folder -- the
exact failure 10-065 fixed for stage 3 ("No valid input found" under
`assets/`).

## Intended Behavior

Owner, 2026-11-02: "this requirement can be gated behind a cli flag." /
"can we rename this then? maybe assets?" / "then let's do --dir as the
project directory." And, on whether bare words should be accepted once a
flag exists: "If so, then we shouldn't accept any bare words."

- `run.sh --dir PATH` sets the project folder. Without it, the hard-coded
  path at the top of the script is the project folder, as now.
- `run.sh --assets PATH` sets the assets folder (default `<project>/assets`).
- `run.sh` refuses every bare word: it stops before any work, names the
  word, and says the flags take their values after them. The message for
  `wordcloud-poems 64` names `wordcloud-poems`.
- Every child program takes the assets folder as `--assets PATH` (and
  `--assets=PATH`). A child that is given `--dir` stops with an error saying
  what `--dir` now means and naming `--assets`, so an old call can never
  turn an assets path into a project path.
- The children's own bare-word project folder is left as it is (see Open
  questions).

### Second part (owner, 2026-11-03)

On every program taking `--dir` and refusing plain words: "sure". On the
assets folder's silent `<project>/assets` default: "should remove fallback
defaults".

- **Every program** -- the stages, the scripts, and the tests -- takes its
  project folder as `--dir PATH` (or `--dir=PATH`) and stops, naming the
  word, on any word that is neither a flag nor a flag's value. Without
  `--dir`, the program's written-in default, as now.
- One shared reader per language does this, so every program says it the
  same way: `libs/project-dir.lua` (loaded by path, before `package.path`
  exists, since `package.path` is built from the folder it finds) and
  `libs/project-dir.sh`. Each takes the program's flags that carry a value,
  so their values are not mistaken for stray words.
- `--dir` in a child program now means its project folder, as in `run.sh`;
  the first part's "stop on `--dir`" guard is retired with it.
- `scripts/run-tests` hands each Lua test `--dir DIR`; every caller of a
  program (`run.sh`, scripts that call scripts, tests) passes `--dir`.
- `scripts/check-folder-flags` lists every program that still reads its
  folder from a plain word or does not use the shared reader; it runs as a
  test, so a new program cannot slip back.
- The assets folder: from `--assets PATH`, or from `config.lua`
  `asset_paths.assets_root`; neither is an error naming both. No silent
  `<project>/assets`. `generate-embeddings.sh` reads `--assets` (it ignored
  it before and wrote `$DIR/assets` itself in four places), and `run.sh`
  passes it.
- The two places a library guesses the project folder when it was not
  told: `libs/config-loader.lua` (its own location, then a list of two
  known paths, then "return relative path and hope for the best") and
  `libs/inference-server-config.lua` (`package.path`, then a written-in
  path). The first way of each stays -- a library finding the project it
  sits in is not a guess -- and the guesses after it go: when neither
  `set_project_root` nor the library's own location gives the folder, it
  is an error naming `set_project_root`.
- Other fallbacks found while looking (date guessing, terminal width,
  text menu, ...) are behaviours, not folders: listed in Issue 10-078 and
  decided one by one with the owner.

## Suggested Implementation Steps

1. `run.sh`: in the flag loop, `--dir` / `--dir=` set `DIR`, `--assets` /
   `--assets=` set `ASSETS_DIR`, and the bare-word branch becomes an error.
   Update the usage line, the help text, and the header notes on derived
   defaults.
2. `run.sh`: `ASSETS_ARG` and the two inline `init_assets_root` calls pass
   `--assets`.
3. `libs/utils.lua`: `parse_assets_dir` reads `--assets`; the two pair-
   skipping parsers skip `--assets` and stop on `--dir`; the three "Fix:"
   messages name `--assets`.
4. `src/main.lua`, `src/wordcloud-generator.lua`,
   `src/generate-word-pages.lua`, `src/generate-gallery-pages.lua`: the same
   swap in their parsers, and `--dir` stops them.
5. `generate-embeddings.sh`: `--assets=PATH`, and its help line.
6. `scripts/seed-reproducibility.test.sh`: pass `--assets`.
7. Grep the whole project (code, docs, `.info.md` files, notes) for `--dir`
   and update each mention that means the assets folder. Completed issues
   are history and keep their words; 8-014 and 10-005 gain one line each
   pointing here.
8. Tests: a run-script argument test (the folder flags set the right
   variables; a bare word stops the run and is named; `--dir` reaches the
   project folder) and a child-parser test (`--assets` is read, `--dir`
   stops the program, a bare word after `--assets PATH` is not the assets
   path).
9. Dry-run a full build (`./run.sh --full --dry-run ...`) to see every stage
   get `--assets`.

Second part:

10. `libs/project-dir.lua` and `libs/project-dir.sh`, with tests: `--dir`
    in both spellings, a missing value, a bare word named, a flag's value
    not mistaken for one, the default when `--dir` is absent.
11. `scripts/check-folder-flags` (and its test), run by `scripts/run-tests`.
    Its list is the work list for step 12.
12. Each program on the list: read the folder through the shared reader;
    its own parser keeps its other flags and turns its bare-word branch
    into an error. Callers pass `--dir`. Tests' `setup()` too, and
    `scripts/run-tests`.
13. `utils.init_assets_root`: no project default; `generate-embeddings.sh`
    reads `--assets` everywhere it wrote `$DIR/assets`; `run.sh` passes it.
14. `.info.md` beside each program changed in this issue that lacks one.
15. The whole test suite; a plan-only full build.

## Open questions

1. (Answered 2026-11-03: "sure".) Should the child programs also take their
   project folder as `--dir PATH` and refuse bare words? -- Yes: the second
   part above.
2. (Answered 2026-11-03: "should remove fallback defaults".) Keep the
   assets folder's `<project>/assets` default, or make it an error? -- An
   error: the second part above.
3. (Answered 2026-11-03: "no".) Should tests have notes files too? -- No:
   each test's header says what it checks. `scripts/write-info-notes
   --missing` leaves tests out; `--include-tests` exists but is not used.
