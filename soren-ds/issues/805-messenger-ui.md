# 805 — Messenger: UI

## Current behavior

The messenger app exists in name only — the rmail port (710)
provides the protocol, the peer table (705) provides the
addressable peers, but nothing renders a conversation, lists
peers, or accepts text input as the messenger app.

## Intended behavior

The messenger app uses both screens by default:

- **Top screen:** the conversation view. The currently-selected
  peer's message history scrolls vertically. Each message
  occupies one or two lines (more if it has an image attached,
  once paint ships). The most recent message is at the bottom;
  older messages scroll up. The user pans with the touch screen
  or with the analog stick.
- **Bottom screen:** the input area. The top half is a peer
  list — every peer the device knows about, sorted by recent
  activity. The bottom half is a text-entry surface using the
  radial-menu chord box (506) the editor also uses; the text
  appears as it's typed, ready to send.

Tapping a peer on the peer list (or selecting via radial menu
chord) switches the conversation view to that peer's history.
Switching peers does not affect the typed-but-unsent text;
that text stays in the input area until cleared.

A "send" button sits at the bottom-right of the input area. The
user taps it (or activates it through the drawer) to send the
typed text as a new message to the currently-selected peer.

The peer list updates live from the peer table (705) —
`peer-state-changed` events drive the list's repaints. Peers
that go stale grey out; peers that come alive light up.

## Suggested implementation steps

1. The messenger's top-screen conversation view surface and the
   per-message rendering.
2. The bottom-screen split: peer list (top half) plus input
   area (bottom half).
3. The peer-list rendering — subscribed to 705's
   `peer-state-changed`.
4. The text-entry surface — wires the radial-menu chord box
   into a small text buffer.
5. The send button and its wiring (806 implements the
   actual send).

## Related documents

- `docs/008-apps-overview.md` — the messenger section.
- `docs/004-input-model.md`.

## Blocked by

506, 601, 603, 705.

## Blocks

806, 807.
