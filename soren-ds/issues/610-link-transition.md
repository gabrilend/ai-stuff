# 610 — Link transition

## Current behavior

Apps declare exits (609) and drawers expose them as menu options
(608) but pressing one does not yet swap the screen's foreground
to the target app. The link declaration is just data.

## Intended behavior

When a `follow-link` event fires carrying an exit definition,
the link-transition handler:

1. Looks up the target app by name. If the target isn't yet
   loaded into RAM, loads it via 303 and starts its entry tasks
   via 308. The target now runs in the background.
2. Looks up the target's entry box from the exit's
   `entry_box` field (or, if unspecified, defaults to the
   target's `default-entry` box from its `entries.json`).
3. Pushes the carried value into the target's entry box's input
   slot via `slot_push` (205). The push uses release ordering
   so the target's gathering function sees the value.
4. Calls `screen_set_foreground(source_screen, target_app)`
   from 604. The compositor's next tick paints the target's
   surfaces; the source app's surfaces stop being composited.

The source app does not stop running. Its map stays in the
background (013), its surfaces stay allocated, its state is
intact. If the user follows another link from the target back
to the source — through a corresponding forward link on the
target's exit list — `screen_set_foreground` swaps back and the
source app's surfaces immediately appear with their preserved
state.

The transition is single-frame. The compositor sees the new
foreground value before its next tick; no fade, no slide. The
user chose where to go; we put them there.

The system never tracks a history of which app was where. There
is no back button. There is no return path. Every transition is
forward; "back" is just another forward exit the destination app
exposes. See `004-input-model.md`.

## Suggested implementation steps

1. `follow_link(exit_definition, value, source_screen)`.
2. Target-load-if-needed path.
3. Entry box resolution from the target's `entries.json`.
4. Push value, swap foreground.
5. A `follow-link` box that wraps the call so map authors can
   invoke it from a drawer-content radial-menu option.

## Related documents

- `docs/004-input-model.md`.
- `docs/005-display-and-compositor.md` — link transitions
  section.
- `docs/008-apps-overview.md`.

## Blocked by

205, 303, 308, 604, 608, 609.

## Blocks

611.
