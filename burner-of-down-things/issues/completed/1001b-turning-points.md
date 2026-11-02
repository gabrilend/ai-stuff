# 1001b — Turning points

The second piece of 1001.

## Current Behavior

Built. `src/103-the-story.lua`'s `chapters(lines)` cuts 016's `read()`
output at the ledger's own turning points: `opened`, `surveyed`,
`described` (outlined and described), `refereed`, `built`, `delivered`,
`wider look` (audited, inspected), each `request`, each `failure` (every
`*-failed` kind and `breach`) and each `repair` (a repair turn starting).
Checked by `tests/104-checking-turning-points.lua`.

Decisions, made here since nothing yet said:
- Working lines (`turn-started`, `turn-ended`, `goodbye`) are not turning
  points; they join the *next* chapter, since a turn's own lines come
  before the result they lead to. Working lines at the very end wait (the
  `waiting` list) until a turning point arrives — which is also what lets
  1001c tell the ledger a piece at a time without ever splitting a line
  off from its chapter.
- Lines of a stretch of one kind of work in a row (six `described` lines)
  are one chapter; requests, failures and repairs are told one thing at a
  time (two failures in a row are two chapters).

## Intended Behavior

Chapters follow the ledger's own turning points — opened, surveyed,
described, built, each request, each failure and repair — one chapter per
turning point, in ledger order.

## Suggested Implementation Steps

1. The turning-point scanner over 016's `read()` output, grouping lines
   by `kind`. Done: `103-the-story.lua`'s `chapters`. **Test:** a ledger
   with one of each turning-point kind segments into that many chapters,
   in order. Done.

## Blocked by

- 1001a
