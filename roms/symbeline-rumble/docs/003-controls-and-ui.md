# Controls & UI

The game is played in two voices: shoulder buttons for *where you are looking
and acting*, touchscreen for *what you are doing to a specific unit or place*.

## The shoulder protocol

The L and R buttons are page+menu, not just-page.

| State                      | Press L                    | Press R                    |
|----------------------------|----------------------------|----------------------------|
| Viewing right half         | Page to left half          | Open right-half menu       |
| Viewing left half          | Open left-half menu        | Page to right half         |
| Menu open                  | Close menu (page if same)  | Close menu (page if same)  |

Semantically: *the shoulder you press is the shoulder whose half you are
asserting attention over*. Pressing it once asserts viewing; pressing it
again asserts intent (the menu).

The menu opens spells, behavior-pattern toggles, and structure actions for
units present in that half. Spells with no targeting requirement fire from
the menu; spells with targeting requirements prompt for a touchscreen target.

## Touchscreen role

- Select a friendly unit or structure → opens its detail view (spell or
  order targeting).
- Tap a destination on the bottom screen → issues a context order (e.g.,
  rally point set, treasure collection, structure capture intent) within
  the limits the path graph permits.
- Drag is reserved for camera nudge inside the half, if needed; the
  default camera is fixed per-half.

The top screen is touch-tappable on the Anbernic DS but not on baseline DS
hardware. Any feature reliant on top-screen touch must have a baseline
equivalent or be flagged as Anbernic-only. This is a divergence row in
`005-divergence-grid.md`.

## The no-HUD discipline

There is no on-map text, no health bars, no resource counters in the corners.
What the player needs to read off the map:

- **Gold** — section-marks on a bar near owned infrastructure.
- **Notifications** — speech-bubble style, emerging from the unit or
  structure the notification is about.
- **Targeting** — drawn into the world (a glow on the unit, a marker on
  the path).
- **Cast feedback** — visual effect at the cast site; the menu closes.

What does *not* appear on the play surface:

- Unit names.
- Hit-point bars.
- Numbers of any kind, anywhere, ever.
- Mini-map (the half-paging *is* the mini-map).

When in doubt: if the information is needed only sometimes, put it in a menu.
If it is needed continuously, find a way to draw it into the world's geometry.

## Dual-screen vs. native window

On the DS, top screen is the primary play view (3D scene) and bottom screen
is the touch surface (a tactical inset of the same half, plus menu
surface). On native, the same layout is rendered as a single vertical
window split top/bottom. The seam is implemented as a single virtual
screen-pair surface inside the platform layer (see
`004-architecture.md`).
