# 810 — Paint: persistence and the messenger handoff

## Current behavior

The paint app can draw with tools (808, 809) but the canvas
exists only in RAM and the messenger's "to paint" exit (807) is
still greyed because paint doesn't yet declare an inbound entry
for an image request or an outbound exit that returns an image.

## Intended behavior

**Persistence.** The drawer's "save" option writes the canvas
bitmap to `/drawings/<name>.png` via `write-path`. The drawer's
"open" option lets the user pick an existing drawing and loads
its bytes into the canvas via `read-path`. The undo ring resets
when a drawing is opened — opening replaces the canvas wholesale.

A small PNG encoder/decoder runs in the kernel. The encoder is
straight uncompressed image data wrapped in the PNG container
(IHDR / IDAT / IEND chunks); compression is not in scope at
launch — uncompressed PNGs are larger but the SD card budget
absorbs that. The decoder accepts uncompressed or
zlib-deflated PNGs equally so drawings imported through the USB
inbox from other tools still load.

**Messenger handoff.** Paint declares one entry and one exit:

`entries.json`:
```json
{
  "entries": [
    { "name": "image-request", "value_type": "image-request" }
  ]
}
```

`links.json`:
```json
{
  "exits": [
    { "name": "to messenger", "target": "messenger",
      "value_type": "image",
      "target_entry": "from-paint" }
  ]
}
```

When the messenger's "to paint" link fires, paint's
`image-request` entry receives the call. The user is on the
paint canvas; either they keep painting or they open a drawing.
When ready, they follow the "to messenger" exit. Paint's exit
flow:

1. Capture the current canvas as PNG bytes.
2. Push the bytes through the link transition (610) with the
   target entry `from-paint`.
3. The messenger receives the image, attaches it to its compose
   buffer, foregrounds on the calling screen.

Once 810 ships, the messenger's "attach image" drawer option
(from 807) ungreyes — the system detects paint's declarations
exist and lights up the option automatically.

## Suggested implementation steps

1. Drawer "save" / "open" wiring with `write-path`/`read-path`.
2. PNG encoder/decoder.
3. `links.json` and `entries.json`.
4. The capture-and-handoff flow on the exit.
5. The "paint installed" detection in the messenger to
   ungreyout the image-attach option.

## Related documents

- `docs/008-apps-overview.md`.
- `docs/011-filesystem.md`.

## Blocked by

406, 407, 608, 609, 610, 807, 808, 809.

## Blocks

811.
