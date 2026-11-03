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

## Open questions

- *Allocated from 108?*
- *What is "a callback" when the subscriber is a box?*
- *Is a peer removed when gone?*
- *What does "I am leaving" do to the table?*
- *How big is the table?*

### Proposed answers (UNVERIFIED)

Each one is Claude's call, open for Ritz.

1. *A static table of 32 entries:* small, fixed, and present before
   anything else runs. Full, a new name is refused and counted.
2. *A station's port.* `peers_subscribe(station, port)` delivers a
   `struct peers_event` for every event: kind, link, state before and
   after, name. The box-side value type is `struct peer_event` in
   `src/boxes/122-peers.c`, checked byte for byte by the test. There
   are up to 8 subscribers.
3. *Never, while the device runs.* Gone is a state, as the issue says.
4. *Gone on that link at once,* and alive again when heard again.
5. *The windows are the issue's:* alive within 20 s of the last
   announcement on that link, stale until 5 minutes, then gone. A peer's
   own state is the best of its links'.

Events: the first time a name is heard sends one "discovered" event,
not a change as well. Every later change of a link's state sends one
"changed" event, whether from aging or from hearing. Hearing a peer that
is already alive sends nothing.

## What happened

704 and 705 built together on 703, over the STAND-IN LINK:

- `src/system/121-peers.c` and `.h`: announcing, hearing, the table,
  aging and subscribers.
- `src/boxes/122-peers.c`: `peers_frame`, `say_peer`, and the
  `peer_event` value type.
- `src/maps/peers.map`: the once-a-second tick.
- `notes/networking/000-discovery-format.md`: the layout.

`twin/tests/123-test-peers.c` (28 checks), playing other devices on
the stand-in on the test's own clock:

- The device's name, until one is set.
- An announcement every five seconds, only on a link with an address,
  in the documented layout.
- A peer heard, and the subscriber told once.
- Its own announcements and six kinds of bad one ignored.
- Following a move, and counting missed announcements.
- Stale at 20 s and gone at 5 minutes, each told once, and alive again
  when heard.
- One peer on both links is one entry.
- Leaving on one link.
- A full table.
- The net and peers maps on their own timers.

## Related documents

- `docs/006-transport-and-networking.md`.

## Blocked by

704.

## Blocks

709, 711.
