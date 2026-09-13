# 601 — The window and the two snapshots

| | |
| --- | --- |
| Phase | 6 — Watching It Happen |
| Blocked by | 109 |
| Blocks | 602, 603, 604, 609 |
| Reads | [the views](../docs/010-the-views.md) |
| Open questions | none |

## Current behavior

Nothing. There is no window. The simulation is designed to copy the world out
as a snapshot at the end of every tick (issue 109), and the terminal viewer
(issue 111) is the only thing designed to read one. The test program
`tests/024-watching-it-happen.lua` asserts that a viewer reads snapshots and
nothing else, and it fails today because the viewer does not exist.

## Intended behavior

One window, drawn with the LOVE engine, that holds a list of lenses and the
always-open menu, and that **never touches the live world**. Everything it draws
comes from snapshots; everything it wants comes through the command door. When
a pixel is wrong the bug is in here, and when a rule is wrong it is not.

**Two snapshots, not one.** The simulation advances in ticks and the window
draws many times between one tick and the next. A window that drew the latest
snapshot alone would show every unit teleporting a step at a time. So the viewer
keeps the **last two** snapshots it was handed and, at each frame, draws a
position blended between them by how far the wall clock has moved from the
older tick toward the newer. The drawn body lags the real one by up to a tick,
on purpose, and nothing in the viewer ever extrapolates ahead of what the
simulation has said. Health, ownership, counts, and everything else that is not
a position is drawn from the newer snapshot without blending, because a health
value halfway between two integers is a lie.

The pair is replaced as one operation: when a new snapshot arrives, the newer
becomes the older and the arrival becomes the newer. A viewer that has only one
snapshot so far draws it unblended.

**The simulation runs in the same process, on its own thread**, and hands
snapshots across through the engine's thread channel. The viewer never calls a
simulation function. The one exception is the command door: a command the
viewer issues is a record pushed onto the channel in the other direction,
stamped by the simulation when it arrives, never applied by the viewer.

Refusals come back the same way. The door returns a named refusal for a command
it will not take, and the viewer shows every one where it happened — on the
drawing, on the button, on the ring — because a command that quietly did nothing
is the worst thing a viewer can do to a player.

The window's shape lives in the engine's configuration file at the project root,
which holds settings and no logic: which engine modules start, the initial size,
that the window may be resized, that lines are antialiased because the field is
drawn out of lines. The doorway file beside it is issue 609's.

## Suggested implementation steps

1. Write the viewer as a numbered source file with a companion. It owns: the
   snapshot pair, the lens list (issue 603), the menu (issue 604), and a table of
   engine callbacks — load, update, draw, resize, key, mouse — each a row a
   doorway can forward to.
2. Write the snapshot channel: the simulation thread pushes a copy from issue
   109's `copy` at the end of each tick; the viewer's update pulls whatever has
   arrived and replaces the pair. A snapshot that arrives with a tick number not
   one greater than the newer is an error, named, not smoothed over.
3. Write the blend: a function of the two snapshots and a fraction that yields a
   drawn position per unit. Units present in the newer and absent from the older
   — just born — draw at their newer position. Units absent from the newer are
   not drawn, because they are dead.
4. Write the command channel and the refusal path: every command carries the
   viewer's own identifier for the thing that issued it, so a refusal can be
   routed back to that thing to be shown.
5. Write the configuration file at the root: window title, size, resizable,
   antialiasing, and every engine module not needed turned off, so that nothing
   can be quietly depended on.
6. The test: a viewer given two snapshots and a fraction draws a position on the
   segment between them; a viewer handed a snapshot out of order refuses it;
   nothing in the viewer's exports takes a world as an argument.

## Related documents and tools

- [The views](../docs/010-the-views.md) — the rule this issue enforces.
- [The tick and the timers](../docs/003-the-tick-and-the-timers.md) — where the
  snapshot is taken, and why the viewer never reads the live world.
- Issue 109, which makes the snapshot the viewer reads; issue 108, the door it
  talks through; issue 111, the terminal viewer that follows the same rule.
- `tests/024-watching-it-happen.lua`.

## Still open

- Whether the simulation should run on a second thread in the same process, or
  as a separate process the window talks to over a pipe. The thread is chosen
  because the engine provides one and a channel; the process would make the
  window a client of the headless runner, which is the shape the network already
  has. Worth revisiting when issue 703 exists.
- How large a snapshot is at a full field, and whether the copy per tick costs
  more than the blend saves. Measured by the headless runner, not argued.
