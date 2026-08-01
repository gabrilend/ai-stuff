# 003 — Datapath: The Bootstrap

Everything between power arriving and the machine being able to be asked for
something. Four steps, in an order that cannot be rearranged, because each one
is the ground the next stands on.

```
find memory        → an allocator, written in assembly, that knows where not to allocate
find the body      → a map of what is attached
learn the body     → how to operate each attached thing, without destroying it   003a
open the channels  → every part of the body that can carry a request becomes one
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

## Where anything permanent goes

**The medium the image was delivered on.** It is the one place certain to exist,
because the machine is running from it, and it is where everything permanent goes
until somewhere better is found — the intent notes written before dangerous
experiments (`003a`), the values that arrived from outside (`006`), and this map.

So enumerating attached storage is an early concern rather than a later one.
Search, find a better place to put things, and put them there.

```
what did I boot from?                       → the store, provisionally
what else is attached that can hold bytes?  → enumerate all of it
which is largest, fastest, least likely to leave?
   → move what has accumulated so far
   → keep writing there
```

The image may be on removable media, or may not, and the machine cannot assume
either. Finding somewhere better is therefore survival rather than tidiness: a
machine that keeps its only account of itself on a stick somebody can pull out
has an account that can walk away mid-sentence.

This mirrors step one exactly. There, the allocator's first job was to find where
its own author sits in memory so it never hands those bytes away. Here, the
storage layer's first job is to know which blocks hold the image it is running
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

## If the delivery medium cannot be written

The machine does what it can with what it has: probes, and holds what it finds in
working memory until it finds somewhere to put it down. Memory is writable
whether or not the boot medium is, so a read-only medium stops the machine
keeping things rather than stops it thinking.

The real cost lands on `003a`. The intent note written before a dangerous
experiment cannot be written at all, so a machine that dies exploring learns
nothing from having died. It will rediscover the same lethal register on every
boot, forever, and each rediscovery costs another piece of hardware.

A machine on read-only media should therefore treat finding writable storage as
its most urgent task, ahead of anything else it might do with what it has found.

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
- **When is the store considered moved?** Migrating to better media means there
  is a window where the account exists in two places, or in neither. A machine
  that dies in that window is the one case where the thing designed to survive
  crashes does not.
- **What happens if the delivery medium is read-only?** Some are. The machine
  would then have nowhere to write until it finds something else, which puts the
  intent notes of `003a` out of reach during exactly the phase that needs them.
