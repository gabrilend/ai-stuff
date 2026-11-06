# 305 — Phase 3 demo

phase 3, the link

## Current behavior

Nothing exists.

## Intended behavior

`issues/completed/demos/phase-3-demo`: two folders on kuvalu, one standing
in for each computer, on the `local` transport. A stand-in steward commits to
`distant-work` and files requests on a timer; the courier and watchdog run.
Partway through, the cut switch is set: the watchdog turns to waiting,
requests pile up in the outbox, and the demo shows the may-touch check
refusing the clone. The switch is cleared, the backlog arrives, and the
demo approves them. Output: a timeline of state changes, a count of
requests per minute in and out, and the receipts of the courier and watchdog.

## Suggested implementation steps

1. Stand-in steward on a timer.
2. The timeline as a separate viewer of the ledger.

## Related documents

- `docs/roadmap.md`, phase 3

## Blocked by

302, 303, 304.

## Blocks

None.
