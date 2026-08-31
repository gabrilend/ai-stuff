# 011 — Roadmap

## What is being built

**A seed generation system.** Not a seed, and certainly not the machine.

**Corrected 2026-08-21**, and it adds work after what this document calls the
capstone:

> pack a snowball at the top of a hill, roll it down, see how it goes, and then
> design a better snowball, over and over again until we have a "seed generation
> system" that we can use to instantiate arbitrary hardware systems with useful,
> unique, and intelligently designed software systems.

So a seed is a *sample*. The deliverable is the thing that produces seeds: point it
at an `input/` directory holding whatever an engineer wants the machine to have,
add the always-present instruction and assembly machinery, and it builds an image
for a named board. It **refuses to build** when the board cannot satisfy something
the seed assumes, because that failure happens at build time and build time is where
a person is standing.

Everything below still describes the seed, because the seed is what the generator
generates. Two things follow that the phases do not currently carry: the generator's
adjustment points are a deliverable in their own right — which model, what weight
precision, how long a context, which floor to assume, which architectures ride
along, which descriptions ride along, which auto-included software rides along, and
the carried random number — and the loop of *build, roll, watch, pack a better one*
is a person turning a handle after phase six, not a piece of software anybody
builds. Declined 2026-08-21 and pruned again 2026-08-22: the carried random number
is already a build parameter, so twenty seeds is the front door run twenty times,
and counting how they went is measurement somebody does rather than a thing to make.

The project already invented the generator twice in miniature without naming it:
the six boards in the proving ground are expressed as data with the emulator
invocation generated from the description, and the payload generator already
declines to emit a drawing instruction on a board with nowhere to draw. Those are
the two halves — a description that configures a build, and a build that refuses
rather than pretends — stopping at the emulator's front door.

## What the seed is

**The seed.** Not the machine.

Everything in `002` through `006` describes what a grown machine does — writes an
interpreter, finds its body, climbs the four rungs, reads its own status. None of
that is built here. It is what the seed grows into, and the machine decides how.

What people build is the chip: the code that runs a model, the hands that let it
act, the text it wakes up holding, and the tooling that turns all of it into
something flashable. That is an ordinary software project with an ordinary
roadmap, and the paradigm used to build it should not be insisted upon once the
seed is growing.

```
what people build                    what it becomes
─────────────────────                ─────────────────────
the engine, in assembly       →      arithmetic that can be trusted
the driver, in assembly       →      a machine that can think
the hands                     →      a machine that can act
the instruction and patterns  →      a machine that knows what to do
the image and the flasher     →      a machine that exists
```

**The first two rows were one row until 2026-08-04**, and merging them cost
this project a false reading of three phases. "The engine, in assembly"
was taken to mean the arithmetic — which is written, three times over, and
agrees with itself to the last bit on all three architectures. What it did
not mean, and had to, is the program the firmware actually enters: the one
that finds its own pieces without a linker, finds the model's tensors, lays
out memory without an allocator, and runs the arithmetic in a loop forever.

Arithmetic that agrees is not a machine that thinks. It is a machine that
would think, if something drove it. That something is `107`.

## The phases

Clusters of functionality, not a schedule. Lower numbers are more foundational,
so the last ticket finished may well be an early-phase one.

| Phase | Cluster | What exists at the end |
|---|---|---|
| 1 | **The engine** — weights in, tokens out, on one architecture | A model that thinks on bare hardware, with no operating system beneath it |
| 2 | **The hands** — the tool calls the engine offers | Thinking that can touch memory, ports, storage and a console |
| 3 | **What it is told** — instruction, patterns, device descriptions | The text payload the machine wakes up holding |
| 4 | **Three tongues** — the other two architectures, and choosing between them | One chip that runs on the machines people actually have |
| 5 | **The image** — recipe, board descriptions, build, flash, verify | Something you can put on a card |
| 6 | **Waking** — integration, and the install | A machine that boots, thinks, writes itself onto the computer's own disk, and keeps running after the card comes out |
| 7 | **The proving ground** — developing without a computer in front of you | An emulated machine, and devices that can be destroyed |

Phase 6 is the capstone and the only one that proves anything. Phases 1 through 5
each produce a part that can be tested alone; phase 6 is where a chip is put into
a computer that has nothing on it and the computer starts.

**And it is not the end.** What follows is the crank: watch what the machine does
with its life, change the seed, and build another one. That is the seed generation
system earning its name, and it is where the project stops being a demonstration.
Nothing about it is scheduled here, because how many turns of the crank it takes is
not knowable in advance — but it should not be described as unplanned, which is what
this document used to say.

**Phase 7 is numbered last and built first.** Everything in phases 1 through 6
either goes onto the chip or makes the chip. Nothing in phase 7 ever ships — it
is scaffolding, and that is what its number means rather than any statement about
when to do it. In practice `701` is the first ticket anybody should finish,
because it is where the other twenty-two are developed.

## Why this order

**The engine is first because nothing else means anything without it.** A model
that cannot be run is a file. Everything above depends on tokens coming out at
some rate on real hardware.

**The hands come before the words.** A machine that can think but not act has
nothing to be instructed about. The tool calls decide what kinds of sentence the
instruction can even contain.

**The words come before the ports.** Getting the instruction and the patterns
right is a matter of judgement and revision, and it should be settled while there
is one engine to test against rather than three.

**Porting comes before the image**, because the image builder has to be told what
it is packaging, and until the other two architectures exist there is only one
thing to package.

## What is deliberately not planned here

The machine's own life. Growth, the four rungs, condensation, the backward walk,
what it does when it runs out of room to build. Those are
described in the datapath documents because the instruction has to convey them,
not because anyone is going to implement them.

The line is worth stating plainly: **if a ticket would constrain how the grown
machine organises itself, it belongs in the instruction or the bundled patterns,
not in a phase.** Recommending a shape is fine. Requiring one is the mistake
`strategems/009` is about.

## Demos

One per completed phase, in `issues/completed/demos/`, runnable from a script in
the project root that asks which phase to show. They are part of the deliverable
rather than a development artifact, and they should show numbers rather than
describe features — tokens per second on a given board, bytes of engine per
architecture, the time from power to first token.

## Issue files

Named `{PHASE}{ID}-{DESCR}`, ID two digits, read from the right — `104` is the
fourth issue of phase 1. A trailing letter marks a sub-issue of the ticket it
shares a number with. Each names what blocks it and what it blocks, so dependency
order is recoverable from the tickets rather than from their numbering.

Progress per phase is kept in `issues/phase-X-progress.md`, which stays in
`issues/` after the phase completes.
