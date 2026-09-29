# 1002 — Lessons

Each turning point of a story — a failure, a repair, a hold, a wider look's finding — written as one lesson: what happened, the mechanism behind it, what now guards against it ([069](../docs/069-the-story.md), *watching mechanisms*).

## Current Behavior

1002a, 1002b and 1002d are built (issues/completed/1002a-lesson-schema.md,
1002b-append-only-write.md, 1002d-mechanism-counting.md): a lesson's
fields and shape check, an append-only writer (one Markdown section per
lesson, no reader yet), and a mechanism counter proved to feed 1003a's
trigger unchanged. 1002c (the fuller mood-vs-mechanism refusal) is not yet
built.

## Intended Behavior

- Lessons appended to `output/story/lessons.md`, each naming its case, its ledger lines, and a **mechanism** in a short fixed form (`a builder grading its own work passes itself`).
- A lesson without a mechanism is sent back.
- The mechanisms are a growing list the machine counts, so recurrence is counted, not judged.

## Suggested Implementation Steps

1. Lessons from the stand-in. **Test:** a lesson with no mechanism is refused; lessons are appended, never rewritten.
2. Counting mechanisms. **Test:** the same mechanism in two cases counts two.

## Sub-issues

- 1002a — the lesson schema
- 1002b — append-only write
- 1002c — mechanism refusal
- 1002d — mechanism counting

## Blocked by

- 1001
