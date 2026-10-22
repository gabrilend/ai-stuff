# 203 — Page files in RAM, with history

phase 2, the page protocol

## Current behavior

The page keeper (107) publishes pages only to its log.

## Intended behavior

A second publisher in the page keeper's list writes each new page to
`tmp/shared-memory/page/current` (written to a temporary name, then renamed,
so a reader never sees half a page) and to
`tmp/shared-memory/page/history/NNNNNN`, never rewritten.

At start the folder is emptied of the previous run's pages, unless the owner
decides runs should continue (`docs/open-questions.md`, 9).

## Suggested implementation steps

1. The publisher, using the page writer (201).
2. A test that runs a short replay and checks that history holds every page
   number with no gaps, and that `current` equals the last one.

## Related documents

- `docs/page-protocol.md`, "On kuvalu: files"

## Open questions

- Start each run fresh, or from the last page? (`docs/open-questions.md`, 9)

## Blocked by

107, 201.

## Blocks

204, 206, 601, 602.
