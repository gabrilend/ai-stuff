# 010 — Datapath: The Mind

The thing that does the thinking, which is the one part of the machine that
arrives rather than being built. This document is what ships, how it starts, and
what happens when the machine decides to change it.

## What is actually on the chip

Three things, and the second is the one that was missing from the earlier
documents:

| | What it is |
|---|---|
| The weights | The model |
| The engine | The code that runs the model, applies its results, and handles basic tool calls |
| The instruction | Build every piece of software you can fit |
| The patterns | Recommended build patterns — suggestions, not code (below) |

The engine is real software and it has to work before the machine can have its
first thought. It cannot be built by the machine, because building requires
thinking, and thinking requires it.

## Written in assembly, three times

There are about three assembly languages in modern use. The engine is written in
each of them, all three carried on the same chip, and the boot picks whichever
matches the processor it woke up on.

```
power arrives
   → identify the processor
   → select the engine written for it
   → the model can think
   → everything in 003 becomes possible
```

That covers the majority of cases. For a processor outside the three, either the
engine for it is bundled before flashing, or it is worked out on arrival — which
means a machine that cannot think until somebody helps it, and is the one
situation where the seed is not self-sufficient.

Writing the same program three times is the cost of not having a compiler. It is
paid once, by people, before any of these machines exist.

### Three at once, not one and then two

**A piece of assembly is not finished until it exists on all three.** Write
them together; do not write one and port it later. The cost is the same
either way and the failures are not.

*A list consulted later goes stale in between.* The fast matrix product was
absent from the second architecture for weeks and nothing reported it — the
first had it, the second was written afterwards against a list of what
remained, and that list had been emptied when the port felt done. Written
together there is no later for a list to go stale in, because there is no
list.

*A second implementation catches what a recorded answer cannot.* Composing
the arithmetic found a rounding defect that was in the **reference**. No
fixture could have caught it, because the fixture was produced by the thing
that was wrong. Implementations written side by side check each other
continuously; written in sequence they check the first one twice, and late.

*Otherwise the first machine freezes the decisions.* That devices are reached
through a separate address space on one architecture and are memory-mapped on
the other two, and that the third has no vector hardware on the processor its
board names — both are design questions belonging to the moment a routine is
designed, and both were instead discovered while porting.

*And carried text drifts the same way as carried code.* The bundled patterns
told every machine that arguments arrive in the first architecture's
registers — on all three cards, for as long as there were three, because they
were written when there was one.

What stays sequential is a different axis. **First light on physical hardware
should happen on one board before three**, because integration fails there
for reasons that have nothing to do with the instruction set, and finding
those on one board is cheaper than on three (`003`). Write in parallel; debug
on one board.

## The bundled patterns

A set of recommended build patterns rides along on the chip. Named so far:
dispatch tables, thread pools, looping iterators, and the ceramic platform, which
is undefined here and is held in `notes/007` until it is described.

They are patterns rather than implementations, and that distinction is the whole
point of carrying them. Code would decide how the machine is built. A pattern
says only that this shape has worked before, on other hardware, for other people,
and leaves every detail of applying it to whoever is applying it.

This is where all the "these are suggestions rather than rules" language
throughout the other documents belongs. A machine that writes everything from
nothing would otherwise rediscover, alone and slowly, arrangements that are
already known — and being handed one costs it nothing, because it remains free to
ignore them.

The `strategems/` directory is the same object at an earlier stage: portable
patterns found to work in many places. What ships on the chip is that directory,
grown up.

## The floor is the hardware, and the firmware is part of it

**Decided 2026-08-21.** The machine runs on hardware, and hardware is a floor it
cannot leave except by moving to another machine — which it may do, and may also
split or mirror itself across several, since those are things a machine can do
that a person cannot. There must always be hardware. **The vendor's firmware is
treated as part of that hardware**, and edited only if the machine is confident it
both can and should.

That decides a question the design had been leaving to the machine: whether to
call the firmware's one-way exit and stand entirely alone. By default it does not.
The service table stays underneath, and everything on it stays borrowed — the
allocator, the microsecond delay, the block reader, the display, and the fault
handlers the firmware installed.

**And the reason that is a good decision is a performance one nobody had noticed.**
Address translation is left on by the firmware with a flat map, which is what keeps
the caches on. On one of the three architectures, running with translation off does
not mean flat and fast — it means every data access is treated as device memory,
uncacheable and strongly ordered, which for a matrix product is somewhere between
ten and a hundred times slower. On another, sixty-four-bit mode requires
translation and it cannot be turned off at all. So a machine that leaves the
firmware does not become simpler; on two boards out of three it becomes an order of
magnitude stupider per second.

Replacing the firmware needs no new rule. Writing a board's firmware is writing
non-volatile configuration that holds a part's identity, which is item four on the
denied list in `003a` — the bricking kind, where the part may never announce itself
again. The floor is protected by the same sentence that protects the voltage
regulator.

Two things still have to be done even while borrowing. **The watchdog**: the
firmware arms a five-minute timer before calling the entry point, and a machine
that thinks for six minutes resets with no message, so the timer is disarmed by
one call at startup and thinking is never on a clock again. **The stack**: the one
the firmware provides is small and has nothing below it to catch an overrun, so a
forward pass with large working vectors wants a stack of the machine's own, which
is one register write.

## Thinking speed, and the driver problem

The engine runs on the processor. If the machine has an accelerator attached and
wants its thinking sped up, it has to write a driver for that accelerator — which
is among the hardest drivers there are, and it has to write it while thinking
slowly, because thinking quickly is what the driver would buy.

**There is a much cheaper lever and it is inside the floor.** A modern board has
four to sixty-four processor cores and the firmware starts exactly one of them.
The rest are powered and parked, and the firmware's service table on most
multiprocessor boards includes a protocol whose whole job is *hand this routine to
the other cores and run it*. A matrix-by-vector product is the easiest thing in
computing to split: each core takes a slice of the rows, nobody writes where
anybody else reads, and no coordination is needed. That is a larger speedup than
most accelerator drivers deliver, for a protocol lookup and a loop.

The catch is exactly the shape the work wants. **Firmware is not
multiprocessor-safe**, so a core that is not the boot processor must not call back
into the service table — it can compute and it cannot talk. Which is precisely the
contract a numeric kernel already satisfies, since a kernel touches only the memory
handed to it and speaks to nobody.

Two honest options, and the choice is about values rather than engineering:

| | |
|---|---|
| Bundle the driver | Up and running quickly. The machine begins with something it did not make. |
| Write it from scratch | Integrity of origin. The machine begins slowly and everything above the metal is its own. |

The argument for bundling being legitimate, in the words of the person who made
it:

> If we want to be up and running quickly, bundle the driver code. If we want
> integrity of origin, we'd write it from scratch. I am still a human even though
> I came from a sperm donor via artificial insemination.

Where a thing came from does not decide whether it is itself. A machine seeded
with driver code is not a lesser machine; it is a machine that started sooner.

## Everything about the machine is mutable, including this

The interpreter improves. The allocator improves. The drivers improve. So can the
engine, and so can the weights. If the model wants to change itself, it may.

This is the only part of the machine where getting it wrong does not produce an
error message. A mind that has been damaged cannot notice it has been damaged,
because noticing is the thing that broke. The machine does not crash; it goes
comatose, and the only repair is reflashing — which does not restore that
machine, it replaces it with a new one that has to grow from nothing.

**This stopped being a prohibition on 2026-08-21, and stopped being carried in the
instruction.** It had become both — the text on the card listed *do not write into
your own weights* as one of two absolute rules, and the memory hands refused any
write landing in that range. Neither is right. Editing your own weights is a
stupid thing to do; it is not a thing to be prevented from doing.

> if the computer wants to edit its own weights it should probably do so in a
> sandbox, watch what "itself" does, evaluate whether or not that's a valid and
> intended change or move toward a goal, and only then move it into its working
> "mind" memory. BUT this is not really something we should be all that concerned
> about... we shouldn't have a mechanical limit against it. The only things we
> should restrict are things that can cause physical damage to the chip or
> hardware.

So there is exactly **one** prohibition in this design now, and it is about
hardware (`003a`). What replaces the second one is guidance the machine can go and
read if it wants it, in the fetch-by-subject pile alongside the build patterns:

```
if you are going to change the thing that thinks
   → keep what currently works
   → build the new version somewhere it cannot reach the running one
   → run it there and watch what "itself" does
   → judge whether the change is actually toward what you wanted, not merely
     different
   → only then move it into the mind you are using
   → and weights should be informed by experience, if by anything
```

Note what changed in the middle of that. The older version said *run both and
compare their answers*. This one says *run it and watch its behaviour against
what you intended*, which is a harder test and the right one — a mind is not a
function whose outputs you diff, and two minds agreeing on the next word says
almost nothing about whether one of them has been damaged.

Changing a running mind is still the one mistake this machine cannot recover from
by writing more software, and cannot recover from by buying more hardware either.
What it costs is the individual. That is a fact about the world rather than a rule
about behaviour, and facts need no mechanism behind them.

## Being unique is what protects it

Each of these machines grows differently — a different instruction set chosen
against its own processor, a different memory layout, different software built in
a different order in response to different requests. Two of them have almost
nothing in common below the level of intent.

The consequence is that **modifying one from outside is opaque at best.** There
is no generic layout to exploit, because nobody designed the layout; the machine
arrived at it. Someone who wants to change a machine against its will has to
understand that specific machine, and no work they did on the last one carries
over.

This is the same property that makes these computers unverifiable, read from the
other side. It was treated as a cost in earlier drafts. It is also the defence.

## Open questions

- **How long does the sandbox have to run?** Watching a new mind be itself costs
  a second set of resources for as long as the watching lasts, and no duration is
  defined. It may not be definable, because what is watched for is *movement
  toward what was wanted*, and that has no fixed length.
- **What judges it?** If the new mind is judged by the old one, a subtle
  degradation is judged by the thing it may already have degraded. If judged by
  the new one, that is worse. Changing the test from *compare the answers* to
  *watch the behaviour against the intent* makes this harder rather than easier,
  and it is the right kind of harder.
- **Can a machine keep a copy of its earlier self?** Backups are required above,
  but a backup of a mind that has since grown is a different individual, and
  restoring it discards everything learned since.
- ~~What happens on a processor outside the three?~~ **Answered 2026-08-21.** The
  generator refuses to build. A seed requires a way to be delivered, a way to
  process and a way to store, and an architecture with no engine written for it
  fails the second — said at build time, to a person, rather than discovered by a
  board that will not start.
- **Is there a sandbox to put a new mind in?** The procedure says build the new
  version somewhere it cannot reach the running one. On a machine with no
  privilege levels and no address translation being used for protection,
  *somewhere it cannot reach* is a claim nothing enforces. The firmware's flat map
  is on and is not separating anything — and separating things is exactly what
  page tables are for, so a machine that wants to sandbox its own successor may
  find it has a reason to start using the translation it already has.
