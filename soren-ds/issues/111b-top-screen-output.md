# 111b — Top screen output

## Current behavior

After 111a, the display controller is running and the bottom
screen is being scanned out. The controller's second output path
— the one that drives the top screen — is unconfigured. The top
screen is dark or showing whatever the controller's reset state
leaves on it.

## Intended behavior

The top screen is being actively scanned out alongside the bottom
screen, from its own framebuffer in RAM. Specifically:

- A framebuffer for the top screen is allocated from the page
  allocator. It is independent from the bottom screen's
  framebuffer — they don't share pixels.
- The controller's second output path is configured to scan out
  from the top screen's framebuffer.
- A boot-time confirmation, like the one in 111a, reports both
  outputs as running through the debug stream.

## Why this is smaller than 111a

The controller is already up. The clocks, the power, the
initialization sequence — all done. This sub-issue only adds an
output path on an already-running controller, plus its
framebuffer. It is a few register writes and one allocation,
where 111a was the entire bring-up.

## When to do this

111b is required to close phase 1. The phase is supposed to
demonstrate the hardware, and the hardware has two screens. The
phase 1 demo confirms a bright pixel on each screen, not just the
bottom one. 111b is the small remaining piece that lights up the
second output once 111a has the controller running.

## Suggested implementation steps

1. Allocate the top screen's framebuffer from 108. Zero it.
2. Configure the controller's second output for the top screen.
3. Update the boot-time status report to cover both outputs.

## Related documents

- `docs/005-display-and-compositor.md` — phase 6 (the compositor)
  is the first thing that actually needs both screens running.

## Blocked by

111a.

## Blocks

112 (the demo draws a pixel on each screen), 113, phase 6.

## Parent

111.
