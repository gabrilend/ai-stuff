# 809b — Concurrent append

The second piece of 809.

## Current Behavior

A card can be written once; nothing appends to it safely.

## Intended Behavior

Ratings (and any other repeated field) append as one line at a time,
safe under two writers at once — the card's own version of the ledger's
append-only discipline (016).

## Suggested Implementation Steps

1. An atomic-append primitive (open-append-close, one line, no
   read-modify-write race). **Test:** two appends issued at once both
   survive — neither line is lost or interleaved.

## Blocked by

- 809a
