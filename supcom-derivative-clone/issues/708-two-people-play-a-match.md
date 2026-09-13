# 708 — Two people play a match

| | |
| --- | --- |
| Phase | 7 — Other Players |
| Blocked by | 609, 704, 705, 706 |
| Blocks | — |
| Reads | [other players](../docs/011-other-players.md) |
| Open questions | none |

## Current behavior

Nothing. Every blocker is open: there is no window (issue 609), no lobby (704),
no hash exchange (705), and no rejoin (706). This is phase 7's capstone and it
has nothing of its own to build; it is the first time all of the above run at
once with people at the keyboards.

## Intended behavior

Two people, on two computers in one room, on one local network, play a match
to the end. Each opens the way in (issue 609), chooses to join, sees the other
in the lobby, and the match opens on the seed the first one proposed. Every
placement, pattern, level and launch either makes takes effect on both screens
at the same tick. The hashes hold for the whole match. When it ends, both
machines write the same goodbye: the same winner, the same final tick, the
same hash.

Then a third machine joins late, catches up from the command log at full
speed, and sees the same match in progress — the proof that nothing but
commands was ever needed.

The **phase 7 demo** is that, with the people replaced by the measuring bot so
it can run unattended: `issues/completed/demos/phase-7-demo` starts two
headless runners on one computer over UDP on the loopback address, each with a
bot behind it, lets them lobby, runs a match, starts a third runner part-way
through that rejoins from the log, and prints all three final hashes on one
line. The demo passes when the line has one distinct value on it.

## Suggested implementation steps

1. Add `join` to the way in (issue 609): announce, show the lobby as it fills,
   open when agreed.
2. Wire the viewer's command path through `schedule` (issue 702) rather than
   straight into the door.
3. Show the stall by name on screen when it happens, and the halt tick if a
   desync ever fires.
4. Write the phase 7 demo script as described, reading the port and the bot
   choice from `input/`.
5. Play it, two people, and write down everything that was wrong. Those go to
   group H on the open questions page.

## Related documents and tools

- [Other players](../docs/011-other-players.md)
- [The views](../docs/010-the-views.md) — the way in
- `tests/025-other-players.lua` — the loopback version of the same match
- `./run-phase-demo` — the front door to the demo this issue ends with

## Still open

Nothing beyond the questions in the table. The first thing two people find
wrong will open something.
