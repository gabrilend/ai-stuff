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

`timer-60hz` is not a box. When every core has run out of work the
idle path arms the chip's timer and parks; at the deadline a core wakes
and writes a fixed value, which runs the readiness check on the station
holding it, which builds the frame's first task (206). No interrupt
handler runs and nothing self-arms. The interval is exactly 1/60
second, measured from the previous deadline rather than from whenever
the consuming boxes finished. The wire from the timer to each read box carries the
frame number as the value — useful for the event boxes that
compute "how long has this button been held" by subtracting the
press-frame from the current frame.

The read boxes are added in later issues (`502`, `503`, `504`).
This issue establishes the timer, the map structure, and the
wires; the read boxes are stubbed at first with no-ops that
return an empty state.

The map runs forever, and nothing anywhere needs to know that. There
is no quiescence to detect and no long-running state to be kept in — a
program ends when it is asked to (213) and never because it ran out of
work. Every core asleep with an armed timer is the ordinary idle
condition of this device, not a program finishing.

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

## Open questions

- *JSON, or the map file?* Step 1 says the map's JSON; phase 3 settled
  on a line-oriented `.map` file compiled into the image.
- *Where does the frame number come from?* The timer writes a fixed
  value, and a box cannot count.
- *Exactly 1/60 second?* The engine's timer takes a whole number of
  nanoseconds, and a sixtieth of a second is not one.
- *What does a frame number count when frames are missed?*
- *Who calls it on the device?* `kernel_main` does not start the
  engine's cores yet.

### Proposed answers (UNVERIFIED)

Each one is a choice Ritz can overturn.

1. *The map file.* `src/maps/input-poll.map`, compiled into the image
   like every other map; JSON was the plan before 305.
2. *A loop.* The timer writes `1` into the program's argument door; a
   `frame_next` station adds one to the previous frame, which its own
   output carries back round, exactly as `counting.map` counts. A
   `constant` station puts frame 0 on the loop once. Only one frame
   number is ever on that wire, so frames are made one at a time and in
   order — the fan-out to the surfaces is beside the loop, so two
   surfaces' reads of neighbouring frames may still run at once.
3. *16 666 667 ns.* The frame runs 20 ns a second slow (1.7 ms a day).
   Nothing counts frames to keep time, so exactness was not worth
   changing the engine's timer. Each deadline is the previous one plus a
   period, never "now plus a period", which is the part that matters:
   frames do not drift with how long the boxes take.
4. *Deliveries, not periods.* A period the engine skipped (every core was
   busy past the next deadline too) is counted by `engine_timer_missed`
   and has no frame number, so "held for N frames" undercounts time by
   the skipped periods. On an idle device none are skipped; 502 can turn
   frames into milliseconds at 1000/60 each.
5. *Nobody yet.* `input_poll_start` exists and is linked into the kernel;
   calling it belongs after the engine's cores are running on the device
   (202), which is hardware work.

## What happened

Built on the twin as answered above.

- `src/maps/input-poll.map` — eight stations: `first_frame`, `frame`,
  three read stubs (`read_buttons`, `read_sticks`, `read_touch`)
  answering an empty state stamped with the frame, and three event stubs
  that tally the frame they were handed.
- `src/boxes/095-input.c` — those boxes, and the value types every
  surface will use (`struct button_snapshot`, `stick_snapshot`,
  `touch_snapshot`).
- `program_argument_every` (068) — an engine timer aimed at a program's
  argument door, so the outside does not reach into the program record.
- `src/system/096-input.c` — `input_poll_start` (load, bring up, arm the
  timer one frame from now) and `input_poll_stop` (disarm; the program
  stays placed with the next frame waiting on its loop).
- `twin/tests/097-test-input-poll.c` (33 checks): frames 1, 2, 3 … each
  reaching all three surfaces exactly once; frames plus skipped periods
  matching the time that passed at 60 Hz; every deadline the first plus a
  whole number of periods; nothing after the stop; two copies side by
  side not seeing each other's ticks. Passes with eight busy loops
  competing for the laptop's four CPUs.

Step 5 (load from `kernel_main`) is not done; see answer 5.

## Related documents

- `docs/004-input-model.md`.
- `docs/012-soramech-runtime.md` — self-arming pattern.

## Blocked by

309 (timer box), 311 (the runtime is up by phase 3's close).

## Blocks

502, 503, 504, 508.
