# own-changes-patch.lua

Works out which of a repository's uncommitted changes are this session's own,
as a patch for `git apply --cached`. Shared by `commit-own-changes` (which
applies it to a private staging list and commits it) and `stage-own-changes`
(which prints what that would commit), so the two can never disagree. Design:
issue 032a.

## How a change block is judged

Against the session's edit ledger (`own-lines-ledger.lua`), every added and
removed line in a block is looked up:

| verdict | meaning | what happens |
| --- | --- | --- |
| ours | every line claimed | kept, renumbered past skipped blocks |
| foreign | no line claimed | left out, reported |
| mixed | some claimed | left out, reported, and listed in `mixed` — `commit-own-changes` stops on these unless told `--leave-mixed` |

A new or deleted file is all-or-nothing. A binary or mode-only change counts
only when the file is claimed whole. A file the staging list has never seen
counts when every line is claimed or it is claimed whole.

**Transcripts** count by conversation, not by folder: a changed or new
`llm-transcripts/*.md` counts when its first line, `# Conversation Summary:
<id>`, names this session or one of its helpers (`agent-<id>`, found as
`<sessions-root>/*/<session>/subagents/agent-<id>.jsonl`). It is taken whole.

## Data

**result** — `collect` returns:

| field | type | meaning |
| --- | --- | --- |
| `patch` | string or nil | the kept blocks as one unified diff, ready for `git apply --cached --unidiff-zero` |
| `whole` | list of strings | repository-relative paths to add whole |
| `report` | list of strings | one line per file or block: `ours`, `whole`, `left out` with the reason |
| `mixed` | list of strings | `"path:line"` for every mixed block |

## Functions

| function | takes | gives |
| --- | --- | --- |
| `collect(top, claims, rels, env)` | repository root, ledger claims, ledger files under the root, environment for git (`{ GIT_INDEX_FILE = private list }`) | **result**, or nil and a reason |
| `ledger_files(claims, top)` | claims, repository root | sorted repository-relative paths the ledger names there |
| `own_ids(session_id, sessions_root)` | session id, Claude Code's session store | set of conversation ids: the session and its helpers |
| `own_transcripts(top, ids)` | repository root, that set | sorted paths of changed or new transcripts whose header names one of the ids (read-only: `git status` without the index lock) |
| `run(argv, env)` | argument list, optional environment table | output (stderr folded in), success |
| `run_quiet(argv, env)` | argument list, optional environment table | stdout, success, stderr — for output that is data |
| `command_line(argv, env)` | argument list, optional environment table | one quoted shell command line |
