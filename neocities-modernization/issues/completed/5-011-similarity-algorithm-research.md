# 5-011: Similarity Algorithm Research

## Status
- **Phase**: 5
- **Status**: Completed (its one sub-issue, 5-011a, is complete)
- **Written**: 2026-10-20, after the fact. The research was filed as 5-011a
  and closed on 2025-12-14, but this parent was never written; the issue
  checker reported 5-011a as an orphan.

## Current Behavior

5-011a surveyed similarity measures for poetry embeddings and wrote the
findings to `docs/similarity-algorithms-research-report.md` (with a shorter
`docs/similarity-algorithm-research.md`). It recommended Jensen-Shannon
divergence as the main addition to cosine similarity, and laid out an order
for building more. Building them is Issue 5-024, which is open.

Before: only cosine similarity was used, with no study of the alternatives.

## Intended Behavior

The choice of similarity measure rests on written research into which
measures suit high-dimensional text embeddings of short poems.

## Suggested Implementation Steps

1. 5-011a: the research and its report (done).
2. Further research questions, if any arise, become 5-011b onward.

## Related
- 5-010 (validation framework, which can compare the algorithms), 5-024
