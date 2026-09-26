# 401 — The outline and its checks

The first step of describing: one turn plans the whole blueprint as a table,
and the machine checks the table ([006](../docs/006-datapath-the-blueprint.md),
*the outline*).

## Current Behavior

A case can be surveyed; nothing plans a blueprint.

## Intended Behavior

- **Outline step** (case): makes one `outline` turn whose prompt holds the
  survey summary, the file table, the outline format of
  [002](../docs/002-the-terms.md), and the house rules for phases (clusters of
  function, foundations low); runs it as a set of one (306); reads
  `blueprint/outline.tsv`; checks it; on failure, appends `outline-failed`
  with the findings and makes a new outline turn given them, up to three;
  on success appends `outlined`.
- **Checks** (outline rows, survey rows), each a function returning findings
  (strings): ids well-formed and unique; names well-formed; blockers exist;
  no cycles (depth-first walk, naming the cycle's ids in order); every `code`
  and `build` survey file covered; no covered path missing from the survey.

## Suggested Implementation Steps

1. The checks. **Test:** one fixture outline per finding, each finding named.
2. The step with the stand-in: a script whose first outline is bad and
   second good. **Test:** two turns, one `outline-failed`, then `outlined`.
3. **Test:** three bad outlines stop the step with the findings in goodbye.

## Blocked by

- 204
- 306
