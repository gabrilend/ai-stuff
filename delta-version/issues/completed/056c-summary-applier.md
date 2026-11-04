# Issue 056c: Summary Applier

**Phase**: 0 - Tooling
**Status**: Completed (2026-11-03), with renames off by default
**Priority**: High
**Created**: 2026-11-03 (split out of 056, which specified it)
**Parent**: 056 (Recursive Transcript Summarization)

---

## Current Behavior

056b prints a summary record but nothing puts it where a reader would see it.

## Intended Behavior

As specified in 056 step 3: `scripts/apply-summary.sh` adds a table-of-contents
entry and a summary block, and renames the transcript to `<slug>-<date>.md`.
As decided on 2026-11-02, renames are off by default and turned on by a
config setting.

## Suggested Implementation Steps

1. Read and check the record against the transcript's header.
2. Add or replace the entry in `table-of-contents.md`, keyed by conversation id.
3. Add or replace the summary block under the header line.
4. Rename, only when configured, and only if the shared rulebook accepts the name.
5. Test in a RAM folder.

## What Happened

**2026-11-03 — built and tested.**

- **Renames are off by default** (`[apply] rename=off` in
  `config/transcript-summary-repos.conf`).
- **Even with renames on, the rulebook is asked first.** 056's step 3 warns
  that the exporter would rename a slug-named file straight back until the
  shared rulebook learns such names. That change belongs to the scripts
  project's `transcript-discovery.sh` and `backup-conversations`, which
  delta-version does not edit. So the applier asks the rulebook
  (`transcript_is_new_format` on the new name). While the answer is no, it
  holds the rename back with a message naming the change needed, and applies
  the rest. When the scripts project widens the rule, renames start working
  with no change here.
- **The table of contents is the durable record.** Entries are keyed by
  conversation id, so a rerun replaces an entry and a rename moves its link.
  The in-file summary block is replaced on a rerun too, but the exporter drops
  it whenever it rewrites that conversation. Both behaviours are documented
  in the config and the info file. 056d should check the table of contents
  before paying for a new summary.
- **References are fixed narrowly.** Links in the same folder follow a
  rename. Mentions elsewhere are listed, not edited, because each project's
  folder can hold its own `dec-10-25.md`.
- **End to end:** `summarize-transcript.lua` against the stand-in, then
  `apply-summary.sh`, produced the block and the entry.

Tests: `scripts/test-apply-summary.sh` passes 34/34.

**For the scripts project:** widen `transcript_is_new_format` and the
exporter's claim comparison to accept `<slug>-<date>.md`. Also make the
exporter's content comparison step over the `<!-- transcript-summary v1 -->`
block, so a re-export keeps it.
