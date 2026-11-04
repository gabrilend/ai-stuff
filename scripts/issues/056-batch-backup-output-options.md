# Issue 056: Batch transcript backup: output location, combined export, metadata, parallel levels

## Status
- **Priority**: Low
- **Type**: Feature / Tooling
- **Status**: Open
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

1. [ ] Decide what `--combined` joins: the baseline transcripts only, or one
       combined file per level. Then decide its name and where it goes when
       `--output-dir` is not given.
2. [ ] `--output-dir`, honoured by `--commit` (commit the output folder if it
       is in a repository, or say it is not).
3. [ ] `--combined` and the menu's output-mode radio list.
4. [ ] The metadata file: plain text, one line per export, written after the
       exports so a failed export is not listed.
5. [ ] `--parallel N`, with each level's messages kept apart so a failure
       still says which level it was.
6. [ ] Extend `tests/test-batch-transcript-backup.sh` for each.

## Related Documents

- `issues/completed/009-batch-transcript-backup-with-tui.md`: the tool, and
  why these steps were split off.
- `batch-transcript-backup.sh`

## Renumbered

**2026-11-04:** this issue was 042, a number main gave a different issue in
the 2026-11-03 push, so it moved to the next free number, 056.
