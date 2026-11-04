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
