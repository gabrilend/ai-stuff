# 101 — Settings from input/ and the goodbye receipt

phase 1, the record and the settings

## Current behavior

Built. Two Lua modules, used by every distant-computer program on both
computers, with tests:

- **The settings reader** (`src/001-settings.lua`, notes in
  `src/001-settings.info.md`) reads `input/<program>` (or any named
  settings file) against the program's declaration: a table of setting name
  → type (`whole`, `decimal`, `text`, `words`) and whether it is required.
  It returns the values, or raises `<file>:<line>: <reason>` for a missing
  file, an undeclared name, a repeated name, an empty value, a wrong type, a
  line that is not `name = value`, or (line 0, all listed at once) missing
  required names. Value types are a dispatch table from type name to a
  parse-and-check function. A `#` starts a comment only outside double
  quotes. Inside quotes, only `\"` and `\\` are escapes, and any other
  backslash is refused rather than guessed at. A bare word allows letters,
  digits and `- _ . / :`. Anything else, including `@`, needs quotes, so a
  sentence can never be mistaken for a list.
- **The receipt** (`src/002-goodbye.lua`, notes in `src/002-goodbye.info.md`)
  starts a run (program name, seed, both required; `"none"` is said out loud
  when there is no seed) and keeps whole-number counters. On finish it
  writes `output/goodbye.<program>` and `output/goodbye`: `program`,
  `ended` (UTC), `seed`, then counters sorted by name. Each file is written
  to a temporary name and renamed into place. A run log goes to
  `tmp/shared-memory/<program>.log`.
- Before opening the log, the receipt makes sure the RAM scratch folders
  exist, by calling the house library in the monorepo's `scripts/libs/`. It
  finds that folder from its own file's location, so the same code works on
  kuvalu and in the distant computer's clone at a different path.
- `tests/run-tests` runs every `tests/*.test.lua` with LuaJIT. Each test gets
  its own folder in RAM, and the scratch roots are moved inside the project's
  own scratch space for the run, so a throwaway test project never builds
  folders in the real `/tmp` or `/dev/shm` roots.

## Intended behavior

As above (`docs/settings-files.md`).

## Decisions

- **The scratch-folder library is not copied into the project.** The first
  plan copied `ensure-ram-tiers.lua` into `libs/`, as guide-feature does. But
  that Lua file only calls the bash library beside it. A copy would need both
  files and would drift from the original, which is the drift the library's
  own header warns about. The distant computer holds a full clone of the
  monorepo, so `scripts/` is always beside the project. The module finds it
  relative to itself.
- **No defaults in the settings reader.** An optional setting is absent from
  the result, and the program decides what absence means, visibly, in its own
  code.

## Steps taken

1. `src/001-settings.lua`: the line reader, comment stripping aware of
   quotes, the value-type table, the declaration check, the gathered report
   of missing names.
2. `src/002-goodbye.lua`: start, count, set, note, text, finish, read; the
   whole-file write by rename; the scripts folder found from the file's own
   location.
3. `tests/001-settings.test.lua` (a good file with every type and comment
   form; ten refusals, each checked for the line it names; a bad
   declaration). `tests/002-goodbye.test.lua` (a receipt round trip, the
   per-program copy, no temporary file left, the log's contents; the
   refusals).
4. `tests/run-tests`, with `--help`.
5. `.info.md` beside each source file.

Result: `tests/run-tests` → settings 18 passed, goodbye 14 passed.

## Related documents

- `docs/settings-files.md`
- `docs/provisioning.md` (the library needs `jq` on the distant computer)

## Blocked by

None.

## Blocks

102, 103, 201, 301, 302, 303, 401, 602.
