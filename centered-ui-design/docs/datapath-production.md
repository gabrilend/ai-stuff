<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10.
     Current design of factories, paths and engineers. Updated by phase 4
     issues. -->

# Datapath: factories, locked paths, engineers

## Data

| Structure | Fields |
|---|---|
| resource counts | `metal`, `glass`, `aether` (numbers) |
| factory | `id` (integer), `owner_seat` (integer), `position` (position), `kind` (string, a choice id it was built from), `waypoints` (list of positions, may be empty while unlocked), `locked` (boolean), `queue` (list of unit kinds), `build_progress` (number 0–1), `state` (one of the words `placing`, `pathing`, `running`, `dismantling`) |
| engineer stand | a stand whose units include engineers; given the order `dismantle` with a factory as target |

## Steps

```
 build button ─▶ map click ─▶ factory placed (state pathing)
 waypoint clicks ─▶ path drawn ─▶ confirm ─▶ locked = true (state running)
 running: income spent per the team vote ─▶ queue ─▶ unit made
        ─▶ unit walks waypoints in order ─▶ joins the stand waiting at the last waypoint
 engineers ordered to dismantle ─▶ courier ─▶ engineers walk there ─▶ work for a time
        ─▶ factory removed, part of its price refunded ─▶ site free to rebuild
```

The lock is the point: you plan a factory's route once, and live with it
until you spend engineers and time to change it.
