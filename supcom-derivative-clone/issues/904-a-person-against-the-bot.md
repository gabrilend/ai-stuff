# 904 — A person against the bot

| | |
| --- | --- |
| Phase | 9 — An Opponent |
| Blocked by | 609, 903 |
| Blocks | — |
| Reads | [roadmap](../docs/015-roadmap.md) |
| Open questions | none |

## Current behavior

Nothing. The way in (issue 609) opens a window on a match; the opponent (issue
903) does not exist. This is phase 9's capstone and the project's last: a
person playing a full match alone and wanting to play another one.

## Intended behavior

The way in offers **against the bot**, with the level chosen from the
opponent's table. The person places factories, draws in the sand, presses one
of four buttons, launches planes on the wheel, and watches the cloud in the
corner; the opponent does the same through the door, at the same delay, seeing
the same snapshot. The match runs under the lockstep loop with one peer, as
every match does, so a single-player match is a network match with nobody on
the other end of the wire — and a replay of it can be watched afterwards, or
sent to somebody, exactly as a two-person match can.

The match ends the way the truck rule says it ends, the goodbye names the
winner and the hash, and the window offers another.

The **phase 9 demo** is the opponent playing the measuring bot, watched:
`issues/completed/demos/phase-9-demo` opens the window on a match with the
opponent behind one team and the measuring bot behind the other, at a level
read from `input/`, and lets a person watch what a hard opponent does with a
dune. The unattended form runs the same match headless and prints the goodbye.

## Suggested implementation steps

1. Add the choice to the way in: a level, a team, a seed or `random`.
2. Route the opponent's commands through `schedule` with the same delay as the
   person's, so neither side acts sooner than the other.
3. Show the opponent's placements and patterns on the field as they take
   effect — it has nothing to hide, and a person learns the game by watching
   what beats them.
4. Write the phase 9 demo as described.
5. Play it. Everything that was wrong goes to group H on the open questions
   page; everything that was worth keeping goes to `faith/` as a belief that
   held.

## Related documents and tools

- [Roadmap](../docs/015-roadmap.md) — phase 9
- [The views](../docs/010-the-views.md) — the way in
- [Other players](../docs/011-other-players.md) — the one-peer match
- `./run-phase-demo` — the front door to the demo this issue ends with
- `tests/027-an-opponent.lua`

## Still open

Nothing beyond the questions in the table. What a person finds wrong in the
first hour will open something, and it will be more interesting than anything
written here.
