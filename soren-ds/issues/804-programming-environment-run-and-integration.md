# 804 — Programming environment: Run and inter-app integration

## Current behavior

The HTTP server (803) can serve and save maps but the
programming environment app's on-device side — the screen the
device shows when the programming environment is foreground —
does not yet display anything, and the "Run" button on the
laptop editor has no on-device implementation.

## Intended behavior

The programming environment app's on-device surface (the screen
it shows when it's foregrounded) renders a compact view of the
currently-edited map:

- Top of screen: the map's name and edit status (clean,
  modified, unsaved).
- A small canvas (reuses the editor panel rendering from 801)
  showing recent run output and any error from the last
  attempt.
- A small panel listing connected laptop clients — when a
  laptop is editing, the device shows "laptop browsing".

When the user (on the laptop) clicks "Run", the POST
`/map/<name>/run` route writes a value into the program's way in
(309) on the device — there is no separate run call, because writing
is what starts a program. The output comes back out of the program's
way out, through the HTTP response, into the laptop editor's run
panel. The device's own canvas updates with the
same output.

The programming environment's drawers:

- **Left:** map menu — "new map", "open map", "save map", "branch"
  (writes the running program out as text under a new name, which is
  the only kind of fork there is — code has no generations).
- **Right:** exits — "to editor" (open a box's source in the
  text editor), "to files" (browse the map's files).

The app's `links.json` declares the two exits. The `entries.json`
declares one entry: `from-editor` accepts a text-typed value
representing edited source for a named box, compiles it through 409,
places a station on the result and moves the arrows to it via 411,
and returns confirmation naming both the new station and the old one
it left unwired — because the old one is still there, and putting the
arrows back is how a person undoes this.

## Suggested implementation steps

1. The on-device map view rendering.
2. The Run wire-up: HTTP route → a write into the program's way in →
   the way out → response.
3. Drawer content sub-maps.
4. `links.json`, `entries.json`.
5. Branching, which writes the running program out under a new name
   and needs nothing from the code side.

## Related documents

- `docs/008-apps-overview.md`.
- `docs/012-soramech-runtime.md`.

## Blocked by

308, 409, 410, 411, 608, 609, 610, 803.

## Blocks

811.
