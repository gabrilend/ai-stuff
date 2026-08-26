# 053-session

Turns, and taking one back.

A turn is a **transaction**: a window in which declarations accumulate, a
simultaneous resolution when it closes, a snapshot at its head, and an undo.

That is all the server understands about a turn. Not initiative, not rounds, not
whether acting twice is legal — those are a ruleset's. A ruleset wanting
continuous play sets the window to one beat and none of this machinery fires.

## Undo needed no mechanism

It needed two mechanisms built for other reasons aimed at each other. A snapshot
is a copy of some bytes, because the world is flat arrays with no pointers. A
replay lands in the same place every time, because the tick is deterministic.

## The functions

| Function | Purpose |
| --- | --- |
| `session_start` | Over a borrowed world. Takes ring depth and window length. |
| `session_release` | |
| `session_attach_fogs` | Per-viewer memory the ring will snapshot and restore. |
| `session_command` | Records, then runs the gauntlet, then marks any refusal. |
| `session_tick` | Advances, closing and reopening the window when due. |
| `session_rollback` | `ROLLBACK_REDECLARE` or `ROLLBACK_RETCON`. |
| `session_can_roll_back_to` | |
| `session_ring_depth` / `_held` / `_bytes` | |

## Two things people mean by undo

**Re-declare** restores the head and discards that turn's commands — for a
dropped connection or a misread situation. Everybody decides again.

**Retcon** restores the head, keeps the commands, and replays forward, so a
rewritten one takes effect and everything after it follows. Only possible because
the log is decoded and indexed. Also the dangerous one, because it changes what
somebody did without asking them — open question 3.4.

## What a snapshot holds

The world, the stream positions, the standing orders, and the fog.

**Standing orders**, because a body walking toward a destination is mid-decision,
and restoring where it stood but not where it was going would have it wander off
somewhere nobody chose.

**Stream positions**, because leaving them out makes a retconned turn roll
different dice for a reason nobody can see — which looks exactly like the retcon
having worked.

**Fog**, because a map left un-rolled holds a place reached in a turn that never
happened and contradicts the world every time anybody walks there again. The cost
is that the person still remembers the corridor; their map closes over a room
they can describe out loud. You cannot restore ignorance.

## The ring is finite, and says so

A world is a few hundred kilobytes, so twenty turns of history is a few
megabytes — nothing. Keep the ring and pay the memory; the alternative trades it
for a delay a person would feel on a deep rollback.

A turn that has fallen out is **refused**, not approximated. Restoring the
nearest turn still held would put the world somewhere nobody asked for.

## The window

Closes when it has been open long enough. Three things could close one —
everybody having declared, a timer, or a GM saying so — and only the timer
exists; open question 3.5.

A window of **one beat is continuous play and a real configuration**, running
through the same code as any other rather than down a special path, because a
special path is a path that stops being tested. A window of zero is corrected to
one, since it would close before anybody could say anything.
