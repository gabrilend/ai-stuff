# transcript-patches

Keeps deliberate edits to conversation transcripts alive across re-exports.
The exporter (`backup-conversations`) re-renders a transcript whenever its
session is exported again; an edit made by hand would be overwritten. An edit
is instead a **patch** file with a date and a reason, and the exporter applies
every patch that targets a conversation each time it renders it. Design and
open questions: `issues/036-transcript-patches.md`.

## Where patches live

| Folder | Applies to | Example |
|---|---|---|
| `<repository root>/.transcript-patches/` | every transcript in the repository | the history-graft id translation (001) |
| `<project>/llm-transcripts/.patches/` | that project's transcripts | a fix to one conversation |

Repository-wide patches apply first; within a folder, in file-name order.

## Patch file

A Lua file returning one table (loaded with an empty environment, data only):

| Field | Type | Meaning |
|---|---|---|
| `id` | string | `"001"`; must match the start of the file name |
| `date` | string | `"YYYY-MM-DD"` |
| `reason` | string | one line: why the edit exists |
| `applies_to` | `"all"` or list of strings | conversation ids, from each transcript's header line |
| `kind` | string | `"replace"` or `"commit-map"` |
| `old`, `new` | strings | replace: literal text, compared character by character |
| `count` | number | replace: how many times `old` must occur in the fresh rendering |
| `map` | string | commit-map: `old new` id map, path relative to the repository root |

## Commands

| Command | What it does | Writes |
|---|---|---|
| `apply <transcripts-dir> <conversation-id> <file>` | applies that conversation's patches to a rendering, all or nothing; prints one line per patch that changed something | the file, in place (the exporter's temp file) |
| `list <transcript>` | the patches a transcript carries: level, id, date, kind, reason, and whether each is applied, not yet applied, or stale | nothing |
| `original <transcript> [<out>]` | remakes the unpatched rendering from the session log | `<out>` or standard output; refuses to write over the transcript |
| `verify <transcript>...` | re-renders, re-patches, re-applies the patches to their own output, and compares with the file on disk (ignoring the "Generated on" clock line); a transcript whose session log is gone is reported as unverifiable | nothing; exits 1 on any mismatch |
| `new --for <id\|all> --reason <text> --old <file> --new <file> [--count N] [--repo-wide] <transcripts-dir>` | scaffolds the next numbered replace patch; the count defaults to the old text's occurrences in that conversation's transcript | the new patch file |

`--dir=<scripts>` as the first argument points the tool at another checkout of
this folder.

## States of a replace patch

- **apply**: its old text occurs exactly `count` times; it is replaced.
- **applied**: its result is already there, so it does nothing. This is what
  makes applying to an already-patched file harmless.
- **stale**: neither. The export of that conversation fails with a message
  naming the patch, and the transcript on disk is left exactly as it was.

A commit-map patch has no stale state: an id already translated maps to itself.
A missing map file is an error.

## Parts

- `libs/exact-text.lua`: literal count and exact-count replacement.
- `../delta-version/scripts/libs/commit-id-quotes.lua`: finds quoted commit ids
  and rewrites them through a map (shared with `graft-project-histories`).
- `libs/conversation-parser.lua`: the exporter's renderer, used by `original`
  and `verify`.
- Tests: `tests/test-transcript-patches.sh`.
