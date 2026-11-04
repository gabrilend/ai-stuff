# 403 — The decision table

**Phase:** 4 — The inputs
**Blocked by:** 401, 402
**Blocks:** 404

## Current Behavior
Inputs lead nowhere.

## Intended Behavior
One table maps each input to an action: change the picture (to phase 1's
planner) or move the arm (to phase 3). "your inputs determine what gets
shown."

## Suggested Implementation Steps
1. Table and actions.
2. Tests: every input has exactly one entry.
