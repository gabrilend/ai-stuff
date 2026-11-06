# 1002 — Lessons

Each turning point of a story — a failure, a repair, a hold, a wider look's finding — written as one lesson: what happened, the mechanism behind it, what now guards against it ([069](../docs/069-the-story.md), *watching mechanisms*).

## Current Behavior

All four pieces are built (issues/completed/1002a-1002d): a lesson's
fields and shape check; the mood-vs-mechanism refusal (`mood_of`), so a
lesson without a mechanism is sent back; an append-only writer and its
reader (`lesson.read`, one Markdown section per lesson); and a mechanism
counter that takes the reader's records unchanged and feeds 1003a's
trigger. Both of this issue's tests hold (a lesson with no mechanism is
refused, lessons are appended and never rewritten; the same mechanism in
two cases counts two, now read from the file itself).

What is left: nothing yet *writes* a lesson from a story's turning point.
Naming the mechanism behind a failure or repair is a turn's work (a model
or the stand-in, given 1001's failure/repair chapters); wiring that turn is
kept open here, and 1004b's demo is the natural place to show it.

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
