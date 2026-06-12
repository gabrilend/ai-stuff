# 501 — Polling-loop map structure

## Current behavior

The runtime can run maps (phase 3) but no map is driven by the
60Hz frame the input model needs. Polling once per frame is what
every input surface in this phase hangs off; without that, there
is no scheduled wake-up for the input pipeline.

## Intended behavior

A statically-embedded map called `input-poll` is loaded at boot
and runs continuously. Its skeleton:

```
timer-60hz ──→ read-buttons ──→ button-events
            ├→ read-sticks   ──→ stick-events
            └→ read-touch    ──→ touch-events
```

`timer-60hz` is a self-arming timer from 309. Its interval is
exactly 1/60 second. It fires sixteen-point-six milliseconds
after the previous fire, regardless of how long the consuming
boxes took. The wire from the timer to each read box carries the
frame number as the value — useful for the event boxes that
compute "how long has this button been held" by subtracting the
press-frame from the current frame.

The read boxes are added in later issues (`502`, `503`, `504`).
This issue establishes the timer, the map structure, and the
wires; the read boxes are stubbed at first with no-ops that
return an empty state.

Because the input-poll map runs forever, it never reaches
quiescence in the one-shot sense. The runtime's quiescence
detector (308) sees its self-arming pattern and keeps the map
in the "long-running" state.

The handedness and drawer-swap settings (507) interpose between
the raw event boxes and any consumers; this issue commits only
the raw event boxes' positions in the graph, not the settings
application.

## Suggested implementation steps

1. Statically embed the input-poll map's JSON.
2. `timer-60hz` config: 16667 microseconds, unlimited fires.
3. Stub read-buttons, read-sticks, read-touch boxes (no-ops).
4. Stub event boxes.
5. Load and start the map from `kernel_main` after the runtime
   is up.

## Related documents

- `docs/004-input-model.md`.
- `docs/012-soramech-runtime.md` — self-arming pattern.

## Blocked by

309 (timer box), 311 (the runtime is up by phase 3's close).

## Blocks

502, 503, 504, 508.
