# 502 — The embedding index: contract and build guide

phase 5, looking into the project

## Current behavior

The contract is drafted from the look tool's side in
`docs/embedding-index-contract.md`. No project has an index.

## Intended behavior

The owner: "that's part of the project development. We'll have a tool file
that explains how to build that functionality, because we'll build it once
for each project. I guess maybe it could be part of delta-version? That's
sorta what it's for..."

Two things:

1. **The build guide**: a document, written where the owner decides it
   belongs, that explains how to give a project an index meeting the
   contract. It covers which pieces to cut the code into, the name-extraction
   rule (`names-v1`), the embedding endpoint, the git hooks that rebuild it on
   commit, pull and checkout, and the checks that an index matches its commit.
2. **A first index, for guide-feature itself**, built by following the
   guide, so the look tool (503) has a real index to test against. It also
   tests the guide.

guide-feature reads indexes and never builds another project's index.

## Suggested implementation steps

1. Settle with the owner where the guide lives.
2. Write the guide. Then follow it for guide-feature, fixing the guide
   wherever following it went wrong.
3. Update `docs/embedding-index-contract.md` from draft to agreed.

## Related documents

- `docs/embedding-index-contract.md`
- `docs/datapath-looking-into-the-project.md`

## Open questions

- delta-version or the shared scripts folder? Build guide-feature's own
  index first? (`docs/open-questions.md`, 2)

## Blocked by

401.

## Blocks

503.

## Decisions (2026-11-05; each the owner's to overturn)

1. **The guide lives in guide-feature for now**,
   `docs/embedding-index-build-guide.md`, written so it can move unchanged
   to delta-version or the shared scripts folder when the owner decides
   (open question 2, answered for now). Nothing in it makes one project
   depend on another: a project that wants an index copies
   `src/060-embedding-index.lua` into itself as vendored code, with
   guide-feature as its upstream.
2. **guide-feature's own index was built first**, by following the guide,
   which three findings then changed (in the guide's last section). Here
   it was built against the stand-in embedding model (047), since no model
   is installed here; on kuvalu it is built with `kuvalu-embed`.
3. **The contract is agreed**, with what building it settled: the index
   lives in the project's own folder (guide-feature is a monorepo folder,
   with no `.git/` of its own); the commit is the full one; an optional
   `tree` field lets a builder skip commits that did not touch the project;
   `names-v1` drops one-letter names, keeps each name once, and leaves out
   a first `#!` line; the checks the look tool makes are listed.
4. **The rules are split from the builder.** `060` holds the rules and the
   file format, with no model call and no other dependency; `061` is
   guide-feature's builder around it. Another language can write its own
   builder to the contract.
5. **Pieces follow the house folds** (`pieces-v1`): every outermost `{{{ }}}`
   fold is a piece, which in this repository is every function and table;
   functions at the left edge and blank-line blocks otherwise; at most 60
   lines a piece.
6. **Files are read from git at the commit**, not from the working tree, so
   the index is exactly the commit's. Code only, by extension or `#!`;
   `libs/` is skipped (copied code from other projects).
7. **Rebuilding is cheap**: a commit that did not change the project's
   folder renames the index; a piece with the same names keeps its vector.
8. **Hooks add a marked block beside what a hook does**, because a
   monorepo's projects share one set of hooks, and run the builder in the
   background, never failing git. They are not installed by anything
   automatically: `scripts/install-index-hooks` is run once by hand.
9. **The builder reads its settings without making RAM tiers** in the
   project it indexes, and writes its log and receipt under a root it is
   given, so it can index a voice's clone without leaving anything in it.

## What was built (2026-11-05)

- `docs/embedding-index-build-guide.md`; `docs/embedding-index-contract.md`
  agreed.
- `src/060-embedding-index.lua` (the rules and the files),
  `src/061-build-embedding-index.lua` (`scripts/build-embedding-index`,
  settings `input/embedding-index`), `src/062-embedding-index-tools.lua`
  (`scripts/check-embedding-index`, `scripts/install-index-hooks`), and
  `046`'s `model_name`.
- `/.embedding-index*` in `.gitignore`.
- `src/063-test-embedding-index.lua`, which also builds and checks
  guide-feature's own index: about 1,070 pieces from about 90 files.

## Needs the owner's machine

- `scripts/install-index-hooks` on kuvalu's checkout, once, with
  `kuvalu-embed` running (401a), and the first real index built with it.
- Its size and the time a full build takes with a real embedding model.
