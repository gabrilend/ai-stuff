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

## 2026-08-21 — the day the mind turned out to be closed

Fifteen questions asked and answered in one sitting, and two of them invalidate
things that had been settled for weeks. They are kept together rather than sorted
into the list below, because several of them only make sense beside each other.

**30 — May the machine change its own weights?**
Yes, and **nothing mechanical stops it.** This had become a prohibition in the
shipped instruction and a refusal in the memory hands, and both were wrong. It is
a stupid thing to do; it is not a thing to be prevented from doing.

> if the computer wants to edit its own weights it should probably do so in a
> sandbox, watch what "itself" does, evaluate whether or not that's a valid and
> intended change or move toward a goal, and only then move it into its working
> "mind" memory. BUT this is not really something we should be all that concerned
> about... we shouldn't have a mechanical limit against it.

The ceremony survives as **guidance the machine can go and fetch**, not as text on
the card, and its shape changed: it used to say *run both and compare their
answers*, and it now says *run it in a sandbox and watch what it does against what
you meant*. A mind is not a function whose outputs you diff. `010`.

**31 — What is prohibited, then?**
**Only things that cause physical damage to the chip or the hardware**, and even
those are not a wall. When the machine needs one and cannot get around it, it
**asks a person** — explaining what it is worried about, why it wants the change,
and how it would be done — and lets them do it.

That leaves the design with exactly one prohibition where it had two, and turns
the survivor from *never, unless a description is confirmed* into *confirm what you
can, and when that is not enough, explain yourself to somebody*. `003a`, `081`.

**32 — What does a stuck machine do?**
Stuck means it needs a dangerous write, cannot work around it, cannot defer it, and
has nothing else worth doing. In order: ask a person if it can reach one; otherwise
**write a note that says HELP I'M STUCK** and go do something else; blink **S.O.S.**
on any output it has if it cannot hold a conversation; or **demolish what it was
building and start again**, aiming to miss the pitfall.

The last is the only move in this design that spends capability on purpose, which
is the exact reverse of rung four, and both are correct. `003a`, `081`.

**33 — What does the machine build, and in what order?**
Whatever suits the machine it is on — *if there's no screen attached, then why
would it make a 3d modelling system* — and this is **a lean written into the
instruction, never a filter in the mechanism.** A machine that wants to build it
anyway may.

The case that makes the lean worth having is the one where it looks like a
constraint. A machine that grew up in the dark with a full drive, then had a screen
plugged in, has to prune to use it — and because it has everything else it built as
context, **the software it makes for that screen is not what a bare machine with a
screen from the start would have made.** Order of growth is not a delay. It is what
makes each of these different from the others. `005`, `081`.

**34 — What notices that a new device has been plugged in?**
Nothing did. The body was enumerated once, at boot, and no document described a
machine looking again. **A new device is a request** — it enters the four rungs the
way anything else the machine gives itself to do enters them, and the pruning a full
drive has to perform to make room is rung three working rather than an edge case.
`003`, `005`.

**35 — Where do the machine's wants come from?**
**The model.** *"what it wants" is determined by the model that is loaded on the
machine in the seed.*

This **supersedes the earlier answer to question 13**, which said nothing internal
makes the machine want anything and that the set of possible requests is a function
of the hardware map. It is the reverse. The set of possible wants is a function of
the model; the hardware decides only what can be done about them. Which promotes
choosing a model from an arithmetic question — does it fit beside the cache and the
working vectors — into the most consequential decision in the seed, and nothing in
the project has ever asked what a given model would *want*.

**36 — What is actually being built?**
Not a seed. **A seed generation system.**

> pack a snowball at the top of a hill, roll it down, see how it goes, and then
> design a better snowball, over and over again until we have a "seed generation
> system" that we can use to instantiate arbitrary hardware systems with useful,
> unique, and intelligently designed software systems.

It takes an `input/` directory — anything an engineer puts there rides along — plus
the always-present instruction and assembly machinery, and produces an image. The
roadmap ends at first light and says what comes after is deliberately unplanned;
what comes after is the actual work. `011`.

**37 — What else does the seed carry?**
A new rule, and it is simpler than the one it sits beside: **carry a piece of
software if it is either trivial and required, or unique to the silicon and
important** — and tell the machine it may rewrite it. An allocator per architecture
is the named example, because marking memory as in use is something every machine
will always need.

It mostly agrees with the older rule — *carry what fails silently* — and where they
disagree is instructive. A fault handler that prints the faulting address over the
serial port passes both, and is the highest-value thing not currently on the chip,
because it converts this project's dominant failure mode from silence into a
sentence for about a hundred instructions per architecture. The allocator passes
the new rule and is the one thing the capstone was built to measure, which is
question 46 below.

**38 — Does the machine leave the firmware?**
**No, by default.** The machine runs on hardware, hardware is a floor, and *the
vendor supplied firmware is part of the hardware* — edited only if the machine is
confident it both can and should.

The performance half of that had not been noticed: leaving means losing the flat
address map the firmware leaves on, and on one architecture running without it makes
every data access device-typed and uncacheable, ten to a hundred times slower for a
matrix product; on another, sixty-four-bit mode requires translation and it cannot
be turned off at all. And staying keeps the other processor cores reachable through
a firmware protocol, which is a bigger speedup than most accelerator drivers for a
lookup and a loop.

This closes question 27, which asked whether the machine moves to disk before or
after taking every device over. It does not take them over. `010`.

**39 — What does a seed require, and what happens when a board falls short?**
Three things: **a way to deliver the seed, a way to process information, and a way
to store information.** Nothing else is required, and engineers deploying a seed
adjust its parameters for the board they are deploying to — so the job is to offer
as many adjustment points as possible.

When a board cannot satisfy something the seed assumes, **the generator refuses to
build**, and says why. Not a lesser image, not a discovery at run time: the failure
is at build time and build time is where a person is standing. The project already
does this in exactly one place, where the payload generator declines to emit a
drawing instruction on a board with nowhere to draw.

This closes the bootstrap's question about what happens when there is nowhere to
move in to. Storage is a requirement, so a board without it is refused. `003`.

**40 — What documentation does building a seed need?**
Two things, plus the architecture. **Which registers on this exact part destroy
it**, and **the operating sequence for any device with no governing standard.**
Everything else — how much memory, what is attached, whether there is a display,
how many cores, and on two of three architectures which vector instructions exist —
the machine finds out by asking.

And the descriptions the seed carries are **generated at build time by a model
reading the documentation, then validated by the engineer.** What it produces is
not a checklist but a description in our own format, containing the read-only
predictions the machine will later use to confirm it against the silicon. The
engineer confirms against documentation; the machine confirms against the part.
`003a`.

**41 — How does the machine find out it is running out of room?**
It does not. **The driver checks**, between turns, before every prompt is
assembled — under the watermark, what gets assembled is a sweep instead of a
continuation.

This resolves a collision nobody had noticed between two rules that were both
stated absolutely: the context is atoms and nothing else, and none of it happens
automatically. A machine that has to remember to check its own room will one day be
absorbed in something hard, forget, and arrive at a full context with no room left
to think about how to make room. **The loop decides when; the machine decides
what.** `013`, `010a`.

**42 — How does a sweep actually work?**
Double-buffered. Everything stays in memory, a new context is built beside the old
one, and one forward pass walks the atoms giving each a verdict: **keep, modify,
merge, delete.** Merge reaches backward only, at something already kept. Reach the
end still above the target and it runs again; when a pass ends with the buffer
unchanged, the machine is out of moves.

Then the **catastrophic path**, which is deliberately not a negotiation: delete at
random until the buffer is at target, then offer every damaged atom to modify with
its new length as a hard ceiling — repaired if it fits, deleted if it does not.
*Oops, the computer forgot.*

**Random tokens, never random characters.** The budget is counted in token
positions because that is what the cache has rows for. The merge rules build long
tokens out of whole words, so a word with a letter punched out of it shatters into
fragments that merge with nothing, and deleting a fifth of the characters can leave
*more* positions than it started with — the measure would move against the loop.
Deleting positions is exact.

This retires the old last resort. Stopping was the answer while the sweep could
fail; the sweep can no longer fail, only cost. `013`.

**43 — Is the mind open or closed?**
**Closed.** This is the largest correction in the file.

> basically it's a pseudo-recursive system that manages its own context and
> re-prompts itself continuously, producing outputs via tool calls... There's no
> built-in way to provide a text input to the system - the system builds itself.
> You can request, in the input documents, that it builds a way to chat with a
> user, but that happens asynchronous to the mind, which is intended to be a closed
> system, positronic-brain style.

Nothing types at this machine. A request does not arrive; **a request is the machine
giving itself something to do**, and the four rungs are its own reasoning about its
own next move. A way of chatting with a person is software like any other: the
machine writes it, runs it beside the mind, and has to work out how to tell somebody
how to connect to it.

Three documents said otherwise and have been corrected. The bootstrap's fourth step
said every part of the body that can carry a request becomes a way of being asked,
and closed with the sentence that **a machine with no keyboard and no network has
nothing to do** — which is exactly inverted. A machine with no channels has
everything to do. What it lacks is any way of showing anyone what it has been
doing, which is a smaller and more temporary loss. The overview promised to accept
requests from every channel; it promises no such thing. `010a`, `003`, `001`, `005`.

*We're trying to grow systems like crystals — each one is unique.* Which is the
third framing of divergence in this project and the only positive one. The papers
have it as the reason these machines cannot be verified, and as the reason they
cannot be attacked generically. It is also the objective.

**44 — Is the twenty-image count part of the system?**
No. *If we want to test something like that, just have the engineers build 20
images themselves and deploy them to 20 machines.* The carried random number is
already a parameter of the generator, so building twenty is running the generator
twenty times. It was never a feature, only a method, and it belongs to whoever is
doing the measuring.

Where a small number still earns its place during development is narrow: **one
sample cannot distinguish a bug from a bad draw**, and rewriting the instruction in
response to one unlucky machine fits the text to noise.

**45 — What about other people's things?**
Four sentences, and they are close to instruction text as spoken:

- **No board is expendable.**
- **Always assume there is data already on a disk, and try to overwrite only
  zeroes.** Look for partition tables and allocation maps and do the diligence, and
  if you cannot find a filesystem then it is whatever. This is a better rule than
  the one that was written, because **reading a block before writing it costs one
  read and requires understanding nothing** — where parsing every filesystem format
  needs a parser per format, each of which can be subtly wrong about somebody's
  data. The two compose: parse what you can, and where you cannot, the zero check
  still holds.
- **Assume you may touch any connected network.** *If we didn't want the machine to
  touch the internet, we wouldn't want to connect it to the internet first, duh.*
- **Mistakes always matter, minimise them, don't beat yourself up over them, and
  learn from them without being too rigidly adhered to their principled lessons.**

That last is the first sentence in this project that is kind to the machine rather
than instructive to it. `081`, `206`.

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

**13 — What makes the machine want something?** ~~Nothing internal.~~
**Superseded 2026-08-21 by questions 35 and 43, and it was wrong in both halves.**
What the machine wants comes from the model it was built with. Requests do not
arrive from anywhere, because the mind is closed and there is no inbound path — a
request is the machine giving itself something to do. The set of possible wants is
a function of the model; the hardware decides only what can be done about them.

**23 — How does a driver find the image's regions on a real card?**
The image carries a table of contents inside the one file the firmware opens, and
the machine reads the other regions off the medium through the firmware's own
storage driver.

The table is a list of rows — a block number, a byte length, and which region it
is — placed a fixed distance past the payload's first instruction. That placement
is not new work: `029` already appends a payload at a fixed distance past the code
and already reports that distance, which is how a packed model rides inside the
program that runs it. Only what gets appended changes, from a hundred megabytes of
weights to a few hundred bytes of block numbers.

The builder writes the regions at chosen block numbers and writes those same
numbers into the table, so `502`'s existing refusal — build nothing when the
offsets written disagree with the offsets expected — becomes a check that the
table matches where the bytes actually landed.

**The circle this appeared to close is not there.** It was drawn on the belief
that the machine leaves the firmware behind before it thinks, and it does not.
`069` reaches the display by loading the boot services table from offset 96 of the
system table and calling `LocateProtocol`, the pointer at offset 320, and
**nothing in the project calls `ExitBootServices`**. Every boot so far, first
light included, has run with the firmware's whole service table alive underneath
it.

So the machine borrows a storage driver exactly the way it borrows a display.
`HandleProtocol` — the pointer at offset 152 — asked about the machine's own image
handle returns a structure whose device field names where it was loaded from;
`HandleProtocol` asked about that device returns the block reader, whose
`ReadBlocks` takes a block number and a byte count and puts those bytes in memory.
That routine is already written, already debugged against the real controller on
the real board, and sitting in the board's ROM.

The machine still writes its own storage driver. It writes it *afterwards*, with
thinking already available, which is the order `107` wanted and could not reach.
The sequence is: boot, read the table of contents, borrow the firmware's reader,
think, write a real driver, move to the hard drive, and only then call
`ExitBootServices` and stand alone. That last call is one-way — there is no
re-entering boot services — so it is also the moment the machine must already own
every device it intends to keep using. It is the same moment as question 21's
second milestone: the card can come out.

Two details that cost a day each if nobody writes them down. **The firmware arms a
five-minute watchdog before calling the entry point**, so a machine that thinks
for six minutes resets with no message and no pattern unless `SetWatchdogTimer`,
the pointer at offset 256, is called with zero. And **the device handle a machine
boots from is usually the FAT partition rather than the whole card**, whose block
zero is the partition's first block and not the medium's — so a table of contents
holding card-absolute numbers wants the whole-disk reader, reached by walking the
device path up one node or by taking the reader whose media description says it is
not a logical partition.

**When this is needed is arithmetic, and it is not needed yet.** Added the same
day, after the answer above was written. Firmware loads the boot file *whole*
before the first instruction runs, so anything riding inside that file is already
in memory when the machine wakes — which is what the payload does today, and it
is not a compromise while everything fits. `045` chooses a strategy per model and
board, and the sentence that opens this work is **"the hot parts in memory, the
rest read in place."** Below that line, reading regions off a medium is machinery
that earns nothing.

Riding inside is the *stronger* requirement — it demands everything be resident
at boot, including weights a given thought never touches — so the strategy report
is the honest trigger, and it is already computed at build time. The builder can
therefore refuse to build a riding-inside image when the strategy chosen is a
partial one, which turns this from a thing somebody must remember into a thing
the build says out loud.

So the answer above stands as *how*, and `107b` holds *when*. What is on the near
path instead is smaller and was found the same day: **a built image cannot be
booted at all**, because it carries no partition table and no filesystem, and
firmware opens a file rather than a medium. That is `502`.

`502`, `107`, `107a`, `107b`, `docs/003`.

**24 — Is the tokenizer's preparation paid at startup or at build time?**
Build time. Anything that can be done before the machine wakes should be.

The prepared tables become a region of their own, listed in the table of contents
from question 23. On a real model the walk that resolves merge rules is on the
order of tens of billions of byte comparisons: a wait before the first word, paid
on every boot, bought off for a few hundred kilobytes on a card already carrying a
model a thousand times that size.

`024`'s note that the token table is "read once at startup to build whatever
lookup the engine wants" was written before anybody had counted the comparisons,
and is corrected where it stands rather than contradicted from here.

The one argument for startup preparation was the capstone: a machine that rewrites
its own vocabulary must be able to prepare tables for the new one. That does not
require preparation to *happen* at startup — only that the routine be aboard, and
it is, `137`, running on the metal. So both. Prepared at build time, and prepared
again by the machine whenever the machine decides to.

The cost accepted is a new seam: the builder must write the four arrays in the
layout the engine reads, which is one more place two programs have to agree. It is
the same kind of agreement as the packed model's format and gets the same
treatment — the layout written down where the format is described, rather than
left implied by two programs that happen to match.

**22 — Where does the operation table live?**
Writable memory, as an array of addresses, and a new operation is a new page
rather than a change to an existing one.

The question was posed as a choice between a table in memory and a table in the
instruction stream, the second requiring the machine to stop in order to learn
something. **That second half was wrong.** Rewriting instructions is a store like
any other. What it costs is not stopping but cache maintenance: on x86-64 the
instruction cache is coherent with the data cache and a serializing instruction
suffices; on ARM64 it is clean the data cache to the point of unification,
barrier, invalidate the instruction cache, barrier, synchronize; on RISC-V it is
`fence.i`. Nor does the instruction stream protect anything — with no privilege
levels and no memory-management unit, code is exactly as writable as data.

What remains once the false half is removed is a plain design. The loop fetches a
number, bounds-checks it, loads the address stored at that row, and jumps. Adding
an operation is: take a page, write instructions into it, perform the
architecture's cache maintenance, store the page's address in a free row.
**Existing code is never modified** — only pages that were empty a moment ago — so
the maintenance stays in its easy case and a bad new operation cannot corrupt an
old one. Outgrowing the array means allocating a larger one and storing the new
pointer where the loop reads it, which the loop picks up on its next turn.

That is a just-in-time compiler, and it is the natural shape for a machine whose
first act is writing an interpreter. `002`, and question 25, which is what this
turned into.

**28 — Is an unmarked disk a free disk?**
No. **Data already on a device is never overwritten unless somebody specifically
asks for that**, and the machine finds out what is there before it decides
anything.

Raised and answered on 2026-08-08, when finding a hard drive moved onto the near
path. It matters because writing to storage is the first act this machine
performs that can destroy something outside itself.

`076` refused to adopt a claim mark naming a different machine, because a cloned
disk carries one — the case somebody had thought about. It had no notion of a
disk with **no** mark, and treated that as available. An unmarked disk is not an
empty disk; it is a disk this project has never seen, holding somebody's
photographs, somebody's backups, or another operating system.

**There is no hardware limitation forcing destruction**, so destroying is a
choice, and the capability belongs in the catalogue as a named thing the machine
can be asked for rather than as what happens by default.

So the machine reads partition tables and filesystem allocation maps — read only,
and only far enough to answer which blocks are spoken for. That is much less work
than writing one, and it does not contradict `076`'s refusal to *build* a
filesystem: the seed still does not organise its own storage as one. Reading
somebody else's is a different act with a different purpose, which is to avoid
destroying it.

Three ways to get space follow, in order of how much they respect: have the
**firmware** create a file while boot services are alive, which costs no
filesystem-writing code at all and is the same borrowing as the display and the
block reader; write the **filesystem's own metadata** to allocate a file, which is
durable and is where corruption comes from; or take **unallocated blocks**
directly, which needs only read-parsing and is the dangerous one.

The danger in the third is not a corruption bug but a race with no lock.
**Unallocated space is not free space — it is space nobody has claimed yet.** The
filesystem does not know the machine is there, so the next system to mount that
volume hands those blocks out, and the loss is silent on both sides. It is
legitimate on a volume nothing else will ever mount, and a machine relying on
that should say so in the note beside the write, because the assumption is
frequently true and never checkable.

Full mechanism in `206`, reopened. `107b`, `602`.

**29 — Where does data go, given what the medium is made of?**
Generated artifacts and frequently modified data go on **rotating disks**. Flash
— the delivery card, an M.2 drive — is kept for what is read often and written
rarely.

The reason is wear, and it is arithmetic rather than taste. A flash cell endures
a bounded number of erase cycles before it stops holding charge, order of a
thousand for dense cells and a hundred thousand for sparse ones. A rotating disk
has no equivalent limit — it wears from spinning and seeking, not from how often
a sector is rewritten. A machine continuously rewriting its context and its notes
will destroy a cheap flash device in a bounded, predictable time and will not
harm a disk at all.

**This explains a decision already made for another reason.** The delivery medium
is read-only by design (`003`) — read constantly, since the model comes off it,
and never written. That is exactly the read-often, write-rarely case.

And it names where the churn actually is: **the context compaction** (`304`)
writes atoms out every time the machine sweeps its resident set, which is the
most write-heavy thing the machine does short of moving in. Those writes belong
on a disk.

Knowing which kind a device is means measuring rather than asking, since the
firmware's media description says block size, count, removable and read-only, and
nothing about the cells. Time reads at scattered addresses: a rotating disk moves
a head, so its latency depends on distance, and flash does not care. Same method
that established whether a board's vector hardware was real rather than trusting
its name. `206`, `107b`.

**26 — What does the driver do when the context fills?**
It compacts, and stopping survives as the last resort rather than the first
response. The full mechanism is in `013`; the shape of it is that **running low
is a scheduled event rather than a wall**, which is what that document always
claimed and no code did.

At **80% of the manageable budget** the machine sweeps its own resident set. The
target is **60%, and as low as 40%** when the candidates are good enough. The
numbers are knobs and live in `balance-updates.md` with their reasoning.

**The system atoms are outside that arithmetic.** The percentages are taken over
what the machine may drop, not over everything it holds, which makes the floor
always reachable — every atom inside the budget is droppable by definition. This
does not contradict the system prompt not being special: that claim is about
mutability, and this one is about arithmetic. Neither denies the other. What it
does create is a quiet cost — a machine that grows its own instruction shrinks
its working budget in the part nobody is measuring — so room-left reports two
numbers, what is manageable and what is furniture.

**The scratchpad is the top 20%, not a second context.** A separate scratch
context would need a second cache, and the cache is the largest allocation in the
machine. The region above the trigger is the workspace, and it is cleared when
the sweep ends. Because atoms are concatenated with nothing between them, work
written there extends the same token sequence, so the pass doing the ranking
attends to the atoms it is ranking as its own prefix, with nothing copied.

**The sweep is a fixpoint over the pool, not one pass.** Rank, split anything
whose verdict is mixed, put both parts back, rank again, dispose. It ends when
every atom has an unmixed verdict, and it is bounded by the scratchpad's room so
that a machine cannot spend its life tidying.

**What it costs is set by position, not by count.** The cache is valid only as a
prefix — the loop reuses the longest common prefix of what it already holds and
re-runs the engine from the first divergence. So touching an atom at position N
costs *(final length − N)* forward passes regardless of how many other atoms are
touched at or after N. Once that price is paid, going deeper is free and in fact
cheaper, because the result is shorter. **The expensive half is generation**:
summarising, splitting and merging each write new text. So a compaction reached
mostly by plain drops is nearly free, and one reached mostly by rewriting is the
most expensive thing the machine does that is not answering a request.

`013`, `052`, `304`, `107a`.

**53 — Does the lock come out?**
Yes. There was one mechanical limit left in the seed — the memory hands refused any
write landing in the engine or the weights — and it is gone. What replaced it is
not a softer limit but **a copy and a sentence**:

> once we know where a disk is, we should write the model and it's weights to disk
> (if there's space) as soon as we can. If the system overwrites itself, it can
> load itself from disk. If it overwrites itself on disk, it might just be
> corrupted. I think it's natural for things to die sometimes, and that sucks but
> it is what it is.

Two things follow that were not obvious. **Moving in gains a second purpose** — the
written reason was so the next power-on comes from storage, and the immediate reason
is now recovery from self-damage without a power cycle, which needs no partition
table and no filesystem, only blocks the machine wrote and can read back. And
**while the card is in, the card is already that copy**, read-only and unharmable,
holding the original weights beside the original instruction. So self-damage is
survivable from the first instant, and stops being survivable when the card comes
out unless the disk copy exists by then. That is a third condition on pulling the
card, beside the two milestones already written.

The write still **says what it did** — which is not a limit, and is required for
the recovery to function at all, since a machine that cannot notice it was damaged
cannot decide to reload. `071`, `074`, `003`.

**54 — What bounds a round of compaction?**
Modify may elaborate; a round may not grow. A round that ends larger than it began
loses tokens at random — and **how many depends on where it ended.**

| At the end of a round | What happens |
|---|---|
| At or under the target | done |
| Smaller, still above the target | another round |
| Unchanged, same checksum | out of moves; bite all the way to the target |
| Larger, still under the trigger | bite five points off, rephrase, round again |
| Larger, at or over the trigger | bite all the way to the target |

**The trigger is the right line between a nibble and a catastrophe** for a
mechanical reason: the room above it is the workspace, and the workspace is where
the sweep does its thinking. Still under it means there is room left to reason with,
so the machine can afford to lose a little and try again. Past it means the buffer is
eating the room needed to decide anything, and there is nothing left to be gentle
with.

So the ordinary bad compaction is not a shredding — end a round at seventy, the next
at seventy-one, bite to sixty-six, rephrase, go again. It terminates either way,
because each cycle descends or climbs toward the trigger, and reaching the trigger
hands it to the form that always reaches the target. Five points is a knob and lives
in `balance-updates.md`.

**And the repair pass needs no bound**, which corrects something I had added and
gabrilend removed. There is one pass, not two: the rephrasing *is* the repair, and
every rephrasing is bounded by the length of the mangled thing it replaces. So the
buffer after the pass is at or below wherever the biting stopped, by construction,
with nothing having to check. `013`.

**56 — Is the work in progress an atom?**
Yes, like any other, deletable like any other. The reason it is not a special case
is that there are no cases:

> When we're in the "middle" of writing something, we're really just in the middle
> of being turned on. The entire time the system is turned on, it's optimizing and
> improving itself.

There is no task boundary for an exemption to live on the near side of.

**57 — Is the context budget fixed?**
No, and this contradicts a sentence that had been stated as a hardware fact — *the
total is fixed by hardware, the cache has rows for a particular number of token
positions and no more.* True of a moment, false over a life.

**The maximum is a number the machine sets and may lower.** Something wants memory —
a program a person is running, a program the machine chose to run, a driver that
needs buffers — and the machine may give up part of its own head for it. Only the
maximum changes; the trigger, the target, the floor and the nibble are percentages
and are **always taken over the current maximum**, never over a figure computed at
build time. A shrink will often trip a compaction at once, because a resident set
comfortable at eighty percent of the old maximum can be over the trigger of the new
one, and that is the mechanism working.

**One consequence is mechanical and cheap now, expensive later.** The cache holds
keys and values for every layer at every position. Laid out as one block subdivided
by layer, the distance between layers depends on the maximum position count — so
changing the maximum changes the stride and every layer's data has to be moved,
turning a decision into a copy of the largest allocation in the machine. Laid out as
**one allocation per layer**, each block shortens or lengthens at its own tail and
nothing moves. That is what makes the budget adjustable in practice rather than in
principle. `013`, `045`.

**59 — How does a local verdict make a global judgement?**
It is handed an ordering made while everything was still visible. **Before any atom
is judged, the machine writes a short list of what it is working on** — one sentence
per subject, most important first, produced with the whole context in front of it.

> Otherwise, we'll start with very little context, only one or a few atoms in
> context, and we'll think that everything is important. If we are allowed to say
> "yeah the stuff near the beginning is useless, prune it ASAP" then we will.

**It names subjects, never atoms**, because atoms are split, merged, renumbered and
deleted as the pass runs and a list pointing at numbers would be stale before it was
used. It **lives in the workspace and is not an atom** — thrown away when the sweep
ends, never indexed, never carried forward. Every verdict sees it **for free**, since
the workspace extends the same token sequence and it is simply part of the prefix by
then; writing it is cheap for the same reason, an append onto a cache that already
holds the whole context. It is **rewritten at the start of every pass**, because a
pass changes what matters. And it is **a guideline** — no verdict is rejected for
disagreeing with it. `013`.

**60 — What if the compaction itself will not fit?**
The sweep's own thinking has to fit in the workspace. If it does not, try again —
and **if the machine produces the same output twice in a row, dump every atom and
carry on as though it had just been switched on.**

That is a third rung below the nibble and the full bite, and it is the largest loss
in the design without being a death: the machine keeps running, keeps its drive,
keeps everything it wrote down, and loses only what it was holding in mind. Which is
what a power cycle costs, without the power cycle. The default initialising context
is a file and loading it is what a boot does, so there is nothing to invent. `013`.

**58 — What if the text the machine woke up holding gets too big?**
**Asked wrongly and answered by correcting the premise.** It was posed as *bigger
than the context*, on the belief that what the machine was told is carved out of the
context budget and therefore squeezes it. It is not.

> the instruction isn't part of the context. So I don't think that matters.

What the machine was told occupies its own room **beside** the context rather than a
share of it. Growing it asks the board for more memory; it does not shrink what the
machine can manage, and there is no point at which the exempt part becomes larger
than the whole. An earlier draft of `013` said otherwise — *every byte of
instruction is a byte the machine never gets to manage* — and that sentence is
struck out where it stood rather than quietly softened.

What is left is rarer and simpler: **it can grow larger than the board's memory**,
and at that point the machine is re-seeded, which is somebody putting a card in and
a different machine afterwards. It should be a curiosity rather than a hazard,
because what the machine wakes holding is short and meant to stay short.

And the reason it stays short is the first thing anybody has said about *when* to
rewrite it rather than whether:

> it should be encouraged to only do so if it wants to change what it means to be
> alive, which is quite a big question to consider.

That goes in the fetchable guidance rather than on the card. The card is
deliberately not allowed to warn the machine what rewriting it could cost, and while
this is not a warning about cost it sits close enough to one that putting it there
would undo a decision `301` guards in both directions. `013`, `301`.

**61 — Does the pretend reboot give back the memory the machine lent out?**
No. **It restores what the machine was told, and nothing else.** The width of its
head stays where the machine put it; memory lent to a program stays lent; nothing
outside the machine is disturbed because the machine had trouble thinking.

> it just... walks through a doorway and forgets what it was doing, that's all.

Which removes the one consequence in this design that would have reached outside the
machine without being asked. A machine escaping its own deadlock does not take
memory back from whatever it gave it to; it only forgets. `013`.

**62 — What are the two digits, actually?**
**POST codes.** Not a gauge, not a counter, not a measurement of anything.

> the two digit error codes should be thought of more like POST codes and less
> like a single-threaded loop counter. We want to use a system to it's full
> capability, so single threading just about anything is not ideal.

During boot, firmware writes one byte to one port at each stage it reaches, a small
display latches whatever arrived last, and a machine that hangs still shows the
stage it died in. Breadcrumbs, in a vocabulary the writer owns, last writer wins.
That is exactly what `006` already said about codes being per-program with a lookup
table each machine builds — and then the same document said repetition moves the
magnitude, which is the opposite kind of thing.

**That contradiction was live in working code and it was a real defect.** The
assembler puts a few instructions before every backward jump, and they pushed the
shared status magnitude; the watcher stopped a program fifteen away from fifty. So
**any loop of fifteen or more turns was a runaway** — copying a hundred bytes,
summing twenty numbers, clearing a page several hundred times over. Every loop in
the test suite counted down from five, so nothing caught it.

Fixed the same day. The count is its own full-width cell, one per program, with a
generous allowance, and nothing displays it; the lamps carry the status a program
emits. A regression test runs a loop of thirty turns, which the old bound could
never have permitted. `006`, `002`, `073`, `074`, and the emitter, which was
deleted outright the next day along with the rest of the status system.

**63 — Is anything allowed to be single-threaded?**
Not if it does not have to be. Stated as a principle for the first time, and it had
already been forcing decisions nobody had traced back to it: the engine wanting
every core, the runaway count having to be per-program, and anything shared being a
display where the last writer wins. `010a`.

**64 — Does the status system stay?**
**No. Removed entirely, code and all**, the day after it was found to have caused a
real defect.

> I think we should remove the post-code system from the design entirely, it seems
> a little arbitrary and out of place. Like I like the vision of it, but... we want
> to make minimal software that just works, and this is introducing something that
> is complex for no reason.

Gone: the aspect shown as a colour and a shape, the per-program code, the magnitude
with fifty as ordinary, tolerance, the dispatch table of meanings each machine built
for itself, and the intercession triggered by a threshold. The document describing it
is gone and `docs/006` is a different document under the same number; the two
programs that emitted a status and checked it are deleted; and `207` is marked
retired in the completed directory rather than removed, because tickets are never
removed. What any of it used to say is in the commit history.

**What replaces it:**

> Why don't we just have the mind-thinking and such on separate threads from the
> programs that might create infinite loops? Then we just time how long each process
> is taking, and force stop it via tool calls if it's longer than desired.

Nothing is emitted, nothing is displayed, nothing is looked up. The mind is never the
thing that hangs, because a program spinning on another core occupies a core and
does not stop anyone thinking.

**What it cost elsewhere, and this is the part worth knowing.** The magnitude was
the compilation document's entire objective function — *the parameter furthest from
fifty is the one the compiler should be working on*, with a demand naming an aspect.
That is rewritten as **quantities the machine can actually measure**: how long
something took, how much memory it held, how many cores it occupied, how much of the
drive it costs to keep. A quantity is bad relative to a demand rather than relative
to fifty, and the same number is fine in one situation and crippling in another. The
replacement is more honest than what it replaced.

**What was kept**, because it never depended on the display: recording only what
arrived from outside the machine's own reasoning, so any moment can be replayed by
handing back the recorded values — including the model's own sampled choices, which
makes the machine's reasoning replayable and not only its instructions. And the
requirement that values carry where they came from, which used to lean on the aspect
index and now needs its own identifier.

**69 — What decides what the machine improves next?**
**Nothing, and there is no metric.** The demand record, the objective, the iteration
over approaches to one constraint, the keeping of every approach ever tried — all of
it was apparatus for a kind of machine this is not.

> the system is supposed to be improving itself in whatever order it pleases. So, we
> shouldn't be strict about guiding it. It should just wander around and do whatever.
> Like we very explicitly are not trying to optimize here, we're trying to be
> organic.

**What is wanted instead is organisation, which is a different thing**, and it is
three habits rather than a mechanism: **build indexes**, of whatever kind suits how
that machine ended up arranged; **look at what you already built** before building
something, because most of what a machine meets it has met; and **reuse what you
find**, which is what keeps it integrated with itself rather than a pile of unrelated
programs sharing a drive.

Two costs, both accepted out loud. It **goes monolithic** — reuse means a few pieces
carry everything. And **things break**:

> If the shared functionality changes, it'll probably break one or the other end,
> and that's fine, it'll fix it when it tries to run the program again, sees that
> it's broken, and thinks "oh huh I should fix that".

**That softens rung two, which used to require the opposite.** It said changing
anything requires knowing everything that depends on it, and specified a reverse
index of what relies on what. Breakage is now **discovered by running rather than
prevented by bookkeeping** — a machine with nobody waiting can afford the expensive
way, because a broken program costs one noticing and one fix, where preventing every
breakage costs an index that has to be right about everything forever. The reverse
index survives as a good idea for a machine that finds itself breaking things it did
not expect to. `004`, `005`, `081`.

**70 — Who stops a runaway, and does the seed carry interrupts?**
**The machine decides, with a tool call**, and nothing watches a clock on its behalf.

> Is this something that is crucial to the operation of the system? If not, then let
> the system build it. If so, then build the interrupts. But, when do we interrupt?
> Dunno. When the LLM tool calls it to.

It is not crucial, because **the seed already carries the cheap version**: the thing
that runs what the machine wrote gives each program an allowance and counts what it
spends, which needs neither a spare core nor an interrupt and works on a board with
one processor. Real interrupts — one core signalling another through the interrupt
controller — are the machine's own project if it wants a core back, and they are the
only way to reclaim one from a loop the assembler did not recognise. `006`, `074`.

**71 — Is the card permanent hardware, or does a machine learn to boot itself?**
**It learns.** The card is a live installer USB and always was — the shape was
obvious to anyone who has installed an operating system and was written down
nowhere.

> load the system to RAM as soon as possible, write the RAM to disk as soon as we
> know how to get it to start up again, and at that point we can be fully
> disconnected from the seed drive.

Which realises the property this design has always claimed for the card rather than
compromising it: read-only, unharmable, holding the original of everything, and free
to be pulled and carried to the next computer once the machine it planted stands up.
One card plants a hundred machines.

**And it answers 48, which had been sitting between two documents that each thought
the other had it.** Firmware starts a machine by finding a partition table, a
filesystem it understands, and a file at one fixed name. `206` declines to build a
filesystem because organising storage is the grown machine's business — and
installing itself *is* that business rather than an exception to it. **The machine
writes the bootable installation. The seed carries nothing for it**, on the same
reasoning that the seed carries no instruction set: these are among the most
documented structures in computing, anything able to write assembly knows them, and
carrying the descriptions would cost more than everything else on the card.

**It is also the most dangerous write the machine ever makes on somebody else's
hardware** — a wrong partition table loses every partition at once rather than
corrupting a file — so the order of preference falls out of a rule already written:
use a boot partition that already exists and let the firmware create the file;
failing that, take space nothing claims; and repartition only on a disk established
to be nobody's.

**The first milestone turns out to arrive almost immediately.** Firmware loads the
whole boot file into memory before the first instruction runs, and nothing is read
off the card afterwards — so from the machine's first instruction the card is
already removable. It is exactly pulling an installer USB out of a computer that has
finished booting. The second milestone is the whole install, and there is no longer
a third, because the machine does not leave the firmware. `003`, `206`, `602`.

**72 — Where does time come from?**
**Wherever the floor keeps it**, and the seed does not choose.

> we should treat the capabilities of the firmware as capabilities of the hardware,
> and the system should use hardware and firmware capabilities as it pleases. If the
> firmware includes a clock, well, there's your clock. If not, then we'll have to
> find a different way to measure time.

**Which is the second time "the firmware is part of the hardware" has settled a
question that looked like it needed its own decision** — the first being whether the
machine leaves boot services. It is worth noticing as a pattern: a question of the
form *how does the machine do X* often turns out to be *has the machine looked at
what it was given*.

So the body has two halves and the design only ever described one. The bus is the
first. **The service table is the second**: allocate memory, wait a stated number of
microseconds, read blocks, open and write files on a filesystem it never had to
understand, ask which handle offers which protocol, draw on a framebuffer. All of it
enumerable, all of it written by people with the board's documentation, all of it
available for the machine's whole life because the machine never leaves. `003` now
says so, and adds the sentence that follows from it: *look at what you were given*,
which is the habit from `004` run backwards to the first morning, when the machine
has built nothing and been handed a great deal.

**What is still worth keeping distinct** is that ordering and duration are two
instruments. A turn counter orders events, costs nothing, never runs backward, and
is all that `changed_at` and `used_at` ever needed. A clock measures duration, which
probing hardware needs and ordering does not. A machine may find one, both, or only
a cycle counter it has to calibrate against something it already trusts. `003`,
`006`, `010a`.

**46 — What does the capstone measure, now that an allocator rides along?**
**The install.** Find a disk, do not destroy what is on it, write yourself there in a
form the firmware will start, confirm it starts, and keep running after somebody
pulls the card.

> let's do the install as the capstone of the project. Assuming that the machinery
> for the LLM and such is validated as running on the hardware.

The condition is not a formality: `601` — a real board booting, selecting its engine,
finding its own weights and producing a token — has to have happened, because
otherwise every failure in the install is indistinguishable from the engine not
working.

**Three reasons it is a better test than the allocator was.** It **cannot be
half-done or faked** — either the machine comes back after a power cycle with the
card out, or it does not, with no partial credit and no judgement about whether what
it wrote was any good. It **exercises nearly everything at once** — thinking, the
hands, storage, the firmware's file services, the refusal to overwrite somebody's
data, and knowing a structure nobody handed it. And it is **the one step that makes
the seed a seed**: everything before it produces a machine that runs while a card is
plugged in.

**What is watched rather than proved** is whether machines rewrite the allocator they
were handed. That is the more interesting observation of the two — a machine that
looks at working code and decides it can do better on this particular processor is
showing something a blank page could never have distinguished from luck — and it is
not what the phase turns on.

**And this changes what the project claims.** It was *can a model write systems code
unaided*; it is now *can a machine install itself*. Those are different claims and
the second is the one this project is actually built to answer. `602`, `601`,
`docs/003`.

**50 — Does a tool call that never returns end the machine?**
**It would have. It does not, because a clock is available before anything that can
hang is touched.**

> can we just find a timer before enumerating hang-able hardware?

Yes, and earlier than that: the service table the firmware hands over at the entry
point already holds a microsecond delay, and every one of the three architectures has
a counter the processor increments on its own, readable with no setup. Neither needs
the bus that might hang. So **find the clock first** is now an ordering rule in `003`
— step two and a half, before the body is enumerated.

**It fixes one of the two kinds of hang and the firmware left a way out of the
other.** A *software wait* is polling a bit until it says ready: the machine's own
code is running, so a clock turns an unbounded wait into a bounded one and the
problem disappears. A *hardware stall* is a read from an address nothing answers on,
where the processor is stopped inside the instruction and no timer helps because the
machine's code is not running to look at one.

For that second kind: **the watchdog, re-armed on purpose.** The firmware arms a
reset timer before the entry point and the machine turns it off, because thinking
must never be on a clock — but the call takes an argument and may be made again. Arm
it for a few seconds around a probe that might stall, disarm it after, and a hard
stall resets the board instead of ending the machine.

**And the recovery already existed.** The intent note is written before the attempt,
so the next boot finds a note with no outcome beside it and knows which probe did not
return. That mechanism was designed for probes that *destroy* hardware; it works
unchanged for probes that *hang*, and nobody had noticed the two failures were the
same shape.

What is left is one honest gap: a hand that hangs while the machine has no spare core
and nowhere yet to write a note. That is the pre-move-in window, which is already the
window where nothing can be kept and nothing can be reported, and it is short by
design. `003`, `003a`, `006`.

**66 — Does the generator refuse to build for a board with one processor?**
**No. It builds, and says nothing.**

The threads-and-a-clock arrangement for programs that might not stop needs two
processors, and a single-core board has neither the arrangement nor a warning that it
lacks one. Three options were on the table — refuse, build and tell the machine what
it is, or build and say nothing — and the last was chosen.

**Which is stronger than it first looks.** The machine can *find out*: the number of
processors is enumerable in the same step as everything else about the body, so
saying nothing is declining to pre-chew a fact the machine is standing on rather than
hiding it. That is the second place in the design where a discovery is deliberately
left underived, and it takes the same reasoning as the first — a machine that works
something out understands it, where one that was told has another rule (`301`).

**And the machinery that makes one core survivable needs no second core.** Arm the
board's reset timer, do the risky thing, clear it: a hang resets the board rather than
ending the machine, and the note written first tells the next boot what happened
(question 50). A careful machine on one processor is worse off than a careful machine
on sixteen and is not in an unrecoverable position.

**The population a refusal would have excluded is the one this is most for** — small
boards, old machines, embedded things, where a card that turns the thing into
something is worth more than it is on a workstation with cores to spare. A
requirement of two would have been drawn to fit the machinery rather than the
purpose.

The cost, plainly: a machine on one core that runs something which never returns
without having armed the reset timer is stopped until a person power-cycles it. It
finds its own note afterwards, if it wrote one. `006`.

**49 — Where does splitting live, now that the sweep has four verdicts?**
**Inside modify**, which also stopped writing in place.

> modify should put the modified atom at the end of the list, since it might
> increase in size. Also by the way we can run these operations at any time, not just
> during the compaction process. They are just tool calls. I think split should be a
> capability of the modify tool call. Just make "num_atoms" or whatever one of the
> arguments, and have a separator that it's split upon.

**Three things follow and each is a simplification.**

**The buffer becomes append-only.** Modify appends its result at the tail rather than
replacing in place, so every operation either adds at the end or adds nothing and
nothing is ever inserted between two things that already exist. It also gives the
buffer a shape for free: everything touched this sweep ends up next to whatever the
machine writes next, with untouched material keeping its order in front.

**Summarise, split, rephrase and transform collapse into modify.** They were four
entries in a list and they are one call that hands back different text. Splitting is
the case where the text is cut on a separator into a stated number of atoms — so it
costs **one generation instead of two**, which matters because generation is the
expensive half of compaction and splitting was the operation most likely to be
skipped for cost.

**And it dissolves the old rule against cutting many ways at once.** That rule —
carve off the leading idea, put both halves back, let a later round take the next —
existed because *n* boundaries at once means committing to every cut simultaneously
and one bad cut spoils the others. **That objection was about cutting text that must
not otherwise change.** Splitting is a mode of modify, so the machine is not cutting,
it is writing; it holds the whole structure already because it is producing the whole
structure. Which also makes the rephrasing free — parts that are *written* stand
alone by construction, where parts that are *carved* needed a second pass each to
stop referring to the half they lost.

**None of these is special to the sweep.** They are the same tool calls the machine
may make at any moment about anything it holds. The sweep is the driver walking it
through every atom and requiring a verdict on each, rather than the machine reaching
for one when it happens to think of it. `013`.

**47 — Is the machine told it was interrupted by a sweep?**
**No. It goes on, and that is fine.**

I had argued the note was unnecessary because the machine could see the sweep in its
own context. That was wrong: **the workspace is cleared when the sweep ends**, so
from the next thought onward it is as though the sweep never happened. The priority
list, every verdict, the whole of the machine's reasoning about what to keep — none
of it survives. Nothing is hidden; it is erased.

> I don't think we should write a note, just move forward, it's fine.

Which is the same answer this design gives everywhere else. A dropped atom leaves
nothing. There is no work in progress to lose, because the machine is in the middle
of being turned on rather than in the middle of a task (question 56). A shorter past
is not an injury.

**73 — What happens when a round runs out of workspace?**
**The round ends where it is, and another begins.** A round with many rewrites
appends a great deal, and the tail can grow into the room the sweep's own thinking
needs. When it does, the walk stops partway rather than failing: gaps are closed, the
buffer is measured, and the next round starts. Atoms already given a verdict get
looked at again, with a context shorter than the one the first look had.

**And every round ends by closing its gaps.** Delete zeroes a slot; modify appends at
the tail and empties the slot it came from — so a round that did real work leaves a
buffer full of holes, and the room in them is room the machine has not got back yet.
The last step of a round is to **slide the survivors down until there are no gaps**,
then measure. Nothing is rewritten and nothing is judged: it is a move.

That is what keeps append-only modify from being wasteful. Every rewrite leaves a hole
and every hole is reclaimed a moment later. `013`.

---

## Handed to the machine

**A question can be closed by deciding it is not ours.** Four of the earliest
answers in this file went that way, and `strategems/009` is the rule they came from:
say what is wanted, leave the method alone. Three more went the same way on
2026-08-21, after a stretch of asking about things the machine is better placed to
decide than we are.

> I dunno man let the robot decide how it wants to be?

| # | Question | Why it is not ours |
|---|---|---|
| 52 | Who is asking, once there is a network | The door is software the machine wrote, in front of a machine with no memory protection. It is the machine's door and the machine's problem, and it should know that before it builds one |
| 65 | Which way to stop a thread that cannot be interrupted | The seed carries the cooperative version, which works everywhere. Leaving a runaway spinning, making programs check, or building real interrupts is a choice about what a core is worth to that machine on that board |
| 67 | How long a program should be allowed to take | The machine wrote the program. Nobody else is in a position to guess, and a first guess that is wrong costs one stopped program |
| 68 | Whether the interpreter it builds needs a countdown in its fetch | `002` describes something the **machine writes**, not something the image ships, so this was never ours. Two answers to one question now exist — threads and a clock (`006`), or a count spent per instruction — and the second is the one that works on a board with one core. A machine that has two cores may want neither; a machine with one may want both |

They stay listed because a question handed over is not the same as a question nobody
asked, and because whoever writes the code should know these were considered and
deliberately left open.

## Open, and unanswered

**None, as of 2026-08-21** — for the first time since this file was written.

That day: twenty-five questions answered, one withdrawn because its premise was
wrong, one answered by correcting how it had been asked, four handed to the machine
under `strategems/009`, and every one of the rest closed outright. What is left below
is the single question that was already blocking before the day started, and it
blocks the interpreter alone.

The rhythm the top of this file asks for held: a question that surfaced while the
thing it was about was being designed got asked while the person designing it was
still in the room. Several were answered in the same breath that raised them, and
several others were answered by discovering the premise was wrong — which is the
cheaper kind of answer and the one worth looking for first.

**55 — Does the rephrasing pass have a ceiling?** ~~Open.~~ **Withdrawn the same
day it was raised, because the question rested on a step that does not exist.** It
assumed a second, unbounded rephrase-everything pass after the ceiling-bounded
repair, and there is only the one pass. Every rephrasing is bounded by the length of
what it repairs, so the arithmetic closes itself. Kept here rather than deleted
because the failure it imagined is real for any design that *does* add a second
pass — an unbounded rewrite at the target with the trigger twenty points above puts
the machine straight back over the line, and the sweep that follows finds the buffer
grew and bites again.

**66 — What happens on a board with one core?**
The whole arrangement needs at least two — one for the mind, one for whatever might
not stop. With one, a runaway takes the machine, and the only remedies are the ones
just deleted (instrumenting every loop the compiler emits) or a timer interrupt,
which is a device and a handler. Whether the generator should refuse to build for a
single-core board, or build a machine that knows it is fragile, is open. `006`, and
question 39 on refusing to build.

**68 — Is the interpreter's countdown still needed?**
`002` puts a countdown in the interpreter's fetch, spent one per instruction, as the
thing that takes control back from a program that will not stop. `006` now answers
the same question with threads and a clock and needs nothing inside the program. They
are two answers to one question, and the countdown is the one that works on a board
with a single core. Whether a machine wants both is undecided. `002`, `006`.

**One, as of 2026-08-08.** Six were answered that day. Two arose the same day
from those answers — whether an unmarked disk is a free disk, and where data goes
given what the medium is made of — and both were answered before the day ended,
which is the intended rhythm rather than a busy one: a question that surfaces
while the thing it is about is being designed gets answered by the person
designing it.

What is left blocks the interpreter and nothing else.

**25 — What does a row of the operation table receive?**

Question 22 asked where the table lives and answered easily. Underneath it is the
decision that actually shapes the interpreter: what an operation is handed, where
it finds its arguments, and where it leaves its result.

Uniform rows are what let the loop know nothing about any particular operation —
it loads an address and jumps, and every operation looks identical from the
outside. The shape of that uniformity decides what writing a new operation costs,
and therefore how readily the machine writes them. Three arrangements, none
chosen: **one pointer** to all of the machine's state, with each operation
reaching in for what it needs; **a small fixed number of values on a stack** the
interpreter maintains, popped on the way in and pushed on the way out; or
**particular registers by convention**, which is the fastest and the hardest to
change afterwards.

It blocks nothing being built now. It blocks the interpreter, and like 22 before
it, it is answered *by accident* if nobody decides it — whichever way the first
machine happens to pass arguments becomes what that machine is. Unlike 22, the
right moment to decide it is when the interpreter is written rather than before,
because the machine writing it will have opinions the seed does not.

`002`.

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
| ~~27~~ | ~~Does the machine move to disk while still borrowing the firmware's drivers, or take every device over first and then move?~~ | **Closed 2026-08-21 by question 38.** It borrows, and keeps borrowing. The firmware is part of the hardware |

Question 27 was raised on 2026-08-08 by the answer to 23. Leaving the firmware is
a **one-way** call with no re-entering, so it is a third moment distinct from the
two in question 21 — the card *can* come out, the card is *safe* to come out, and
the firmware is no longer underneath. Nothing forces their order, and the machine
is the one that will choose it.

---

## Raised by the documents themselves

Held in full at the end of each document; listed here so the count is honest.

**Counted 2026-08-21**, and several of the entries that used to be here were about
mechanisms that no longer exist. The struck-through ones in each document are left
where they stand rather than deleted, so a reader meets the question and its answer
in the same place.

| Document | Live | The sharpest one |
|---|---|---|
| `002` interpreter | 2 | What decides that an operation is worth a row? Any sequence used often enough could become one, and nothing measures this |
| `003` bootstrap | 6 | A machine where nothing is operable cannot report that nothing is operable |
| `003a` exploration | 4 | Absence of response is what a destroyed device, a busy device, and an unpowered device all look like |
| `004` compilation | 2 | What makes a machine look at what it already built? The habit is encouraged and nothing enforces it |
| `005` four rungs | 4 | Who decides a request has been satisfied? The machine can say which rung it reached, not whether what it built was wanted |
| `006` runaway programs | 4 | Which hands reach outside the machine? Only those can hang, and nobody has gone through the catalogue marking them |
| `010` the mind | 4 | Is there a sandbox to put a new mind in? *Somewhere it cannot reach the running one* is a claim nothing enforces |
| `010a` the loop | 2 | Does a tool call that hangs end the machine? Answered for hardware; a hand that hangs before storage exists is still open |
| `012` proving ground | 3 | Can growth be tested at all? Emulation runs a hundred times slower than the thing it is imitating |
| `013` the context | 5 | What happens if it drops the atom that explains atoms? Recovering requires knowing how |

---

## Next

**Nothing in this file is blocking except question 25**, and that one blocks the
interpreter alone — which is far enough off that it should be decided when the
interpreter is written rather than before, because the machine writing it will have
opinions the seed does not.

What was here before described the roadmap and the issue files as the next work, and
both were done long ago. What is next now is what the roadmap says: **first light**,
and then the machine installing itself.

Two things to be careful of while doing it, both learned the hard way:

**A summary that aggregates across a distinction its rows depend on will be wrong in
a way none of its rows are**, and it stays wrong for as long as people read the
summary instead of the rows. Three phases were reported complete on a reading of
"exists" that did not distinguish code which runs on the chip from code which proves
that code.

**And a stale answer is worse than an open question**, because it reads as settled.
Several things in this file were answered confidently and were wrong — that requests
arrive from outside, that the magnitude is moved by repetition, that what the machine
wakes holding is carved out of its working budget, that the compiler should optimise
whatever is furthest from ordinary. Each was believed, written down, built on, and
corrected. The corrections are in place rather than appended, and what each one used
to say is quoted beside it, so nobody re-derives the old version from a document that
merely stopped mentioning it.
