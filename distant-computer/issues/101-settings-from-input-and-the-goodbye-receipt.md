# 101 — Settings from input/ and the goodbye receipt

phase 1, the record and the settings

## Current behavior

Nothing exists. The project has empty `input/` and `output/` folders from
the skeleton.

## Intended behavior

Two small shared Lua modules every distant-computer program uses, on both
computers (`docs/settings-files.md`):

- **The settings reader** reads `input/<program>` (or a named shared file
  such as `input/link`) against a declaration: a table of name → type
  (whole number, decimal, text, list of words) and whether it is required.
  It returns a table of values and raises an error, naming the file and
  line, for a missing file, an undeclared name, a missing required name, a
  wrong type, or a repeated name. No defaults are hidden in code.
- **The goodbye writer** gathers a program's counters (a table of name →
  whole number) and, on a clean exit, writes `output/goodbye.<program>` and
  `output/goodbye`: `program`, `ended` (UTC), `seed`, then the counters
  sorted by name. Each is written under a temporary name and then renamed.
- Both make sure the RAM tiers exist first, through a project copy of the
  house `ensure-ram-tiers.lua`. No program reaches into another folder of
  the monorepo at run time.

## Suggested implementation steps

1. Copy `scripts/libs/ensure-ram-tiers.lua` into `libs/`, with a note
   saying where it came from.
2. The settings reader as the first numbered source file. Value types are a
   dispatch table from type name to a parse-and-check function.
3. The goodbye writer.
4. Tests: a good file; one test per kind of bad file; a receipt written and
   read back.
5. An `.info.md` beside each source file.

## Related documents

- `docs/settings-files.md`

## Blocked by

None.

## Blocks

102, 103, 201, 301, 302, 303, 401, 602.
