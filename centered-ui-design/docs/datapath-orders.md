<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10;
     reworked the same day: who is named on the map, what is chosen on the
     dashboard. Updated by phase 1 (couriers) and phase 3 (order grammar). -->

# Datapath: an order, from two clicks to obedience

## Data

| Structure | Fields |
|---|---|
| named stand (view only) | `stand_id` (integer) — set by a click on the map, waiting for a button |
| command (view → simulation) | `seat` (integer), `stand_id` (integer), `order_kind` (string, from the button), `issued_tick` (integer) |
| courier | `id` (integer), `command` (the command above), `position` (place on the sphere), `speed_tiers_per_second` (number, faster than any unit) |
| order (on the stand) | `kind` (string), `received_tick` (integer) |

## Steps

```
  map click ─▶ pixel ─▶ sphere projection inverse ─▶ nearest own stand ─▶ named stand
  order button clicked ─▶ command (named stand + verb) ─▶ simulation
      ─▶ courier spawned at hub ─▶ chases the stand each tick
      ─▶ arrives ─▶ stand's order replaced ─▶ stand obeys
```

- The grammar is strict: map first (who), dashboard second (what). A button
  click with no one named does nothing but flash the "name someone first"
  dial. A second map click before a button changes who is named. After a
  command is sent, no one is named.
- Dials are never part of this: they are not clickable.
- The order verbs are relative to the stand and the front: advance (toward
  the front in its direction), fall back (toward the hub), flank left / right
  (around the circle), hold, attack (the nearest enemy it can reach), deploy
  shield (where it stands), build (an engineer builds where it stands),
  dismantle (an engineer dismantles the factory it stands at), adventure (a
  hero goes deeper). How a verb that needs a second party (follow, or a
  specific target) is given is an open question.
- The courier chases the stand, not a place: it is carrying the message to
  the stand wherever the stand now is.
- Two couriers to the same stand: each takes effect when it arrives; the
  later arrival wins.
- Transit is visible: the courier is drawn on the map, and a dial counts
  couriers in flight.
