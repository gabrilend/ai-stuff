# adopt-left-behind-changes

Takes ownership of uncommitted work whose author session has ended, so this
session can commit it through `commit-own-changes` without a one-time token.
Design: issue 032b.

## Usage

```
adopt-left-behind-changes [repo] [--from <session>]... [--dry-run] -- <path>...
```

| argument | type | meaning |
| --- | --- | --- |
| `repo` | directory | the repository (default: the ai-stuff monorepo) |
| `--from <session>` | session id string, repeatable | also take lines that session's ledger holds: it has ended, but its ledger is still in RAM |
| `--dry-run` | flag | print the report, write nothing |
| `-- <path>...` | repository-relative paths, required | what to adopt; `.` is the whole repository |

The session is read from `CLAUDE_CODE_SESSION_ID`.

## What it does

1. Lists every uncommitted change under the paths: tracked changes against
   the branch tip, line by line, and untracked files git does not ignore.
   Transcripts (`llm-transcripts/`) are skipped, because they ride along on
   every commit anyway.
2. A line claimed by any other session's ledger in
   `/dev/shm/claude-own-edits/` is **held** and left alone.
3. Every other line is appended to this session's ledger as `+` and `-`
   records, which are the same records the edit hook writes. An untracked or
   binary file that no other ledger names is claimed whole (`W`).

## Output

One line per file:
- `adopted <path> +N -M` means lines were taken.
- `adopted <path> whole (...)` means the whole file was claimed.
- `left <path>` means every changed line is held.

Under each file, one `held` line per holding session gives the count of lines
and the time that session's ledger was last written. Exit status is 0, or 1
with a message on standard error.

## Then

```
commit-own-changes <repo> -F - -- <path>...
```

## Known limits

- A person's uncommitted hand edits have no ledger, so they count as left
  behind.
- Claims are by line text within a file. A line identical to a held one counts
  as held.

Tested by `tests/test-adopt-left-behind.sh`, which `test-refusal-gates` runs.
