# 1001 — The storyteller

A case's ledger told back as chapters in plain words, *narrative like a child*, naming whose each thing was ([069](../docs/069-the-story.md)).

## Current Behavior

All four pieces are built (issues/completed/1001a-1001d): the
`storyteller` turn kind (034), and `src/103-the-story.lua`, which cuts a
case's ledger into chapters at its turning points, names the ledger lines
each chapter tells so no line is told twice, and names whose each thing
was. `machine story <case>` appends the untold lines to
`output/story/<case>.md`. Both of this issue's tests hold (every chapter's
first line names its ledger lines, no line told twice; a request's chapter
names the person as its author).

What is left: the chapters are the machine's own plain telling. A
`storyteller` turn run through the pool to retell them in a model's words
(docs/069, "The chapters are drafted by a turn") is not yet wired; the
chapters are its facts when it is. Kept open for that, which 1004a's demo
is the natural place to show.

## Intended Behavior

- A turn kind `storyteller`: reads one case's ledger (and its requests, in the person's words), writes only `output/story/<case>.md`.
- Chapters follow the ledger's own turning points: opened, surveyed, described, built, each request, each failure and repair.
- Every chapter names whose each thing was: the person, the referee, the builder, the stand-in or model — the sovereignty of others.
- A new chapter is only added for lines not yet told; the story grows like the ledger.

## Suggested Implementation Steps

1. With the stand-in. **Test:** every chapter's first line names ledger line numbers it tells; no line is told twice.
2. Whose each thing was. **Test:** a request's chapter names the person as its author.

## Sub-issues

- 1001a — the turn kind
- 1001b — turning points
- 1001c — no line told twice
- 1001d — whose it was

## Blocked by

- 104
- 306
