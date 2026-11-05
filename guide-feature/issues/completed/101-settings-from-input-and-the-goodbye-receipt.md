# 101 — Settings from input/ and the goodbye receipt

phase 1, the canvas and the blit

## Current behavior

Nothing exists. The project has an empty `input/` and `output/` folder from
the skeleton.

## Intended behavior

Every guide-feature program (blitter, turn runner, canvas server, viewers)
starts and ends the same way, using two small shared Lua modules:

- **The settings reader.** Reads one settings file from `input/` named after
  the program (`input/blitter`, `input/turn`, ...). The format is the same
  `name = value` lines as rmail's `contacts` and the project's `endpoints`
  file (`#` comments, quoted text, bare numbers), so the owner has one format
  to learn. It returns a table of settings and **throws an error** for a
  missing file, an unknown name, a missing required name, or a value of the
  wrong type. Each program declares its settings as a table of name, type
  (whole number, decimal, text, `WxH`, list of names) and whether it is
  required. No defaults are hidden in code, so every value a program uses is
  visible in its input file. Programs that must pick up changes while running
  (the blitter's merge mode) call it again.
- **The goodbye writer.** On every clean exit, writes `output/goodbye`: the
  program's name, when it ended (UTC), the seed if it uses one, and its own
  counters (a table of name to whole number, gathered as it runs), one
  `name: value` line each, sorted, so two receipts can be compared with
  `diff`. A crash writes nothing, so a missing or stale goodbye is the crash
  report. A run log goes to `tmp/shared-memory/<program>.log`.
- Both make sure the RAM tiers exist first, through this project's own copy
  of the house `ensure-ram-tiers.lua`, `libs/ensure-ram-tiers.lua`, copied
  from `/mnt/mtwo/programming/ai-stuff/scripts/libs/` with an `.upstream`
  note (`docs/vendored-code.md`). No guide-feature program reaches into
  another folder of the monorepo at run time.

The settings reader also reads the project-root `endpoints` file
(`docs/endpoints.md`), which uses the same format.

## Suggested implementation steps

1. The settings reader, as the first numbered source file (next index from
   `.file-index-counter`). Value types are a dispatch table from type name to
   a parse-and-check function.
2. The goodbye writer.
3. Tests: a good file, and one test per kind of bad file; a goodbye written
   and read back.
4. A `.info.md` beside each source file.

## Related documents

- `docs/architecture.md`, "Every program starts with input/ and ends with
  output/goodbye"

## Blocked by

None.

## Blocks

107, 204, 405, 601, 801, 802.

## Decisions (2026-11-05; each the owner's to overturn)

Questions met while building, answered here so the work could go on.

1. **One receipt per program: `output/goodbye-<program>`.** The blitter, the
   canvas server and the desktop viewers run on kuvalu at the same time. A
   single `output/goodbye` would hold only whichever ended last, so a crashed
   program could hide behind another's receipt. `docs/architecture.md` and
   `docs/datapath-round-trip.md` now say so.
2. **The last receipt is moved aside as a program starts**, to
   `output/goodbye-<program>.previous`. So "missing" is the crash report, and
   no stale receipt can be mistaken for this run's. The last good one is
   still there to `diff` against. The receipt is written to a `.partial` file
   and renamed into place, so a crash while writing leaves none rather than a
   cut one.
3. **The receipt's order:** the head lines (`program`, `ended`, then `seed`
   when there is one) first, then the counters sorted by name. Counters are
   whole numbers of zero or more and only grow. No counter may take a head
   line's name.
4. **How values are written.** Text, choices and lists are always in double
   quotes, and numbers and sizes never are, so a mistyped number can't quietly
   become text. Inside quotes, `\"` and `\\` are the only escapes. A `WxH`
   is bare, as in `80x24`, the way the canvas's `size` header is written. A
   list of names is one quoted text, split on spaces or commas. A name may not
   appear twice in a list.
5. **A sixth type, `choice`:** one of a fixed set of words. Merge mode,
   collision rule and an endpoint's kind are all this, and checking the word
   when the file is read beats each program checking it later.
6. **A setting set twice is an error**, naming both lines. Taking the last
   one silently would let an edit near the top of a file be undone by a
   forgotten line at the bottom.
7. **The endpoints file's names are patterns** (`*.url`, `use.*`). When two
   patterns match, the one with the longer fixed start wins, so `use.url` is
   a role and an endpoint can't be called `use`. `read_endpoints` also checks
   that each endpoint has a url and a kind, and that each `use.` line names an
   endpoint in the file of the kind its role needs (the embedder an embedding
   one, every other role a chat one; `docs/endpoints.md`). Whether an
   endpoint answers is left to the client (401b).
8. **The RAM tiers are checked once per project root per process**, because
   the blitter reads its settings on every arrival and the check runs a
   shell.
9. **Both halves of ensure-ram-tiers are copied**, unchanged. The Lua file
   only asks the bash library beside it, which is where the layout is written
   down. The Lua file is always handed this project's root as its
   `scripts_dir`, so its default path into the monorepo is never used. It
   needs jq.
10. **A `run-tests` script at the project root** runs every
    `src/NNN-test-*.lua`, the way every-software-image-able's does.
    `scripts/refresh-vendored` (`docs/vendored-code.md`) is not built here;
    101's steps don't include it.

## Implementation notes (2026-11-05)

- `src/001-settings.lua`: `read`, `read_endpoints`, `parse`, `check`, the
  `TYPES` dispatch table (`whole`, `decimal`, `text`, `WxH`, `names`,
  `choice`), `ENDPOINT_FIELDS`, `ensure_tiers`.
- `src/002-goodbye.lua`: `start` returns a run with `log`, `count` and
  `finish`; `format`, `parse`, `read` and `path` work on receipts.
- `libs/ensure-ram-tiers.lua` and `libs/ensure-ram-tiers`, each with an
  `.upstream` note; the row in `docs/vendored-code.md` is filled in.
- Tests (each on a throwaway project with its RAM tiers moved under the
  system's temporary folder):
  - `src/003-test-settings.lua`: 51 pass;
  - `src/004-test-goodbye.lua`: 27 pass, including a crashing program in a
    separate process;
  - `./run-tests` runs both.
- A `.info.md` beside each source file. `.file-index-counter` is at 004.
- `.gitignore` ignores `output/goodbye-*`, which are run artefacts, as other
  projects in the monorepo ignore their `output/goodbye`.

**Checked here:** with LuaJIT 2.1 and jq on Linux.

**Not checked:** on kuvalu and the mini-computers. Whether the
mini-computers' BusyBox userland has `bash`, `jq` and `readlink -f`, which
the tiers library uses, goes with 701's survey (open question 1).
