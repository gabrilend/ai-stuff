# transcript-patches

Keeps deliberate edits to conversation transcripts alive across re-exports.
The exporter (`backup-conversations`) re-renders a transcript whenever its
session is exported again; an edit made by hand would be overwritten. An edit
is instead a **patch**: a small folder belonging to one conversation, which
the exporter re-applies every time it renders that conversation. Design and
open questions: `issues/036-transcript-patches.md`.

## Where patches live

```
<project>/llm-transcripts/.patches/<conversation-id>/<NNN-short-name>/
```

One folder per conversation (the id from the transcript's header line, which
survives renames), one sub-folder per patch, applied in name order. Hidden, so
the transcript-naming rulebook never mistakes a patch for a transcript.

## Patch folders

| Files | Kind | What it does |
|---|---|---|
| `find`, `replace`, `about` | text | every occurrence of the bytes in `find` becomes the bytes in `replace` |
| `ids`, `about` | id | commit ids quoted in the transcript are translated through the `old new` lines in `ids` (written by `translate-ids`) |

- `find` and `replace` are taken **byte for byte**. A final newline in `find`
  is part of what is matched; `new` copies the input files exactly, so write
  them without a trailing newline unless you mean one.
- `about` is one line: `YYYY-MM-DD <reason>`.

## States of a patch

| State | Text patch | Id patch | Result |
|---|---|---|---|
| to apply | `find` occurs | an old id is quoted | changed |
| applied | `find` absent, `replace` present (or `replace` empty) | no old ids, some new ones | nothing changes |
| stale | neither | neither | error naming the patch; the export of that conversation fails and its file on disk is left as it was |

A replacement that contains its own find text ("X" → "X, revised") changes
only occurrences outside existing replacements, so applying it again never
grows the text.

## Commands

| Command | What it does | Writes |
|---|---|---|
| `apply <transcripts-dir> <conversation-id> <file>` | applies that conversation's patches, all or nothing (the exporter calls this) | the file, in place |
| `list <transcript>` | the patches a transcript carries: name, date, kind, state, reason | nothing |
| `original <transcript> [<out>]` | remakes the unpatched rendering from the session log | `<out>` or standard output; never the transcript |
| `verify <transcript>...` | re-renders, re-patches, re-applies to its own output, compares with the file on disk (ignoring the clock line); a transcript whose log is gone is reported as unverifiable | nothing; exits 1 on any mismatch |
| `new --for <id> --name <short-name> --find <file> --replace <file> --reason <text> <transcripts-dir>` | records the next numbered text patch; refuses a `find` that does not occur in that conversation's transcript | the patch folder |
| `translate-ids [--exclude <id>]... --all \| <project-dir>...` | writes an id patch for each conversation whose raw rendering quotes commit ids the history graft replaced, then checks raw + patches against every re-renderable transcript | patch folders |

`--dir=<scripts>` as the first argument points the tool at another checkout.

## translate-ids

- **Map:** `delta-version/archive/history-graft/commits.map` (override with
  `TRANSCRIPT_PATCHES_MAP`). Each generated `ids` file holds only the ids that
  conversation quotes.
- **Exclusions:** `transcript-patches.exclude` beside the tool (one conversation
  id per line, `#` comments; override with `TRANSCRIPT_PATCHES_EXCLUDE`), plus
  `--exclude <id>`. An excluded conversation never gets an id patch.
- **Frozen transcripts** (session log gone) are counted, not patched: they are
  never re-exported, so the ids already translated in them cannot come back.
- **Reruns** refresh each conversation's `NNN-commit-ids-after-history-graft`
  folder in place.
- Exit status 1 when any re-renderable transcript differs from raw + patches.

## Parts

- `libs/exact-text.lua`: literal count and replacement.
- `../delta-version/scripts/libs/commit-id-quotes.lua`: recognises quoted
  commit ids and rewrites them (shared with `graft-project-histories`).
- `libs/conversation-parser.lua`: the exporter's renderer, used by `original`,
  `verify` and `translate-ids`.
- Tests: `tests/test-transcript-patches.sh`.
