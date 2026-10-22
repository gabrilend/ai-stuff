# 304 — Rehearsal with stand-in voices on kuvalu

phase 3, the relay through rmail

## Current behavior

Frames reach the page keeper only by being dropped into its folder.

## Intended behavior

Three extra rmail mailboxes on kuvalu, on spare local ports, named
`fg-sora-1`, `-2`, `-3`, each with the guide mailbox as a contact, stand in
for the real machines. A stand-in voice script per mailbox writes scripted
frames into its `outbox/frame` on a timer, and reads its `inbox/the-page`.

This proves the whole relay (hook, page keeper, page back) with real rmail,
real encryption and real sync timing, before any fg-sora machine is set up.
It stays useful afterwards as the test bench for every later change.

## Suggested implementation steps

1. A setup script that makes the three stand-in mailboxes in RAM and wires
   their contacts with the guide mailbox (using the same generator as 301).
2. The stand-in voice script, reading the same scripted frames as the
   phase-1 demo.
3. Measure, per frame: written, arrived in the page keeper, page published,
   page arrived back. These go to the log for the demo.

## Related documents

- `docs/datapath-frame-to-page.md`

## Blocked by

301, 302, 303.

## Blocks

305, 406.
