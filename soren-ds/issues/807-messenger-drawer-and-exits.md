# 807 — Messenger: drawer and inter-app exits

## Current behavior

Send and receive work (806) but the messenger's drawer is empty
and the inter-app exits the messenger should declare — "to
paint" for image attachments, "to editor" for quoting a message
— don't exist yet.

## Intended behavior

The messenger's four drawers:

- **Bottom-left** (peer-side actions): "block peer", "rename
  peer", "delete peer history". Acts on the currently selected
  peer.
- **Bottom-right** (message-side actions, when a message is
  selected): "quote in editor" (exit to the text editor with
  the selected message's body), "save body to files" (write
  the body as a `.txt` under `/messages/<peer>/`).
- **Top-left** (compose actions): "attach image" — until paint
  ships in 810, this option is greyed out and shows a small
  "paint not installed" caption. Once 810 lands, the option is
  active and follows the inter-app link to paint.
- **Top-right** (settings): "change my name" (writes
  `/settings/name`), "set discovery cadence", "transport
  preferences".

The messenger's `links.json`:

```json
{
  "exits": [
    { "name": "to paint",   "target": "paint",   "value_type": "image-request" },
    { "name": "to editor",  "target": "editor",  "value_type": "text" },
    { "name": "to files",   "target": "files",   "value_type": "text" }
  ]
}
```

The `entries.json`:

```json
{
  "entries": [
    { "name": "default",    "value_type": "text"  },
    { "name": "from-paint", "value_type": "image" }
  ]
}
```

The `from-paint` entry is what paint's "to messenger (image)"
exit targets — when the user finishes a drawing in paint and
follows the exit, the image lands in the messenger's compose
buffer ready to send.

## Suggested implementation steps

1. Drawer content sub-maps for the four drawers.
2. Greyed-out rendering for the image-attach option until 810
   ships.
3. `links.json` and `entries.json`.
4. The `from-paint` entry: receives bytes, attaches to compose
   buffer, displays a preview thumbnail.

## Related documents

- `docs/008-apps-overview.md` — the messenger and inter-app
  links sections.

## Blocked by

608, 609, 610, 806.

## Blocks

810, 811.
