# 1001b — Turning points

The second piece of 1001.

## Current Behavior

1001a defines the turn kind; nothing segments a ledger into chapters.

## Intended Behavior

Chapters follow the ledger's own turning points — opened, surveyed,
described, built, each request, each failure and repair — one chapter per
turning point, in ledger order.

## Suggested Implementation Steps

1. The turning-point scanner over 016's `read()` output, grouping lines
   by `kind`. **Test:** a ledger with one of each turning-point kind
   segments into that many chapters, in order.

## Blocked by

- 1001a
