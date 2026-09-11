# 107b — Read the card

A sub-issue of `107`. That ticket lists ten things the driver must do in order,
and this is the rest of step one — what the machine keeps from the firmware, and
how it reaches anything that is not already in its hands.

`107a` was steps five through eight.

**Scoped down on 2026-08-08, before any code was written.** It began as "read
regions off the medium by block number," and the arithmetic says that is not
needed yet. What is left here is two small things the machine needs regardless,
and a larger thing that waits for a model big enough to require it.

## Current behavior

**The machine already reaches everything it needs, by riding inside the one file
the firmware loads.**

The payload carries the model, the starting text and the carried randomness
sixty-four kilobytes past its own first instruction (`029`'s appending), and
finds each by measuring from where the code is standing. Firmware loads the whole
file into memory before the first instruction runs, so the data is simply
*there*. No filesystem, no block numbers, no reading. That is the arrangement
that said six words on 2026-08-07.

**The two small things are done on the first architecture, 2026-09-10. What
remains here is the storage, and the deferred layout work.**

**The machine keeps the firmware's name for itself, and proves it is the right
one.** The entry point is called with the image handle in `%rcx` and the system
table in `%rdx` — the Microsoft x64 convention, which UEFI uses on this
architecture. Both are now kept: the table in a register as before, the handle in
a slot of the work area, stored before the first mark is said because saying
anything is a call into firmware and the console's own first argument also
travels in `%rcx`.

It is then spent immediately, on the only question about it that has a checkable
answer — *firmware, where did you put me?* The loaded-image record it reaches
says where this program was placed and how long it is; the machine knows where it
is standing because it measured. Those two agreeing is the difference between a
saved handle and the right saved handle, and a stale register fails it loudly
rather than answering confidently about another program. The record's device
field is said aloud in the same breath, which is the card, and the card is the
one device a machine looking for somewhere to live must not move into.

**The firmware's five-minute timer is turned off.** UEFI starts a watchdog before
entering the program and resets the machine when it expires — with no message, no
pattern, and no relationship to what was being thought about. It is now disarmed
by one call with a nought timeout, immediately after first light is said, so that
a firmware which faults on the call leaves a line behind saying how far it got.

**Where it is done is not where this ticket said it would be.** The design below
says the waking code, before the hand-over. The waking code is not on the boot
path: firmware enters the assembled machine directly, and the processor-selection
payload is a separate program that says what it found and halts. So the disarming
lives at the entry point firmware actually calls. **When selection joins the boot
path it becomes that entry point, and both of these move to it** — they belong to
whatever runs first, not to any particular file.

The two demonstration payloads — the one that says a line on screen and serial,
and the one that names the processor — still discard the handle and still leave
the timer armed. Both halt within milliseconds, so neither can reach five
minutes, and giving them a handle neither will ever ask a question with would be
two more places for the same instruction to be wrong.

**The three architectures are not equal here.** This is the first one only. The
handle arrives in a different register on each, and the three firmwares already
hand over three different ways (`401`, and `notes/023`).

## What is built now

**Keep the image handle.** One line in the waking code, saved into a register
that survives, and passed to the driver alongside the system table. Everything
the firmware can be asked about *this program* starts from it.

**Turn the watchdog off.** `SetWatchdogTimer(0, 0, 0, NULL)`, through the boot
services table, in the waking code before the hand-over so that everything after
it is covered rather than only the driver. This modifies what `402` built. It
prevents a failure that is undiagnosable after the fact — a reset at five minutes
looks like anything at all.

**Find the storage.** Added 2026-08-08, and it is the reason this ticket is on
the near path rather than waiting.

`206` built everything about keeping something except the part that touches a
device: extents, a claim mark that survives a power cycle, a refusal when the
medium is read-only, and a refusal to adopt a mark naming a different machine —
28 of 28. But its device list is a **parameter**, and its own comment says why:
*on the metal they are a controller driver, hosted they are a file, and what this
file holds is the part that is the same.* Hosted, files fill it. On the metal
nothing does, and no assembly in this project touches storage at all.

**The controller driver does not have to be written.** The firmware enumerated
every storage device when it started, and hands the list over on request:
`LocateHandleBuffer` for every handle speaking the block protocol, then
`HandleProtocol` on each for its reader. Each reader carries a media descriptor,
and those fields are nearly one-to-one with what `076` asks for:

| What `076` wants | What the media descriptor says |
|---|---|
| `blocks` | the last block, plus one |
| `block_bytes` | the block size |
| `writable` | the read-only flag |
| `removable` | the removable-media flag |
| `read`, `write` | the protocol's own two functions |

So filling that seam is a translation rather than a driver, and the same three
calls serve three separate needs: finding a home to move into (`602`), reading
regions when a model stops fitting (below), and letting `206`'s tested machinery
run against something real for the first time.

**Enumeration is read-only and therefore safe to build first.** A wrong list is a
wrong answer the machine can look at, not a silence — which is `107`'s test for
what belongs in the seed. Choosing among the list, and writing to what was
chosen, is where the danger is, and that is `206`'s, reopened.

**Two things the list must carry that the firmware does not say.**

**What each device is made of.** The media description gives block size, block
count, removable and read-only, and nothing about the cells. The machine needs to
know rotating from solid-state, because churn belongs on disks and flash is kept
for what is read often and written rarely (`docs/008` question 29). **Measure it
rather than ask**: time reads at scattered addresses, and see whether latency
depends on how far apart they are. A rotating disk moves a head; flash does not
care. Nothing can misreport a physical property, it needs no protocol beyond the
block reads already being built, and it is the method that established whether a
board's vector hardware was real rather than trusting the board's name.

**Which device the machine booted from**, so it can be told apart from the rest.
That comes from the loaded-image structure the saved handle reaches, and it is
free once the handle is kept.

## What waits, and what will ask for it

**Not the mechanism any more — only the layout.** Finding storage brings the
lookups and the block reads forward, so what still waits is narrower: the table
of contents, deciding where regions live on a medium, and the fetching that reads
them. `docs/008` question 23 answers *how*; this records *when*.

**When is arithmetic, and the arithmetic already exists.** `045` decides which
rung is affordable for a given model on a given board, and `046` reports it:

| Model | Total | On a small single-board computer |
|---|---|---|
| the test model | 2.0 MB | everything in memory |
| very small — 12 layers of 768 | 218 MB | everything in memory |
| small — 22 layers of 2048 | 680 MB | **the hot parts in memory, the rest read in place** |
| medium — 32 layers of 4096 | 6.21 GB | does not fit at all |

**"The rest read in place" is the sentence that opens this work.** Until a build
selects that strategy, everything fits in memory at once and riding inside the
one file is not a compromise — it is fewer moving parts doing the same job.

Note that riding inside the file is a **stronger** requirement than fitting in
memory: it demands everything be resident at boot, before the machine has decided
anything, including weights a given thought never touches. So the strategy
report is the trigger, and it is already computed at build time — the builder
calls `strategy` and refuses a model that does not fit at all. It can equally
refuse to build a riding-inside image when the strategy chosen is a partial one,
which turns this from a thing somebody must remember into a thing the build says.

## What this uncovered, 2026-08-08

Found by asking what a block number would actually name, before code was written
against the assumption — the cheapest this class of discovery gets.

**The image the builder produces cannot be booted by any firmware.** `089` lays
down five regions at block boundaries and writes nothing else: no partition
table, no filesystem, no file. UEFI firmware opens one file on a FAT filesystem
at an architecture-specific path, and there is no such file in a built image.
Nobody noticed because the builder's seam check compares its offsets against what
the *engine* expects, and both sides are right — the engine is not what has to
find the first byte. The firmware is, and it was never asked.

**The emulated boards have never exercised a medium.** `018`'s firmware road
hands the emulator `fat:rw:<directory>`, so the emulator synthesises a FAT
filesystem out of a host directory as firmware asks for it, and no disk image is
built at any point. The reason was good — it avoids rebuilding an image for
something that changes every build — but it means the built image has never been
the thing under test. Recorded in `notes/023`.

**Neither is this ticket's to fix.** Both belong to `502`, which now has to
produce a medium something can boot from. That is required whether regions ride
inside the file or sit in blocks beside it, so it is on the near path either way.

## How it is proved

**The handle**: use it for one real lookup — the loaded-image protocol —
requiring success, a device handle that is also non-zero, and the place the code
is standing to fall inside the span firmware reports for this program. A saved
register that is never used proves nothing about whether the right thing was
saved. Checked in both directions: saving the wrong register instead makes the
lookup refuse, the standing place fall outside the span, and the machine stop
before it thinks, rather than thinking with a handle that names something else.

There is a second, cheaper check beside it, on the emitted text rather than the
running machine: the handle must be stored **before the first call into
firmware**. A machine that stores it one instruction too late boots, speaks, and
is wrong — it would keep a console pointer and call it the program's name.

**The watchdog**: two claims, and they are different. That firmware accepted the
disarming, which is the status it gives back. And that the machine is still there
afterwards, which is an emulated board sitting for longer than the five minutes
the timer would have run. An armed watchdog does not look like silence — the
board resets, firmware starts over, and the payload runs a second time from the
beginning — so the symptom is the machine saying *first light* twice, and
counting how many times it said it is the whole test.

The sit is behind a flag, because it costs its own duration and proves a thing
that does not change once proved.

## Suggested implementation steps

1. Save the handle. One line, and everything the firmware can ever be asked about
   this program starts from it.
2. Turn the watchdog off, and prove it with the six-minute sit.
3. **Enumerate and say what was found, and stop there.** A machine that lists
   every attached device with its size, block size, and whether it is removable
   or read-only is already useful, is entirely read-only, and is the thing to
   look at before deciding anything. Narrate the whole list over the console —
   this is the first time anybody sees what a board actually has.
4. **Read a block.** This proves the protocol with nothing at risk, and it is
   what everything above the firmware then builds on.
5. **Classify each device by timing scattered reads**, which needs only step 4
   repeated at chosen addresses. Report the measurement alongside the verdict
   rather than only the verdict, so a wrong classification can be argued with.
6. Hand the enumerated, classified list to `076` and let its tested machinery
   run against something real — the claim, the mark, the read-only refusal. That
   code has never met a device.
7. **Write nothing from this ticket.** Every step above reads. The first write to
   a device belongs behind `206`'s refusal to touch anything whose contents are
   not accounted for, and that refusal is `206`'s to build.
8. First architecture only, then the other two, since the register holding the
   handle and the convention for reaching boot services both differ (`401` already
   found the three firmwares hand over three different ways).
9. Leave the region-layout work alone until a build selects a partial strategy.

## What happens to the list, once it exists

Answered 2026-08-08 and held in `206`, reopened, so this ticket stays about
reaching the firmware rather than about judgement.

The short form: **data already on a device is never overwritten unless somebody
specifically asks.** An unmarked disk is not an empty disk, so the machine reads
partition tables and filesystem allocation maps — read only — to find out what is
spoken for before deciding anything. Space is then obtained by having the
firmware create a file, by allocating one through the filesystem, or by taking
unallocated blocks, in that order of preference, and the last one is a race with
no lock because unallocated space is space nobody has claimed *yet*.

**Which means writing can wait and this ticket does not need it.** Everything
here — the handle, the watchdog, the enumeration, the classification, reading a
block — touches nothing. The first write belongs behind `206`'s refusal.

## Open questions, deferred with the work

These are real and are parked because the thing they are about is parked. They
should be answered when a model stops fitting, not before.

1. **What is a built image, once regions live outside the boot file?** Firmware
   needs a partition table and a FAT partition regardless. Where the other
   regions go has three answers — raw blocks outside the partition named by
   number, ordinary files inside it named by name, or one file with offsets into
   it — and they need different work in the builder, the driver, and the boards.
2. **Partition-relative or card-absolute block numbers**, if regions go in raw
   blocks? The handle a machine boots from is usually the partition rather than
   the whole medium, so its block zero is not the medium's.

## Blocks

`602`, which cannot let a machine find storage and move in until something can
find storage. `206`'s metal half, whose device list has never been filled by
anything but a file. And the deferred layout work, which a machine carrying a
model too large to hold will need.

## Blocked by

Nothing. Steps one through eight of `107` are done on the first architecture, and
the firmware call convention this needs is demonstrated by `069`.

## Related documents

`docs/008-open-questions.md` — question 23, whose answer this defers rather than
contradicts.
`src/045-memory-budget.info.md` — the arithmetic that decides when the deferred
half is needed.
`notes/023-what-the-emulator-lies-about.md` — the fabricated filesystem, and the
three firmwares handed over three different ways.
