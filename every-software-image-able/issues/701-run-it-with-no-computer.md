# 701 — Run it with no computer

## Current behavior

Testing anything requires a board, a card, and a flash — which is a slow loop for
work that fails a hundred times a day.

## Intended behavior

The seed boots and runs inside a hardware emulator, on all three target
architectures, from a single command, with output arriving in the terminal it was
launched from.

## Suggested implementation steps

1. Use an existing hardware emulator rather than writing one. What is needed is
   emulation of a processor, memory, a bus and devices — not emulation of
   operating system calls, of which there are none in this project. No guest
   operating system is involved, which is the thing that makes this simpler than
   it sounds (`docs/012`).
2. **Stand up an example machine for each of the three architectures from the
   start** — one for x86-64, one for 64-bit ARM, one for RISC-V. This is what
   replaces knowing which board the project targets: it does not need to know.
   Each example is a named configuration with a stated processor, memory size, set
   of attached devices and boot scheme, kept beside the board descriptions of
   `501` so the two stay recognisable as the same kind of thing.
3. Give each example machine more than one memory size, so the ratchet in `102`
   is exercised rather than assumed. A configuration with barely enough memory to
   read the weights in place is a test; one with plenty is a demonstration.
3. Give each example machine a framebuffer as well as a serial port, since the
   framebuffer is what most real machines will actually have (`202`) and the
   serial port is what most development boards have. Wire the serial port to
   standard output so text appears in the terminal, and make the framebuffer
   inspectable — a window, or a captured image per run — so the drawing path is
   exercised from the start rather than assumed.
4. Present a host file as an emulated storage device — and attach it through a
   controller of the kind real boards have rather than the emulator's paravirtual
   one. The convenient device would leave the emulator loop and the hardware loop
   running different drivers from the first day, which is exactly the sort of gap
   that stays invisible until first light. Emulators model the real controllers;
   using them costs a longer command line and nothing else. Configure each example
   machine with a different one, so all of them get exercised.
5. Write the launcher as a script with the project location fixed at the top and
   overridable by an argument, so it runs from anywhere. It should take which
   architecture, which image, and whether to wait for a debugger.
6. Make it fast to invoke. This is the command that will be run more than any
   other in the project, and every second it takes is paid thousands of times.

## Blocks

Everything. This is where the other twenty-two tickets are developed.

## Blocked by

Nothing.

## Related documents

`docs/012-datapath-the-proving-ground.md`.
