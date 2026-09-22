# Issue 031: Import Project Histories

## Current Behavior

Before the monorepo existed, six projects kept their own git histories. The
first version of this issue imported five of them as side branches
(`import-project-histories.sh`), planning a branch-per-project layout beside a
trunk holding every project. That layout was dropped (046 retired side
branches; worktrees are retired too), and the trunk began instead at one
snapshot, `930edf0d` "Initial commit: AI project collection" (2025-12-15), a
commit with no parents. So on the trunk every project's history starts at the
snapshot: `git log -- handheld-office/` begins on 2025-12-15, and `git blame`
credits the snapshot for lines written in September.

The earlier commits, 52 in all:

| Folder | Commits | Dates | Kept where |
|---|---|---|---|
| handheld-office | 7 | 2025-09-22..23 | bundle (below); GitHub branch |
| risc-v-university | 5 | 2025-11-06 | bundle; GitHub branch |
| progress-ii | 2 | 2025-12-01 | bundle; GitHub branch |
| magic-rumble | 1 | 2025-09-10 | bundle; GitHub branch |
| adroit | 1 | 2025-12-02 | bundle; GitHub branch |
| RPG-autobattler | 36 | 2025-10-22 | the repository nested in its folder, up to `cc62a2f0` |

The five retired branches' local copies were deleted on 2026-09-22 once their
files were confirmed present, in later form, on main. Their complete history
is kept on disk in
`/mnt/mtwo/programming/archives/ai-stuff/retired-project-branches.bundle`
(8.8 MB, verified complete, deliberately not committed), and still on GitHub
until step 8 below. game-state, listed in the first version with 1 commit, was
never imported and its history no longer exists.

**Built, not yet applied:** `delta-version/scripts/graft-project-histories`
(with `libs/commit-id-quotes.lua`, both with `.info.md` files, and
`test-graft-project-histories.sh`: 17 unit checks and 21 integration checks,
all passing, including a full prepare-and-swap on a toy repository). Its
`prepare` step runs against the real trunk read-only and passes every gate
(2026-09-22, main at `77c10b94`, 1611 commits, 118 s):

- the rebuilt trunk has 1611 + 52 = 1663 commits, and its final files are
  identical to the old trunk's;
- all 1611 trunk twins have the same files, author, committer and both dates;
  all 52 project twins hold their original files under their folder, with the
  same identities and dates;
- 1663 messages checked; 6 held quoted ids, and they were translated;
- `git log -- <folder>/` reaches each of the six projects' first commits; for
  example, blame on `handheld-office/src/lib.rs` credits 33 of 35 lines to
  2025-09-22;
- the three carried tags follow their commits;
- the quote commit rewrites 658 ids in 84 files (66 transcripts, 13 issue
  files, `README-3.md` and four documents), with none lengthened, none left
  ambiguous, and none left as 7-digit numbers. Undoing it restores every file
  byte for byte, and with the ids masked, its 624 removed and 624 added lines
  are identical.

The swap has not happened. The real trunk, its refs and GitHub are untouched.

## Intended Behavior

Every project's history reads as one line from its first commit to today,
with the default tools and on GitHub. The snapshot commit becomes the point
where the histories join: its parents are each project's last commit before
it, and its change against each parent is what that project gained between
then and the snapshot. No file, author, date or message changes. Project
commits keep their identities and dates; their files sit one folder down,
where they live on the trunk.

Decided on 2026-09-22 (the person's answers):

1. **Rewrite the trunk (approach A below)**, accepting that every commit after
   the snapshot gets a new id.
2. **Include RPG-autobattler's 36 commits** in the same rewrite, so it happens
   once.
3. **Rewrite the quoted ids too**, in the trunk's files and in commit
   messages, with transcripts carrying the new ids afterwards. Also keep
   `archive/main-before-history-graft` (the old trunk) and
   `archive/pre-import/<folder>` (each project's last pre-snapshot commit) as
   tags, and commit the map at
   `delta-version/archive/history-graft/commits.map`, with a note in
   `delta-version/archive/history-graft/README.md`. Every old id then stays
   resolvable and translatable.
4. **Prepare now; swap and push only when the person says the repository is
   quiet.**

## Suggested Implementation Steps

Steps 1–3 are done; the rest is the swap-day checklist.

1. ~~Build the tool (prepare / swap / translate), the quote library, and their
   tests.~~
2. ~~Move the retired branches' bundle to durable storage.~~
3. ~~Run `prepare` against the real trunk and pass every gate.~~
4. **Freeze.** Every session working in the monorepo commits its work, or sets
   it aside, and stops. The index must hold no staged changes, since swap
   refuses otherwise. Uncommitted edits in files the quote commit changes
   (mostly `llm-transcripts/`) block its last step, so commit those too.
5. **Prepare again.** Main will have moved since the last run; `prepare`
   rebuilds from the current main (about two minutes). Read the gates and the
   result lines. A reboot empties the scratch area, so a fresh run is needed
   anyway.
6. **Swap** from a terminal:
   `delta-version/scripts/graft-project-histories swap --i-understand-this-rewrites-history`,
   then type `rewrite main`. It checks that main is still the prepared one,
   tags the archive and pre-import tips, moves `main` with a compare-and-swap
   (the files are identical, so nothing on disk changes), moves the three
   tags, fast-forwards onto the quote commit, and prints the push commands.
7. **Look before publishing:** `git log -- handheld-office/ | tail`,
   `git blame` on a project file, and `git status`. To roll back before
   publishing: `git update-ref refs/heads/main archive/main-before-history-graft`,
   then `git checkout -- .` for the quote commit's files.
8. **Publish**, with the commands swap printed, in order: the archive tags;
   `main` with `--force-with-lease` against the recorded origin/main; the
   moved tags; deleting the five retired branches on GitHub; `fetch --prune`.
9. **Afterwards:**
   - Translate quoted ids in files written or left uncommitted since prepare:
     `graft-project-histories translate <file>...`.
   - Commit this issue, and move it to completed.
   - Decide the questions below.

## Approaches Considered

Measured on scratch copies on 2026-09-22.

- **A. Rewrite the trunk with the join built in (chosen).** Measured above.
  Every trunk commit id changes. Five commits made in GitHub's web editor lose
  GitHub's signature (`33bcff7d`, `28590707`, `17c74464`, `035a0a89`,
  `e0642cd2`); the archive tag keeps the signed originals.
- **B. Join with merge commits, rewrite nothing.** No ids change. But git's
  default history view follows the parent the merge's files match, so
  `git log -- <folder>/` and blame still start at the snapshot, on GitHub too.
  The old commits show only with `--full-history`.
- **C. Replacement refs only.** Looks like A on a machine that has the refs.
  Ordinary clones don't fetch them and GitHub ignores them.

## Risks & Rollback

- **Transcripts may revert to old ids.** Transcripts are regenerated from
  Claude Code's session files, which keep the ids as they were said. If
  `backup-conversations --all` or `rederive-transcripts --write` re-renders an
  old session, the file goes back to old ids and shows as modified. The
  exporter would need to apply the map as it writes (see Open Questions).
  Until then, `translate` repairs a regenerated file.
- **A session commits mid-swap:** refused by the compare-and-swap.
- **Rollback after publishing:** force-push
  `archive/main-before-history-graft` to `main`. Every old id still exists.
- **Signatures on the five web-editor commits are dropped:** kept on the
  archive tag.

## Coordination

- The swap needs a quiet repository and a person at the terminal (it asks for
  typed confirmation).
- GitHub shows 0 forks, 0 stars and 0 watchers; any other clone must re-clone,
  or run `git fetch && git reset --keep origin/main`.
- The nested repositories (RPG-autobattler's own `.git`, `symbeline-2`,
  `llm-http`) are separate and are not rewritten.

## Open Questions

1. Should the transcript exporter apply `commits.map` when it renders, so a
   re-rendered transcript keeps the new ids?
2. After the swap, RPG-autobattler's nested repository adds nothing: its first
   36 commits are on the trunk, and its 4 later ones mirror trunk work. Should
   it be archived to the same bundle folder and removed?
3. The bundle becomes redundant once the swap is published, because the
   pre-import tags hold the same commits on GitHub. Keep it, or delete it
   then?

## Related

- `import-project-histories.sh`: the first version's branch importer.
- 046 (side branches retired), 041 (worktrees, deprecated).
- 035 / 035e: history reconstruction for projects without any git history.
- `scripts/issues/032-commit-only-your-own-lines.md`: the commit route used for
  committing this issue and the tool.
