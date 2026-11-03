# Phase 5 progress — Input drivers

Phase 5 makes the device's input surfaces visible to apps. By the
end of the phase, a 60Hz polling map fires once per frame, reads
the raw state of every button, every analog stick, and both
touch panels, compares against the previous frame, and emits
event boxes downstream apps subscribe to. The radial-menu chord
mechanism assembles D-pad-plus-face-button events. The
handedness and drawer-swap settings from phase 4 are applied at
the event-emission stage so apps downstream see events already
interpreted through the user's preferences.

Phase 5 is the first phase where most of the work is soramech
maps rather than kernel C. The C leaf boxes read GPIO and I2C
registers; the maps that wire them together fire on the
runtime's schedule.


## The story of the phase

1. `501-polling-loop-map-structure.md` — the 60Hz frame-driven
   map every other input surface hangs off.
2. `502-button-surface.md` — D-pad, ABXY, L/R, the four center
   buttons, the two stick clicks. GPIO reads as C leaf boxes,
   event boxes for down / up / held.
3. `503-analog-stick-surface.md` — left and right stick X/Y
   ADC reads, deadband, eight-direction quantization, click
   events.
4. `504-touch-panel-surface.md` — both touch panels'
   controllers, position and pressure reads, down / move / up
   events with screen id attached.
5. `505-chord-detection.md` — same-frame multi-button
   correlation, the general mechanism the radial menu uses.
6. `506-radial-menu-chord-box.md` — the specific D-pad-plus-
   face-button chord that drives text entry.
7. `507-settings-application.md` — read handedness and
   drawer-swap from `/settings/` at boot and re-read on
   change; apply them to the event stream so consumers don't
   each have to.
8. `508-phase-5-demo.md` — touch screens, push buttons, watch
   counters and surface drawings update through CDC-ACM and on
   the framebuffer.

## Completed issues

Built as portable C and maps and proven on the laptop twin. Counts:
`progress-dashboard.lua <project> -m`.

- **501** the input-poll map: an engine timer writes a tick into its
  argument door every 1/60 s, each deadline the one before plus a
  period; the frame number rides a loop back to the station that makes
  it, and fans out to three read stubs and three event stubs. Started
  and stopped by `input_poll_start` / `input_poll_stop`; nothing calls
  them on the device yet (that waits for 202).

The boxes are in `src/boxes/095-input.c`, the map is
`src/maps/input-poll.map`, the starting and stopping in
`src/system/096-input.c`. Test: `twin/tests/097` (33 checks: every frame
reaches every surface exactly once; frames plus skipped periods match the
time that passed at 60 Hz; nothing after the stop; two copies do not see
each other's ticks).

## Open issues

Sorted by what each one waits on (scoped at the start of the phase's
work, against main as it stood then).

**Buildable on the twin now.** The logic that turns one frame's raw
state into events needs no hardware: the raw reads sit behind a small
seam the twin can set, and the device's side of that seam waits for 101.

- **502** — `button-down`, `button-up`, `button-held`, history on a loop,
  the bit order; the device's GPIO snapshot waits for 101's pin mapping.
- **503** — deadband, eight-way direction without floats, direction
  changed; the ADC reads wait for 101's channel mapping, and calibration
  (`notes/diagnostics/002-stick-calibration.md`) is measured on the device.
- **504** — `touch-down`, `touch-move`, `touch-up`, per-screen history;
  the I2C controller and its register map wait for 101.
- **505** — `chord-of`, once 502's events exist (it needs nothing else).

**Blocked on an unmerged stack.**

- **506** — needs 502, 503 and 505, and its lookup table lives on the
  card at `/system-maps/` and `/settings/`, so it reads through
  `read-path` (406, PR #35).
- **507** — reads handedness and drawer-swap from `/settings/` (408, PR
  #48) through `read-path` (406, PR #35), and re-reads on change.

**Needs the device.**

- **508** — the demo is pressing real buttons and touching real screens.
- The device halves of the issues above: starting `input-poll` at boot
  once the cores run the engine (202), the GPIO, ADC and I2C reads (101),
  and stick calibration.

## Phase demo

`issues/completed/demos/phase-5/run.sh` will exist once the
phase closes. It builds and flashes a kernel with a tiny test
app statically embedded: each button increments a labeled
counter, the analog sticks move a cursor, touches paint a
single bright pixel where they land. The demo passes when every
input surface produces visible output in the CDC-ACM event log
and the framebuffer matches the expected drawing.
