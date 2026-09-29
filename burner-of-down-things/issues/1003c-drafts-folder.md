# 1003c — The drafts folder

The third piece of 1003.

## Current Behavior

Nothing manages where drafts live.

## Intended Behavior

Drafts are written to `strategems/drafts/`, one file per mechanism, never
duplicated — a further recurrence updates the existing draft's examples
rather than writing a second file.

## Suggested Implementation Steps

1. The one-file-per-mechanism naming rule. 2. The update-in-place on a
   further recurrence. **Test:** a third lesson of an already-drafted
   mechanism updates that draft's example list rather than creating a
   second file.

## Blocked by

- 1003b
