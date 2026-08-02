# 202 — Say something

## Current behavior

**Done, and photographed** — `src/068` is the font, `src/069` emits the
drawing, `src/070` checks both, 13 of 13 on 2026-08-02. The sentence *first
light, drawn from the firmware's own framebuffer* appeared on a machine with
no operating system, and every pixel of every letter was compared against
what the font holds — in both directions, since checking only the lit pixels
would pass a machine that filled the line solid.

The font is **drawn as pictures in its own source**, dots and hashes, turned
into bytes at load. A wrong hex byte in a font is a letter that looks
slightly odd forever and nobody suspects the right thing; a wrong hash is
visible while typing it. The bytes are rendered back to a picture and
required to equal the source, so the derivation is proven rather than
assumed. Every row is checked for width and stray characters, which caught a
typo in the `C` while the font was being written.

The model can speak, not only the engine: `say` reaches every voice at once,
`say_on` names one, `voices` says what there is. A machine with no voice is
refused when its hands are built rather than discovered in the field, and a
`say` that no voice carried is a refusal rather than a quiet zero.

**Two things learned that were not in the plan.**

The pixels-per-row sits at offset thirty-two of the mode structure, not
twenty — twenty is inside the pixel bitmask. It read zero, and every row of
every letter collapsed onto the first scanline: one confident horizontal
line, with the serial port reporting success. Same failure as the header
offsets in `033`, found the same way, by looking at what was drawn rather
than at what was written.

The carried font must be **contiguous** over its whole code range, with a
visible box where no picture exists, because a glyph is found by subtracting
rather than searching. A table of only the drawn characters indexes wrong at
every gap — the screen fills with real letterforms spelling something else.
The stand-in is a box rather than a blank, since a blank says the machine
printed a space it never printed.

Only x86-64 draws so far; the other two tongues are `401`'s.

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

## Which firmware, and what it costs

The handover above is **UEFI's**, and only UEFI's. This was assumed rather than
checked when the ticket was written, and building the harness proved it
matters:

| How the board starts | What a display costs at boot |
|---|---|
| UEFI | nothing; the framebuffer arrives with the memory map |
| BIOS | text memory at a fixed address — characters, not pixels |
| No firmware | nothing exists until a driver, an enumeration and a command queue do |

So a board that boots any other way cannot draw at its first instant, and the
seed should target UEFI on all three architectures — which is also what makes
`402` work, since the architecture field a firmware matches on is UEFI's too.
**The boot story and the drawing story point at the same place.**

## What this also settles

`docs/004` asks what draws the picture that justifies a choice, given that the
renderer is software that has to be built and the display may not be operable
yet. The framebuffer answers it: **the machine can draw from the first instant,
before it has a driver for anything** — on a UEFI machine.

Proved in the small on 2026-08-02: a machine with no operating system wrote
into BIOS text memory and the result was photographed through the emulator and
read back as legible text. Drawing before anything else exists is real; the
linear framebuffer specifically waits on UEFI boards. Charts showing what a choice was made
against are available immediately rather than in a late phase.

## Blocks

Practically everything. Every later ticket is debugged through this.

## Blocked by

`201`.

## Related documents

`docs/003-datapath-the-bootstrap.md` — what the firmware leaves behind.
`docs/004-datapath-compilation.md` — the picture that shows the field.
