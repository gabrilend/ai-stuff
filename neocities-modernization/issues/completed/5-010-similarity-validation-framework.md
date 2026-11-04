# 5-010: Similarity Validation Framework

## Status
- **Phase**: 5
- **Status**: Completed (its three sub-issues are complete)
- **Written**: 2026-10-20, after the fact. The work was split into 5-010a,
  5-010b and 5-010c and those were built and closed, but this parent was
  never written; the issue checker reported the three as orphans. This file
  records what the three together are, so the phase reads as a whole.

## Current Behavior

Built by the sub-issues:
- a modular similarity calculator with several interchangeable algorithms
  (`src/similarity-calculator.lua`, tested by
  `src/test-similarity-calculator.lua`) — 5-010a;
- a validation engine that recalculates stored similarity scores and reports
  where they disagree, over the whole set or a sample
  (`src/validation-engine.lua`, `src/run-validation.lua`, tested by
  `src/test-validation-engine.lua`) — 5-010b;
- validation reports with statistics and comparisons between algorithms
  (`src/run-validation-with-reports.lua`, `src/test-report-generator.lua`) —
  5-010c.

Before: similarity scores were stored and served without any check that
they matched a fresh calculation, and only one algorithm existed.

## Intended Behavior

Stored similarity data can be checked against a recalculation at any time,
with a report of the agreement, and the algorithm used is a choice rather
than a hard-coded formula.

## Suggested Implementation Steps

1. 5-010a: the modular calculator (the algorithms behind one interface).
2. 5-010b: the validation engine, built on the calculator.
3. 5-010c: the reports, built on the engine's results.

## Related
- 5-011 (algorithm research), 5-024 (multi-algorithm selection, open)
