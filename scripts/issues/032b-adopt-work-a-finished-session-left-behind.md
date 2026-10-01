# Issue 032b: Adopt Work a Finished Session Left Behind

Sub-issue of `032-commit-only-your-own-lines.md`. Builds on
`032a-commit-through-a-private-staging-area.md`.

## Current Behavior

The commit route takes only lines the committing session's edit ledger
claims, and the ledger lives in RAM (`/dev/shm/claude-own-edits/<session>/`),
one per session. Work that a session wrote and never committed becomes
ownerless when that session ends and a new one picks up the job. It becomes
ownerless even when the old ledger still exists, because the new session has
a different id. A reboot empties every ledger.

On 2026-09-29, in `wow-chat-2026`, a session was asked to commit the large
backlog an earlier session had left. The machine had rebooted at 01:38, so
that backlog had no owner. `commit-own-changes` had nothing it could take.
`stage-own-changes` was refused by the auto-mode permission classifier. The
commit gate's only exit was the person's one-time token. Each token covers one
commit, and about ten commits were planned. The first plain commit also
carried a rename that someone else had staged in the shared staging area,
which is exactly the accident the gate exists to prevent.

`claim-own-change <file>` could have claimed the files, but it claims whole
files. That sweeps in any other session's lines in them, and its own words
restrict it to files "this session produced".

**Built (2026-09-29):**
- `adopt-left-behind-changes` does everything described under Intended
  Behavior, and the ledger library has `all_sessions`.
- The gate's refusal names the adoption route.
- `stage-own-changes` and the adoption command are allowed in
  `~/.claude/settings.json`.
- The README, the `.info.md` files and the issue-lifecycle skill describe the
  route.
- `tests/test-adopt-left-behind.sh` has 30 checks, and `test-refusal-gates`
  runs it.

The issue stays open until the open question below is answered.

## Intended Behavior

### What the gates protect, restated

A commit must never record lines that a *live* session is still working on,
and must never record what someone put in the shared staging area. The
danger is always a collision with somebody who is still around. Lines whose
author has gone have nobody to collide with. They need an owner, not a
refusal.

### Adoption

`adopt-left-behind-changes <repo> -- <path>...` takes ownership of left-behind
work, out loud and on the record:

1. It reads every uncommitted change under the named paths: tracked changes
   against the branch tip, and untracked files git does not ignore.
   Transcripts (`llm-transcripts/`) are skipped, because they ride along on
   every commit anyway.
2. It loads every other session's ledger in `/dev/shm/claude-own-edits/`. A
   line any of them claims is **held**. Held lines are left alone and
   reported with the session id and the time that ledger was last written, so
   whoever is reading can tell a session that is still working from a stale
   one.
3. Every other changed line becomes this session's. It is appended to this
   session's ledger as the same line-level `+` and `-` records the edit hook
   writes, so the commit route judges it the same way as a line the session
   typed itself. An untracked or binary file that no other ledger names at all
   is claimed whole.
4. `--from <session-id>` (repeatable) also takes lines held by a named
   session, for a ledger that is still in RAM but whose session has ended.
   Naming the session is the statement "that session is finished", written
   where the transcript records it.
5. `--dry-run` prints the same report and writes nothing.

At least one path is required, and `.` counts as a path. In the ai-stuff
monorepo, adopting "everything" would reach into thirty projects, so the
scope has to be named.

After adopting, the normal route commits the work: `commit-own-changes <repo>
-- <path>... -F -`, one batch at a time. No token is needed, and nothing from
the shared staging area rides along.

### The gate points the way

The commit gate's refusal names the adoption route beside the commit route.
A session that hits the wall then finds the door without asking the person
for a token. The token stays for the case nothing else covers.

### The preview is not a stranger to the classifier

`stage-own-changes` writes nothing. `adopt-left-behind-changes` writes only
this session's RAM ledger, and every run is printed in the transcript. Both
are allowed in `~/.claude/settings.json`, so the auto-mode classifier does
not refuse them for being scripts it has not seen before.

### Decisions not taken

- **Keeping ledgers on disk so they survive a reboot.** This would not help.
  A new session has a new id, so the old ledger would still not be its own,
  and the handover would still need a named step. Adoption covers both a
  reboot and a session that has ended.
- **Deciding automatically whether a session is live.** A session can sit
  idle for hours and still be working, so neither a ledger's age nor a session
  log's age can say it has finished. The report shows the times, and the
  adopting session names the finished ones with `--from`.
- **Relaxing `claim-own-change` instead.** A whole-file claim cannot leave
  another session's lines out. Adoption works line by line.

### Known limits

- A person's own hand edits have no ledger, so adoption treats them as left
  behind and takes them. That is right when the person asked for the commit,
  and wrong when the person is still typing in that file.
- Claims are by line text within a file, as everywhere in 032. A line
  identical to one another ledger holds in the same file counts as held, which
  errs toward leaving lines out.

## Suggested Implementation Steps

1. `adopt-left-behind-changes` (LuaJIT, beside the other commands): parse
   `<repo>`, `--from`, `--dry-run`, `--scripts-dir` and `-- <path>...`. Diff
   against the tip (or git's empty tree) with `-U0 --no-renames`. List
   untracked files. Load the other ledgers through `own-lines-ledger.lua`.
   Judge each line with `line_claimed`. Write the records with
   `ledger.append`, and print the report.
2. Add a list of every ledger and its last-write time to
   `own-lines-ledger.lua` (`ledger.all_sessions`).
3. Change the gate's refusal text to name the adoption route.
4. Tests (`tests/test-adopt-left-behind.sh`), in a scratch repository with
   made-up session ids: a finished session's changes are adopted and then
   committed by `commit-own-changes`; a live session's lines in the same file
   stay held and are left out of the commit; `--from` takes them; untracked
   and deleted files; transcripts skipped; `--dry-run` writes nothing; no path
   given is an error. Wire it into `test-refusal-gates`.
5. Update `README-refusal-gates.md`, the `.info.md` files, the issue-lifecycle
   skill's "When it stops" list, and the allow list in
   `~/.claude/settings.json`.

## Open Questions

1. A person's own uncommitted hand edits look left behind and get adopted.
   Should adoption skip files that changed on disk in the last few minutes,
   treating them as "someone may be typing here", or is the named path scope
   enough?

## Related

- `032-commit-only-your-own-lines.md` (parent): the ledger and the gate.
- `032a-commit-through-a-private-staging-area.md`: the commit route that
  adopted lines are committed through.
