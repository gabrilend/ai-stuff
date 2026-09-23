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

The private route below is built and tested. Its transcript rule is the
everything-that-changed rule described under Transcripts. The earlier rule,
this-conversation-only, stranded transcripts, and this one replaced it on
2026-09-23. The two open questions remain.

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

If both sessions changed the same lines (session 1 turned X into "one",
session 2 turned "one" into "two"), the difference between disk and the tip is
a change block neither session wholly wrote: "mixed". The command stops,
names the file and line, and changes nothing. A person, or the two sessions
talking, decides what that region says.

### Transcripts

Every commit carries every transcript in the repository that differs from the
branch tip: new, grown, or gone. It doesn't matter whose conversation it is,
which project folder it sits in, or whether a `-- <path>` limit was given.

The transcripts are one story told across conversations, and git should hold
as much of it as it can. A narrower rule left transcripts behind with no way
to commit them. The first version (032) took every `llm-transcripts/` folder
near a touched file. The second version (the first cut of this issue) took
only transcripts whose header names this session or its helpers. Under the
second rule, if a session committed, talked a little more, and then quit, its
transcript's last lines were dirty for good: no later session could take the
file, and a plain `git commit` is refused. That happened with the kiln
project's transcript on 2026-09-23.

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
  rename shows up in one commit, and the old text stays in history.

The report marks each transcript as this conversation's or another's, and
marks it as gone when it was deleted, so the commit's reader can see what
rode along.

### Amending

A plain `git commit --amend` is refused like any other plain commit. Commits
are small and the history is append-only; a correction is a new commit. The
one-time token remains for the rare exception.

## Suggested Implementation Steps

1. Move the change-block judging out of `stage-own-changes` into a shared
   library (`libs/own-changes-patch.lua`): classify each block as ours, foreign
   or mixed; build the patch of our blocks; judge untracked files; find every
   changed transcript and say whose each is. Both tools use it, so they cannot disagree.
2. Write `commit-own-changes`: take the per-repository lock (`flock` on a file in
   the repository's git directory), read the branch and its tip, seed a private
   list in RAM, diff the working tree against it for the ledger's files, stop on
   mixed blocks, apply our blocks, add whole claimed files and every changed transcript,
   write the tree, commit it with the tip as parent, compare-and-swap the
   branch, retry on a moved branch, sync the shared list for the committed
   paths, and report.
3. Turn `stage-own-changes` into the preview.
4. Change the gate: refuse any `git commit` that records something (dry runs
   and help pass), pointing at `commit-own-changes`; drop the same-line advice.
5. Tests in scratch repositories: two sessions on one file in both orders;
   twenty rounds of simultaneous commits; an overlapping edit; hand-staged
   entries (clean merge and conflict); other entries and the working tree
   untouched; new, deleted and renamed files; nothing to commit; the transcript
   rule (this conversation's, another's, one outside the path limit, a
   transcript-only commit, a renamed transcript's deletion); a branch other than main; a branch moved between build and swap
   (retry); the gate.
6. Update `README-refusal-gates.md`, the `.info.md` files, and the
   issue-lifecycle and transcript-care skills.

## Open Questions

1. When a session's own block is mixed with another's, the command stops the
   whole commit. `--leave-mixed` commits the rest and reports the mixed blocks.
   Is stopping the right default, or should leaving them out be?
2. Hooks run by `git commit` (pre-commit, commit-msg) do not run, because the
   commit is made with `git commit-tree`. No repository here uses them today.
   Should the command run them itself if one appears?

## Related

- `032-commit-only-your-own-lines.md` (parent): the ledger, the gate.
- `034-export-only-the-session-that-stopped.md`: the exporter whose transcript
  headers the transcript rule reads.
