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
2. Stand up all three architectures from the start. The same tool covers them, and
   having the port targets runnable before the ports exist means phase 4 begins
   with somewhere to run.
3. Wire the emulated serial port to standard output, so `202` produces visible
   text on the first attempt.
4. Present a host file as an emulated storage device, so `206` and the whole
   move-in sequence have somewhere to move in to.
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
