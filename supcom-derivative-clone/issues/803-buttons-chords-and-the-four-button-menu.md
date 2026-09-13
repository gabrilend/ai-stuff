# 803 — Buttons, chords, and the four-button menu

| | |
| --- | --- |
| Phase | 8 — The Handheld |
| Blocked by | 604, 802 |
| Blocks | 806 |
| Reads | [the handheld](../docs/012-the-handheld.md) |
| Open questions | G2 |

## Current behavior

Nothing. On a computer the energy menu (issue 604) is four buttons on screen,
the compass wheel is a ring the mouse picks a direction on, and the keyboard
picks levels. The handheld has no mouse: a directional pad and two triggers on
the left, four face buttons and two triggers on the right, two sticks, four
centre buttons along the bottom of the lower screen, and two touch screens.
The sibling system turns every button into a pair of event boxes — down and up,
the up carrying how long it was held — and turns a pad direction pressed with a
face button into one **chord** event, which is how its radial menus are driven.
Its four centre buttons open **drawers**, overlay menus sliding in from a
screen's edges, whose contents the foreground program supplies.

## Intended behavior

Every input the game needs is a **row in one dispatch table** from an input
event to a command, and the table is the only place the two are joined:

| Input | Command |
| --- | --- |
| a radial entry in the bottom screen's left drawer | set the energy level to one of the four |
| the right stick's direction, then a face button | launch the truck's plane on that heading |
| the pad's directions | push the bottom lens: pan |
| the two left triggers | push the bottom lens: zoom in and out about its centre |
| the two right triggers | push the top lens the same way |
| a radial entry in the top screen's left drawer | switch the top screen between the wide lens and the cloud window |
| a radial entry in the bottom screen's right drawer | stop or resume a line, chosen by touching its factory first |

The energy menu is the working ruling for G2: **four entries on a drawer's
radial menu**, one per assignment level, opened by the centre button the system
maps to the bottom screen's left drawer. Four is the design and the radial has
room for exactly four before it starts to look like a menu, which is the test
the document sets. The compass wheel is the right stick, because a stick is a
compass already; the launch is the face button that completes the chord, so a
heading is never sent by accident.

Commands leave through the same door and the same `schedule` as on a computer.
Nothing in the simulation knows a chord exists.

## Suggested implementation steps

1. Write the input table above as a box source: a function from an event record
   — kind, button, direction, duration — to a command record or to nothing.
   The table is data in the source; the function indexes it.
2. Wire the system's button-down, chord, and drawer boxes into that station in
   the map from issue 801, and its output into the `schedule` station.
3. Supply the three drawers' contents: the four levels, the lens switch, the
   line stop-and-resume, each a small radial list the system's drawer box
   reads.
4. Wire the stick's direction and the face-button chord into a launch command
   through the table, with the truck's launch counter refusing a second launch
   too soon, as it already does.
5. Test on the desktop engine by feeding the station recorded event streams and
   asserting the commands that come out, before the device is involved.

## Related documents and tools

- [The handheld](../docs/012-the-handheld.md)
- [The views](../docs/010-the-views.md) — the always-open menu and the wheel
- [Territory, mass, and energy](../docs/005-territory-mass-and-energy.md) —
  the four levels

## Still open

- **G2.** Which four buttons are the energy menu. A drawer's radial menu is the
  working ruling; the pad's four directions are the alternative; a person
  holding the device decides.
- Whether the menu should be on screen at all times on the handheld, as the
  design says it is on a computer, when the drawer that holds it is by
  definition not open most of the time. The bottom screen's edge can show the
  current level as a mark even when the drawer is closed.
