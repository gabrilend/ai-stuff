# commit-own-changes

Commits exactly the lines this Claude Code session wrote, in one repository,
without reading or writing the staging area other sessions share. The only
route for commits since issue 032a; the commit gate (`refuse-foreign-lines`)
turns a plain `git commit` away toward it.

## Usage

```
commit-own-changes [repository] -F - <<'EOF'
Subject line

Body.
EOF
```

| option | meaning |
| --- | --- |
| `repository` | defaults to the ai-stuff monorepo |
| `-F -` / `-F <file>` / `-m <message>` | the commit message; one is required |
| `--leave-mixed` | commit the session's other blocks even when some changed the same place as someone else (blocks that merely touch are taken apart anyway) |
| `--no-verify` | skip the `pre-commit` and `commit-msg` hooks, as git does |
| `--project <dir>` | the session's project folder, whose changed transcripts ride along; default the current folder, which Claude Code keeps at the session's project |
| `--scripts-dir <dir>` | where the libraries live (for trying a copy) |
| `-- <path>...` | commit only this session's changes in these files or folders (repository-relative), to commit work in small pieces; the transcripts of the session's project and of the limited files' projects still ride along |

Exit 0 when a commit was made; 1 for nothing to commit, a tangled block, a
refusing hook, a branch that kept moving, or any error. Preview first with
`stage-own-changes <repository>`.

## What it does, in order

1. Takes the repository's commit lock (`<git dir>/commit-own-changes.lock`,
   `flock`, up to 120 s), so simultaneous runs take turns.
2. Reads the branch HEAD points at and its tip. A detached HEAD is an error.
3. Seeds a private staging list in RAM (`GIT_INDEX_FILE` under
   `/dev/shm/claude-own-edits/<session>/`) from the tip.
4. Judges the ledger's files against it (`libs/own-changes-patch.lua`); stops
   takes apart blocks where its lines touch someone else's; stops on a block
   where both changed the same place unless `--leave-mixed`.
5. Applies this session's blocks with `git apply --cached`, adds whole-claimed
   files and the changed transcripts of the commit's projects (any
   conversation's; a deleted one's deletion too), runs `pre-commit` against
   the private list, writes the tree, runs `prepare-commit-msg` and
   `commit-msg` on a copy of the message, and makes a commit with the tip as
   parent (`git commit-tree`).
6. Moves the branch with `git update-ref <branch> <new> <tip>`, which refuses
   if the branch moved; then rebuilds on the new tip, up to 5 attempts.
7. Updates the shared staging area for the committed paths only: an entry equal
   to the old version (or a stale committed one) follows the commit; an entry
   someone staged by hand is rebuilt as commit + their change by a three-way
   merge of that file, or left alone with a warning if that conflicts.
8. Prints the commit, what it took, what it left out, and any warning.

Never written: the files on disk, and shared staging entries for any path it
did not commit. After the branch moves, `post-commit` runs; its verdict is
reported and changes nothing. Every hook sees `COMMIT_OWN_CHANGES=1`.

## Environment

| variable | meaning |
| --- | --- |
| `CLAUDE_CODE_SESSION_ID` | the session whose ledger is read (set by Claude Code) |
| `CLAUDE_SESSIONS_ROOT` | Claude Code's session store, for finding helper conversations; default `~/.claude/projects` |
| `COMMIT_OWN_CHANGES_LOCKED` | internal: set when re-run under the lock |
| `COMMIT_OWN_CHANGES_TEST_BEFORE_SWAP` | tests only: a command run just before the branch is moved |

## Tests

`tests/test-commit-own-changes.sh` (run by `test-refusal-gates`).
