# 103 — How long the tabs take

**Phase:** 1 — The mask
**Blocked by:** 101
**Blocks:** 104
**Related documents:** docs/how-it-works.md

## Current Behavior
Scene changes are assumed instant.

## Intended Behavior
Each tab swings at a speed limit (number, degrees per second) and each slot
changes in a set time (number, seconds). A scene change reports when each tab
arrives and what the mask shows in between. The speed limit is a knob,
logged in docs/balance-updates.md when turned — "the faster, the more
responsive".

## Suggested Implementation Steps
1. Motion model per tab.
2. In-between masks during a change.
3. Tests: total change time equals the slowest tab's travel.
