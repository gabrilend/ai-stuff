# 202 — Say something

## Current behavior

The machine can think and cannot be heard. Everything that goes wrong before this
ticket is diagnosed by watching a computer sit still.

## Intended behavior

Output, on whatever the machine actually has, working before anything else needs
debugging.

## What is available before there are drivers

Not much, and the order is not the obvious one.

| | How it works | When it works |
|---|---|---|
| **The framebuffer** | Firmware hands over a pointer to memory, the width and height in pixels, the pixel format, and the bytes per row. Write bytes, pixels change. | Immediately, on nearly any modern machine |
| **A serial port** | A handful of registers: set the speed, set the format, poll until the transmitter is empty, write a byte | Immediately, where the board has one |
| **Status lamps** | A pin driven high or low | Immediately, where the board has them |
| **USB** | A host controller driver, then enumeration, then a class driver | Much later. Not an early option at all |

**USB is the wrong end of the difficulty scale.** It looks like the modern
replacement for a serial port and is nothing of the kind — it is a stack, and it
is one of the harder things to bring up rather than one of the easier. A machine
that could talk over USB has already solved most of the problems this output is
meant to help debug.

Most machines this gets installed on will not have a serial port. Development
boards usually do, and it remains invaluable for a headless machine, but it cannot
be the thing the design assumes.

## Suggested implementation steps

1. **Take the framebuffer first.** The firmware leaves its address and geometry in
   the handover structures, alongside the memory map `102` already reads. Nothing
   else is required to make a pixel change colour.
2. Carry a bitmap font — a small table where each character is a few bytes of
   on-and-off pixels — and write the loop that copies those bits into the right
   places. That is the whole of text output. Mind the bytes-per-row figure: it is
   often larger than width times bytes-per-pixel, because rows are padded, and
   assuming otherwise produces a picture that shears.
3. Add the serial port where the board description says one exists. Same driver as
   before: set the divisor, set eight bits with no parity and one stop bit, poll
   the status register until the transmit register is empty, write the byte.
   Unbuffered on purpose — buffering loses exactly the last thing said, which is
   what you want to read after a crash.
4. Expose whichever exist as tool calls, so the model can talk and not only the
   engine. And have the engine narrate its own startup through them — memory
   found, weights located, first token produced — so the machine is describing
   itself before it is capable of being asked to.
5. Handle the machine with none of them by saying so at build time rather than
   discovering it in the field. A machine that cannot speak is a machine nobody
   can help.

## What this also settles

`docs/004` asks what draws the picture that justifies a choice, given that the
renderer is software that has to be built and the display may not be operable
yet. The framebuffer answers it: **the machine can draw from the first instant,
before it has a driver for anything.** Charts showing what a choice was made
against are available immediately rather than in a late phase.

## Blocks

Practically everything. Every later ticket is debugged through this.

## Blocked by

`201`.

## Related documents

`docs/003-datapath-the-bootstrap.md` — what the firmware leaves behind.
`docs/004-datapath-compilation.md` — the picture that shows the field.
