# 302 — The arm reaches and turns

**Phase:** 3 — The panel on its arm
**Blocked by:** 301
**Blocks:** 303
**Related documents:** docs/datapath-input.md

## Current Behavior
No arm model.

## Intended Behavior
The hydraulic arm pushes out and pulls in (reach, number, mm) and turns about
its own axis (turn, number, degrees); the panel moves with it without
rotating. Releases land where the arm puts the panel; and no release fires
while the panel is out of the beam (see docs/open-questions.md, question 1).

## Suggested Implementation Steps
1. Arm pose to panel position.
2. Panel-in-place check; withheld releases counted.
3. Tests: a turn that moves the panel out of the beam withholds releases.
