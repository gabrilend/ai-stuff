# 503 — A Duel Has To End

| | |
| --- | --- |
| Phase | 5 — The Fencing |
| Blocked by | 501, 502 |
| Blocks | 504 |
| Reads | [fencing](../docs/017-fencing.md) |
| Open questions | 1 (camera or fencer) |

## Current behavior

Duels start and run until somebody dies, which two well-matched fencers may never
do.

## Intended behavior

Four endings:

| Ending | The survivor |
| --- | --- |
| one health reaches zero | released to decide again |
| both reach zero in one tick | both die. Issue 502 is why this is possible. |
| the clock passes `stalemate_seconds` | both released, both given `flee` for `disengage_seconds` so they do not immediately re-engage |
| a participant fails its generation check | dissolved, survivor released |

The **stalemate timer** exists for two reasons and the second is not about
combat. Two evenly matched high-parry fencers can stand in a corridor exchanging
misses until the machine is turned off. And a camera watching them under
`auto swap` has nothing to swap to, because the duel never ends and the verdict
never fires. A rule about fighting, added for a reason about watching.

`disengage_seconds` is written as a knob and not a constant **on purpose**.
Setting it to zero makes a released fencer immediately find another opponent,
which is the other reading of
[open question 1](../docs/026-open-questions.md) — a melee rather than a series
of duels. Both readings are one number apart.

## Suggested implementation steps

1. Write the four endings as an ordered list of named predicates, so the camera's
   verdict can name which one fired.
2. Release both bodies: clear their partner fields, resume their locomotion,
   set the flee intent and its timer.
3. Emit a duel-ended signal the director reads. A signal here means a field the
   director polls, not an event bus — see
   [the shape of the code](../docs/024-the-shape-of-the-code.md).
4. Count duels started, ended by each of the four endings, and mean duration,
   into the report. A stalemate rate that climbs means `parry` is too high.
5. Test: two immortal fencers stalemate at exactly `stalemate_seconds` and
   separate. With `disengage_seconds` at zero they re-engage within a tick or two
   and the melee continues.

## Related documents and tools

- [Fencing](../docs/017-fencing.md)
- [Open questions](../docs/026-open-questions.md) — question 1
