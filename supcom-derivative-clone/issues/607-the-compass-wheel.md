# 607 — The compass wheel

| | |
| --- | --- |
| Phase | 6 — Watching It Happen |
| Blocked by | 210, 603 |
| Blocks | — |
| Reads | [the views](../docs/010-the-views.md) |
| Open questions | none |

## Current behavior

Nothing. The command truck's plane is designed in
[the command truck and its plane](../docs/008-the-command-truck-and-its-plane.md)
to launch in a direction chosen on a compass wheel centred on the truck, and
issue 210 builds the `launch` command that takes a heading. No viewer draws a
wheel.

## Intended behavior

The whole input is a direction, and the wheel is the smallest gesture that
yields one.

**A ring around the truck.** When the player selects their truck on a field
lens — a click on it, or a key — a ring is drawn around the truck's blended
position, in the field's plane, so that it reads as lying on the sand rather
than floating on the glass. Moving the cursor chooses a heading: the angle from
the truck's centre to the cursor, drawn as a spoke from the centre to the ring.
A click on the ring issues **one launch command** with that heading through the
door. A click elsewhere, or a key, dismisses the ring and issues nothing.

**The ring shows whether a plane may leave.** The truck launches on a counter —
the pair of integers — and the snapshot carries the increment the last plane
left at and the counter's increment now. The ring is drawn whole when enough
increments have passed and as a partial arc, filling as the counter advances,
when they have not. A click on a partial ring still issues the command; the
door refuses it by name, and the refusal is drawn on the ring in words. The
viewer does not decide what the truck may do; it shows what the truck is.

**The ring is drawn through the lens.** The heading is an angle on the field,
not on the screen, so the spoke is computed in field coordinates and drawn
through `to_screen`, and a lens pushed while the ring is open leaves the chosen
heading where it was.

The truck's plane, once launched, is a unit on the field with a position and a
mission, and the units layer draws it; the wheel has nothing more to do with it.
A second truck — a teammate's — has its own wheel, opened by selecting it, and
only the player who owns a truck may open its wheel, which is a rule the door
enforces and the viewer only reflects.

## Suggested implementation steps

1. Write the wheel as a numbered source file with a companion: a state record —
   the selected truck's identifier, the current heading, a refusal being shown
   — and a dispatch table on input events: select, move, click, dismiss.
2. Compute the heading from the cursor's field point (issue 603's `to_field`)
   against the truck's blended position (issue 601), so that the spoke is a
   field angle.
3. Draw the ring and the spoke through `to_screen`; draw the ring's readiness
   from the snapshot's launch pair against the counter's increment, as an arc.
4. On click, build one launch command in the shape issue 210 expects and hand it
   to the door with the wheel's identifier, so the refusal returns to the ring.
5. Draw the refusal's words on the ring until the ring is dismissed or the next
   click.
6. The test: a cursor at a known field offset from the truck yields the expected
   heading; a click yields one launch command with that heading; the ring's
   readiness is whole exactly when the pair says enough increments have passed.

## Related documents and tools

- [The views](../docs/010-the-views.md) — the wheel as the same shape as the
  drawing, smaller.
- [The command truck and its plane](../docs/008-the-command-truck-and-its-plane.md)
  — the heading, the launch counter, the plane's missions.
- [The tick and the timers](../docs/003-the-tick-and-the-timers.md) — the pair
  the ring reads.
- Issue 210 (the launch command and the counter), issue 603 (the lens), issue
  601 (the command channel and the refusal path).
- `tests/024-watching-it-happen.lua`.

## Still open

- Whether the ring should show the heading the last plane took, as a faint
  spoke, so that a player sweeping the field in sectors can see which sectors
  have been swept. It is a fact from the snapshot if the truck remembers its
  last heading, which is a field issue 210 would have to add.
- Whether the wheel should snap to a small number of headings — eight, say —
  which would make the handheld's directional pad (issue 803) and the mouse
  produce the same set of commands. A question for the handheld, written here
  so the wheel is built with a snapping step it can turn on.
