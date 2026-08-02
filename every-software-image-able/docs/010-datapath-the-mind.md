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

## Thinking speed, and the driver problem

The engine runs on the processor. If the machine has an accelerator attached and
wants its thinking sped up, it has to write a driver for that accelerator — which
is among the hardest drivers there are, and it has to write it while thinking
slowly, because thinking quickly is what the driver would buy.

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

So this is the second place in the design where the procedure is written down
rather than delegated (`strategems/009`):

```
before changing the thing that thinks
   → keep a backup of what currently works
   → build the new version alongside, not in place
   → run it in parallel and compare, while the old one is still thinking
   → switch only after the new one has been watched working
   → never modify what is currently running
```

Changing a running mind is the one mistake this machine cannot recover from by
writing more software, and cannot recover from by buying more hardware either.
What it costs is the individual.

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

- **How long does parallel running have to last?** Comparing a new mind to an old
  one requires both to be thinking, which costs twice the resources, and no
  duration or agreement threshold is defined.
- **What compares them?** If the new engine is judged by the old one, a subtle
  degradation is judged by the thing it may already have degraded. If judged by
  the new one, that is worse.
- **Can a machine keep a copy of its earlier self?** Backups are required above,
  but a backup of a mind that has since grown is a different individual, and
  restoring it discards everything learned since.
- **What happens on a processor outside the three?** Named above. The seed cannot
  bootstrap itself there, and nothing says whether such a machine should refuse
  to start or wait for help.
