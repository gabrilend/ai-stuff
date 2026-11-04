# 704 — Deploy the turn hook

phase 7, bringing up the mini-computers

## Current behavior

The turn hook, runner and real turn run on kuvalu in the rehearsal (304,
405, 501).

## Intended behavior

A deploy script copies the turn hook, the turn runner, the turn, its input
files and instruction file to each mini-computer, installs the hook into the
voice's mailbox config, and restarts the daemon. Running it again updates the
machines in place. The blitter's voice contacts switch from the stand-in
mailboxes to the real machines with one setting.

## Suggested implementation steps

1. The deploy script, sharing its machine list with 701–703.
2. Run for an hour and read every voice's goodbye receipt.

## Related documents

- `docs/datapath-voice-turn.md`
- `docs/datapath-round-trip.md`

## Blocked by

304, 405, 501, 702, 703.

## Blocks

705.
