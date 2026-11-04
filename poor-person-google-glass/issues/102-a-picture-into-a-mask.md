# 102 — A picture into a mask

**Phase:** 1 — The mask
**Blocked by:** 101
**Blocks:** 104
**Related documents:** docs/datapath-light.md

## Current Behavior
No planner.

## Intended Behavior
Given a picture (grid of brightness 0–1), choose tab angles and slot states
whose mask comes closest, and report the match (fraction of cells right,
number). Brightness between on and off is carried by how often a cell is lit
across releases, so the planner outputs a short sequence of masks.

## Suggested Implementation Steps
1. Score a mask against a picture.
2. Search tab settings (start simple: greedy, one tab at a time).
3. Masks-over-time for grey levels.
4. Tests on a letter, an icon and a gradient.
