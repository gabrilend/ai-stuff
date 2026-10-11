<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10.
     Current design of how an order travels. Updated by phase 1 (couriers)
     and phase 3 (the wheel and order grammar) issues. -->

# Datapath: an order, from press to obedience

## Data

| Structure | Fields |
|---|---|
| pending order (view only) | `stand_id` (integer, from the rim sector under the notch), `order_kind` (string, from the button pressed), waiting for a map click |
| command (view → simulation) | `seat` (integer), `stand_id` (integer), `order_kind` (string), `target` (position: tier-distance number + angle number), `issued_tick` (integer) |
| courier | `id` (integer), `command` (the command above), `position` (position), `speed_tiers_per_second` (number, faster than any unit), `route` (list of positions: hub → current stand position, re-aimed each tick because the stand moves) |
| order (on the stand) | `kind` (string), `target` (position), `received_tick` (integer) |

## Steps

```
  rim turned ─▶ stand under notch ──┐
  order button pressed ─────────────┴─▶ pending order (view)
  map clicked ─▶ screen pixel ─▶ accordion inverse ─▶ target position
              ─▶ command ─▶ channel ─▶ simulation
              ─▶ courier spawned at hub ─▶ runs toward stand each tick
              ─▶ arrives ─▶ stand's current order replaced ─▶ stand obeys
```

- The grammar is strict: button first, map second. A map click with no
  pending order does nothing but show where you clicked. A second button
  press before a map click replaces the pending order kind. Escape or a right
  click cancels it. There is no way to give one order to two stands.
- The courier chases the stand, not the target: it is carrying the message
  to the stand wherever the stand now is.
- Two couriers to the same stand: each takes effect when it arrives; the
  later arrival wins. A newer order can overtake an older one only if its
  route is shorter (for example the stand moved toward the hub).
- Transit time is visible: the courier is drawn on the map, and the stand's
  rim sector shows a readout counting down the courier's estimated arrival.
