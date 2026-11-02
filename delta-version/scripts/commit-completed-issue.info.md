# commit-completed-issue.sh

Closes an issue in one commit: the issue file moves into its project's
`issues/completed/`, one line recording it goes into the project's progress
file, and both are committed together. If any step fails, the move and the
progress file are put back exactly as they were. Design: issue 055.

## Usage

    commit-completed-issue.sh <issue-file> [message-file] [--dir <monorepo>] [--dry-run]

| argument | meaning |
| --- | --- |
| `issue-file` | the open issue to close; must be tracked by git |
| `message-file` | the commit message; without one, the issue's title and a line saying it moved |
| `--dir` | the monorepo whose shared `scripts/` are used (default `/mnt/mtwo/programming/ai-stuff`) |
| `--dry-run` | run every check and print the move, the record and the commit route; change nothing |

Exit 0 when the commit was made (or the dry run found nothing wrong), 1 when it
refused or failed and changed nothing, 2 for bad arguments.

`manage-issues.sh complete FILE` (and its menu) runs this.

## What it does, in order

1. Finds the issue's `issues/` folder (an issue in `issues/phase-3/` still
   closes into `issues/completed/`) and refuses an issue already in
   `completed/`, a destination name already taken, or an untracked file.
2. Runs the shared `scripts/validate-issues --file` on it. A finding about the
   issue's own shape (name, missing sections) refuses; the validator's other
   findings (one-sided links, another file's duplicate id) are printed as
   notes and do not stop it.
3. Reads the issue's id, phase and title through the shared issue-name reader
   (`libs/issue-completion.lua locate`).
4. Picks the progress file: `issues/phase-N-progress.md` for a phase N issue
   when that file exists, otherwise `issues/progress.md`; refuses with
   neither.
5. Moves the file with plain `mv` (its modified date is kept) and writes the
   record (`libs/issue-completion.lua record`).
6. Commits:
   - **in a Claude Code session** (`CLAUDE_CODE_SESSION_ID` set): claims the
     move with `claim-own-change` and the added progress lines in the
     session's ledger, then runs `commit-own-changes`, so the commit carries
     the session's own lines and transcripts and nobody else's. Success is
     judged by whether the branch moved to a commit holding the move, not by
     the exit status alone.
   - **by hand**: `git commit --only` on exactly the old path, the new path
     and the progress file, so whatever else is staged stays staged.
7. On any failure after step 5: moves the file back and restores the progress
   file's bytes and date. Ledger claims stay (the ledger is append-only); they
   name files that are back as they were and claim nothing new.

## The progress record

Written under the progress file's first "Completed" heading ("Completed",
"Completed Issues", "Recently Completed", ignoring case, emphasis and emoji):
at the end of its list, or at the top of a "Recently ..." list, which is kept
newest first. Its style follows the list's first item:

    - **Issue 055**: The title (2026-11-02)       when the list writes "- **Issue ..."
    - 055 The title — completed 2026-11-02         otherwise

A progress file with no such heading gains `## Completed Issues` at its end.
Nothing else in the file is touched; an "In Progress" line about the issue is
left for whoever closes it to edit.

## Tests

`test-commit-completed-issue.sh [monorepo]` builds scratch repositories in RAM
and closes issues by hand, through `manage-issues.sh`, and as a made-up
session with its own ledger: the commit's contents, the record's place and
style per progress file, other people's staged and unstaged work left out,
and refusals (missing sections, no progress file, completed already, a
refusing commit hook, `commit-own-changes` refusing a detached HEAD) leaving
every file, date and staged entry as it was.
