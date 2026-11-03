# Issue 063: Disentangle the Author from History

**Status**: Planned
**Priority**: Medium (the owner set no deadline: "there is no urgency, take
your time")
**Created**: 2026-10-01
**Type**: History rewrite of the monorepo (the second, after issue 031)
**Related**: `completed/031-import-project-histories.md` (the first rewrite
and its tool), `scripts/issues/003a-redaction-capability.md` (the
redactions this rewrite applies), `scripts/issues/036-transcript-patches.md`
(commit id translation in transcripts)
**Waits on**: `scripts/issues/003a-redaction-capability.md` (another
project's issue, so it is named here rather than as a blocker the issue
checker would look for in this project)

---

## Current Behavior

**Swapped and published; waiting on GitHub Support** (2026-11-03). The owner
gave the word ("Just remove the files as best you can"). The rewrite was made
in a scratch mirror on `/mnt/kaun`, passed every gate below, and the owner
ran the publish script herself, because Claude Code's safety check refuses a
force-push from a session: `main` (now `f24bf609`), the 237 `claude/*`
branches and the 9 kept tags were replaced, the archive tag deleted, and this
machine's `main` moved onto the new history. The open pull requests followed
their branches. Before it, a full mirror of GitHub's state, pull-request refs
included, was kept at `/mnt/kaun/scratch/ai-stuff-github-backup-2026-11-03.git`.
Then the quoted ids were translated (steps 6 and 7, below). The owner's
request to GitHub Support (delete pull request #1, dereference the old
commits behind the force-push links, run garbage collection) is filed; this
issue is complete when it is answered. Remaking the GitHub repository was proposed and refused
by the owner ("I do not want to do that"); the swap stays a force-push (see
Intended Behavior). The redactions of issue 003a are
not part of this pass: the mail state lives inside `words-pdf/input/`, which
is removed whole, so no byte-level redaction is needed for it.

**The inventory** (step 1), found by path in every commit of every ref,
GitHub's 237 `claude/*` branches included. The owner did not know of most of
the neocities part:

| Path | What it held | Tracked |
|---|---|---|
| `neocities-modernization/input/` | 977 files: pictures sent in messages, pictures never posted, drawings and poem pictures, notes (Reddit comments among them), a Bluesky account export, extracted poems | 2025-12-15 to 2026-06-29 |
| `neocities-modernization/assets/`, `output/` | generated poem data and a generated copy of the poem site | until 2025-12-23 |
| `neocities-modernization/excluded-poems.txt`, `config/excluded-poems.txt` | the lists of poems kept off the site | early history |
| `words-pdf/input/` | 510 files: poems, notes, the mail tool's state | until 2026-10-01 |
| `neocities-modernization/compiled.txt`, `words-pdf/backup-mvp/input/` | the compiled poems, twice | until 2026-11-03 (ignored that day) |

**The prepared rewrite** (`git filter-repo --invert-paths` on those eight
paths, in a `--no-local` mirror; a plain local clone raced a background
repack and lost a pack file mid-copy):

- 1,567 paths removed; none reachable from any ref afterwards.
- `main`'s newest tree identical apart from the two poem copies.
- All 2,120 surviving commits on `main` keep author, committer, both dates
  and subject.
- 25 commits across all refs (12 on `main`) held nothing else and are
  dropped, among them "Five notes, and a folder of letters" and the notes
  added between 2026-08-11 and 2026-09-09.
- filter-repo translates abbreviated ids in commit messages itself; its map
  is `filter-repo/commit-map` in the mirror, kept as
  `delta-version/archive/disentangle/commits.map`.

**The quoted ids** (open question 1 answered: one combined map). The two
rewrites' maps are joined into `delta-version/archive/disentangle/chained.map`,
oldest id to today's, so a quote from before the graft, between the
rewrites, or of a commit made just before this one lands on today's commit.
Tracked text files were translated in place with `commit-id-quotes.lua
translate` against every old commit id (the GitHub backup's and this
repository's), except the transcript patches, the maps themselves, the saved
pull-request record, and files another session had open: about 1,900 quotes
in 707 files, among them the development-history fingerprints, which record
the commit each picture was taken at. Each conversation with a session log
got its id patch refreshed from the chained map (`transcript-patches
translate-ids`, with `TRANSCRIPT_PATCHES_UNIVERSE` naming the old ids rather
than keeping a ref to the old history). 30 transcripts on disk lag behind
their session logs (a recap or a turn added since the last export); none
quotes an old id, and the next export brings each up to date.

The owner's poems and the mail tool's private state are in git history, on
a public GitHub repository (`gabrilend/ai-stuff`):

- **`words-pdf/input/`** has been tracked since the trunk's first commit
  (`472e9b9d`, 2025-12-15). It held 510 files: the poems, the notes, and the
  mail tool's folder `notes/rmail/`. On 2026-10-01 it stopped being tracked
  and was added to `.gitignore`. The files stay on disk; history still holds
  every earlier version.
- **The mail tool's state** came in with "Five notes, and a folder of
  letters" (2026-09-09). It held the home network's public address, the
  local address, and a notice naming the forwarded mail port. Its contacts
  file was only the example template; no real contact or token was ever
  committed.
- **Other copies of the poems are tracked:** `neocities-modernization/compiled.txt`
  and `words-pdf/backup-mvp/input/compiled.txt`. Possibly more as well, such
  as the word-cloud pages under `neocities-modernization/archive/` (step 1
  takes the inventory). The generated website is built in RAM and was never
  tracked.
- **The tag `archive/main-before-history-graft`** keeps the trunk as it was
  before issue 031 and is on GitHub. It holds a second copy of the
  2026-09-09 commit.

## Intended Behavior

The software is separated from its author. Anyone who clones the
repository gets the tools, not the poems or the author's home network.
Someone who wants the poems asks for them on purpose, through the mail tool
by the same request route the RGPL will use for source code.

After the rewrite:

- **No commit on any published branch or tag contains:**
  - the poem files (`words-pdf/input/`, the compiled copies, and anything
    else step 1 finds);
  - the mail tool's state;
  - the bytes the redactions in scripts issue 003a cut, wherever else they
    appear (in a transcript, for instance).
- **Everything else is unchanged:** every other file, author, date and
  message. The rewritten main's final files are byte-identical to the old
  main's, except for the removed paths.
- **Every commit id quoted anywhere still leads somewhere:**
  - in commit messages, the rewrite translates them;
  - in tracked files (issues, docs), a quote commit translates them, as in
    issue 031;
  - in transcripts, id patches from `transcript-patches translate-ids`
    translate them, because transcripts are re-rendered from session logs
    that keep the old ids.

  The rewrite is the first large use of the patch and redaction system.
- **`archive/main-before-history-graft` is deleted,** on GitHub and here (the
  owner's decision, 2026-10-01). Its old ids still translate through
  `delta-version/archive/history-graft/commits.map`.
- **What GitHub keeps after the force-push.** Found 2026-11-03: GitHub
  keeps every pull request's refs (`refs/pull/N/head`), and only GitHub
  Support can delete them. ai-stuff has 237 pull requests: 236 open drafts
  and one merged (#1, "Implement WC3 gameplay systems and world editor
  integration"). Force-pushing the cleaned `claude/*` branches moves each
  open pull request to its clean commits, but each one's timeline keeps a
  link to the old commits, and #1's ref keeps the old history for good.
  Deleting and remaking the repository would remove all of that; the owner
  refused it ("I do not want to do that"). What is left is accepted, or
  removed later by a request to GitHub Support, the owner's choice. Every
  pull request's details are saved in
  `delta-version/archive/disentangle/pull-requests.json` all the same.
- **No old clone pushes again.** Any session holding a clone of the old
  history (a cloud session, a worktree) would carry the old commits back
  on its first push. Every such session is stopped before the swap and
  starts again from a fresh clone afterwards.

## Suggested Implementation Steps

1. **Inventory.** List every tracked path, past and present, that holds
   poem text or the mail tool's state:
   - `git log --all --name-only` filtered for the known folders;
   - a search of history for a few distinctive poem lines;
   - a search of history for the network address bytes held in the
     redaction store.

   The owner confirms the list before anything is rewritten.
2. **Redactions ready** (scripts issue 003a, which this is blocked by). The
   network address and port are recorded as redactions. Stage 1 writes
   filter-repo's replace-text file in RAM.
3. **Prepare in a scratch mirror, never in place.** Run git-filter-repo in
   a mirror clone in RAM. In a working checkout it would reset the working
   tree, which would wipe uncommitted work from other sessions, such as
   world-edit-to-execute's. It runs with `--invert-paths` on the inventory's
   paths and `--replace-text` on the redaction file. Follow
   `graft-project-histories`'s shape: `prepare` reads only, and `swap` moves
   refs. Extend that tool or give this one its own, whichever reads better.
4. **Gates in `prepare`,** stopping at the first failure:
   - the new main has the same number of commits, less any that become
     empty;
   - the final files are identical to the old main's, apart from the
     removed paths;
   - every commit keeps its author, committer, dates and message (apart
     from translated ids);
   - nothing from the inventory, and no redacted bytes, is reachable from
     any ref that will be pushed;
   - the map gives each old commit exactly one new one.
5. **Map:** `delta-version/archive/disentangle/commits.map`, with `old new`
   full ids for every rewritten commit, beside the issue 031 map.
6. **Quote commit:** translate the ids quoted in tracked files, as issue 031
   did.
7. **Transcripts:** re-run `transcript-patches translate-ids` with this
   rewrite's map, so each conversation's id patch translates to the newest
   ids. See the open question on chaining.
8. **Swap:** only when the owner says the repository is quiet. Move `main`
   (compare-and-swap against the recorded old tip). Move the carried tags.
   Delete `archive/main-before-history-graft`. The working tree is not
   touched; its files already match.
9. **Publish:** delete the archive tag on GitHub, then force-push `main`,
   every `claude/*` branch and the moved tags (`--force-with-lease` against
   the recorded origin refs). The open pull requests follow their branches.
10. **Afterwards:** translate ids in files written since prepare. Check
    `git status` matches the status from before the swap. Update issue 031's
    note that the archive tag is kept.

## Open Questions

1. **Chained translation.** A transcript may quote an id from before issue
   031, from between 031 and this rewrite, or from after. Should
   `translate-ids` combine the two maps into one (oldest id → newest id), or
   should each conversation carry one id patch per rewrite, applied in
   order?
2. **`delta-version/archive/history-graft/commits.map`** lists issue 031's
   new ids, which this rewrite renames. Should it stay as a record of that
   day, or have its right-hand column translated?
3. **The `refs/graft/*` refs and the six `archive/pre-import/<project>`
   tags.** The `refs/graft/*` refs are local leftovers from issue 031's
   scratch work. Should they be deleted? The pre-import tags hold no poems
   or mail state, so they are kept unchanged unless the inventory finds
   otherwise.
4. **Poems quoted inside transcripts and issues.** Should poem text the
   owner pasted into conversations (CLAUDE.md asks for poetry to be kept in
   issue files) stay? It is part of how the software was made, not a copy
   of the collection.
