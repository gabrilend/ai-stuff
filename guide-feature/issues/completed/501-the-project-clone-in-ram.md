# 501 — The project clone, in RAM if it fits

phase 5, looking into the project

## Current behavior

Nothing exists. The canvas carries a `project:` header (303), and the turn
ignores it.

## Intended behavior

The owner: "whatever we're working on at the time", and "I think we'd git
clone a project into the mini-computer if we were gonna work on it. To RAM
if it fits."

The clone keeper, called at the start of every turn:

- reads the project name and commit from the canvas;
- if this voice has no clone of that project, clones it from kuvalu over SSH
  (allowed between the four machines);
- places the clone in `tmp/` (RAM) when the project's size, plus room for
  the turn's own working memory, fits within a share of free memory (a
  setting). Otherwise it goes on disk. The choice is logged, because the disk
  is the slower path;
- if the clone is behind the commit, fetches and checks it out;
- keeps one clone per project, so returning to an earlier project is a
  fetch, not a fresh clone, while it is still in RAM.

Which repository to clone from, for a project name, comes from a list in
`input/turn` (name to SSH address on kuvalu).

## Suggested implementation steps

1. Size measurement on kuvalu (`git count-objects -vH` on the source), sent
   in the header or measured after the first fetch.
2. Clone, fetch, checkout, placement.
3. Tests in the rehearsal: first clone, a newer commit, a project switch, a
   project too big for its RAM share.

## Related documents

- `docs/datapath-looking-into-the-project.md`
- `docs/network.md`

## Open questions

- Do the mini-computers have `git`? (`docs/open-questions.md`, 1)

## Blocked by

None.

## Blocks

503, 704.

## Decisions (2026-11-05; each the owner's to overturn)

1. **The keeper's settings are `input/project-clone`, not `input/turn`.**
   Every program reads its own `input/<name>` (001), and the keeper also
   runs by itself as `scripts/project-clone`. The list of projects is
   there: `repository.NAME` (kuvalu's checkout as `HOST:/PATH`, reached
   over SSH with `BatchMode`, so it never stops for a password; or a path
   on the same machine; URLs are refused) and `folder.NAME`, the project's
   folder inside the repository, because guide-feature lives in a monorepo.
2. **One commit at a time, and only the project's files.** Each commit is
   fetched alone (`--depth 1`), only the project's folder is checked out
   (sparse), and only its files are fetched (`--filter=blob:none`, asked of
   kuvalu's own `upload-pack` with `uploadpack.allowFilter`, so kuvalu
   needs no setting changed). The monorepo is 735 MiB of packs; one commit
   of it fetched this way is about 7 MiB of git store. A history is not
   needed to look at the project.
3. **The size is measured from the project's own files, twice.** Before
   cloning: the folder's files at the commit, counted twice (checked out,
   and in git's store), from `git ls-tree` on the source. The issue
   suggested `git count-objects`, but that measures the whole repository's
   history, which the clone never fetches. After cloning into RAM: `du` of
   the clone, and a clone over the share is moved to disk.
4. **RAM is the project's RAM tier**, `tmp/shared-memory/clones`
   (`/dev/shm`), used only when it can be made and written and is a tmpfs.
   Otherwise, and when the project and the working room do not fit the
   share, the clone goes in `clones/` in the project root (ignored by git),
   and the log says why. No root is needed. The defaults: `ram-share = 0.5`
   of `MemAvailable`, `working-room = 512` MiB.
5. **A clone stays where it was made.** It is not moved between RAM and
   disk later, and other projects' clones are not removed to make room;
   the share is measured against the memory available then, with any
   other clones already in it.
6. **Clones are kept per voice and project**, `<folder>/<voice>/<project>`,
   so the rehearsal's three voices on one machine never share one.
7. **A clone that cannot be had does not fail the turn.** It is logged and
   counted (`clone-failed`), and the turn goes on with the canvas alone:
   the canvas is the work, the clone only what a look sees.
8. **The canvas's short commit is looked up on the source** for its full
   name, which a one-commit fetch needs, and only when the clone lacks it.
9. **The rehearsal clones from the checkout `input/to-voices` names**, on
   the same machine, so it needs no SSH.

## What was built (2026-11-05)

- `src/058-project-clone.lua`, `scripts/project-clone`,
  `input/project-clone`, and `/clones/` in `.gitignore`.
- The turn's step 2 (`src/055-turn.lua`): the log line, and the receipt's
  `clone-ram` or `clone-disk`, `clone-made`, `clone-fetched`,
  `clone-moved`, `clone-milliseconds`, or `clone-failed`.
- The rehearsal (`src/043-rehearsal.lua`) copies `input/project-clone`
  with the project coming from the local checkout.
- `src/059-test-project-clone.lua`: the keeper's cases (first clone in RAM,
  the same commit, a newer one, an older one, a project switch and back, a
  lost RAM clone, too big for the share, no tmpfs, a RAM folder that cannot
  be made, moved once measured, refusals), the turn's step 2, and the
  rehearsal, where each voice clones once and fetches a commit made while
  it runs.
- `docs/datapath-looking-into-the-project.md` and
  `docs/datapath-voice-turn.md` say how it works; open question 1 says
  what the voices now need.

## Needs the owner's machine

- SSH from each fg-sora to kuvalu by key, and `git` 2.25 or later on each
  voice (issue 701's survey answers whether it is there).
- The first real clone of the monorepo from kuvalu, to see its size in RAM
  and the time it takes; `ram-share` and `working-room` set from what the
  fg-sora machines have.
