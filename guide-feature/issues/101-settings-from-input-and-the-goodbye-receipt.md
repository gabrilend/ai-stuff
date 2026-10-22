# 101 — Settings from input/ and the goodbye receipt

phase 1, the fit and the fade

## Current behavior

Nothing exists. The project has an empty `input/` and `output/` folder from
the skeleton.

## Intended behavior

Every guide-feature program (page keeper, thinker, page server, viewers)
starts and ends the same way, using two small shared Lua modules:

- **The settings reader.** Reads one settings file from `input/` named by the
  program (`input/page-keeper`, `input/thinker`, ...). The format is the same
  `name = value` lines rmail uses (`#` comments, quoted text, bare numbers),
  so the owner only has one format to learn. It returns a table of settings
  and **throws an error** for a missing file, an unknown name, a missing
  required name, or a value of the wrong type. Each program declares its
  settings as a table of name, type (whole number, decimal, text, WxH box,
  list of names), and whether it is required. There are no default values
  hidden in code. Every value the program uses is visible in its input file.
- **The goodbye writer.** On every clean exit, writes `output/goodbye`: the
  program's name, when it ended (UTC), the seed if it uses one, and its own
  counters (a table of name to whole number, gathered from the program as it
  runs). A program that crashes writes nothing, so a missing or stale goodbye
  is the crash report. A run log goes to `tmp/shared-memory/<program>.log`.
- Both make sure the RAM tiers exist first, by calling the shared
  `ensure-ram-tiers.lua` from `/mnt/mtwo/programming/ai-stuff/scripts/libs/`.

## Suggested implementation steps

1. Write the settings reader as the first numbered source file, taking the
   next index from `.file-index-counter`. Settings types are a dispatch table
   from type name to a parse-and-check function.
2. Write the goodbye writer as the next numbered file. It formats one
   `name: value` line per counter, sorted by name, so two receipts can be
   compared with `diff`.
3. Tests: a good file, each kind of bad file (one test per error), a goodbye
   written and read back.
4. A `.info.md` beside each source file.

## Related documents

- `docs/architecture.md`, "Every program starts with input/ and ends with
  output/goodbye".

## Blocked by

None.

## Blocks

107, 204, 406, 601, 602.
