# 608 — Drawer content delegation

## Current behavior

Drawers open and close (607) but their interior is blank — the
compositor draws the drawer's outline and slide animation but
the rectangle inside is empty pixels. Apps haven't been given a
way to populate it.

## Intended behavior

Each app declares, in its map, a `drawer-content` sub-map per
screen it might be the foreground of. When the system opens a
drawer (607), the runtime asks the screen's current foreground
app for its drawer-content sub-map for that drawer's side (left
or right). The sub-map renders into the drawer's interior
surface area.

A drawer-content sub-map typically holds:

- A radial-menu chord receiver (506) — most drawers present
  their options as a radial menu so the user picks with the
  input mechanism they already know.
- A list of options, each option being one entry in the radial
  menu's table for this drawer.
- An inter-app exit list (609) — the named exits the foreground
  app declares for this drawer.

When the user activates an option (radial menu chord, or a
touch on a touch-equipped option), the option's wire delivers
the appropriate value to the consumer. Some options call
`drawer_close` after firing; others stay open so the user can
make multiple picks.

The drawer-content sub-map is loaded lazily — only when the
drawer first opens. The map stays loaded across opens (it's
small and in RAM); a foreground change unloads the old
foreground's drawer-content and the next open reloads the new
foreground's.

## Suggested implementation steps

1. `drawer_load_content(drawer, app)` — loads the sub-map and
   wires it into the drawer's surface.
2. The drawer content is a program with its own two doors (309), and
   the drawer wires to them. Nothing is flattened into anything —
   which also means unloading one is unwiring rather than unpicking.
3. App-side: a convention that each app's map directory
   contains `drawers/left-bottom.json`, etc.
4. Default empty drawer-content for apps that don't declare
   one — shows a tiny "no options" placeholder.

## Related documents

- `docs/005-display-and-compositor.md` — drawers section.
- `docs/008-apps-overview.md`.

## Blocked by

303, 305, 506, 604, 606, 607.

## Blocks

611.
