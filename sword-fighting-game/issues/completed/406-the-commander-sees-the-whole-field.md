# 406 — The Commander Sees The Whole Field

| | |
| --- | --- |
| Phase | 4 — Seeing it |
| Blocked by | 401, 403, 404, 305 |
| Blocks | 407, 502 |
| Files | `src/027-third-person-view.lua` |
| Reads | `docs/datapath-rendering.md` |

## Current behavior

Built in `src/027-third-person-view.lua`. One change from the plan: the
ring is drawn where the fixed arc will land, ahead of the contingent, not
under the mouse, because the commander chooses when to throw and never
where. Grey while the volley is cooling down, gold when ready.

## Intended behavior

A raised camera behind the player's contingent, looking down at about 50
degrees toward the battle's centre, slid with W A S D and zoomed with the
wheel. Every figure is drawn, at the same detail as first person.

Drawn over the field, in the same 3D pass (not as interface text):

- the push direction as a clay arrow on the ground ahead of the contingent;
- the volley landing zone under the mouse, a ring on the ground at the
  current range (501);
- volleys in flight as small brick darts along their arcs;
- the shield wall as raised shield discs on the front ranks.

The player's own soldier is marked by a small clay pennant above its head, so
the commander can find themself before dropping in.

## Suggested implementation steps

1. Camera from the contingent's centre and the push direction.
2. Mouse ray onto the ground plane for the landing ring (inverse of the
   projection and view).
3. Check by screenshot.
