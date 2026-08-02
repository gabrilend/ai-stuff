# 003 — Datapath: The Bootstrap

Everything between power arriving and the machine being able to be asked for
something. Four steps, in an order that cannot be rearranged, because each one
is the ground the next stands on.

```
find memory        → an allocator, in assembly, that knows where not to allocate
find somewhere to  → enumerate storage before anything else; the machine
  put its thoughts    cannot afford to learn things it has nowhere to keep
move in            → write itself to that storage and run from there instead
                     of from the medium it arrived on
find the rest of   → a map of everything else attached
  the body
learn the body     → how to operate each thing, without destroying it   003a
open the channels  → every part that can carry a request becomes one
```

Only after the fourth does the machine have anything to do, because a request has
to arrive through something.

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

## Step two: find the body

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

## Step two: find somewhere to put its thoughts, and move in

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

Moving in is the step that matters. Afterward the machine is no longer running
from the thing it was delivered on, which means the delivery medium is free to be
removed, reused, or plugged into the next machine unchanged.

This mirrors step one exactly. There, the allocator's first job was to find where
its own author sits in memory so it never hands those bytes away. Here, the
storage layer's first job is to know which blocks hold the copy it is running
from, so it never writes over itself while writing about itself.

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

## Step three: learn the body

Carried descriptions cover the standard classes — keyboards, mice, disks, basic
display, serial. Everything else is explored, and exploring hardware can destroy
it permanently. That discipline is `003a`, and it is a constraint rather than a
preference.

The simplest output on any machine is a serial port: write one byte to one
address and it appears on a wire. It needs no description, works before display,
before storage, before anything requiring a driver, and it is how a machine that
has just woken says anything at all. It should exist before the first thing goes
wrong.

## Step four: open the channels

Every part of the body that can carry a request becomes a way of being asked.
Requests come from arbitrary sources; the machine's job is to build the
capability to accept input from as many sources as its body provides.

**Channel**

| Field | Type | Meaning |
|---|---|---|
| `channel_id` | integer | which channel |
| `device` | integer | the slot it runs over |
| `direction` | integer | inbound, outbound, or both |
| `carries` | string | text, bytes, images, or something else |
| `opened_at` | integer | when it first worked |

The set of possible requests is a function of the body. A machine with a keyboard
can be asked by typing. One with a network card can be asked from elsewhere. One
with a camera can be shown things. One with neither has nothing to do, and that
is a correct outcome rather than a failure.

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
- **Moving in needs a storage driver, and drivers are learned after moving in.**
  To write itself to storage the machine must already be able to operate a
  storage device, but the discipline that makes learning a device safe (`003a`)
  depends on being able to write a note first. The circle only opens if storage
  is reachable through a standard class interface, which most storage is — so
  tier one of the knowledge table is not a convenience, it is what makes step two
  possible at all. A machine whose storage controller answers to nothing standard
  has to explore its way in with no way to record what killed it.
- **What if there is nowhere to move in to?** Every step after step two assumes
  step two finished. A machine with no writable storage attached could refuse to
  continue, or could run permanently inside the pre-move-in window and relearn
  itself on every boot. Neither is written.
- **When is moving in finished?** There is a window in which the machine exists
  in two places, or in neither. A machine that dies inside it is the one case
  this design cannot help, because the thing that survives crashes is the thing
  being installed.
