# 502 — Asking for another

## Current behavior

Nothing exists. Needs `304`, `501`.

## Intended behavior

**Middle-click on the quantity (or on its panel) means "I didn't understand",
and sends `reroll`.**

Chosen by the owner. It keeps the request to the pointer alone, and it is the
one mouse button a reader rarely presses on plain text.

**Middle-click already means something** in three places, and the extension
must take it over only where it is meant to:

- **on a link**, Firefox opens it in a new tab. A quantity inside a link (a
  product page's "15 kg" linking to the product) is ambiguous. Who wins is
  open question 11 in `docs/008`.
- **on Linux**, middle-click pastes the selection into text fields. The
  extension does not act on quantities inside editable fields at all.
- **with autoscroll enabled**, middle-click starts scrolling. Over a quantity
  with an open panel, the extension stops the event so autoscroll does not
  start.

The panel shows that a re-roll is happening (the old picture dims, the new
sentence replaces the old as soon as it arrives). After `exhausted`, a
middle-click does nothing more. The re-roll's result replaces what the cache
shows for that quantity (`403`).

## Suggested implementation steps

1. `src/extension/` — listen for the middle button over a quantity or panel;
   stop the browser's default only there; send `reroll` with the hover's id.
2. Tests by hand: middle-click on a quantity in plain text, inside a link,
   inside a text field, with autoscroll on and off.

## Related

`docs/006-datapath-the-bridge.md` · `docs/008-open-questions.md` (11) · needs
`304`, `501` · blocks `504`
