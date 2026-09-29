# Issue 061: The Compository — Every Repository, Carried on a Flash Drive

**Status**: In progress (built and tested against a pretend drive; not yet
run on a real flash drive; open questions below)
**Priority**: Medium
**Created**: 2026-09-23
**Type**: New tool (`scripts/compository.lua`) and its list
(`assets/compository-list.lua`)

---

## Current Behavior

**Built (2026-09-23).** Steps 1–8 are done, as `scripts/compository.lua`,
`assets/compository-list.lua`, `scripts/compository.info.md` and
`scripts/test-compository.sh`.

- **Tests:** 22 of 22 pass, run against a pretend drive in RAM.
- **`--list`** carries 15 of the owner's repositories. It passes over 32:
  16 empty, 14 someone else's, and both teriyaki-euler repositories, which
  the list excludes.
- **Selected items** are gathered into their own git repository,
  `selected_repository` in the list, and committed whenever they change,
  under the owner's identity. That makes it one of the owner's
  repositories, so ordinary discovery carries it. The list is empty for now.
- **Found while building:**
  - **Order matters.** Four of the owner's repositories sit inside the
    ai-stuff folder. They are cloned inside ai-stuff's copy on the drive, so
    updates run in nesting layers, outer first.
  - **Untracked files are expected.** The "uncommitted changes" check reads
    tracked files only, because a nested copy looks untracked to its
    parent.
  - **Size.** ai-stuff's history is 8.1 GB, so a drive needs room for that
    plus the working files.
- **Not yet exercised:** detection of real removable drives. No flash drive
  was connected while this was built.

**Before this issue** — the owner's own git repositories live on this computer's disks and nowhere
portable. There are about twenty of them: the monorepo, and repositories
outside it such as `civics/algorism`, `python/joust`, `c/dungeon` and
`ai-playground/minimal-soramech`. They sit among clones of other people's
work (raylib, LuaJIT, V, mGBA) and empty `git init`s with no commits.
Nothing copies them anywhere, and nothing keeps a copy current.

## Intended Behavior

One command, run any time, brings every connected flash drive up to date:

    compository.lua                  # update every connected compository drive
    compository.lua --init=/mount    # mark a mounted drive as a compository
    compository.lua --drive=/mount   # update one drive, removable or not
    compository.lua --list           # show what would be carried, write nothing

**What goes on the drive** comes from a list, `assets/compository-list.lua`,
which is walked item by item. For now it holds one kind of item, the git
repositories. Later it will also hold hand-picked notes, documents and tools.

**Which repositories are the owner's:** a repository counts as the owner's
when its first commit was made under one of the owner's email addresses.
That keeps raylib, LuaJIT and other clones out, whatever has been committed
on top of them since.

Three kinds of repository are skipped:

- **Empty ones** (no commits), because there is nothing to carry.
- **Worktrees and submodules**, whose `.git` is a file rather than a
  folder, because each is a view into a repository already carried.
- **Anything the list excludes by name.**

**On the drive** each repository is an ordinary clone, so its files can be
read on any computer, placed at the same relative path it has under the
programming folder: `compository/ai-stuff/`, `compository/civics/algorism/`.

- **Upstream:** each clone's `origin` is the repository's folder on this
  computer. Git accepts a plain path as a remote, exactly as it accepts a
  web address.
- **Updating is fetch, then fast-forward only:** the drive's branch is
  moved to the computer's tip only if that is pure forward motion. A drive
  copy with local commits, or with uncommitted edits, is left alone and
  reported, never overwritten.
- **Other branches are fetched too**, so they can be checked out on the
  drive.

**Which drives:** only drives the owner has marked. A drive carries a file
`.compository` at its root, written by `--init`. The tool scans mounted
filesystems on removable or USB disks and updates only those with the
marker. A disk that was never marked is never written to, however it is
connected.

- **Idempotent:** a second run with nothing new changes nothing and says
  so. A first run clones, and later runs fetch.
- **Parallel:** repositories are updated concurrently, one worker per CPU
  core, since each is an independent fetch and copy.

## Suggested Implementation Steps

1. **The list.** Write `assets/compository-list.lua` with:
   - `repositories`: the roots to search, the owner's email addresses, and
     the names to exclude;
   - `selected`: an empty list, for the notes, documents and tools to come.
2. **Discovery.** Find every `.git` folder under the roots, pruning inside
   `.git`, `node_modules` and `libs`. Keep a repository only if its root
   commit's author email is the owner's and it has at least one commit.
   Record its path relative to the root.
3. **Drive detection.** Use `lsblk` to find mounted partitions whose disk
   is removable or on USB, and keep those with `.compository` at their
   mount point. `--drive=` names one directly and skips detection, but
   still requires the marker.
4. **One repository, one worker.** For each repository:
   - **Absent on the drive:** `git clone --no-hardlinks <local> <drive path>`.
   - **Present:** check that `origin` is the local path (repair it if the
     repository has moved), then `git fetch origin`, then fast-forward the
     checked-out branch with `git merge --ff-only`. If it cannot
     fast-forward, or has uncommitted changes, report and stop *that
     repository only*.
   - Print one line naming what happened: cloned, advanced from one commit
     to another, already current, or refused and why.
5. **Parallel run.** Run the workers through `xargs -P <cores>`, each one
   the tool itself in an internal one-repository mode, and collect their
   lines.
6. **Filesystem notes.** Flash drives are often FAT or exFAT, which have no
   symlinks and no executable bit. Set `core.symlinks=false` and
   `core.fileMode=false` on clones made on such a drive, and say so in the
   report.
7. **Test.** `scripts/test-compository.sh`, run against a fake "drive"
   folder in RAM and a small fixture repository:
   - first run clones;
   - second run changes nothing;
   - a new commit on the computer is fast-forwarded;
   - a local commit on the drive is refused and left intact;
   - an unmarked folder is refused;
   - someone else's repository is not carried.
8. **Document.** Write `compository.info.md`.

## Answered questions (2026-09-23)

- **Selected items as plain files or git?** "git". They are gathered into
  their own repository and carried like any other.
- **teriyaki-euler?** "neither of those should be included". Both are
  excluded in the list.
- **algorism-backup?** The owner copied civics/algorism into ai-stuff
  because it is not synced anywhere. The two are identical (same commit,
  same uncommitted edits). The owner chose "repository of it's own... you
  can delete the backup". The backup was deleted after checking that it held
  nothing the original lacks: the same single branch at the same commit, no
  stashes, identical files. civics/algorism is carried as its own
  repository.

## Open questions
- Should the tool also carry `llm-transcripts` from outside the
  repositories, or the Claude session store?
- ai-stuff's history is 8.1 GB. Should ai-stuff be carried whole, or should
  the drive copy leave out large generated history? (Leaving it out would
  mean the drive copy is not a full clone, and could not become the
  upstream for another computer.)
