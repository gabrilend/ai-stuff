# 302 — The courier's visit

phase 3, the link

## Current behavior

Nothing exists.

## Intended behavior

`scripts/courier` on the near computer: every `interval` seconds
(`input/courier`) it makes one visit, steps 1–4 and 8 of
`docs/datapath-link.md`. Steps 5–6 (git) are 304 and step 7 (twins) is 402;
they slot in as further entries in the visit's list of steps.

- A visit is a list of steps run in order. The first failure ends the
  visit, and its error goes to the run log.
- Requests carried in land in the gate's `incoming/`, and the gate's admit
  (202) runs after the carry.
- Counters for the receipt: visits, visits-failed, requests-carried-in,
  answers-carried-out.
- `courier --once` makes one visit and exits; `courier` runs until stopped;
  `courier --help`.

## Suggested implementation steps

1. The visit as a list of step functions.
2. Steps 1–4 and 8 on the transport (301).
3. Tests with the `local` transport: a request goes in and its answer comes
   back; with the cut switch on, nothing moves and the next visit carries
   everything; a request carried twice is admitted once.

## Related documents

- `docs/datapath-link.md`, `docs/datapath-gate.md`

## Blocked by

101, 102, 201, 202, 301.

## Blocks

304, 305, 402, 403, 501, 702.
