# 504 — Deploy the thinkers

phase 5, bringing up the fg-sora machines

## Current behavior

Thinkers run on kuvalu in the rehearsal (406).

## Intended behavior

A deploy script copies the thinker, its input files and its context folder
to each fg-sora, and starts it on boot after rmail and the model. Running it
again updates the machines in place.

## Suggested implementation steps

1. The deploy script, sharing its machine list with 501 and 502.
2. Switch the page keeper's contacts from the stand-in mailboxes to the real
   machines.
3. Run for an hour and read every goodbye receipt.

## Related documents

- `docs/datapath-thinker.md`

## Open questions

- How the context folder's files get there and stay fresh
  (`docs/open-questions.md`, 1).

## Blocked by

406, 502, 503.

## Blocks

505.
