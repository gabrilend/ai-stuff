# 302 — The arm reaches and turns

**Phase:** 3 — The panel on its arm
**Blocked by:** 301
**Blocks:** 303, 304
**Related documents:** docs/datapath-input.md

## Current Behavior
No arm model.

## Intended Behavior
Where the arm is (the owner, sixth round, notes/vision): an extension of, or
mounted parallel to, the side arms of the glasses the wearer has on. Its
hydraulic pistons move it forward, and closer to the face. It turns at
several joints, and it is smooth and metallic, "like a really nice ink pen".
So the arm runs along the side of the head from the temple forward, not
down from the brow (the crown sketch in src/002-the-test-shapes.lua still
has it down from the brow, and is a placeholder).

The hydraulic arm pushes out and pulls in (reach, number, mm) and turns about
its own axis (turn, number, degrees); the panel moves with it without
rotating. Releases land where the arm puts the panel; and no release fires
while the panel is out of the beam (see docs/open-questions.md, "Safety" under Answered).

## Suggested Implementation Steps
1. Arm pose to panel position.
2. Panel-in-place check; withheld releases counted.
3. Tests: a turn that moves the panel out of the beam withholds releases.
