# 804 — Patterns drawn with a stylus

| | |
| --- | --- |
| Phase | 8 — The Handheld |
| Blocked by | 605, 802 |
| Blocks | 806 |
| Reads | [the handheld](../docs/012-the-handheld.md) |
| Open questions | none |

## Current behavior

Nothing. On a computer (issue 605) a pattern is drawn with the mouse: the viewer
collects points as the button is held, shows the line in the sand, and issues
one placement command — cell, domain, line, pattern — when the drawing ends,
showing any refusal at the point that failed. The handheld's bottom screen is
a touch surface reporting touch-down, touch-move and touch-up with a position,
one cursor at a time, which is what a stylus is.

## Intended behavior

**Drawing in the sand is what the bottom screen is for.** The stylus touches
the factory's cell, and that is the first point; it moves, and every reported
position is converted through the bottom screen's close lens into a field
point and appended; it lifts, and the drawing is done. One placement command
leaves through the door, exactly as on a computer, and the simulation applies
the same validation: every point on the field, a land pattern off the water,
the first point on the factory. A refusal comes back with the point that
failed, and the drawing stays on the screen with that point marked until the
player draws again or touches elsewhere.

Which line the factory runs, and which domain, are chosen before the first
touch from a radial in the bottom screen's right drawer (issue 803); the touch
then supplies the cell and the pattern. A touch that begins on a cell the team
does not hold is refused before a line is drawn, by the same rule the door
would apply, so the player is not asked to draw a route from ground they do
not own.

The stylus reports many points; the pattern wants few. Points closer than a
catalogue distance to the previous kept point are dropped as the drawing is
made, so a slow hand and a fast hand draw the same route.

## Suggested implementation steps

1. Write a drawing box: takes a touch event and the current drawing — a list of
   field points and a state — and returns the new drawing, with no memory of
   its own; the drawing is the station's value.
2. Convert each touch position through the bottom lens's screen-to-field from
   issue 802.
3. On touch-up, emit the placement command record with the line and domain
   chosen in the drawer, and wire it into `schedule`.
4. Draw the drawing in progress and any refusal mark on the bottom surface from
   the drawing station's value, in the bottom drawing box of issue 802.
5. Apply the point-thinning distance from the catalogue as points arrive.
6. Test on the desktop engine with recorded touch streams: a route over land is
   accepted; a route through water is refused at the right point; a fast and a
   slow trace of the same shape produce the same pattern.

## Related documents and tools

- [The handheld](../docs/012-the-handheld.md)
- [Factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md)
- [The views](../docs/010-the-views.md) — drawing in the sand, and refusals
  being loud

## Still open

- Whether a pattern can be drawn across both screens — beginning on the close
  lens and continuing on the wide one — for a route longer than the bottom
  screen shows. The working answer is no: pan the close lens with the pad
  mid-drawing instead, which needs the drawing to survive a lens push.
