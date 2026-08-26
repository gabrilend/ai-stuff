# 059-outbound

The only place a thing may be written to a socket.

> The server never sends a viewer something they are not entitled to know. Not
> sends-and-marks-it-hidden. Not sends-and-trusts-the-client. **Never puts it on
> the socket.**

## The audit

`write_thing` is `static`, so nothing outside this file can call it. **Every
caller is in this file, and there is one:** `outbound_build`, which has already
run the gates.

That is what makes the rule checkable — "can this leak?" is answered by reading
one function and its callers rather than the whole program. A rule enforced in
one place is a rule; a rule enforced in forty places is a habit.

**If a second caller ever appears anywhere, the argument is broken.** This list is
the check.

## The functions

| Function | Purpose |
| --- | --- |
| `outbound_build` | One viewer's whole update. Returns instructions written. |
| `outbound_refusal` | What you asked for, and why not. |
| `outbound_recall` | A stretch of time did not happen; here is the world again. |
| `outbound_may_send_thing` | The gates, askable directly so a test need not infer them from bytes. |
| `outbound_may_send_wall` | |

`struct viewpoint` is which body a viewer sees from. In phase 6 it becomes the
union across every body in every scope they hold; the interface is already
shaped for the plural so adding scopes is adding a loop rather than changing
every caller.

## The four gates, cheapest first

1. **Scope** — inside a scope this viewer holds? Then everything below passes; you
   always know what you command. *Phase 6. Stubbed returning 0 — "admits
   nothing" — because that is the direction that cannot leak. A stub returning 1
   would have quietly disabled the rest of the filter.*
2. **Hidden** — `THING_HIDDEN` and no `MAY_SEE_HIDDEN`? Never passes, whatever the
   geometry says. The GM's ambush standing in plain view.
3. **Sight** — visible right now? **Bodies need this.**
4. **Memory** — in their fog? **Walls need only this.**

Three and four differing is why you keep the shape of a room you have left and
have no idea whether anybody is still standing in it.

## Passing a gate is not being sent whole

A goblin a player can see goes out as position, facing, radius, and `kind`. Its
`sheet` — the door into the ruleset's numbers — does not, because seeing a goblin
does not entitle you to its hit points. Its `scope` does not either, because who
commands a body is not something looking at it tells you.

Both are covered by leak tests that search the raw bytes for those values.

## An update is the whole picture, not a difference

A difference-based protocol needs both ends to agree about what was received, and
a rollback breaks that agreement in a way neither end can detect. So the buffer
is cleared and rebuilt each beat — which also means a dropped update costs a beat
of freshness and nothing else.

## The wall midpoint, which is a simplification

A wall is a segment and memory is per cell, so "is this wall remembered" is
reduced to its midpoint. A very long wall with one end explored is sent whole or
not at all.

Acceptable because it errs toward sending **less**, and because walls in a
generated dungeon are short. If walls ever get long this becomes a wall that pops
into existence — a visible symptom rather than a silent leak.

## Measured

About 150 microseconds to build one viewer's update, roughly a kilobyte of it,
against the two-room fixture. The phase 4 demo reports the current figures.
