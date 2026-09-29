# 1001c — No line told twice

The third piece of 1001.

## Current Behavior

Nothing tracks which ledger lines a story has already told.

## Intended Behavior

A new chapter is only added for lines not yet told; the story grows like
the ledger — a second run over an unchanged ledger adds nothing.

## Suggested Implementation Steps

1. Each chapter's first line names the ledger line numbers it tells. 2.
   The incremental scan skipping already-told ranges. **Test:** every
   chapter's first line names ledger line numbers it tells; no line is
   told twice across two runs.

## Blocked by

- 1001b
