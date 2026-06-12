# 705 — Peer table and aging

## Current behavior

Peer discovery (704) emits events for every announce it sees.
The system needs to remember peers across many announces, age
out stale entries, and offer a single read surface apps can query.

## Intended behavior

The peer table is a small in-RAM list of every peer the device
has seen since boot, keyed by friendly name. Each entry holds:

- The peer's friendly name.
- The peer's MAC.
- The peer's IP, per current transport.
- The peer's last-seen-on-each-transport timestamp. A peer can
  be reachable through more than one transport (radio AND
  USB-C, if a laptop bridges); the table tracks each
  independently.
- A liveness flag: alive (heard within the freshness window),
  stale (heard, but past the window), or gone (never heard or
  past the gone window).

Per-transport aging:

- Within the freshness window (the broadcast period times a few
  — default 20 seconds), the peer is alive.
- Past freshness but within the gone window (default 5
  minutes), the peer is stale. Apps can still try to reach it;
  the attempt may or may not work.
- Past the gone window, the peer is gone. The table keeps the
  entry but apps see it as not currently reachable.

The peer table exposes:

- `peer_table_by_name(name) → peer_entry` — lookup.
- `peer_table_alive_count() → int` — how many peers are currently
  reachable.
- `peer_table_subscribe(callback)` — register interest in
  changes. The messenger uses this to update its peer list
  view.

The aging is run by a periodic box that fires every few
seconds, walks the table, and updates liveness flags. The same
box emits `peer-state-changed` events on transitions so
subscribers update without polling.

## Suggested implementation steps

1. `struct peer_entry_t` — fields above.
2. `peer_table` — flat array, allocated from 108.
3. `peer_table_aging_tick_box()` — periodic walker.
4. `peer-state-changed` event.

## Related documents

- `docs/006-transport-and-networking.md`.

## Blocked by

704.

## Blocks

709, 711.
