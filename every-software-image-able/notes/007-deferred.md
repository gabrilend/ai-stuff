# 007 — Deferred

Things worked out in conversation and then explicitly set aside. They are written
down so that they are not rediscovered from scratch later, and so that the line
between "decided" and "not yet" stays visible.

Nothing here is rejected. Everything here is waiting on the machine underneath it
running first. The stated focus is: **actually making a system that does whatever
it needs to.**

Each section names where it was said. Line numbers refer to
`llm-transcripts/jul-31-26-through-aug-1-26.md`, so that un-parking one of these
starts from what was actually meant rather than from this summary of it.

---

## The canvas

*Lines 555 and 1309. It began at line 454 as "there's no desktop, it's only
windows," and was revised into a desktop two messages later.*

An infinitely scrolling shared space, described as *rooms, but with zoomed
concern* — go low and you see what relates to you specifically, go high and the
reach and breadth widen. Terminal windows and such, arranged loosely and vaguely
geographically around each other rather than in a list. Everyone shares their
computer space, so everyone can contribute to larger wholes.

> The trick is to make it connectable, reachable, and interestingly dynamic.

Held with many ideas already about how to do it beautifully.

**Why it is parked.** It is a display for a machine that does not yet run, and
the terms in it — windows, layers — were being built on faster than they were
being defined.

**What was settled before parking.** That the arrangement is a loose geography
rather than a causal graph. Things sit near each other because they are related,
not because one caused the other. This matters because a geography stays put and
can be learned, where a layout that rearranged itself every time causality
changed could never be navigated from memory.

**What un-parks it.** A machine that can draw, and a request arriving from more
than one person.

---

## The people

*Line 453. Set aside at line 1309.*

The machine takes in images of a person's life and designs itself with them in
mind, being guided as it goes.

**Why it is parked.** *Don't worry about the people, the people will use this
kind of computer as they please.*

**Worth keeping from it.** This was, for a while, the answer to how an unbounded
set of imaginable software fits on a bounded drive — *imaginable for this person*
is finite in a way that *imaginable* is not. That answer has since been replaced
by a better one that needs no person at all: capability condenses (`005`). Both
are true, and only one of them is load-bearing.

There is an unanswered privacy question sitting inside this, held in `008` as
question 6.

---

## The table

*Line 625. The wish at line 345 — "I wanna raid Razorfen Kraul" — arrived nearly
three hundred lines earlier, in the middle of a paragraph about error counters,
and belongs here.*

An ongoing game, run under old-school rules, with a model as referee updating
world state from what players do. Parties of models that talk amongst themselves
and sometimes go on adventures with human narrators. Sometimes all humans. Rarely
all machines — usually only when spectated, or when certain characters are
beloved.

**Why it is parked.** Same reason as the canvas: it runs on the machine, it is
not the machine.

**What was settled before parking.** Two things worth not re-deriving.

The rules split cleanly along a line that matters. The *procedures* are
clockwork — ten-minute turns underground, a torch burning down over six of them,
a check for wandering monsters every second turn, reaction and morale resolved on
two dice against a table. Those are code, and they are literally dispatch tables.
The *rulings* — deciding what happens when someone tries a thing the book never
anticipated — are the whole reason this style of play works, and they are what a
model is for. Code keeps the clock; the model answers the question.

And the dungeon turn is the same instrument as the countdown in `002`: spend
down, cross a threshold, something intercedes and demands attention. Two
unrelated parts of this design want the same clock.

The condition for a machines-only session being *spectated or beloved* is a
scheduling policy: attention is what buys compute.

---

## Mail between machines

*Line 562.*

Sending things back and forth over the network, built into every system as
fine-tuning on the suggested models, at least until people train their own for
this kind of seed.

**Why it is parked.** Explicitly: *we don't have to worry about that yet.*

**The hazard to remember when it un-parks.** The wire format would live in the
weights rather than in a document. Both ends being models means they can agree
without a specification — and also that neither can *check* that they agree,
because there is no third thing to validate against. Two differently-tuned
machines drift silently rather than failing loudly. The status colourshape is the
natural fix: mail that carries its aspect lets a mismatch arrive as a
wrong-coloured reply instead of as quiet nonsense.

---

## Ring buffers, and cheap backward reach

*Line 1142.*

Building in a soramech way, so that previous values can be read out of buffers
that have been released but not yet overwritten — stepping back at least a couple
of seconds from anywhere in a program, and on error, ceasing to hand out work in
the thread pool and working backward from there.

**Why it is parked.** *That's like, a much later concern. We don't need to worry
about that for this project, which is in its infancy.*

**What is captured in the meantime.** The mechanism is summarised in `006` under
walking backward, including the one detail that makes it trustworthy: a lap
number stored beside each slot, so a reader can tell a genuinely old value from a
slot that has already been reused.

---

## Deployment, when there is something to deploy

*Pointed at, line 625.*

The civics project at `/home/ritz/programming/civics/algorism/` has this worked
out already, and most of it transfers.

A recipe says what the box is; a board description says what it runs on; neither
names the other, so supporting new hardware is a description file and no code.
They hash together into a manifest, and the manifest's hash is the image's
identity. Nothing secret is ever built in — one image goes onto a thousand cards
and each one generates who it is at first boot.

That last move is the same ceremony as this project's, one level lower. That
image ships without knowing **who** it is. This one ships without knowing **what**
it is.

**Where it does not transfer.** That project refuses to ask anyone to trust a box
they cannot verify, and verification there means reproducing a hash. A machine
whose purpose is to rewrite its own floor diverges from its image in the first
minute and never converges back, so there is no reproducible hash of it
afterward. Verification has to become "here is everything I did between the image
and now" rather than "here is a number matching a reference." That is question 5
in `008`.
