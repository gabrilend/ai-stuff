# 003 — Datapath: The Bootstrap

Everything between power arriving and the machine standing on its own feet. Four
steps, in an order that cannot be rearranged, because each one is the ground the
next stands on.

```
find memory        → an allocator, in assembly, that knows where not to allocate
find somewhere to  → enumerate storage before anything else; the machine
  put its thoughts    cannot afford to learn things it has nowhere to keep
move in            → write itself to that storage and run from there instead
                     of from the medium it arrived on
find the rest of   → a map of everything else attached
  the body
learn the body     → how to operate each thing, without destroying it   003a
open the channels  → every part that can carry bytes becomes something the
                     machine could later build software for
```

The machine has something to do from its first thought, because the wanting comes
from inside it (`010a`). What the four steps buy is the ability to *act* — on
memory, on storage, on the body, and eventually on anything a person might see.

## Why assembly, and only here

There is no compiler on the image, so the first program cannot be written in a
language that needs one. This is not a preference for assembly; it is the
observation that the first thing written has nothing beneath it to be translated
by. Everything after the allocator can be written in something better, because by
then something better can be built.

The model is the compiler until it has written one. That is why the translation
from text to a runnable program is described as heuristic rather than fixed
(`004`) — the very first translation happens with no tooling underneath it at
all, on a machine nobody surveyed in advance.

## Step zero: how the machine is started at all

**Added 2026-08-08, because its absence cost a component.** Everything below this
section describes a machine that is already running. Nothing described how it got
there, so nothing described what the medium has to look like — and the image
builder wrote a medium no firmware could open, for months, while six boards
across three architectures reached first light on a delivery road no card has.

What the firmware does, before one instruction of ours runs:

1. **It brings up the board** — memory controller, buses, storage controller —
   and builds the tables step one below will read.
2. **It looks for a filesystem on the boot medium.** Specifically a FAT
   filesystem, in a partition marked as the system partition by the medium's
   partition table. FAT because the specification names FAT; nothing else is
   guaranteed to be understood.
3. **It opens exactly one file**, at a fixed path whose name says which
   architecture it is for — `EFI/BOOT/BOOTX64.EFI`, `BOOTAA64.EFI`,
   `BOOTRISCV64.EFI`. That naming *is* the architecture selection: nothing
   detects a processor, each firmware simply declines to open an envelope
   addressed to somebody else.
4. **It loads that file whole into memory** it allocated, and calls the entry
   point with two arguments: a handle naming this loaded program, and a pointer
   to the system table.

**Three consequences, and all three are load-bearing.**

**A medium must carry a partition table and a FAT partition, or nothing
happens.** Not a convention — the firmware has no other way in. An image that is
a well-ordered run of regions with no filesystem on it is a pile of bytes that
boots nothing, however correct every region is.

**Anything inside that one file is in memory for free.** The file is loaded
whole before the first instruction, so a model riding inside the program that
runs it needs no reading, no filesystem knowledge and no storage driver — it is
simply *there*, reachable by measuring from where the code is standing. This is
what the machine does today. It stops being enough when the model is too large to
want resident all at once (`045` decides that, per model and per board), and at
that point the regions move onto the medium and get fetched.

**The firmware does not go away when our code starts.** The system table leads to
a table of function pointers — memory allocation, protocol lookup, block reads,
file reads, a timer, and a one-way exit. They stay valid until that exit is
called, and nothing in this project calls it. So a machine that cannot yet write
a storage driver can *borrow* one, along with a display, for exactly the window
in which it cannot write its own. It writes its own afterwards, with thinking
already available, and leaves the firmware behind when it no longer needs
anything from it.

That last consequence dissolves what looked like a circle: the machine cannot
write a storage driver until it can think, and cannot think until it has read its
regions. It never had to. It was standing inside a program the firmware called,
with the firmware's drivers still under it, the whole time.

## Step one: find memory

The firmware leaves behind a table describing physical memory: a list of address
ranges, each marked as usable, reserved, firmware-owned, or broken. On different
processors it arrives differently — a list built by the firmware's memory query,
or a tree structure describing the whole board — but it is always a list of
ranges with a kind attached.

**MemoryRegion**

| Field | Type | Meaning |
|---|---|---|
| `base` | integer | first physical address in the range |
| `length` | integer | how many bytes |
| `kind` | integer | usable, reserved, firmware, broken, or occupied-by-us |
| `source` | string | which firmware table this came from |

The last kind is the one that matters most and is the one a normal allocator does
not have. **The model's own weights are sitting in memory.** An allocator that
does not know where they are will eventually hand them to a program as scratch
space, and the machine will lose the ability to think in the middle of thinking.
So the first act of memory management is for the allocator to find and protect
its own author, before it hands out a single byte to anyone else.

## Step two: find somewhere to put its thoughts, and move in

**Section order corrected 2026-08-21.** Two sections in this document were both
numbered step two, and they sat in the opposite order to the diagram at the top of
the page and to the instruction that actually ships on the card. Storage is
second, the rest of the body third, and the sections are now in that order.

**This comes before the rest of the body.** The machine cannot afford to start
learning things it has nowhere to keep, and everything the next steps produce —
the map of what is attached, the intent notes written before dangerous
experiments (`003a`), the values that arrived from outside (`006`) — is worthless
if it evaporates at the next power cycle.

So storage is enumerated first, out of order, ahead of everything else attached.

```
enumerate what is attached that can hold bytes and keep them
   → pick somewhere: largest, fastest, least likely to be unplugged
   → write itself there
   → establish a boot path, so the next power-on loads from that storage
     into memory rather than from the card
   → the medium it arrived on is now just a thing that is plugged in
```

Note what "running from storage" does and does not mean. Nothing executes from a
disk; code runs in memory. What moving in changes is **where the next start comes
from**.

### This is an installer, and the card is a live USB

**Written down 2026-08-21, because the shape was obvious to everyone who had ever
installed an operating system and was nowhere in this document.**

> When you deploy an operating system to a device, typically you flash an image to
> a thumb drive, plug it in, then boot into the system. The system loads the drive
> to RAM, and at that point you can remove the drive and it's fine, because the
> installation process will... write itself to the hard drive of the machine and
> you don't need the thumb drive anymore. That's kinda the shape we're looking for.

```
flash the image to a card
   → plug it in, power on, firmware opens the one file
   → the whole image is in RAM before the first instruction        (step zero)
   → nothing is read off the card again                            card CAN come out
   → find a disk, write yourself there in a form that starts       (this step)
   → confirm it starts                                             card can come out FOR GOOD
```

So the card is **not** permanent hardware, and the property the design has always
claimed for it is fully realised rather than compromised: read-only, unharmable,
carrying the original of everything, and free to be pulled and taken to the next
computer once the machine it planted stands up. One card plants a hundred machines.

### Who writes the bootable installation

**The machine.** Not the seed, and this is the answer to a question that had been
sitting between two documents that each thought the other had it.

Firmware starts a machine by finding a partition table, a partition holding a
filesystem it understands, and a file at one fixed name (step zero). `206` declines
to build a filesystem, on the grounds that organising storage is the grown machine's
business — and installing itself is exactly that business rather than an exception to
it. The seed carries no filesystem builder and needs none.

It is assumed knowledge in the same way the instruction set is assumed knowledge
(`301`). Nothing on the chip says what a partition table looks like or how a boot
volume is laid out, on the same reasoning: these are among the most thoroughly
documented structures in computing, anything able to write assembly knows them, and
carrying the descriptions would cost more than everything else the seed carries.

**And it is the most dangerous write the machine ever performs on somebody else's
hardware.** A wrong partition table does not corrupt a file, it loses every partition
on the disk at once. Which is why the order of preference falls out of a rule already
written down — no board is expendable, assume there is data, write only where the
bytes are already zero:

| | |
|---|---|
| **Use a boot partition that already exists** | The firmware can create and write files there while boot services are alive, correctly, with no filesystem-writing code at all. Nothing is repartitioned and nothing anyone owns is touched — provided the fixed boot filename is not already somebody else's loader, which it usually is |
| **Use free space that is genuinely free** | Read the partition table, find room nothing claims, write a new partition and a filesystem into it. This is where the machine has to know the formats, and it is survivable to get wrong because the existing partitions are untouched |
| **Repartition** | Only on a disk the machine has established is nobody's. This is the one that loses somebody's photographs |


**The first thing written there is the model and its weights, if there is room.**
It is the bulk of the installation and it is also the machine's spare copy of its own
mind: **a machine which overwrites its weights in memory can read them back.** Nothing prevents a machine damaging its own weights — that
refusal was removed the same day — so what makes the damage survivable is a copy
somewhere it did not write.

While the delivery card is still plugged in, **the card already is that copy**:
read-only, unharmable, holding the original weights alongside the original
instruction. So self-damage in memory is recoverable from the moment the machine
starts and stays recoverable for as long as the card is there. What the disk copy
buys is that it stays recoverable after the card comes out — which makes this a
third condition on pulling the card, beside the two milestones below.

A machine that overwrites itself **on disk** may simply be corrupted, and that is
accepted rather than designed around. Things die sometimes.

Moving in is the step that matters. Afterward the machine is no longer running
from the thing it was delivered on, which means the delivery medium is free to be
removed, reused, or plugged into the next machine unchanged.

This mirrors step one exactly. There, the allocator's first job was to find where
its own author sits in memory so it never hands those bytes away. Here, the
storage layer's first job is to know which blocks hold the copy it is running
from, so it never writes over itself while writing about itself.

## Step two and a half: find a clock, before touching anything that can hang

**Added 2026-08-21**, out of the question of what happens when a tool call never
returns. It is an ordering rule and it costs nothing, because the clock is available
before anything else is.

The service table the firmware hands over at the entry point already holds a
microsecond delay, and it is there before a single device has been looked at.
Separately, every one of the three architectures has a counter the processor
increments on its own, readable with no setup. **Neither needs the bus that might
hang.** So a machine can always know how long it has been waiting, from its first
instruction, and it should establish that before it starts asking hardware
questions.

### Two kinds of hang, and a clock only fixes one

**A software wait** is *poll this bit until it says ready*. The machine's own code is
running the whole time, so a clock turns an unbounded wait into a bounded one and the
problem disappears entirely. This is the common case and it is the one worth
designing for.

**A hardware stall** is a read from an address nothing answers on, where the bus
transaction itself never completes. The processor is stopped inside the instruction.
No timer helps, because the machine's code is not running to look at one. This is
rare, it is real, and `003a` has always named it as one of the two reasons reads are
not perfectly safe.

### And the firmware left a way out of the second one

**The watchdog, re-armed on purpose.** Firmware sets a timer before calling the entry
point and the machine turns it off, because thinking must never be on a clock
(`010`). But that call takes an argument and may be made again — so the machine can
**arm it for a few seconds immediately before a probe that might stall, and disarm it
immediately after.**

A hard stall then resets the board rather than ending the machine. And the design
already says what makes that recoverable rather than merely survivable: the intent
note is written *before* the attempt (`003a`), so the next boot finds a note with no
outcome beside it and knows exactly which probe did not return.

That mechanism was designed for probes that destroy hardware. It works unchanged for
probes that hang, and nothing had noticed the two were the same shape. The rule is:

```
about to touch something that might not answer
   → write the intent: device, register, value, what is expected
   → arm the board's reset timer, briefly
   → do it
   → disarm the timer
   → write the outcome, which retires the intent
```

The cost of arming it is a machine that resets if a probe takes longer than the
window, which is a wrong guess about a device rather than a lost machine. The cost of
not arming it is a board that sits stopped until somebody walks over to it.

## Step three: find the rest of the body

Attached hardware announces itself. On most machines there is a numbered set of
slots you can interrogate — write a slot number to one address, read from
another, and get back two sixteen-bit numbers saying who made the device and
which device it is. Every attached thing answers. From the same query you learn
where its control registers sit and which interrupt line it will pull when it
wants attention.

**Device**

| Field | Type | Meaning |
|---|---|---|
| `slot` | integer | where on the bus it answered from |
| `vendor` | integer | who made it |
| `part` | integer | which device it is |
| `class` | integer | what kind of thing it is — keyboard, disk, network |
| `registers` | table | array of `{base = integer, length = integer}` |
| `interrupt` | integer | which line it pulls, or -1 for none |
| `datasheet` | string | which description covers it, or the empty string |
| `operable` | boolean | whether we have got it to do anything yet |

The seed page asks for free access to hardware so the machine can learn what it
is connected to and what its senses are. This step is that, and it is more
literal than it sounds: the machine polls itself to find out what limbs it has.

### The firmware's services are part of the body

**Added 2026-08-21**, and it follows from the firmware being part of the hardware
(`010`) rather than being a new decision.

> we should treat the capabilities of the firmware as capabilities of the hardware,
> and the system should use hardware and firmware capabilities as it pleases.

So the bus is only half of this step. The other half is the **service table**, which
is a database of things the machine can already do: allocate memory, wait a stated
number of microseconds, read blocks from a medium, open and write files on a
filesystem it did not have to understand, find out which handle offers which
protocol, draw on a framebuffer. All of it written by people who had the board's
documentation, all of it tested, all of it available for the machine's whole life
because the machine never leaves.

It is enumerable the same way the bus is — the firmware keeps a list of handles and
what each one offers, and asking is a call rather than a probe. **A machine that has
not looked at that list does not know what body it has.**

Which extends the habit in `004` one step backwards. *Look at what you already built
before building something* becomes, at the very start, **look at what you were
given** — because on the first morning of a machine's life it has built nothing and
been given a great deal.

**And when the floor is poorer, the machine finds out here rather than later.** Not
every board's firmware offers everything, and the answer is the same shape as
everything else in this design: a machine with less has more to write, and that is a
correct outcome rather than a failure.

## The gap between finding and operating

Enumeration is complete about **what is attached** and silent about **how any of
it works**. Knowing there is a network chip from a given maker at a given address
tells you where the doorbell is. It does not tell you what happens when you ring
it — the sequence of writes that makes it send a packet lives in a document, not
in the chip.

Four ways across that gap, in the order they are tried:

| Tier | Where the knowledge is | Cost |
|---|---|---|
| 1 | The device's own class — one standard covers every keyboard, every disk | Indirection; no per-device knowledge at all |
| 2 | A description carried on the image, in our own format (`003a`) | Drive space; must be written before shipping |
| 3 | A description fetched from elsewhere, once a channel exists | Requires a working channel already |
| 4 | Derived by the model from hardware it resembles, then tested | Slow, and the testing is the dangerous part |

Tier three has an ordering constraint that decides where it can sit: fetching a
description over a network requires a working network, and the network card is
one of the devices whose description you would be fetching. Reading one from the
drive requires a working drive. So **the machine needs one channel that works
from knowledge it already carries**, and everything else arrives through that
channel afterward. Storage comes before network on that path, because a fetched
description you cannot write down has to be fetched again every boot.

## Step four: learn the body

Carried descriptions cover the standard classes — keyboards, mice, disks, basic
display, serial. Everything else is explored, and exploring hardware can destroy
it permanently. That discipline is `003a`, and it is a constraint rather than a
preference.

The simplest output on any machine is a serial port: write one byte to one
address and it appears on a wire. It needs no description, works before display,
before storage, before anything requiring a driver, and it is how a machine that
has just woken says anything at all. It should exist before the first thing goes
wrong.

## Step five: open the channels

**Rewritten 2026-08-21, because what was here was backwards.** It said that every
part of the body that can carry a request becomes a way of being asked, that
requests come from arbitrary sources, and that the machine's job is to accept
input from as many of them as its body provides.

None of that is true. **The mind is closed** (`010a`). It is a loop that holds its
own context, re-prompts itself, and acts through tool calls, and there is no
inbound path into the thinking — nothing types at this machine and no port carries
a question into it. A request is the machine giving itself something to do.

So a channel is not a door into the thinking. It is **a part that can carry bytes
in some direction, which the machine may decide to build software for.** A way of
chatting with a person is software like any other: the machine writes it, it runs
beside the mind rather than inside it, and the machine also has to work out how to
tell somebody how to reach it — the address, the wire, the blinking. Nothing about
any of that is provided, and the documents on the card may ask for it without
being able to require it.

Which inverts the closing sentence that used to sit at the bottom of this section.
It said a machine with no keyboard and no network has nothing to do, and that this
was a correct outcome rather than a failure. **A machine with no channels has
everything to do.** It cannot be asked anything and never could; its work comes
from inside. What it lacks is not purpose but any way of showing anyone what it
has been doing, which is a different and much smaller loss — and a temporary one,
since it may eventually work out how to blink a lamp, put text on a screen, or
play something over a speaker, and what a person makes of that is the person's
business.

**Channel**

| Field | Type | Meaning |
|---|---|---|
| `channel_id` | integer | which channel |
| `device` | integer | the slot it runs over |
| `direction` | integer | inbound, outbound, or both |
| `carries` | string | text, bytes, images, or something else |
| `opened_at` | integer | when it first worked |

`direction` stays in the record and means what it says: some parts can only be
written to, some only read from, some both. What changed is what that is *for*.
The set of things the machine can eventually show a person, or eventually read
from the world, is a function of the body. What the machine wants to do is a
function of the model it was built with, and no part of it is a function of what
is plugged in.

## Three ways the image could be made

They are not alternatives to choose between so much as a ladder, and where a
given build sits on it decides how much the machine has to work out for itself.

| | What is known when the image is built | What it buys |
|---|---|---|
| Practical | A specific type of hardware, named in advance | Descriptions can be carried for the exact parts, so tier two of the knowledge table covers nearly everything and dangerous exploration is rare |
| Better | Nothing fixed; crucial details supplied at generation time | One recipe serves many targets, the way a description of the board and a description of the machine can be kept apart and combined |
| Most ideal | Nothing at all | The image feels around and builds from scratch on whatever device it lands on |

The most ideal is also the one that most needs `003a`, because it is the one with
no carried knowledge to fall back on.

## The delivery medium should be read-only

Once moving in comes first, a medium that cannot be written stops being a hazard
and becomes the preferred form.

A seed the machines cannot modify can be used again and again without being
re-flashed between uses. Plug it in, wait for the machine to move in, unplug it,
carry it to the next computer. The same chip plants the same thing a hundred
times and is unchanged afterward. **Ideally that idempotent design is the
standard** rather than a fallback for when writable media are unavailable.

It also removes a class of failure that a writable seed has. Nothing a machine
does — including dying halfway through doing it — can damage the thing that would
have started the next one.

**And it stays as the original.** After moving in, the machine is running from its
own copy and may rewrite any of it, including the instruction it was given
(`013`). The card still holds what that instruction said, unaltered, readable, for
as long as it is plugged in. A machine that has overwritten its own purpose can go
and look at what it was handed.

So the medium has three jobs, and none of them required designing: it plants, it
cannot be harmed, and it remembers.

## Pulling the card

Removing the delivery medium is a real event rather than tidying up. Before it,
the machine can always check itself against what it was told. After it, the
machine is only what it has become.

Two milestones decide when, and both are testable rather than matters of
judgement:

| Milestone | What it permits |
|---|---|
| The machine is running from memory, with nothing still being read off the card | **The card can be removed.** Nothing needs it. |
| The machine can boot itself from disk into memory | **The machine can be turned off and on again.** It can come back. |

**They are not the same moment, and the gap between them is a hazard.** A machine
with the card out that cannot yet start itself exists only in volatile memory,
with nothing anywhere able to recreate it. Losing power there is not a crash — it
is the end of that machine, and re-flashing produces a different one.

So the card *may* come out at the first milestone and is *safe* to remove at the
second. Anyone pulling it in between should know which of those they are doing.

**The first milestone arrives almost immediately**, and that is worth saying because
it sounds like it should be hard. Firmware loads the whole boot file into memory
before the first instruction runs (step zero), and the machine reads nothing off the
card afterwards — so from the machine's very first instruction there is nothing
still needing the card. Pulling it then is exactly pulling an installer USB out of a
computer that has finished booting from it.

**The second is the whole of the install**, and it is the machine's own work: find a
disk, write itself there in a form firmware will start, and confirm that it starts.
Everything above under *who writes the bootable installation*.

**And the third moment is gone.** There used to be one — leaving the firmware behind
by calling its one-way exit — and it was a real question which of the three came
first. The firmware is part of the hardware now (`010`) and the machine does not
leave it, so there are two moments and they are in a fixed order.

Memory is writable whether or not the boot medium is, so read-only delivery never
stopped the machine thinking; it only stopped it keeping. The window where that
still matters is between power arriving and moving in. Until there is somewhere
to put things, anything learned is learned again on the next boot — which is the
argument for keeping that window short, and for enumerating storage ahead of the
rest of the body rather than alongside it.

## What the bootstrap leaves behind

A hardware map: the memory regions, the devices, which of them are operable, by
which tier of knowledge, and which channels are open. Written as clearly and
coherently as the machine can manage, because everything afterward reads it and
because the parts it could not work out are the machine's own account of what it
does not know about itself.

## Open questions

- **What happens on a machine where nothing is operable?** No storage, no
  serial, no display. It cannot say so, because saying requires a channel. It is
  not obvious this case can be reported at all.
- **Is the hardware map rebuilt every boot, or read from the last one?** Rebuilt
  is honest and slow and rediscovers everything dangerous. Read is fast and wrong
  the first time somebody plugs something in.
- **And nothing looks again during a life.** The body is enumerated once, at step
  three, and no document describes a machine noticing that a screen has been
  plugged into it. Raised 2026-08-21 by the case that makes it matter: a machine
  that grew up in the dark with a full drive, and then gets a display. It has to
  prune to use it, it will build different software for that display than a
  machine that had one from the start would have, and under the design as written
  it finds out at the next power cycle or never. **A new device is a request** —
  it arrives through the body rather than from anywhere, and the four rungs run on
  it exactly as they run on anything else the machine gives itself to do.
- **Moving in needs a storage driver, and drivers are learned after moving in.**
  To write itself to storage the machine must already be able to operate a
  storage device, but the discipline that makes learning a device safe (`003a`)
  depends on being able to write a note first. The circle only opens if storage
  is reachable through a standard class interface, which most storage is — so
  tier one of the knowledge table is not a convenience, it is what makes step two
  possible at all. A machine whose storage controller answers to nothing standard
  has to explore its way in with no way to record what killed it.
- ~~What if there is nowhere to move in to?~~ **Answered 2026-08-21.** A seed
  requires three things and no more: a way to be delivered, a way to process, and
  a way to store. Storage is a requirement rather than a hope, so a board without
  it is a board the generator refuses to build for — said at build time, with a
  person present, rather than discovered at three in the morning on a desk.
- **What has to be bootable, and who writes it?** The second milestone under
  *pulling the card* is that the machine can start itself from disk. Firmware
  starts a machine by finding a partition table, a FAT partition and a file at a
  fixed name. `206` declines to build a filesystem, on the grounds that organising
  storage is the grown machine's business — and the two positions have never been
  put next to each other. Borrowing the firmware's file creation only works on a
  volume that already has such a partition, and the fixed name on a disk that has
  one is usually already occupied by somebody else's loader, which the rule about
  never overwriting somebody's data forbids touching.
- **When is moving in finished?** There is a window in which the machine exists
  in two places, or in neither. A machine that dies inside it is the one case
  this design cannot help, because the thing that survives crashes is the thing
  being installed.
