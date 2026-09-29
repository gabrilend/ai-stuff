# 1002 — Lessons

Each turning point of a story — a failure, a repair, a hold, a wider look's finding — written as one lesson: what happened, the mechanism behind it, what now guards against it ([069](../docs/069-the-story.md), *watching mechanisms*).

## Current Behavior

Turning points are ledger lines only.

## Intended Behavior

- Lessons appended to `output/story/lessons.md`, each naming its case, its ledger lines, and a **mechanism** in a short fixed form (`a builder grading its own work passes itself`).
- A lesson without a mechanism is sent back.
- The mechanisms are a growing list the machine counts, so recurrence is counted, not judged.

## Suggested Implementation Steps

1. Lessons from the stand-in. **Test:** a lesson with no mechanism is refused; lessons are appended, never rewritten.
2. Counting mechanisms. **Test:** the same mechanism in two cases counts two.

## Blocked by

- 1001
