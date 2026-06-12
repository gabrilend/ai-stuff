# 806 — Messenger: send, receive, persistence

## Current behavior

The messenger UI exists (805) but the send button does nothing
and the conversation view is empty because nothing wires the
incoming message events into history storage. The rmail boxes
(710) are ready but unconsumed.

## Intended behavior

**Sending.** When the user taps send (or activates it through
the drawer), the messenger:

1. Captures the text-entry surface's current buffer.
2. Calls `rmail-send` (710) with the peer's name and the
   buffer's bytes as the message body.
3. On success, appends the message to the local persisted
   history for that peer.
4. Clears the text-entry surface.
5. On failure, displays a brief inline error and leaves the
   text-entry surface untouched so the user can retry or edit.

**Receiving.** The messenger subscribes to `rmail-receive`'s
event box. When a message arrives:

1. Identify the sending peer.
2. Append the message to the persisted history under
   `/messages/<peer>/<timestamp>.json`. The file's contents are
   the message body plus metadata (sender, timestamp, message
   type).
3. If the conversation view is currently showing this peer's
   history, scroll the new message into view.
4. If the conversation view is showing a different peer (or the
   app is in background), increment the unread count for the
   sender. The peer list (805) shows unread counts as small
   badges.

**Persistence.** Each peer's history is a directory under
`/messages/<peer>/`. One file per message, named by timestamp.
The messenger reads recent messages at peer-switch time (the
last N messages, where N fits in the conversation view's scroll
window) and lazily loads more as the user scrolls back.

Sent messages are persisted the same way received messages
are; the metadata field distinguishes inbound vs outbound.

## Suggested implementation steps

1. `messenger_send_box()` — captures input, calls rmail-send,
   updates history.
2. `messenger_receive_box()` — subscribes to rmail-receive,
   updates history and view.
3. `messenger_load_history(peer, count)` — lazy backwards-scroll
   loader.
4. Per-peer unread-count state.

## Related documents

- `docs/008-apps-overview.md`.
- `docs/006-transport-and-networking.md`.
- `docs/011-filesystem.md`.

## Blocked by

406, 407, 710, 805.

## Blocks

807, 811.
