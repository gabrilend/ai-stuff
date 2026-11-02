# libs/issue-completion.lua

The text work behind `commit-completed-issue.sh`, run as a command.

    luajit issue-completion.lua locate <scripts-dir> <project-dir> <issue-file>

Prints `id <TAB> phase <TAB> title` for the issue, phase `-` when it has none.
Id and phase come from the shared `scripts/libs/issue-names.lua`, so they agree
with the progress dashboard and `validate-issues`. The title is the first `# `
heading without an "Issue 055:" or "055 —" prefix. `project-dir` and
`issue-file` must be real paths (symlinks resolved). Exit 1 when the reader
does not recognise the file as an issue.

    luajit issue-completion.lua record <progress-file> <id> <title> <date> [--dry-run]

Writes the completion line into the progress file (see the "progress record"
section of `../commit-completed-issue.info.md` for where and in which style)
and prints each line it added, a blank one included, so the caller can claim
them. With `--dry-run` it prints and writes nothing. A file without a final
newline keeps lacking one.
