# Issue 065a: The Map of Stops

**Status**: Completed 2026-10-10
**Parent**: 065-the-reading-walk.md
**Dependencies**: None
**Blocks**: 065b, 065c, 065d, 065h

## Current Behavior
`scripts/reading-walk-map.lua <project>` writes a map of the project to
`delta-version/tmp/shared-memory/reading-walk/<project>.map.lua` and prints a
report: how many stops, how many described by the `.info.md` page, how many
only by a source comment, how many not at all, how many have a recorded
reason, how many are never used. The map's fields are tabled in
`scripts/reading-walk-map.info.md`.

## Intended Behavior
One stop per fold marker, in the order the file names give (zero-padded index
numbers sort as they read). A fold title that is a name (`M.flatten(path)`,
`local function split()`, `MAX_DEPTH -- note`) is a function or
datastructure; any other title (a prose heading such as "ONE OF THESE PER
PROCESS") is a **passage**: a stop in the story with no uses. The description
comes from the file's `.info.md` page — a `### \`name()\`` section, else a
table row — and when the page has no entry, from the comment under the
marker, marked as such so the missing entry shows; never silently. The
summary is the description's first sentence.

Uses: each non-comment source line is split into words and each word looked
up in a table of stop names (one lookup per word, whatever the number of
stops). A private function's uses count only in its own file — two files may
each have a local `split`; an exported one counts elsewhere only after a dot
or colon.

Two parallel passes, each one worker process per CPU with a round-robin share
of files: stops per source file, then uses and reasons over source and issue
files. A worker whose output lacks its closing field died part-way and stops
the run. The map is a Lua data file, read back with `loadfile` in an empty
environment, with keys written sorted so the same project gives the same
file whatever the worker count.

## Suggested Implementation Steps
1. Reading order from sorted file names; fold markers (by file type's comment
   opener, a table: lua `--`, c/h/js `//`, sh `#`) to stops, nesting allowed.
2. Name or passage from the title; description from the page, comment
   fallback marked.
3. Uses by word lookup with the private/exported rule.
4. Parallel passes in the RAM tier (`scripts/libs/ensure-ram-tiers.lua` first).
5. Tests in `scripts/test-reading-walk.sh` (fixture project in /dev/shm).

## Decided against
- Matching every stop's name against every line with a pattern: stops × lines
  work; a word table makes it one lookup per word.
- Counting a private name's appearance in another file as a use: different
  files reuse helper names.
