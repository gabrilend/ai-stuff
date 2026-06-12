# 113 — Phase 1 demo

## Current behavior

Issues 101 through 112, taken together, produce a kernel image
that boots on the device, brings up the LEDs for earliest-stage
signalling, brings up the USB controller and CDC-ACM virtual
serial port for streaming debug output, sets up flat memory, dumps
the layout through the CDC-ACM stream, and draws a bright pixel on
each of the two screens. But there is no automated way to flash
that image, observe the debug output, and confirm the visible
pixels — each developer would do those steps by hand.

## Intended behavior

A demo script at `issues/completed/demos/phase-1/run.sh` that:

- Builds the kernel image using 103's build system.
- Prompts the developer to put the device into chip ROM recovery
  mode (hold the documented button, plug in the USB cable), and
  flashes the image directly to the device's storage using the
  chip-specific recovery tool identified in 101. The stock OS
  never executes during this process.
- Opens the USB CDC-ACM virtual serial port (from 110) and
  streams its output to the developer's terminal so the
  memory-layout dump, any panic messages, and any other text the
  kernel emits are visible live.
- Tells the developer to look at the device's two screens and
  confirm a bright pixel at the center of each. The two pixels
  are different colors so the developer can tell at a glance
  which framebuffer drives which panel.
- Reports the wall-clock time from build start to "device is
  ready," because that number is the iteration loop developers
  will live in during phase 2.

The script follows the project convention of a hard-coded `${DIR}`
at the top, accepting an override as the first argument, and
using paths relative to `${DIR}` throughout. It includes a
one-paragraph header comment that explains what it does in
language fit for a general.

The script lives in `issues/completed/demos/phase-1/` from the
moment phase 1 is closed; before then it can live at
`scripts/phase-1-demo.sh` as work in progress.

## The iteration loop the demo proves out

This script *is* the development workflow for everything after
phase 1. Build, flash via recovery mode, watch debug stream,
iterate. The wall-clock number it reports — usually called the
"compile-to-feedback" loop — is what every later phase's work
will be paced against.

## Suggested implementation steps

1. Stub the script with the `${DIR}` boilerplate and the header
   comment.
2. Wire it through to 103's build system.
3. Wire it through to the chip ROM recovery tool identified in
   101 (`sunxi-fel`, `rkdeveloptool`, or whichever the chip
   wants).
4. Wire it through to the USB CDC-ACM serial port from 110.
5. Add the timing report.
6. Run the script end to end on the device. Iterate until both
   bright pixels appear, the layout dump streams cleanly, and the
   recovery-mode flash succeeds reliably.

## Related documents

- `docs/002-roadmap.md` — phase 1 demo description.

## Blocked by

101 through 112.

## Closes

Phase 1.
