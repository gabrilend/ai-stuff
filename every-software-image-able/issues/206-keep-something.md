# 206 — Keep something

## Current behavior

**Reopened 2026-08-08. It can keep something. It cannot yet do so without
risking somebody else's data, and it does not know what kind of medium it is
writing to.**

Everything below this section holds and is tested. Three things were added on
top of it, and the first is a rule the rest follow from.

### Preserve by default; overwrite only when asked

**Data that was already on a device is never overwritten unless somebody
specifically asks for that.** Not a preference and not a courtesy — there is no
hardware limitation that forces destruction, so destroying is a choice, and a
choice made silently is the wrong one. The capability to overwrite exists, is
listed, and is named; it is simply never the default.

This closes `docs/008` question 28. `076` already refuses to adopt a claim mark
naming a different machine. What it lacked was any notion of a disk with **no**
mark, which it treated as available — and an unmarked disk is not an empty disk.
It is a disk this project has never seen.

### Find out what is there before deciding anything

The machine reads the medium's partition table and the filesystems inside it,
well enough to answer *which blocks are spoken for*. Every filesystem keeps that
answer somewhere — FAT in its allocation table, ext in its block bitmaps, NTFS in
its bitmap file — and reading one is far less work than writing one.

**This does not contradict step 5 below.** The seed still does not *build* a
filesystem, and still does not organise its own storage as one, for the reason
given there: that would decide on the grown machine's behalf how it organises
itself. Reading somebody else's filesystem is a different act with a different
purpose — not to use it, but to avoid destroying it.

### Three ways to get space, in order of how much they respect

| | How | What it costs | What it risks |
|---|---|---|---|
| Ask the firmware | while boot services live, have the firmware create a file and write into it | nothing — the firmware does the bookkeeping | FAT partitions only, and only before the machine leaves the firmware |
| Ask the filesystem | write the metadata to allocate a file, then use its blocks | writing filesystem structures correctly, which is where corruption comes from | getting the metadata wrong destroys the volume |
| Take unallocated space | parse the allocation map, write to blocks nothing has claimed | reading metadata only, which is much less code and much safer to get wrong | **the claim is invisible; anything that later mounts the volume will allocate over it** |

The third is the cheapest and the most dangerous, and the danger is worth stating
exactly, because it is not a corruption bug — it is a race with no lock.
Unallocated space is not free space. It is space nobody has claimed **yet**. The
filesystem does not know the machine is there, so the next operating system to
mount that volume will hand those blocks out, and the loss is silent on both
sides: the machine's data is gone, and the file that got allocated there holds
the machine's bytes.

It is legitimate on a volume nothing else ever mounts, and it should say out loud
that this is what it assumed.

**The first way deserves attention because it is nearly free.** The firmware can
already create and write files on the boot partition, correctly, and the machine
is standing inside it with boot services alive (`docs/003`, step zero). Borrowing
that is the same move as borrowing the display and the block reader — a durable,
visible claim with no filesystem-writing code at all.

### Where things go, by what the medium is made of

**Generated artifacts and frequently modified data go on rotating disks.
Flash — the delivery card, an M.2 drive — is kept for what is read often and
written rarely.**

The reason is wear, and it is arithmetic rather than taste. A flash cell endures
a bounded number of erase cycles before it stops holding charge — order of a
thousand for dense cells, order of a hundred thousand for the sparse kind. A
rotating disk has no equivalent write limit; it wears from spinning and seeking,
not from how many times a sector is rewritten. So a machine that continuously
rewrites its context, its logs and its notes will destroy a cheap flash device in
a bounded and predictable time, and will not harm a disk at all.

**The existing design already obeys this rule, and this explains why.** The
delivery medium is read-only by design (`docs/003`) — frequently accessed,
because the model is read from it, and never modified. That is exactly the
read-often, write-rarely case, and it was arrived at for a different reason.

The churn this policy is really about is named elsewhere: **the context
compaction** (`304`) writes atoms out whenever the machine sweeps its own
resident set, which is the most write-heavy thing the machine does that is not
moving in. Those writes belong on a disk.

### What this asks of enumeration

Knowing the medium's kind is now part of finding it, and the firmware's media
description does not say. It gives block size, block count, removable, read-only
— nothing about what the cells are made of. `107b` carries the enumeration and
this ticket carries what the answer is for.

The honest way to tell is to **measure rather than ask**: time reads at scattered
addresses. A rotating disk has to move a head, so its latency depends on how far
apart the addresses are; flash does not care. That is a physical property nothing
can misreport, it needs no protocol beyond reading blocks, and it is the same
method this project already used to find out whether a board's vector hardware
was real rather than trusting the board's name (`notes/023`).

---

Blocks and an extent, with no filesystem: the machine can build one if it
wants one, and building one into the seed would decide on its behalf how it
organises itself. It claims an extent, writes a mark, and finds that mark
again on a machine that has forgotten everything — and will not write over
the mark itself, which is the storage layer's version of the rule that a
machine must protect its own author.

A read-only medium refuses rather than pretending. That is the expected
case, not an exceptional one, since the seed is meant to be plugged into
machine after machine unchanged.

A mark naming a different device is reported rather than adopted: a disk
cloned from another machine carries one, and adopting it would mean two
machines writing over each other with nothing saying so.

**One defect worth keeping.** The mark was parsed with a pattern, and it has
hyphens in it — a hyphen in a Lua pattern is a quantifier, so the pattern
matched nothing, every field came back empty, and every claim looked like a
stranger's. It surfaced only because the refusal tried to name whose it was.
It is parsed by lines now.

Still to do, and belonging elsewhere: **moving in.** Writing the engine, the
weights and the text to claimed storage and handing control to that copy
needs a real machine to hand control to, and that is `601`.

## Intended behavior

Reading and writing persistent storage, so the machine can move in (`docs/003`)
and so the intent notes of `205` have somewhere to land.

## Suggested implementation steps

1. Reach storage through a standard class interface rather than a part-specific
   driver. This is not a preference — it is what makes the whole sequence
   possible. Operating an unknown device safely requires writing a note first, and
   writing a note requires storage, and the circle only opens because storage
   almost always answers to something standard. The seed therefore carries this
   one driver rather than expecting the machine to explore its way in.
2. **Target the interfaces real hardware uses, not the emulator's convenient
   one.** An emulator offers a paravirtual block device — a queue in memory and
   two registers — that is far simpler than anything on a real board, and taking
   it would mean the emulator loop and the hardware loop exercise different code
   from the first day. Emulators also model the real interfaces, so declining the
   easy one costs configuration rather than work. Write against those, and use the
   paravirtual device only as a known-good comparison when something is wrong.
2. Provide read and write of blocks, and a way to ask how large the device is and
   whether it can be written at all. A read-only delivery medium is the expected
   case (`docs/003`) and must be reported rather than discovered by a write that
   silently does nothing.
3. Provide enumeration: which storage devices exist, how large, how fast, whether
   removable. The machine chooses where to move in from this, and "least likely to
   be unplugged" cannot be judged without it.
4. Support the move: writing a copy of the engine, weights and text payload to
   chosen storage, and handing control to that copy. The window in which the
   machine exists in two places or neither is the one failure this design cannot
   help with, so it should be as short as the medium allows and its boundaries
   should be obvious in the code.
5. Do not build a filesystem — and note what that leaves to the machine, which was
   clarified 2026-08-21. **Installing itself so the card can come out is exactly the
   case this defers**, not an exception to it. Firmware starts a machine by finding
   a partition table, a filesystem it understands, and a file at one fixed name; the
   machine writes those when it is ready to, using knowledge assumed of the model
   the same way assembly encoding is assumed (`301`), and preferring a boot
   partition that already exists over creating one, because a wrong partition table
   loses every partition on the disk at once. Full shape in `docs/003`, under *who
   writes the bootable installation*.

   The original point stands unchanged: the machine can build one if it wants one. What the
   seed needs is blocks, an extent it owns, and the ability to find that extent
   again on the next boot.

### Added by the reopening, 2026-08-08

6. **Refuse to write to any device whose contents are not accounted for.** Make
   this the default in `076`, not a caller's responsibility. An unmarked device
   is refused with what was found on it, the way `077` refuses a destroying
   register with what that register does — a refusal that does not explain itself
   teaches nothing and gets worked around.
7. **Read partition tables and filesystem allocation maps**, enough to answer
   which blocks are spoken for. Read only. Getting this wrong should produce a
   refusal, never a write.
8. **Prefer having the firmware create the file** while boot services are alive.
   It is the only route that makes a durable, visible claim with no
   filesystem-writing code, and the machine is already inside the firmware.
9. **Classify each device as rotating or solid-state by measuring it**, and put
   churn on the rotating ones. Time reads at scattered addresses and see whether
   latency depends on distance; a head has to move and a flash cell does not.
10. **Say what was assumed, every time.** A machine writing to unallocated space
    is assuming nothing else will ever mount that volume. That assumption is
    frequently true and never checkable, so it belongs in the note beside the
    write rather than in somebody's head.
11. **Test against a device holding something.** Every existing check runs against
    blank files. The case that matters is a device with a real partition table and
    a real filesystem holding real files, where the requirement is that the files
    are all still there afterwards, byte for byte.

## Blocks

`205`, and all of phase 6. `602` in particular: a machine cannot choose where to
move in until it can tell what it would be moving onto.

## Blocked by

`203`. And `107b` for the enumeration itself, which is where the firmware hands
over the list of devices this ticket then has to judge.

## Related documents

`docs/003-datapath-the-bootstrap.md` — moving in, and why the seed stays a seed.
