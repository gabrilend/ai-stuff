# 008 — Open Questions

Every question this design has raised and not closed, in one place, so that none
of them are buried at the end of a document nobody opens.

The rule governing this file: **an open question must be asked and worked through
one-by-one before the work holding it can be called complete.** A task with an
unanswered question in it is in progress, not finished. Gather as many as can be
found; a document nobody has revisited is a document whose questions have gone
stale, and stale questions are worse than none, because they look answered.

Each document in `docs/` ends with its own list. This file holds the ones that
cross documents, plus the running status of everything asked in the dialogue that
produced the design.

---

## Answered

**1 — What is measured when the compiler picks the best of several ways?**
There is no fixed metric. Many parameters, and the one that matters is whichever
is holding the machine back. Nothing is measured at all until a demand arrives
from elsewhere needing performance of a particular kind, and the kind names the
axis to vary along. `004`.

**2 — What earns the centre of the canvas?**
Nothing. It is vaguely geographically oriented, a loose collection, not a causal
graph. `notes/007`.

**4 — Does the machine probe hardware, or read descriptions of it?**
Both, and in that order. Descriptions can be found for essentially any modern
computer, but the machine needs the capability to act as though it has none, and
must be able to fall back to a description only once it can confirm the
description is for this exact part. Exploration proceeds one change at a time, and
never into the registers that destroy hardware. `003a`.

**11 — What is the second number in a status?**
Not a second gauge. A status is an aspect, a code, and a magnitude. The code is
per-program and can mean whatever that program needs; the magnitude is a single
axis with fifty as its zero point, where high and low both mean attention should
be given and nothing more. Definitions are looked up through a dispatch table the
machine builds from scratch, returning each code's meaning as a markdown table,
so no two machines have the same one. `006`.

**13 — What makes the machine want something?**
Nothing internal. Requests arrive from arbitrary sources, and the machine builds
the capability to accept input from as many sources as its body provides — so the
set of possible requests is a function of the hardware map. `003`.

---

## Open, and blocking

**5 — What does verification mean after self-modification?**
A machine that rewrites its own floor diverges from its image in the first minute
and never converges back. There is no hash of it afterward that anyone can
reproduce. Either the machine keeps an account of everything it did between the
image and now — which makes that account the only evidence of what it is — or the
question is answered by giving it up, and these machines are simply not verifiable
by anyone who did not watch. Blocks: anything to do with shipping more than one.

**9 — What mediates rungs two and four?**
Condensing makes space cheap and modification expensive; the denser the machine
gets, the more hangs off each remaining piece and the harder every future change
becomes. They pull against each other permanently. Nothing arbitrates. The same
tension shows up one layer down in the interpreter's operation table, where every
new capability lengthens the table read on every instruction fetch. Blocks: `005`
rung four, `002` table growth.

**10 — How many stores are there, and what is in them?**
Three things now want somewhere permanent to be written: the intent recorded
before a dangerous hardware experiment (`003a`), the outside-arriving values
needed to replay a moment (`006`), and the hardware map produced before storage
works (`003`). They may be one store or three. Deciding late means retrofitting
the format of everything already written. Blocks: `003`, `003a`, `006`.

**12 — How many different ways are tried before moving on?**
The machine tries several approaches to one constraint before it is allowed to go
work elsewhere. That rule cannot ping-pong between constraints, but it can grind
on one whose space of approaches is empty. The number that stops the grinding is
unchosen. Blocks: `004`.

---

## Deferred with their subject

These are real questions, parked because the thing they are about is parked
(`notes/007`). They should not be answered before the machine underneath them
runs.

| # | Question | Waiting on |
|---|---|---|
| 2a | What places a new window on the canvas? "Loose" describes the result, but some rule produces it | the canvas |
| 3 | Are layers chosen by whoever is looking, or assigned by whatever made the window? | the canvas |
| 6 | Where do a person's life images live, and who can encounter them? | the people, and 3 |
| 7 | Does the game's world state share the machine's store or get its own? | the table, and 10 |
| 8 | What is "beloved" measured as, and can a beloved character outlive the machine that ran it? | the table |

---

## Raised by the documents themselves

Held in full at the end of each document; listed here so the count is honest.

| Document | Open | The sharpest one |
|---|---|---|
| `002` interpreter | 3 | Can a running program add an operation, or must the interpreter be rebuilt to learn a new trick? |
| `003` bootstrap | 3 | A machine where nothing is operable cannot report that nothing is operable |
| `003a` exploration | 4 | Absence of response is what a destroyed device, a busy device, and an unpowered device all look like |
| `004` compilation | 3 | What draws the picture before there is anything to draw on? |
| `005` four rungs | 4 | With requests from arbitrary sources, who is left to say whether the built thing was what was wanted? |
| `006` status | 4 | A machine-wide magnitude moved by whichever program is running reports the busiest tenant, not the machine's condition |

---

## Next

**10 — how many stores are there.** Three separate things now want somewhere
permanent to be written, and they were arrived at from three unrelated
directions: the intent written before a hardware experiment that might not
return, the outside-arriving values needed to replay a moment, and the hardware
map that exists before storage works. If they are one store it needs a format
that suits all three. If they are three, the machine has three things to build
and three things that can be lost independently. It is asked next because the
cost of deciding it late is rewriting the format of everything already written
by then.
