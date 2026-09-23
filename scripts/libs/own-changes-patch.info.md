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

**Transcripts** are never judged by the ledger: every `llm-transcripts/*.md`
that differs from the branch tip (new, changed, or deleted) rides along
whole, whoever's conversation it is. The header, `# Conversation Summary:
<id>`, is read only so the report can say whether a transcript is this
session's (the session or a helper, `agent-<id>`, found as
`<sessions-root>/*/<session>/subagents/agent-<id>.jsonl`) or another's. Why
this is safe: the exporter replaces each transcript whole in one step, and
lasting edits live in `.patches/`, so there are no lines of anyone's to
tangle with.

## Data

**result** — `collect` returns:

| field | type | meaning |
| --- | --- | --- |
| `patch` | string or nil | the kept blocks as one unified diff, ready for `git apply --cached --unidiff-zero` |
| `whole` | list of strings | repository-relative paths to add whole |
| `report` | list of strings | one line per file or block: `ours`, `whole`, `left out` with the reason |
| `mixed` | list of strings | `"path:line"` for every mixed block |

**transcript entry** — each item `changed_transcripts` returns:

| field | type | meaning |
| --- | --- | --- |
| `rel` | string | repository-relative path |
| `ours` | boolean | its header names this session or one of its helpers |
| `gone` | boolean | deleted from disk (renamed or retired by the exporter); its deletion is committed |

## Functions

| function | takes | gives |
| --- | --- | --- |
| `collect(top, claims, rels, env)` | repository root, ledger claims, ledger files under the root, environment for git (`{ GIT_INDEX_FILE = private list }`) | **result**, or nil and a reason |
| `ledger_files(claims, top)` | claims, repository root | sorted repository-relative paths the ledger names there |
| `own_ids(session_id, sessions_root)` | session id, Claude Code's session store | set of conversation ids: the session and its helpers |
| `changed_transcripts(top, tip, ids)` | repository root, commit id to compare against, that set | sorted list of **transcript entry**, one per transcript that differs from `tip` or is untracked; or nil and a reason (read-only) |
| `transcript_report_line(t)` | a **transcript entry** | one report line: path and whose it is, or that it is gone |
| `run(argv, env)` | argument list, optional environment table | output (stderr folded in), success |
| `run_quiet(argv, env)` | argument list, optional environment table | stdout, success, stderr — for output that is data |
| `command_line(argv, env)` | argument list, optional environment table | one quoted shell command line |
