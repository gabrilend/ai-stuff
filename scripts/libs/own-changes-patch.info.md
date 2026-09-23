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
| mixed | some claimed | taken apart: only this session's lines are kept (reported as `untangled`). When both changed the same place and the order of the two sets of lines cannot be told, left out, reported as tangled, and listed in `mixed` — `commit-own-changes` stops on these unless told `--leave-mixed` |

How a mixed block is taken apart: its removed lines and its added lines each
fall into alternating runs of ours/theirs. The committed region is, region by
region, the lines this session added and the lines someone else removed (their
removal is theirs to commit). The regions are the shortest alternating
sequence both sides fit; if two such readings give different text, or the
block carries git's "no newline at end of file" marker, it is tangled. Worked
examples are in issue 032a, "Two sessions, touching lines".

A new or deleted file is all-or-nothing. A binary or mode-only change counts
only when the file is claimed whole. A file the staging list has never seen
counts when every line is claimed or it is claimed whole.

**Transcripts** are never judged by the ledger: an `llm-transcripts/*.md`
that differs from the branch tip (new, changed, or deleted) rides along
whole, whoever's conversation it is, when it belongs to one of the commit's
projects — the session's project folder, or the project of a committed file
(the nearest folder above it with an `llm-transcripts/` folder) — or when its
header, `# Conversation Summary: <id>`, names this session or a helper
(`agent-<id>`, found as `<sessions-root>/*/<session>/subagents/agent-<id>.jsonl`).
Why taking another's is safe: the exporter replaces each transcript whole in
one step, and lasting edits live in `.patches/`, so there are no lines of
anyone's to tangle with.

## Data

**result** — `collect` returns:

| field | type | meaning |
| --- | --- | --- |
| `patch` | string or nil | the kept blocks as one unified diff, ready for `git apply --cached --unidiff-zero` |
| `whole` | list of strings | repository-relative paths to add whole |
| `report` | list of strings | one line per file or block: `ours`, `whole`, `left out` with the reason |
| `taken` | list of strings | repository-relative paths the patch changes (with `whole`, the files whose projects' transcripts ride along) |
| `mixed` | list of strings | `"path:line"` for every block that could not be taken apart |

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
| `project_of(top, rel)` | repository root, a repository-relative file | the nearest folder above it with `llm-transcripts/`, repository-relative (`""` for the top), or nil |
| `transcript_projects(top, session_dir, files)` | repository root, the session's folder (any spelling; resolved with `realpath`), committed files | set of repository-relative project folders, or nil and a reason |
| `changed_transcripts(top, tip, ids, projects)` | repository root, commit id to compare against, that id set, that project set | sorted list of **transcript entry**, one per transcript that differs from `tip` or is untracked and belongs to a project in the set or to this session; or nil and a reason (read-only) |
| `transcript_report_line(t)` | a **transcript entry** | one report line: path and whose it is, or that it is gone |
| `run(argv, env)` | argument list, optional environment table | output (stderr folded in), success |
| `run_quiet(argv, env)` | argument list, optional environment table | stdout, success, stderr — for output that is data |
| `command_line(argv, env)` | argument list, optional environment table | one quoted shell command line |
