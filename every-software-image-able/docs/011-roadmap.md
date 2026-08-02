# 011 — Roadmap

## What is being built

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
the engine, in assembly       →      a machine that can think
the hands                     →      a machine that can act
the instruction and patterns  →      a machine that knows what to do
the image and the flasher     →      a machine that exists
```

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
| 6 | **Waking** — integration, and the first thing it does unaided | A flashed machine that boots, thinks, and writes its own allocator |

Phase 6 is the capstone and the only one that proves anything. Phases 1 through 5
each produce a part that can be tested alone; phase 6 is where a chip is put into
a computer that has nothing on it and the computer starts.

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

The machine's own life. Growth, the four rungs, condensation, the status square,
the backward walk, what it does when it runs out of room to build. Those are
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
