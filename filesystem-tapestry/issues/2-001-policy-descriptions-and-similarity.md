# 2-001 — Policy Descriptions & Policy-Based Similarity

## Phase 2: The Meaning

## Current Behavior

`similar` and `different` orderings fall back to chronological, because there is
no measure of how alike two files are. You cannot embed a ten-gigabyte video, so
raw content is not the feature space.

## Intended Behavior

Similarity is measured on **policy descriptions**: a short text per file (or per
group of files) describing the policies surrounding its contents — what the file
is, what it is for, and what the machine should do with it. A policy is
**written by a user**, **sourced by a user**, or **auto-generated**; its
provenance is recorded. The policy text is small, so it *can* be embedded, and
those embeddings are what `similar` and `different` compare.

This umbrella issue covers the Phase 2 sub-issues enumerated in
`docs/roadmap.md`:

- **2-001a policy store** — attach/load/save a policy text + provenance per path.
- **2-002 policy embeddings** — embed policy texts via Ollama (same integration
  neocities uses).
- **2-003 similarity matrix** — all-pairs cosine, stored sparsely (top-K
  neighbours per file).
- **2-004 ordering: similar** — nearest-neighbour ordering from a seed.
- **2-005 ordering: different** — greedy diversity chain reusing the
  least-similar-unvisited algorithm from neocities `diversity-chaining.lua`
  (`find_least_similar_unused_*`).
- **2-006 auto-policy generator** — draft a policy for any file lacking one so
  the tapestry is navigable before every file is hand-annotated.

## Design Notes

- Policy text and embeddings live under `assets/policies/` and
  `assets/embeddings.jsonl`, keyed by a hash of the path so they survive
  re-scans.
- The ordering engine's `similar`/`different` seams (issue 1-004) already exist;
  Phase 2 fills them by loading the similarity matrix. When the matrix is
  present the fallback warning disappears; when it is absent the warning stays.
- Cosine similarity: reuse the pluggable calculator design from neocities
  `src/similarity-calculator.lua` (cosine / euclidean / dot / angular).

## Related

- neocities `src/similarity-calculator.lua`, `src/diversity-chaining.lua`
- `src/05-ordering-engine.lua` (the seams to fill)
- `docs/roadmap.md` (Phase 2 breakdown)

## Metadata

- Status: Open (Vision)
- Phase: 2
- Depends on: Phase 1 complete
