# Issue 056: Batch transcript backup: output location, combined export, metadata, parallel levels

## Status
- **Priority**: Low
- **Type**: Feature / Tooling
- **Status**: Completed
- **Created**: 2026-11-03
- **Split from**: issue 009 (steps 11 and 26-29)

## Current Behavior

`batch-transcript-backup.sh` writes each project's transcripts and level
exports into that project's own `llm-transcripts/` folder, one file per
conversation per level, one level after another. Issue 009 is finished
apart from these steps, which it listed under Phase C and Phase F.

## Intended Behavior

1. **`--output-dir DIR`**: write the exports under `DIR/<project>/` instead of
   each project's `llm-transcripts/`.
2. **`--combined`, and an output-mode choice in the `-I` menu** (per project /
   combined / both): one export file across every chosen project.
3. **Metadata per conversation**: a small file beside each conversation's
   exports giving each file's size and when it was exported.
4. **`--parallel`**: run the levels of one conversation at the same time.

## Suggested Implementation Steps

1. [x] Decide what `--combined` joins: the baseline transcripts only, or one
       combined file per level. Then decide its name and where it goes when
       `--output-dir` is not given.
2. [x] `--output-dir`, honoured by `--commit` (commit the output folder if it
       is in a repository, or say it is not).
3. [x] `--combined` and the menu's output-mode radio list.
4. [x] The metadata file: plain text, one line per export, written after the
       exports so a failed export is not listed.
5. [x] `--parallel N`, with each level's messages kept apart so a failure
       still says which level it was.
6. [x] Extend `tests/test-batch-transcript-backup.sh` for each.

## Related Documents

- `issues/completed/009-batch-transcript-backup-with-tui.md`: the tool, and
  why these steps were split off.
- `batch-transcript-backup.sh`

## What Happened

**2026-11-03.** Built in `batch-transcript-backup.sh`. The new checks are
in `tests/test-batch-transcript-backup.sh`, which now has 76 checks (25 of
them new). This branch builds on #164 (issue 009), because the script it
changes is there.

Decisions (step 1, and the questions the others raised):

- **`--combined` joins the baseline transcripts only, into one file.**
  - The file is `combined-<YYYY-MM-DD>.md`, with a `## <project>` part per
    project and a `### <file>` part per transcript.
  - It goes in `--output-dir` when given, or in the monorepo's own
    `llm-transcripts/`.
  - Level exports are left out. Six levels of every conversation in one
    file would be too large to read, and the baselines are the readable
    record.
  - With `--since`, only the conversations that changed are joined.
  - The file starts with "# Combined LLM transcripts", not a transcript
    header, so the transcript tools never take it for one.
- **The menu's output mode is a "Combined file too" box, not a three-way
  choice.** `backup-conversations` always writes each project's baselines
  into that project. So "combined only" would not mean less writing; it
  would only skip the joined file.
- **`--output-dir` moves the level exports and the combined file, not the
  baselines.** The baselines are `backup-conversations`' own files, named
  and placed by it.
  - Level exports go to `<dir>/<project>/`.
  - With `--commit`, that folder is committed in whatever repository holds
    it, or the run says it is in none. The combined file is committed on
    its own, so nothing else in its folder is swept in.
- **`--metadata` is opt-in.** It writes `<id>.exports.txt` beside the
  exports, with one tab-separated line per level written: file, bytes, and
  the export time. It is written after the exports, so a failed or empty
  level is never listed. The `.txt` name keeps it out of transcript
  listings.
- **`--parallel N` runs up to N levels of one conversation at a time.**
  - Each level's output, messages and exit status go to files of their
    own. They are read back in level order, so a failure still names its
    level (its messages are printed as "level N: ...").
  - Without `--parallel`, the levels run one at a time, as before.
  - Conversations still run one after another, so the progress lines stay
    readable.

## Renumbered

**2026-11-04:** this issue was 042, a number main gave a different issue in
the 2026-11-03 push, so it moved to the next free number, 056.
