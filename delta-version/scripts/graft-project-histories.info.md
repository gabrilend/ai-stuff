# graft-project-histories

Gives the monorepo's projects back the history they had before the monorepo's
first commit, by rebuilding the trunk so that commit stands on each project's
earlier commits. Two separate steps: `prepare` builds and checks everything in
a scratch repository; `swap` moves the real trunk, and never pushes.

Plan, decisions and swap-day checklist: `delta-version/issues/031-import-project-histories.md`.

## Commands

| Command | What it does | Changes the real repository? |
|---|---|---|
| `graft-project-histories [prepare]` | Builds the rebuilt trunk and the quote commit in `/tmp/ai-stuff-history-graft`, runs every gate, prints a report | No, it only reads |
| `graft-project-histories swap --i-understand-this-rewrites-history` | Asks you to type `rewrite main`, then tags the old trunk, moves `main` and the carried tags, fast-forwards onto the quote commit, and prints the push commands | Yes: refs and the changed files |
| `graft-project-histories translate FILE...` | After the swap, rewrites quoted old ids in the named working-tree files | Only those files |

Options: `--dir REPO` (default the monorepo), `--work DIR` (scratch area, RAM
by default; a reboot empties it, so run prepare again), `--projects FILE`,
`--join SHA`, `--carry-tags "t1 t2"`. The last three exist for the tests.

## Inputs

- **Join commit:** `15268505` "Initial commit: AI project collection", the
  trunk's first commit. It must have no parents and be on `main`.
- **Project sources**, one line each: `<folder> <source> <ref>`. `<source>` is a
  git bundle or a repository path, and `<ref>` is the project's last commit
  before the join. The defaults are:
  - the five retired branches (adroit, handheld-office, magic-rumble,
    progress-ii, risc-v-university) from
    `/mnt/mtwo/programming/archives/ai-stuff/retired-project-branches.bundle`;
  - RPG-autobattler from the repository nested in its own folder, at
    `28a21142`.

  A missing source is an error, not a skip.
- **Carried tags:** `phase12-complete-stable`, `v0.1.0-phase1` and
  `backup/before-history-fix` are moved to their rebuilt twins.

## Outputs (in the scratch area)

- **`repo.git`**, with these branches:
  - `main`: the rebuilt trunk, whose files are identical to the old trunk's;
  - `quoted`: one commit on top, with quoted ids rewritten plus the map;
  - `old-main`: the old trunk;
  - `old/<folder>`: each project's original commits;
  - `infolder/<folder>`: each project's commits moved into its folder.
- **`commits.map`**: `old new` full ids, one line per original commit.
- **`state`**: the ids `swap` checks against: the old main, the new main, the
  quote commit, and origin/main for the push lease.
- **`tree-report.txt`**: for each changed file, how many ids were rewritten,
  plus notes on any id that was lengthened, left ambiguous, or left because it
  was a 7-digit number.

## Gates (prepare stops at the first failure)

1. The rebuilt trunk has exactly (old commits + moved commits) commits.
2. The rebuilt trunk's final files are byte-identical to the old trunk's.
3. The map gives each commit its own twin, as full ids.
4. Each trunk commit's twin has the same files, author, committer and both
   dates.
5. Each project commit's twin holds the original files under the project's
   folder, with the same author, committer and dates.
6. Every message equals its original, with quoted ids translated, and every
   new short id is unambiguous.
7. With default settings, `git log -- <folder>/` reaches the project's first
   commit.
8. The carried tags point at the twins of the commits they pointed at.
9. The quote rewrite reverses exactly: undoing it restores every changed file
   byte for byte.

## Parts

- `libs/commit-id-quotes.lua` finds and rewrites quoted commit ids. See
  `libs/commit-id-quotes.info.md`.
- `test-graft-project-histories.sh` runs unit tests and a full prepare-and-swap
  on a toy repository.
