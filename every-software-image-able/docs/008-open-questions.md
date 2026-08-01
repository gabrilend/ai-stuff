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

**10 — Where does anything permanent get written?**
The medium the image was delivered on. It is the one place guaranteed to exist at
boot, because the machine is running from it. Enumerating attached storage is
therefore an early concern rather than a later one: the machine searches, finds a
better place to keep things, and moves them there. The delivery medium may be
removable, so finding somewhere better is a matter of survival rather than of
tidiness. `003`.

**9 — What mediates between altering and condensing?**
The machine does. No arbitration rule is designed, and designing one would be the
wrong move: *the system can build itself as it pleases.* The four rungs, the
dispatch tables and the refusal to hold two copies of the same knowledge are
patterns that keep proving useful, not laws the machine is bound by. `005`.

**14 — What if the delivery medium is read-only?**
It does what it can with what it has — probes, and holds what it finds in its own
working memory until it finds somewhere to unload it. Memory is writable
regardless of whether the boot medium is, so a read-only medium prevents keeping
rather than thinking. The real cost is in `003a`: the intent note before a
dangerous experiment cannot be written, so a machine that dies exploring learns
nothing from it and rediscovers the same lethal register on every boot. `003`.

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

**5 — what verification means after self-modification.** It has just become live
rather than distant, because the three ways an image might be produced (`003`)
are three different answers to how much a second machine can be expected to
resemble the first. An image built for known hardware can carry descriptions and
be checked against them. An image generated from supplied details can be
reproduced by anyone with the same details. An image that feels its way from
scratch can be reproduced by nobody, including itself.
