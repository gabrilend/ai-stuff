# Issue 032a: Commit Through a Private Staging Area

Sub-issue of `032-commit-only-your-own-lines.md`.

## Current Behavior

Every session working in a repository shares one staging area, the file
`.git/index`: a sorted list of (path, mode, content id) entries that
`git commit` turns into the next snapshot. 032 made each session stage only
its own lines (`stage-own-changes`, from the edit ledger) and put a gate in
front of `git commit` that refuses when the index holds a line the session did
not write. Staging and committing are still two steps on one shared list, and
the gate checks the list before the command line runs, not at the moment
`git commit` reads it.

On 2026-09-22 that gap swept one session's work into another's commit. The
neocities session ran, on one line, its own `stage-own-changes`, an unstage,
and `git commit`. Its gate ran first and found the index clean. While that
line's `stage-own-changes` was still working, this session's
`stage-own-changes` staged 55 files (the transcript-patch rework) into the same
index, and the neocities `git commit` recorded them all under the message
"Pages tell phones they are already dark" (`1ad8bb7d5`, pushed, then untangled
into `4efe1f8c0` plus three commits of this session's own). The gate even
advertised `stage-own-changes` as safe on the same line as a commit, which
widened the window to seconds. No gate that runs before a command can close
it: the list is shared, and anyone may write it between the check and the
commit.

The private route below is built and tested. Everything in this issue is
built and tested, including the three parts answered on 2026-09-23: the
project-scoped transcript rule, taking this session's lines out of a block
tangled with someone else's, and running the repository's commit hooks. The
remaining open question is whether hooks should be given more information.

## Intended Behavior

A session commits without reading or writing the shared staging area, so
nothing another session has staged can ride along, and nothing of this
session's can ride along in theirs.

- `commit-own-changes <repo> -F -` builds the commit on a private staging list
  (git's `GIT_INDEX_FILE`, a file in RAM) seeded from the branch tip, applies
  only this session's own lines to it with `git apply --cached`, turns it into a
  commit, and moves the branch with a compare-and-swap (`git update-ref
  <branch> NEW OLD`), which refuses if anyone moved the branch in between. On a
  refusal it rebuilds on the new tip and tries again.
- Only then does it touch the shared staging area, and only for the paths it
  just committed, so `git status` does not show the new commit as staged to be
  undone. An entry nobody staged is set to the new content. An entry someone
  staged by hand is rebuilt as "new commit plus their staged change" with a
  three-way merge of that one file; if the merge conflicts, the entry is left as
  it was and the person is told.
- The working tree is never written.
- Runs of `commit-own-changes` in one repository take turns under a lock, so
  two sessions committing at the same instant cannot interleave their
  shared-staging-area updates; the compare-and-swap still guards against any
  other writer of the branch.
- A plain `git commit` is refused by the gate, with a pointer to this command.
- `stage-own-changes` stops writing the shared staging area and becomes a
  preview of what `commit-own-changes` would commit.

### Two sessions, one file

`notes.md` is F0 on main. Session 1 writes change A near the top; session 2
writes change B near the bottom. The file on disk is F0 + A + B, and each
ledger knows only its own lines.

1. Session 1 commits: private list = F0; apply A; commit F0 + A; main moves.
2. Session 2 commits: private list = F0 + A (the new tip); the difference
   between disk and the tip is now only B; apply B; commit F0 + A + B.

Neither commit carries the other session's lines, nothing is reverted, and the
order does not matter. If both run at once, the lock makes one wait for the
other, and the second builds on the first.

### Two sessions, touching lines

When A and B sit on neighbouring lines with no unchanged line between them,
git sees one change block holding both: "mixed". The session's lines are
taken out of it anyway: an agent that wrote specific lines gets exactly
those lines committed, and nobody else's.

How the block is taken apart. Inside a block, git lists the lines removed
from the tip (in file order) and then the lines added on disk (in file
order). Each line is marked this session's or not, from the ledger. The
committed version of the region is built from:
- the lines this session added, and
- the lines someone else removed (their removal is theirs to commit, so the
  line stays for now);
while lines this session removed are dropped and lines someone else added are
left out. What the ledger does not record is where, inside the block, this
session's lines sit relative to the other's. That order is read from the
runs: the removed side and the added side each fall into alternating runs of
"ours" and "theirs", and both sides must fit one sequence of regions, the
shortest one possible. Example: `c2 -> own-c2` (ours) next to `c3 -> their-c3`
(theirs). Removed runs: ours, theirs. Added runs: ours, theirs. Regions: ours,
then theirs. The committed region is `own-c2, c3`.

When the data allows more than one order (two shortest sequences, or a run
that could sit in either of two places and that changes the result), the two
sessions changed the same place. Example: session 1 turned X into "one",
session 2 turned "one" into "two"; the block is `X -> two`, with X not
removed by session 2 and "two" added by it. "two" could go above or below X,
and neither is session 2's intent (its change was made to "one", which the
tip never held). The command stops, names the file and line, and changes
nothing. `--leave-mixed` commits everything else and reports those blocks.

A block with git's "no newline at end of file" marker in it is never taken
apart (the marker belongs to a line whose owner the split might move); it
counts as the same-place case.

### Transcripts

Transcripts are one story told across conversations, and git should hold as
much of each project's part of it as it can. A commit carries every changed
transcript (new, grown, or gone) that belongs to one of these projects:
- **the session's project**: the folder the session runs in (the harness's
  working directory, which never moves; the tool reads it from the directory
  it is run from, or from `--project <dir>`). This is where the exporter
  writes the session's own transcripts, and where the stragglers of earlier
  sessions in the same project pile up.
- **the project of any file the commit carries**: for each file, the nearest
  folder above it that has an `llm-transcripts/` folder. A session that
  reaches out of its project (say, into `delta-version/` to fix a script)
  carries that project's transcripts in that commit too.
A transcript whose header names this session or its helpers rides along
wherever it is. A `-- <path>` limit does not narrow the transcripts, only the
files; the projects of the limited files still count.

Why not every transcript in the repository: in the ai-stuff monorepo a commit
about one project would carry the transcripts of every other project, which
muddles the commit's story. Why not only this conversation's: that was the
second rule, and under it a session that committed, talked a little more and
quit left its transcript's last lines uncommittable forever (the kiln
project, 2026-09-23). The first rule (032) took every `llm-transcripts/`
folder near a touched file, which is close to the second bullet above.

Why taking another conversation's transcript is safe, when taking its source
lines is not:
- The exporter writes a transcript to a temporary file and moves it into place
  (`mv -f`), so the file on disk is always a whole rendering and never a
  half-written one. Taking it records one true moment of that conversation.
  The next commit, by anyone, records the next moment.
- Nobody edits a transcript line by line in the working tree. The exporter
  rewrites it whole from the session log, and lasting edits go through
  `llm-transcripts/.patches/` (issue 036). So there are no lines of anyone's to
  tangle with, and a transcript is always taken whole, never judged against
  the ledger.
- A transcript that has disappeared from disk was renamed by the exporter (a
  conversation that crosses midnight becomes a date-range file, issue 018) or
  retired as a husk. Its deletion is committed alongside its new name, so the
  rename shows up in one commit. Were a transcript deleted by accident, the
  deletion still rides along; that is accepted, because the text stays in
  git's history (answered 2026-09-23).

The report marks each transcript as this conversation's or another's, and
marks it as gone when it was deleted, so the commit's reader can see what
rode along.

### Commit hooks

A commit made with `git commit-tree` runs none of git's hooks, so the command
runs them itself, in git's order, with git's arguments:
1. `pre-commit`, with `GIT_INDEX_FILE` set to the private staging list, from
   the repository's top folder. A failure stops the commit. Anything it
   stages lands in the private list, and so in the commit.
2. `prepare-commit-msg <message file> message`, then `commit-msg <message
   file>`, on a copy of the message; either may rewrite it, and a failure of
   either stops the commit.
3. `post-commit`, after the branch has moved; its exit status is reported but
   changes nothing, as in git.
Hooks are found where git looks (`git rev-parse --git-path hooks/<name>`, so
`core.hooksPath` is honoured) and run only when executable. Every hook also
sees `COMMIT_OWN_CHANGES=1` and the session's `CLAUDE_CODE_SESSION_ID`, so a
hook can tell this route from a person's `git commit`. `--no-verify` skips
`pre-commit` and `commit-msg`, as it does for git. Hook output is shown in the
report.

### Amending

A plain `git commit --amend` is refused like any other plain commit. Commits
are small and the history is append-only; a correction is a new commit. The
one-time token remains for the rare exception.

## Suggested Implementation Steps

1. Move the change-block judging out of `stage-own-changes` into a shared
   library (`libs/own-changes-patch.lua`): classify each block as ours,
   foreign or mixed; take this session's lines out of a mixed block when their
   order is determined; build the patch; judge untracked files; find the
   changed transcripts of the session's project and of the committed files'
   projects. Both tools use it, so they cannot disagree.
2. Write `commit-own-changes`: take the per-repository lock (`flock` on a file
   in the repository's git directory), read the branch and its tip, seed a
   private list in RAM, diff the working tree against it for the ledger's
   files, stop on blocks that cannot be taken apart, apply ours, add whole
   claimed files and the changed transcripts, run `pre-commit`, write the tree,
   run the message hooks, commit it with the tip as parent, compare-and-swap
   the branch, retry on a moved branch, run `post-commit`, sync the shared
   list for the committed paths, and report.
3. Turn `stage-own-changes` into the preview.
4. Change the gate: refuse any `git commit` that records something (dry runs
   and help pass), pointing at `commit-own-changes`; drop the same-line advice.
5. Tests in scratch repositories: two sessions on one file in both orders;
   twenty rounds of simultaneous commits; touching lines taken apart (a
   replacement beside a replacement, an insertion beside a replacement, a
   deletion beside a replacement); the same line changed by both (stops);
   hand-staged entries (clean merge and conflict); other entries and the
   working tree untouched; new, deleted and renamed files; nothing to commit;
   the transcript rule (the session's project, a committed file's project, an
   unrelated project left out, this conversation's anywhere, a
   transcript-only commit, a renamed transcript's deletion); the hooks (a
   pre-commit that refuses, one that stages a file, a commit-msg that rewrites
   the message, --no-verify, post-commit); a branch other than main; a branch
   moved between build and swap (retry); the gate.
6. Update `README-refusal-gates.md`, the `.info.md` files, and the
   issue-lifecycle and transcript-care skills.

## Open Questions

1. Hooks get git's standard arguments plus `COMMIT_OWN_CHANGES=1` and the
   session id. The owner remembers that extra arguments to hooks once would
   have prevented some unwanted behaviour, but not which. What should hooks
   be told beyond this?

## Answered Questions

- Should deletions of transcripts ride along? Yes; they stay in git's history
  (2026-09-23).
- Should transcripts be limited to the project? Yes: the session's project,
  plus the projects of the files the commit carries (2026-09-23).
- When a session's lines touch someone else's, stop or leave them out? Take
  the session's lines: an agent that named its lines gets exactly those
  committed (2026-09-23). Only a true same-place change still stops.
- Should the command run commit hooks? Yes (2026-09-23).

## Related

- `032-commit-only-your-own-lines.md` (parent): the ledger, the gate.
- `034-export-only-the-session-that-stopped.md`: the exporter whose transcript
  headers the transcript rule reads.
