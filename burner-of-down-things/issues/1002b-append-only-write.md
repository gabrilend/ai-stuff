# 1002b — Append-only write

The second piece of 1002.

## Current Behavior

1002a defines the shape; nothing writes it.

## Intended Behavior

Lessons are appended to `output/story/lessons.md`, one per turning point,
never rewritten — the same append-only discipline as the ledger (016).

## Suggested Implementation Steps

1. The atomic-append writer. **Test:** lessons are appended, never
   rewritten — writing a second lesson leaves the first byte-for-byte
   unchanged.

## Blocked by

- 1002a
