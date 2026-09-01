# 408 — The Panel And Its Sliders

| | |
| --- | --- |
| Phase | 4 — The Wandering |
| Blocked by | 407 |
| Blocks | nothing |
| Reads | [the camera and what it watches](../docs/008-the-camera-and-what-it-watches.md) |
| Open questions | 1 (camera or fencer) |

## Current behavior

The director's settings are constants in a file and changing one means editing
and restarting.

## Intended behavior

A panel, bound to a key, holding every director setting as a control that can be
moved while the program runs. Asked for by name: *"definable with a slider"*,
*"toggle checkmark"*.

| Control | Kind |
| --- | --- |
| swap now | button, also a key |
| on swap, follow | toggle |
| dwell seconds | slider, 1 to 60 |
| auto swap | toggle |
| same team only | toggle |
| stay with the loser | toggle |
| boredom seconds | slider |
| follow ease | slider |

Plus a read-only region showing the current subject, its kind, its team, what it
is doing, and **which verdict predicate is currently true** — which is what makes
`auto swap` off usable rather than blind.

**Adjusting anything here never touches the simulation.** The panel writes to the
director and to the camera and to nothing else. A test asserts it: drive every
control through its whole range during a run and compare the simulation checksum
against a run where the panel was never opened.

The panel is drawn in screen space after the world, with its own scale, so
zooming the maze does not zoom the controls.

## Suggested implementation steps

1. Write the control table: name, kind, range, and getter and setter pairs onto
   the director. Drawing and hit-testing are then loops over the table rather
   than code per control.
2. Write the slider and toggle drawing and hit-testing generically.
3. Write the read-only region from the director's verdict list.
4. Persist the settings to `input/` so a session starts the way the last one
   ended, and read them at startup — the first thing a program does is read its
   input files.
5. Test: the checksum test above; and every control's setter round-trips through
   its getter across the full range.

## Related documents and tools

- [The camera and what it watches](../docs/008-the-camera-and-what-it-watches.md)
- [The director decides what is worth watching](407-the-director-decides-what-is-worth-watching.md)
