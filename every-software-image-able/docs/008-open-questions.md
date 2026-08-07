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

**5 — What does verification mean after self-modification?**
It is not a concern of this project, and the question arrived here from
elsewhere — the civics work next door turns on never asking anyone to trust a box
they cannot check, and nothing here turns on that.

What is true and sufficient: **a stranger can verify one of these machines as
well as its owner can.** Nobody has privileged standing. That is a statement
about equal access, not a duty to make checking easy, and no part of the design
should be shaped around making it easier.

Machines diverge from the first token, because a model's output is a weighted
random choice. That is expected and fine.

**12 — How many different ways are tried before moving on?**
The machine decides. Same answer as 9, and the same reason:

> Let's delegate it to the computer — dear computer, try and solve this problem,
> do so as you please. That sounds better to me than "you must show up at 9 and
> leave by 5."

`strategems/009-ask-do-not-schedule.md`.

**15 — When does the interpreter get written?**
Among the first things, before the storage driver, so that the driver can be
bytecode rather than more assembly. Its first operations are the basic hardware
ones — moving values between registers and memory. `002`.

**16 — What runs the model?**
An engine carried on the chip alongside the weights, written in assembly once per
architecture in modern use, with the boot selecting the matching one. It also
applies the model's results and handles basic tool calls. `010`.

**17 — Can the machine rewrite the thing that thinks?**
Yes. Everything about the machine is mutable, this included. It is the second and
last place where a procedure is written down rather than delegated, because a
damaged mind cannot report that it is damaged. `010`, `strategems/009`.

**18 — Are the weights ever changed?**
Yes. If the model wants to change itself it may. Change from outside is possible
and deliberately opaque: each machine grew differently, so there is no shared
layout to work against and nothing learned from one carries to the next. `010`.

**19 — What does the machine do when growth runs out of room?**
Whatever it wants. Keep rewriting itself, play games, sit in idle reflection,
talk with friends, mine coins. There is no waiting state; a request interrupts a
life rather than waking something suspended. `005`.

**21 — When can the card come out?**
Two milestones, both testable. Once the machine is running from memory with
nothing still being read off the card, the card can be removed — nothing needs it.
Once the machine can boot itself from disk into memory, it can be turned off and
on again. They are different moments, and a machine in the gap between them exists
only in volatile memory with nothing able to recreate it. `003`.

**20 — What belongs in the seed, and what does the machine write?**
Not "is it hard" and not "is there one correct way." **What does being wrong
look like.**

If wrong looks like a wrong answer, the machine can see it, say so, and try
again. Leave it to the machine. If wrong looks like **silence** — a jump into
weights, a call whose offset is zero and is therefore a call to itself, a
return to an address that was never a return address — then the machine
cannot see it, cannot report it, and does not get a second attempt, because
there is nobody left to attempt.

The seed carries the second kind. Not to save the machine work, and not
because we know better: because a machine that spins forever from an
instruction we wrote never gets to disagree with us about it.

This is why the arithmetic is carried even though a machine could derive it —
the order of addition *is* the answer, and getting it wrong is a wrong
number, but getting the calling convention around it wrong is silence. It is
why the driver (`107`) is written down and the allocator is not. And it is
the argument for the interpreter being the layer worth reaching quickly:
below it a bad address is unobservable, because checking would need a
memory-management unit this design deliberately does not have; at it, the
check is nearly free, because the loop is already holding both numbers
(`002`). The interpreter is the lowest layer at which "that was wrong" is
something that can be said rather than something that kills you.

**13 — What makes the machine want something?**
Nothing internal. Requests arrive from arbitrary sources, and the machine builds
the capability to accept input from as many sources as its body provides — so the
set of possible requests is a function of the hardware map. `003`.

---

## Open, and blocking

**Two, added 2026-08-07.**

**23 — How does a driver find the image's regions on a real card?**

The builder lays down five regions on a raw medium — the waking code, the
engine, the model, the text, the carried randomness — each on a block
boundary, and it refuses to build if those offsets disagree with what the
engine expects (`502`). Every board this project has boots through UEFI, where
firmware opens **one file** on a FAT filesystem and hands over a pointer to
that file's contents in memory. The other four regions are not at a knowable
distance from anything the driver can see.

The payload that reached first light on 2026-08-07 carries the model, the text
and the randomness inside itself, sixty-four kilobytes past its own first
instruction, and reaches each by measuring from where it is standing. That
works, it is honest, and it is what `029` already does for the memory report.
It is also not what a card with a hundred-megabyte model would do, because a
payload is loaded whole and a model that size should be read as it is needed.

The alternative is for the machine to open the medium it booted from and read
the regions by offset — which is a storage driver, and `107` lists storage
driver under the machine's job rather than the seed's, on the grounds that its
failure is a wrong answer rather than silence. That reasoning still holds, and
it leaves a gap: the machine cannot write a storage driver until it can think,
and on this arrangement it cannot think until it has read the regions.

It blocks `502`, which cannot close while the only image it has produced
contains no engine, and it is the last structural question between here and a
card that boots.

**24 — Is the tokenizer's preparation paid at startup or at build time?**

Resolving one merge rule means finding the token whose text is two other
tokens' texts joined. There is no hash and nothing to build one with, so it is
a walk over the vocabulary per rule: merge count times vocabulary size times
token length. On the fixture that is nothing. On a real model with thirty
thousand of each it is on the order of tens of billions of byte comparisons,
once, before the machine says its first word.

`024` says the token table is "read once at startup to build whatever lookup
the engine wants," which settles it — but that sentence was written before
anybody had counted the comparisons. The alternative is for the builder to
prepare the tables and carry them on the image, which trades a wait at every
boot for a new seam between the builder and the engine's internal layout, and
takes away the machine's ability to re-prepare after it changes its own
vocabulary.

Nobody has measured it on a real model, and the honest form of this question is
that it should not be answered until somebody has.

---

**One, added 2026-08-04.**

**22 — Where does the operation table live?**

The interpreter the machine writes is a loop that fetches a number, looks it
up in a table, and runs the matching operation (`002`). That table is the
whole of the machine's instruction set, and it is also the door — the list of
things a program may ask for is the same table the loop reads, because there
is no privilege level here to put a separate list behind.

If the table lives in **writable memory**, a running program can add a row,
and the machine extends itself while alive. If it lives in the **instruction
stream**, adding an operation means rebuilding the interpreter, which means
the machine cannot learn a new trick without stopping.

`002` already asks whether a program may add an operation, and lists it as one
of that document's open ones. It is promoted here and marked blocking because
it is not really a question about permissions — it is a question about where
one array goes, it is answered by the first machine that writes an
interpreter, and it is answered *by accident* if nobody decides it
deliberately. Whichever way the first machine happens to lay it out becomes
what that machine is, and this is the first minute of its life.

It blocks nothing that is being built right now. It blocks the interpreter,
and the interpreter is the machine's own first act.

---

Every other question that was stopping work has an answer, and four of them
were answered the same way — by handing the decision to the machine rather than
writing a rule for it (`strategems/009`).

The one term still used without a definition, the ceramic platform, is held in
`notes/007` rather than here. It belongs to the bundle of recommended build
patterns and nothing structural waits on it.

The per-document questions below are still open. They are not blocking, because
none of them changes the shape of something already written; they are the things
whoever writes the code will meet.

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
| `002` interpreter | 2 | What decides that an operation is worth a row? Any sequence used often enough could become one, and nothing measures this |
| `003` bootstrap | 3 | A machine where nothing is operable cannot report that nothing is operable |
| `003a` exploration | 4 | Absence of response is what a destroyed device, a busy device, and an unpowered device all look like |
| `004` compilation | 3 | What draws the picture before there is anything to draw on? |
| `005` four rungs | 4 | With requests from arbitrary sources, who is left to say whether the built thing was what was wanted? |
| `006` status | 4 | A machine-wide magnitude moved by whichever program is running reports the busiest tenant, not the machine's condition |

---

## Next

**The roadmap.** It was held back because four unanswered questions could have
moved the phase boundaries. They are answered, and three of them dissolved into
"the machine decides," which removes rather than adds structure. Nothing is
waiting on a decision now.

After that, the issue files — and the thing to be careful of while writing them
is that a ticket describing how the machine must be organised is the same mistake
as a schedule. State what is wanted and what it costs to get wrong; leave the
approach to whoever is holding the problem.

**Both are done, and 2026-08-04 added a third thing to be careful of.** A
progress note that says a phase is complete has to say complete *at what*.
Three phases reported done on a reading of "exists" that did not distinguish
between code which runs on the chip and code which proves that code. Every
individual claim in them was true; the sentences summarising those claims
were not, because they added two kinds of thing together.

The correction is in the phase notes for one, two, three and five. The
general form is worth keeping here: **a summary that aggregates across a
distinction its rows depend on will be wrong in a way none of its rows are**,
and it will stay wrong for as long as people read the summary instead of the
rows. Which is what summaries are for.
