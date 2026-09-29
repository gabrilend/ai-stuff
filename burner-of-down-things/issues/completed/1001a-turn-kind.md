# 1001a — The turn kind

The first piece of 1001.

## Current Behavior

Built. `src/034-turn-kinds.lua`'s `kinds.TABLE.storyteller` reads only
`ledger` and `input/`, writes only `output/story/{{about}}.md`, and never
reads the source (`kinds.reads_source("storyteller")` is false). Checked
by `tests/087-checking-the-storyteller-kind.lua`. Segmenting the ledger
into per-turning-point chapters (1001b), never telling a line twice
(1001c) and naming whose each thing was (1001d) are not yet built, so a
`storyteller` turn today has nowhere to send a chapter boundary — it can
be made, but nothing yet tells it how to structure the story.

## Intended Behavior

A new row in 034's turn-kinds table, `storyteller`: reads one case's
ledger (and its requests, in the person's own words) and nothing else;
writes only `output/story/<case>.md`.

## Suggested Implementation Steps

1. The turn-kind row (reads/writes/crafts/template, matching 034's
   shape). Done. **Test:** `make_turn(case, "storyteller", {...})` writes
   a `storyteller`-kind turn whose `reads` names only the ledger and
   requests, and whose `writes` names only the story file. Done.

## Blocked by

- 104
- 306
