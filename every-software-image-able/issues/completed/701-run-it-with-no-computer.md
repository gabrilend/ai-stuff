# 701 — Run it with no computer

## Reopened 2026-08-21 — nobody can watch the machine

Everything below this section works and stays. What it lacks is the plainest
thing anybody would ask of a proving ground: **a screen you can look at while the
machine is running.**

### Current behavior

The launcher passes `-display none` and always has. The comment beside it is
honest about the consequence -- *the framebuffer device still exists and can be
inspected through the monitor later; only nobody is watching live.* So a machine
can be photographed and the photograph rendered as text, which proves what was
drawn and cannot show it happening.

The serial wire can already come to the terminal, and that is the channel the
machine speaks on before it can do anything else. What is missing is only the
picture.

### Intended behavior

`--watch` opens a window on the running machine, and the serial line keeps
working exactly as it does now. Watching and reading happen at once, in the way
somebody debugging a computer expects: a screen on one side, words on the other.

Three backends exist on this host — a window, a second kind of window, and one
that draws the guest's screen **inside the terminal**. The last matters more than
it looks: half the boards here run in eighty-by-twenty-five text mode, where a
terminal rendering is not a poor substitute for a window but a better thing than
one, and it works over a connection with no display at all.

### Done 2026-08-21, except the last step

`--watch` exists and takes an optional backend. Bare, it opens a window where
the host has a display server and draws in the terminal where it does not,
saying which it chose. Asking for the in-terminal rendering together with
serial-to-terminal declines the second and says so. A word that is not a
backend is refused rather than guessed at. Every board still defaults to no
window, checked across all six.

**Step four is not done and is deliberately left.** Two boards still describe
their display identically while one is characters in memory and the other is
real pixels. Nothing reads that distinction yet, and adding a field nothing
consults is the speculative work this project keeps arguing against. It becomes
worth doing the moment something wants to advise a backend per board rather than
per host.

### Suggested implementation steps

1. `--watch` with an optional value naming the backend. No value picks a window
   when the host has a display server and the in-terminal rendering when it does
   not, **announced either way** — the same shape as `--accel`, which declines out
   loud rather than falling back quietly.
2. Refuse to guess where two options want the same terminal. The in-terminal
   rendering owns the terminal, and so does serial-to-terminal; asking for both
   sends the serial line to its log file instead, and says so.
3. Leave `-display none` as the default. Every test in the project boots
   machines without a window and must keep doing so, because a window nobody
   asked for on a build machine is a hang rather than a picture.
4. Say what a board's screen actually is. Two boards describe their display
   identically while one is characters in memory and the other is real pixels,
   so a description cannot pick a backend for itself. Whichever way that is
   resolved, the fact belongs in the board description rather than in the
   launcher's judgement.

### What this does not cover

Watching a machine and stepping it in a debugger at the same time. Both are
available separately and nothing has tried them together.

---


## Current behavior

**In progress.** The harness exists and all three architectures have produced
first light through it: a board description per machine (`src/015`–`017`), a
launcher that generates the emulator command from a description (`src/018`),
and a stub builder that generates provable payloads from a message string
(`src/019`). Each stub said `first light: <arch>` over its board's console on
the first attempt, with the serial logs landing in `tmp/shared-memory/logs/`.

Two empirical findings are recorded in the board info files: the ARM board
needs its processor pointed at the payload by a second loader entry, and the
RISC-V board with no firmware jumps from its reset vector to the start of DRAM.

**Screens can now be photographed and read.** The launcher takes
`--screenshot`, driving the emulator's monitor from outside while the machine
runs, and `src/028` renders the result as text so a drawing can be confirmed in
the same terminal that started the machine. Proved on 2026-08-02: a machine
with no operating system wrote `first light, drawn` into BIOS text memory,
photographed and read back as legible letterforms.

**Hardware acceleration works** where guest and host share an architecture, and
is declined out loud rather than silently where they do not.

**The memory configurations work**, named and literal, on all three boards.

**Both of the things that remained are now done.**

**The framebuffer gap is closed.** It was a finding rather than a chore: the
linear framebuffer of issue `202` is UEFI's handover, and the first three
boards use BIOS and no firmware. Three UEFI board descriptions now exist
(`src/030`–`032`), all three boot real firmware, and a payload draws into the
framebuffer that firmware hands over — checked pixel for pixel against the
font it carries (`070`). Six boards now, and which kind a payload needs is a
property of the payload rather than something the harness guesses.

**The seed exists to boot.** A payload carrying a packed model finds it
inside itself, reads the firmware's memory map, and computes the memory
ratchet, on all three architectures (`055`). Another says which processor it
woke up on and which engine that means starting (`087`). Neither is the whole
seed, and both are it running with nothing underneath.

The launcher gained two things that turned out to matter more than they
looked. `--screenshot` drives the emulator's monitor from outside while the
machine runs, so what was drawn can be read back in the terminal that started
it. And `--cpu` overrides the processor the board describes — not a
convenience: a detection run on one machine cannot show that it detects
anything, and the only proof is two machines disagreeing (`402`).

**This ticket is complete.** What is left in this phase is the emulator's
honesty rather than its existence: modelled devices instead of synthetic
addresses (`702b`), watching what a machine wrote (`703`), cutting the power
(`704`), and the list that never closes (`705`).

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
3. **An emulated machine is a board, so describe it as one.** Rather than keeping
   emulator configurations beside the board descriptions of `501`, make them *be*
   board descriptions — architecture, boot scheme and where the firmware looks,
   console device, expected storage controllers, medium layout — with the
   emulator's command line generated from the description rather than written by
   hand.

   The payoff is that the emulator stops being a special path. An image for an
   emulated machine is built by the same builder, from the same recipe, in the
   same way as one for a real board — which means `502` is exercised from the
   first day of the project rather than from phase 5, and the seam between the
   builder and the engine is under test long before first light depends on it.
4. Provide hardware acceleration as a launcher option for the case where guest and
   host share an architecture. It is the difference between an afternoon per
   attempt and a few minutes, and `602`'s method depends on it.
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
