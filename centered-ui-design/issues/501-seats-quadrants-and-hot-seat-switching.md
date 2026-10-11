# 501 — Seats, quadrants, and hot-seat switching

**Phase:** 5 — The round table
**Blocked by:** 302, 103

**Blocks**: 502, 505, 604, 606, 802
**Related documents:** docs/core-terms.md (stand-in), docs/console-layout.md
(Center boss)

## Current Behavior

Partly built (2026-10-10): the console spins by hand (issue 302) and the
seat whose arch is in front is the seat being played: its buttons answer,
the other arches' buttons are drawn but do not. Seats are still numbered
round the ring, not yet named by the A-D grid; no seat button or number
keys yet.

## Intended Behavior

- **Spinning to a seat plays it** (the owner, asked whether an ally's
  arch spun to the front should answer: "yes"). Whichever arch the console
  settles on is the seat being played; its buttons answer and its slot
  shows who is named; the arches to either side are drawn whole but do not
  answer.
- Up to four seats (stand-ins), each owning a quadrant, with its own stands,
  factories, view rotation, paint color.
- **Seats are named by a grid** (the owner, 2026-10-10): ours A B over C D,
  the foes' 1 2 over 3 4; A's quadrant is our top-left (north-west), B
  top-right, C bottom-left, D bottom-right; A faces foe 1 across the
  sphere, B faces 2, C faces 3, D faces 4 (issue 602). Going round the hub
  clockwise from the top the seats are B, D, C, A — the console's row of
  arches follows that ring. (The renderer still numbers seats 1-4 round the
  ring from the top-right; renaming to the grid is part of this issue.)
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
