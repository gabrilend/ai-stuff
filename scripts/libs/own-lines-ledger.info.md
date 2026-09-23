# own-lines-ledger.lua

The record of which lines a Claude Code session wrote, and the reading of
unified diffs against it. Shared by `record-own-edits`, `claim-own-change`,
and the `own-changes-patch` library behind `commit-own-changes` and
`stage-own-changes`.
Design: issues 032 and 032a.

## Where it lives

`/dev/shm/claude-own-edits/<session-id>/ledger.tsv` — RAM, one folder per
session (subagents share their parent's session id). Append-only; each batch is
one write to a file opened for appending.

Each line: `kind <TAB> absolute-real-path <TAB> line-text`, the text escaping
`\` as `\\`, tab as `\t`, carriage return as `\r`.

| kind | meaning |
| --- | --- |
| `+` | this line text was added to this file by the session |
| `-` | this line text was removed from this file by the session |
| `W` | the whole file is claimed |
| `R` | every removal in this file is the session's (a whole-file rewrite) |

## Data

**claims** — `ledger.load` returns `claims[path]`:

| field | type | meaning |
| --- | --- | --- |
| `added` | set of strings | line texts added |
| `removed` | set of strings | line texts removed |
| `whole` | boolean | every line in the file claimed |
| `all_removals` | boolean | every removal in the file claimed |

**diff entry** — `ledger.parse_diff` returns a list of these:

| field | type | meaning |
| --- | --- | --- |
| `old_path`, `new_path` | string or nil | repository-relative; nil for `/dev/null` |
| `header` | list of strings | lines before the first `@@`, verbatim |
| `binary` | boolean | "Binary files … differ" |
| `hunks` | list of `{ old_start, old_count, new_start, new_count : integer, suffix : string, lines : list of strings }` | change blocks; each line keeps its `+`/`-`/` ` mark |

## Functions

| function | takes | gives |
| --- | --- | --- |
| `append(session_id, records)` | session id, list of `{ kind, path, text }` | true, or nil and a reason |
| `load(session_id)` | session id | **claims** (empty when no ledger yet) |
| `records_from_hunks(path, hunks, records)` | path, change blocks in the harness's structuredPatch shape, list to fill | the filled list |
| `line_claimed(claims, path, mark, text)` | claims, path, `"+"` or `"-"`, text | boolean |
| `parse_diff(text)` | git unified diff (best with `-U0 --no-renames`) | list of **diff entry**; body lines are counted against the `@@` header, so a removed `-- comment` is never read as a file header |
| `file_path(entry)` | a diff entry | its new path, or old path for a deletion |
| `realpath(path)` | path | symlinks resolved, last part may not exist |
| `session_dir(session_id)` | session id | the session's ledger folder |

## Known gap

Claims are by text within a file: a foreign line identical to one of ours in
the same file passes.
