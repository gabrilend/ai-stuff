# phase-progress-files.lua

Writes `issues/phase-<N>-progress.md` for every phase that has issues. The
issue table in each file is built from the issue files themselves, so it
can't drift from them; the phase's goals and any other text are written by
people and kept.

## Using it

```bash
luajit scripts/phase-progress-files.lua [DIR] [--dry-run]
```

| Argument | Type | Meaning |
|----------|------|---------|
| `DIR` | path | the project folder; defaults to this project |
| `--dry-run` | flag | say what would be written, change nothing |

Run it after completing, retiring, renaming or adding an issue.

## What it writes

- **A phase with no progress file:** a new file with a Goals section, the
  dashboard command for live counts, and the issue table. The goals are
  copied once from the phase's section of `docs/roadmap.md` (its heading
  and first paragraph); a phase the roadmap doesn't describe gets a line
  saying its goals are to be written.
- **A progress file with the markers:** only the table between
  `<!-- phase-progress-files: issues begin ... -->` and
  `<!-- phase-progress-files: issues end -->` is rewritten. Everything
  outside them is left as it is.
- **A progress file without the markers:** left alone and named in the
  output as hand-kept (today, `phase-W-progress.md`).

## The table

One row per issue file in the phase, open, completed or retired:

| Column | From |
|--------|------|
| ID | the file name (the shared name reader, `libs/issue-names.lua`) |
| Title | the file's first `# ` heading, without its "Issue 522:" prefix |
| Status | the folder: open, completed, or retired (with the folder name) |
| Depends on | the ids on the file's `**Dependencies:**` line |

Below it, the counts of completed, open and retired issues as of that run.

Phases come from the same shared reader the progress dashboard and the
issue validator use, so all three place every issue in the same phase.
