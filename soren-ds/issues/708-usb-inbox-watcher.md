# 708 — USB inbox watcher

## Current behavior

The USB MSC volume (707) presents an inbox directory the laptop
can drop files into, but the device has no logic that notices
those drops or routes the dropped files to the right app.

## Intended behavior

A self-arming `inbox-watch` box polls the `/usb/inbox/`
directory through `list-directory` (407) every second or so.
When a new file appears, the watcher:

1. Reads the file through `read-path` (406).
2. Identifies its type by sniffing the first few bytes — a
   PNG header, a soramech map's `meta.json` shape, a plain text
   file, etc.
3. Dispatches to the appropriate app via an inter-app link
   (609, 610):
   - PNG / image → handed to the paint program for review and
     potential save.
   - Soramech map directory → imported into `/programs/<name>/`
     and opened in the programming environment.
   - Plain text → opened in the editor.
   - Anything else → dropped with a warning logged.
4. Deletes the file from the inbox via `delete-path` (407) so
   the same file isn't processed twice.

The dispatch happens through the link transition mechanism — the
target app comes to the foreground of one of the screens with
the inbound file's contents as the carried value. The user sees
the file land in the destination app.

Concurrent drops are handled one at a time; the watcher
processes the inbox in directory-order per pass. A pass that
sees more than one file does them sequentially.

The watcher itself runs on the runtime's normal scheduling — no
USB-side notification; it's just a box that polls. This is fine
because the inbox content rate is low (a human dragging files in
from a laptop).

## Suggested implementation steps

1. `inbox_watch_box()` — the periodic poller.
2. File-type sniffing routines.
3. Per-type dispatch through the inter-app linkage.
4. Wire into the input-poll-style background map at boot.

## Related documents

- `docs/006-transport-and-networking.md` — USB-C inbox/outbox.

## Blocked by

406, 407, 609, 610, 707.

## Blocks

711.
