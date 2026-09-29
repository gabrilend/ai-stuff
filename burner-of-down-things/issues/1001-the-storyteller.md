# 1001 — The storyteller

A case's ledger told back as chapters in plain words, *narrative like a child*, naming whose each thing was ([069](../docs/069-the-story.md)).

## Current Behavior

The ledger is read by the machine and by the case viewer; nothing tells it as a story.

## Intended Behavior

- A turn kind `storyteller`: reads one case's ledger (and its requests, in the person's words), writes only `output/story/<case>.md`.
- Chapters follow the ledger's own turning points: opened, surveyed, described, built, each request, each failure and repair.
- Every chapter names whose each thing was: the person, the referee, the builder, the stand-in or model — the sovereignty of others.
- A new chapter is only added for lines not yet told; the story grows like the ledger.

## Suggested Implementation Steps

1. With the stand-in. **Test:** every chapter's first line names ledger line numbers it tells; no line is told twice.
2. Whose each thing was. **Test:** a request's chapter names the person as its author.

## Blocked by

- 104
- 306
