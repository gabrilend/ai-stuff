# 304 — Wire connector

## Current behavior

The loader (303) parsed boxes and allocated their instances, but
the producer→consumer linkages from each box's `connections[]`
array are not yet wired into the runtime's slot store. Without
that, a box's output has nowhere to go.

## Intended behavior

The wire connector walks every `box_instance_t` in the map. For
each instance, for each entry in its parsed `connections[]`
array, it:

1. Looks up the named destination box_instance by id within this
   map.
2. Looks up the named destination input port on that
   box_instance.
3. Validates the port exists (the destination's descriptor
   declares it in its `inputs[]`).
4. Validates the port is not already wired *and* not already
   carrying a literal value. A port either has one literal, one
   incoming wire, or is declared `optional` — anything else is a
   hard error per soramech's port-state rules.
5. Stores a pointer to the destination slot in the producer's
   outgoing connection record. The worker scheduling loop from
   209 walks this list when a box fires to know where to push
   the output.

The connector treats the producer→consumer relationship as
unidirectional, but it also records the reverse pointer on the
slot — the slot remembers which producer feeds it. The reverse
pointer is what the routing dispatcher (307) needs for the
distributor kind, which polls every downstream slot's fill before
picking a branch.

Encapsulation may have already spliced sub-maps into the parent
graph by this point (305 runs before 304 from the loader's
perspective). The connector sees a flat graph either way.

## Suggested implementation steps

1. `wire_connect(map_t *)` — top-level entry.
2. `wire_one_connection(...)` — per-connection work.
3. Port-state validation helper.
4. Reverse-pointer install on slot.

## Related documents

- `docs/012-soramech-runtime.md`.

## Blocked by

301, 303, 305 (encap splice runs first so the connector sees a
flat graph).

## Blocks

307 (routing dispatcher walks the connection list the connector
built), 311.
