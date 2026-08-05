# Phase 4 — Three tongues

**Goal.** One chip that runs on the machines people actually have. The engine
written for each assembly language in modern use, and the small piece of code
that picks between them at power-on.

Writing the same program three times is the price of not having a compiler. It is
paid once, by people, before any of these machines exist.

## Issues

| | | Status |
|---|---|---|
| `401` | The second and third tongues | **in progress** — a whole thought runs end to end in assembly on all three architectures, and all three produce the same 192 scores bit for bit over the same weights; what remains is the hands, which are ported nowhere |
| `402` | Waking on the right foot | **completed** — the selection proved on all three architectures, the within-architecture detection written and proved by booting two different processors and requiring them to disagree, 18 of 18 |
| `403` | The tokenizer and the console, on all three at once | **completed** — the tokenizer agrees over the awkward corpus in both directions, 9 of 9; and saying something is a callable routine on all three, chunked and checked in order, 9 of 9 |

## Where the risk is

`401`, and specifically its fast half. The plain arithmetic ports almost
mechanically; the vectorised version does not, because the three architectures'
vector instruction sets have nothing in common and RISC-V may not have one at all.
That is three pieces of work wearing one ticket number.

For the second architecture that risk is now spent rather than argued about.
The fast kernel is held to the identical answer over a whole pass, not just
per call — a difference of one bit anywhere compounds through every tensor
and every layer before it reaches a score, so a whole pass is a far harder
question to ask it than any single call. It gave the same 192 scores.

The conducting turned out to be the easy half on this architecture too, for
the reason it was easy on the first: there is no floating point in it. Every
number it touches is a count or an address, so the one genuine difference
between the two — this architecture has ten registers that survive a call
where x86 has six, and therefore keeps in registers what the first tongue had
to spill to the stack — cannot change an answer.

The third architecture's arithmetic turned out to be spent risk too, and not
where it was expected. Its vector hardware is genuinely absent on the
processor its board names -- measured with a bare probe rather than argued
about -- so the fast product keeps its four totals in ordinary registers and
still agrees with the first architecture bit for bit. The extension was never
the obstacle it was budgeted as; the obstacle was that this assembler leaves
a relocation on a branch to a label in its own file, which the word emitter
(`054`) was built for a phase early.

What is left of `401` is the half that is not a translation at all: the
hands. x86 reaches devices through a separate address space with its own
instructions and the other two are memory-mapped throughout, so that hand
changes shape rather than detail — and the hands are still the readable kind
of code on *every* architecture including the first, so they are `107`'s
work rather than a port.

Above the arithmetic and the conducting, the sampler, the tokenizer and
saying something all exist on all three as well. **Everything phase 4 set out
to do is done**, and what remains for a machine to think on its own is not a
port at all: it is the driver (`107`), which has never existed anywhere.

The demo this phase names is now possible for the first time, and was not
before: the same measurement across all three architectures side by side
needs three engines that agree, and there are three.

`402` turned out not to be what it looked like. There is no shared code that can
detect a processor and pick an engine — machine code is not portable, so the
detector would need an architecture of its own. Each firmware finds its own
payload where its convention says to look, which makes this a question of laying
the medium out rather than of dispatching at runtime.

One shape change to expect: x86 talks to devices through a separate address space
and its own instructions, while the other two are memory-mapped throughout. The
catalogue of hands is therefore not identical across architectures, which the
instruction must not assume away.

The open case: a processor outside the three. Either an engine for it is bundled
before flashing or it is worked out on arrival, and that is the one situation
where the seed is not self-sufficient.

## Demo

`issues/completed/demos/phase-4-three-tongues.sh`, chosen through `run-demo`
at the project root.

It was planned as the measurement from `106` run across all three
architectures side by side, and that is not what phase 4 turned out to be
about. Speed is a property of a board; what this phase built is three
engines written by hand that produce **the same numbers to the last bit**,
and a table of three times-per-second would say nothing about that.

So the demo counts agreements instead -- every comparison every architecture
has been put through, with what it was held to beside it -- and then boots a
real emulated machine of each kind and earns them in front of the reader.
`--quick` skips the booting and says so, because without it the numbers are a
story rather than a claim.

Every figure in the summary is derived rather than typed. That is not a
principle applied in advance: the count of routines was written into it by
hand as eleven and was **twelve** by the time it first ran, because a routine
had been added in between. It caught itself doing the thing this phase has
already been bitten by once.
