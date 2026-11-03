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
