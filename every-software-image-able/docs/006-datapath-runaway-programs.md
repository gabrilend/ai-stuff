# 006 — Datapath: Programs That Will Not Stop

What happens when the machine runs something it wrote and that thing never comes
back.

## What used to be here, and why it is gone

**Removed 2026-08-21.** This document used to describe a status system: every
program emitting three numbers after everything it did — an aspect shown as a
colour and a shape, a per-program code, and a magnitude on an axis with fifty as
ordinary — displayed on lamps, looked up through a dispatch table each machine
built for itself, with the extremes of one particular code stopping the machine and
starting a walk backward through its own history.

It was a nice picture and it was **complexity nothing needed.**

> I think we should remove the post-code system from the design entirely, it seems
> a little arbitrary and out of place. Like I like the vision of it, but... we want
> to make minimal software that just works, and this is introducing something that
> is complex for no reason.

It also did real damage on its way out, which is worth recording because it is the
argument for the removal rather than a footnote to it. The magnitude was two digits
with fifty in the middle, and it was *also* being used to count loop iterations —
so a program was declared a runaway after fifteen turns of a loop. Copying a hundred
bytes. Summing twenty numbers. That defect existed because one mechanism was being
asked to serve a picture, and the picture was the part nobody needed.

What is kept from it is at the bottom of this page: recording what arrived from
outside, so a machine can walk back through what happened. That mechanism never
depended on the display.

## What replaces it

Threads, a clock, and a tool call.

```
the mind runs on its own thread
programs the machine wrote run on other threads
the machine times each one
anything taking longer than it should be taking gets stopped
```

**The mind is never the thing that hangs.** A program spinning forever on another
core does not stop the machine thinking; it occupies a core. The machine notices by
looking at the clock, not by having instrumented the program, and it decides what to
do about it the way it decides anything else.

That is the whole design, and its virtue is that there is nothing to build. No
emissions inserted at loop back-edges, no shared cell, no threshold, no vocabulary
of codes, no lookup table, no lamps.

**It is also why single-threading anything is not ideal** (`010a`). This
arrangement is not an optimisation that multiple cores happen to permit — multiple
cores are what make it exist. On a board with one processor the mind and the program
share it, and a program that will not stop takes the machine with it.

## Stopping something on a machine with no interrupts

**Who decides is settled: the machine does, with a tool call.** Nothing watches a
clock on the machine's behalf and nothing has a threshold. The machine looks at how
long something has been running, decides that is longer than it wants to wait, and
asks for it to be stopped — the same way it asks for anything else.

**Whether the seed carries the means is settled too, and the answer is that it
already does.** The thing that runs what the machine wrote gives every program an
allowance and counts what it spends, so a program that will not stop is stopped
without needing a core to spare or an interrupt to exist. That works on a board with
one processor, which is the case none of the arrangements below cover.

> Is this something that is crucial to the operation of the system? If not, then let
> the system build it. If so, then build the interrupts. But, when do we interrupt?
> Dunno. When the LLM tool calls it to.

So real interrupts are **the machine's own project rather than the seed's**, and the
rest of this section is what it will find when it takes the project on.

A thread spinning on another core cannot be asked to stop, because asking requires
it to be listening and it is in a loop that does not check anything. There are three
positions and they cost very different amounts.

| | What it takes | What it costs |
|---|---|---|
| **Leave it spinning** | Nothing at all | One core, until the machine is restarted. Note the program as bad and never run it again |
| **Have it check** | The thing that runs a program gives it somewhere to look, and it looks between iterations | Cooperation, which the machine controls because it wrote the program — but a program with a loop the compiler did not recognise never looks |
| **Interrupt it** | One core signals another: on the first architecture through the interrupt controller, on the second through the software-generated interrupt of the general interrupt controller, on the third through the core-local interrupter | Real driver work, and interrupt handlers, which this machine otherwise does not have |

**Leaving it spinning is a better answer than it sounds.** On a board with sixteen
cores, a runaway costs one sixteenth of the machine and nothing else — no hang, no
crash, no lost work. The machine writes down that the program is bad, stops giving
it anything, and carries on with fifteen cores. That is survivable indefinitely, and
it is the only one of the three that needs no code at all.

## A board with one core

**The generator builds for it and says nothing.** Not a refusal, and not a warning
either.

The threads-and-a-clock arrangement above needs two processors — one for the mind,
one for whatever might not come back. A board with one has neither the arrangement
nor any way to be told it does not have it, and the decision is that **nobody tells
it.**

That sounds harsher than it is, for three reasons.

**The machine can find out.** The number of processors is enumerable, from the
firmware and from the board, in the same step where everything else about the body is
enumerated. Saying nothing is not concealing anything — it is declining to pre-chew a
fact the machine is standing on top of. This is the second place in the design where
a discovery is deliberately left underived, and it takes the same reasoning as the
first: a machine that works something out understands it, where one that was told has
been handed another rule (`301`).

**The machinery that makes a single core survivable does not need a second core.**
Arm the board's reset timer, do the risky thing, clear the timer — a hang resets the
board rather than ending the machine, and the intent note written first tells the next
boot what happened. None of that wants a spare processor. So a careful machine on one
core is in a worse position than a careful machine on sixteen, and not in an
unrecoverable one.

**And the population it would have excluded is the one that most wants this.** Small
boards, old machines, embedded things — a card that turns them into something is
worth more there than on a workstation with sixteen cores to spare. A requirement of
two would have been drawn to fit the machinery rather than the purpose.

What it costs, stated plainly: a machine on one core that runs something which never
returns, without having armed the reset timer, is stopped until a person power-cycles
it. It will then find its own note, if it wrote one.

## Timing, which needs a clock

**The clock is whatever the floor turns out to offer, and the machine finds out by
looking.** Firmware services are part of the body and are enumerated with the rest
of it (`003`), so if the firmware has a timer then that is the clock, and nothing
here needs to specify which one or how it is read.

> If the firmware includes a clock, well, there's your clock. If not, then we'll
> have to find a different way to measure time.

The different way, if it comes to that: every one of the three architectures has a
counter the processor increments on its own, readable without anything being set up.
It counts cycles rather than seconds, so it says *how long* only once the machine has
worked out the rate — usually by timing it against something it already trusts, which
would have been the firmware's timer if there were one. A machine with neither has to
calibrate against something physical it can observe, and that is genuinely harder.

Two numbers per program, then: **when it started, and how long it should take.** The
second is a guess, and the machine that wrote the program is the one making it.

## The other thing that will not come back: a call that hangs

A program that will not stop is the loud version. The quiet version is **a tool call
the machine made that never returns**, and it is worse, because the loop is not
running while a call is being carried out. It handed control to the thing doing the
work and is waiting. Nothing times out, nothing errors, and nothing notices — because
noticing happens between turns and the machine never reaches the next one. The mind
does not crash or spin. It stops, permanently, mid-sentence.

**Most calls cannot do this.** Arithmetic on memory the machine already owns comes
back or faults. The ones that can are the ones that reach outside: a device that never
answers, a disk that has spun down, a firmware path with a bug in it. So the
catalogue of hands should mark which ones reach outside the machine, and only those
need care.

**And the care is cheap, because the ordering makes a clock available first.** A
clock is available at the first instruction, before anything is enumerated (`003`,
step two and a half), so a call that is *waiting on something* can always be bounded.
What a clock cannot bound is a call the processor is stopped inside — and for that
there is the board's reset timer, armed briefly around the attempt, with the intent
written down first so the next boot knows what happened (`003a`).

Which leaves one honest gap: **a hand that hangs while the machine has no spare core
and no note-writing storage yet.** That is the pre-move-in window, and it is already
the window in which nothing can be kept and nothing can be reported. It is short by
design and it is short for this reason too.

## What is kept: walking backward

Independent of everything removed above, and worth keeping because it is cheap and
because nothing else recovers the reason for a failure.

To step backward through a moment, that moment has to still exist, and it cannot be
rebuilt from the current state because the current state is what lost the
information.

The rule is to **keep track of changes, but only when necessary to reconstruct** —
and "necessary" has a precise meaning. Every derived value is left out, because
re-running the same instructions with the same inputs produces it again for free.
What cannot be re-derived is **anything that arrived from outside the machine's own
reasoning**: a key pressed, a byte read from a device, a number drawn at random, the
moment a piece of hardware answered.

Replay is then: run the same code again from the start, and every time it reaches
outside itself, hand it the recorded value instead of asking the world again. The
machine walks the identical path, into the identical failure.

The cost difference is large. A photograph of memory costs whatever the machine is
holding, per moment. A list of things that arrived from outside costs bytes per
moment, because a machine spends nearly all of its time computing rather than
receiving.

**The machine's own thinking belongs on that list.** Nearly all the software here is
built by a model, and a model's output is a weighted random choice among the likely
next words. That choice is a number drawn at random, which the rule already says to
write down. Recording the draws makes the machine's own reasoning replayable
alongside everything else, so a walk backward can step through decisions the model
made and not only through instructions a program ran.

The non-determinism is not a defect to be engineered out. **A single token is a
weighted random choice; a paragraph is not random at all.** Two machines diverge from
the first token and it does not matter, because what matters is the choices going
forward rather than whether both picked the same word.

**A cheaper reach, deferred.** Ring buffers give a short window backward for nothing:
memory that has been released still physically holds its values until something
overwrites them, and a buffer written in a circle keeps the previous lap intact ahead
of the write cursor. How far back that reaches is buffer length divided by write
rate. Each slot needs a lap number beside its value, so a reader can tell "this is
the old value I wanted" from "this slot has already been reused." That belongs to a
later stage and is held in `notes/007-deferred.md`.

## What is kept: co-evolving forward

Going back to a point and moving forward along a different branch. Once there is
both a path that happened and a state that was wanted, curve fitting and similar
tools work out what would have had to be different to reach the intended state.

That imposes one requirement, cheap now and expensive to retrofit: **values must
carry where they came from.** Fitting returns a number — this should have been nearer
seventy — and that is unusable unless something knows which code produced the value.
An earlier draft said the aspect index riding alongside every status was the right
size and shape for this; there is no aspect index any more, so whatever carries
provenance has to be built for the purpose, and it is one identifier per value rather
than a display.

When the fit has nothing to vary, the answer is not a wrong number. It is the
discovery that the code needed does not exist, which is the trigger for rung three
(`005`).

## Open questions

- **Which of the three does a machine actually pick?** Not the seed's decision —
  the seed carries the cooperative one, which works everywhere, and the machine
  builds anything better if it wants a core back. What a machine chooses, and
  whether it bothers, is the first observation nobody has made yet.
- **Who decides how long a program should take?** The machine that wrote it, with
  nothing to base the guess on the first time. A program that legitimately runs for
  an hour and one that hung look identical for the first fifty-nine minutes.
- ~~What happens on a board with one core?~~ **Answered 2026-08-21: the machine
  finds out.** Below.
- **Which hands reach outside the machine?** The care above is only worth paying for
  calls that can hang, and nothing has gone through the catalogue marking which
  those are. It is a property of each hand rather than a decision about the design.
- **What does a machine do with a program it had to stop?** It knows the program is
  bad and it wrote the program. Whether that is a note, a deleted capability, or the
  trigger for rewriting it, is undecided.
