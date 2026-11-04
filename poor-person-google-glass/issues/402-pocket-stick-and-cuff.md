# 402 — Pocket stick and cuff

**Phase:** 4 — The inputs
**Blocked by:** 401
**Blocks:** 403

## Current Behavior
No stick or cuff.

## Intended Behavior
A thumbstick in a pocket, producing { x, y } records (numbers -1..1). A sleeve
or wrist cuff, switchable on and off, that is its own kind of input: the
wearer drags a finger along it and it reports an analog position along its
length (number 0..1) while touched -- "you drag along it and it sends an
analog style input."

## Suggested Implementation Steps
1. Stick records; cuff on/off switch; cuff records.
