# apply-summary.sh

Folds a transcript's summary (the record `summarize-transcript.lua` writes,
issue 056b) into its folder. Issue 056c.

    apply-summary.sh TRANSCRIPT RECORD [--dir MONOREPO] [--config FILE] [--dry-run]

## What it changes

| Step | When | What |
|---|---|---|
| table of contents | always | adds or replaces the conversation's entry in `llm-transcripts/table-of-contents.md`: a `<!-- transcript-summary: ID -->` marker, `## [Title](file.md)`, and the paragraph. Keyed by conversation id, so a rerun updates the entry and a rename moves its link. |
| summary block | `inline_blurb=on` (default) | under the header line: `<!-- transcript-summary v1 -->`, `## Session Summary`, the paragraph, then a separator. A rerun replaces the block. The header stays first, so the rulebook still recognises the file. |
| rename | `rename=on` (default off) | `git mv` (or `mv` if untracked) to `<slug>-<date>.md`, choosing a free `_agent-N` name if needed. Links of the form `](old.md)` in the same folder follow it. Mentions anywhere else in the repository are listed but not edited, because another project's folder can hold a different transcript with the same date name. |

## Why renames are held back

The exporter (`scripts/backup-conversations`, the scripts project's) is the
only program that names transcripts. It re-derives every name and puts back
any name the shared rulebook does not recognise. So even with `rename=on`, the
applier first asks the rulebook itself (`transcript_is_new_format` on the new
name). While the answer is no, it holds the rename back, says why on standard
error, and still applies the rest. The rename starts working once the scripts
project widens `transcript_is_new_format` and the exporter's claim
comparison, as issue 056 step 3 describes.

The summary block has a similar limit. The exporter rewrites a transcript
whenever its conversation is exported again (after the next reply, or a
by-hand sweep), and that drops the block. The table of contents keeps the
paragraph either way.

## Configuration

`[apply]` in `config/transcript-summary-repos.conf`:

    table_of_contents=table-of-contents.md
    inline_blurb=on
    rename=off

`on`, `yes`, `true` and `1` turn a setting on. The shared rulebook is read
from `MONOREPO/scripts/libs/transcript-discovery.sh`, or from
`$SCRIPTS_DIR/libs/` when `SCRIPTS_DIR` is set (the same variable the
exporter uses).

## Refusals and exit status

Exit 2 for:
- a transcript without a conversation header;
- a file that is not a `transcript-summary v1` record;
- a record for a different conversation id;
- a record missing a title, slug or blurb, or whose slug is not lowercase
  words joined by `-`;
- usage errors.

Exit 1 when a write or a move fails. Exit 0 otherwise, including a
held-back rename.

## Tests

`test-apply-summary.sh [--dir MONOREPO]` runs in a RAM folder holding a
small git repository, using the real rulebook. For the rename path it uses a
copy of the rulebook that accepts slug names. 34 checks:

- the defaults;
- reruns, with one entry and one block each;
- `inline_blurb=off`;
- a dry run that changes nothing;
- a held-back rename;
- a real rename with `git mv`, the link updated and an outside mention
  listed;
- no second rename;
- each refusal.
