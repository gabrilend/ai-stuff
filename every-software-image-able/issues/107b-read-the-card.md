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

**Two things are missing that have nothing to do with regions.**

**The image handle is discarded at the first instruction of every payload.** The
entry point is called with the image handle in `%rcx` and the system table in
`%rdx` — the Microsoft x64 convention, which UEFI uses on this architecture.
`069`'s `_start` saves `%rdx` into `%r14` and never touches `%rcx`. Nothing needs
it yet, which is exactly why it is worth keeping now: everything that will ever
ask the firmware about *this program* starts from that handle, and a lookup
handed whatever the firmware happened to leave in a register does not fail
loudly. It looks up a handle that is not this program's.

**The firmware's watchdog is armed and nobody turns it off.** UEFI starts a
five-minute timer before entering the program. A machine that thinks for longer
resets — with no message, no pattern, and no relationship to what it was doing.
Every run so far has been far shorter than five minutes, so it has never fired.
A real model on a real board will.

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

**The handle**: assert it is non-zero where the driver receives it, and use it
for one real lookup — the loaded-image protocol — requiring success and a device
handle that is also non-zero. A saved register that is never used proves nothing
about whether the right thing was saved.

**The watchdog**: let an emulated board sit for six minutes without resetting.
Slow, run once, and worth it — after this the failure it prevents can never be
diagnosed from its symptoms.

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
