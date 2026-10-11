# 501 — Seats, quadrants, and hot-seat switching

**Phase:** 5 — The round table
**Blocked by:** 302, 103

**Blocks**: 502, 505, 604, 606, 802
**Related documents:** docs/core-terms.md (stand-in), docs/console-layout.md
(Center boss)

## Current Behavior

There is one seat.

## Intended Behavior

- Up to four seats (stand-ins), each owning a quadrant, with its own stands,
  factories, view rotation, paint color.
- A painted seat button at the dashboard's center switches to the next seat:
  the map rotates so that seat's quadrant faces up, and the dials change to
  that seat's numbers. A seat-name dial and the seat's color on the bezel say
  who is now playing.
- Seats not currently played keep their last orders running.
- A keyboard shortcut per seat (1–4) for quick switching.

## Suggested Implementation Steps

1. Seat table in the world; current seat in the view only (the simulation
   does not care who is looking).
2. Table rotation animation via a rotor.
3. Tests: commands are refused for stands of another seat.

## Open questions

- Does the table rotate only on switching, or on its own? (Open question 14.)
- What do unplayed seats do? (Open question 9.)
