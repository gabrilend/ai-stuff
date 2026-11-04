# 305 — Rehearsal with stand-in voices on kuvalu

phase 3, the relay through rmail

## Current behavior

Voice canvases reach the blitter only by being dropped into its folder.

## Intended behavior

Three extra rmail mailboxes on kuvalu, in RAM, on spare local ports, named
`fg-sora-1`, `-2`, `-3`, made by the mailbox setup script (301). Each has
the guide mailbox as its contact and the turn hook (304), with the stand-in
turn, installed. Together they rehearse the whole round with real rmail, real
encryption and real sync timing before any mini-computer is set up.

It stays as the test bench for every later change. The real turn (405) and
distill mode (601) are first run here.

## Suggested implementation steps

1. A rehearsal script that makes the three mailboxes, starts their daemons,
   and tears them down on exit.
2. Measure, per voice turn: canvas received, turn finished, arrived on
   kuvalu, blitted, next version received back. These go to the log for the
   demo.

## Related documents

- `docs/datapath-round-trip.md`

## Blocked by

301, 302, 303, 304.

## Blocks

306, 405.
