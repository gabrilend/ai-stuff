# 007 — Datapath: one pane of bits leaving

The sixth face. This is the part of the vision document that sounds like a joke
and is not, and the whole of phase 9 is the work of finding out how much of it
survives contact with a pad pitch.

## What the page asked for

> one of the faces is allowed to be an output data tube, which has 1 wire per bit
> in memory so that it can be almost instantly replicated somewhere else.
>
> alternatively, each byte, so you can pulse 8 bits in a cycle.

One wire per bit in memory. The core holds sixty-four gibibytes, which is five
hundred and fifty billion bits, which is five hundred and fifty billion wires.
That is not a number of wires. It is roughly the number of wires that exist.

So the literal reading fails immediately, and the useful question is the one
underneath it: **how much memory can be moved in a single clock edge, given a
fifty-two millimetre square of face to put conductors on?**

## What a face will actually hold

A face's outward surface is fifty-two millimetres square: two thousand seven
hundred and four square millimetres.

| bond technology | pitch | positions on a face |
|---|---|---|
| hybrid bond, copper to copper | 10 µm | 27,040,000 |
| fine microbump | 32 µm | 2,640,000 |
| land grid, detachable | 250 µm | 43,264 |

Spend one position in five on power, ground and shielding, and the top row leaves
about twenty-one and a half million signal conductors. Round down to a power of
two and you get **two mebibytes — sixteen million seven hundred and seventy-seven
thousand two hundred and sixteen conductors, one per bit, all switching on the
same edge.**

That window is the **pane**. It is not all of memory, but it is a great deal more
than a bus, and the machine's whole output architecture is built around the
observation that moving two mebibytes at once is qualitatively different from
moving sixty-four bytes at once eight million times.

## The path

```
   the core                the cage              the spout face          away
 ┌────────────┐         ┌────────────┐         ┌────────────────┐
 │ pane region│  39 TB/s│  crossbar, │  pane   │ 4096 tiles,    │  one
 │ 2 MiB,     │────────▶│  full width│────────▶│ 4096 bits each,│  edge
 │ aliased    │         │  to one    │  bus    │ each with its  │─────▶
 │ anywhere   │         │  face      │         │ own strobe     │
 └────────────┘         └────────────┘         └────────────────┘
```

**The pane region** is an address window in the core (`038`). It is not a separate
memory — it is an aliasing register that says *which two mebibytes of the core the
spout is currently looking at*. Moving the window is one store. Moving the
contents is one edge.

**The crossbar** has to deliver two mebibytes to one face in one transfer, which
is the single widest thing that happens anywhere in the machine and is the reason
`037` is built for one face to take the whole core's bandwidth. Two mebibytes at
thirty-nine terabytes a second is fifty-four nanoseconds of core read to fill a
pane the spout will empty in one nanosecond.

**That mismatch is the real limit on the spout**, and it is worth stating before
any of the wire counts: the tube can leave faster than the memory can be read.
Sustained output is bounded by the core at thirty-nine terabytes a second, not by
the conductors at two thousand one hundred. The pane is a *burst* device, and
`065` treats it as one.

## What a burst costs

A hybrid-bonded connection is about ten microns long and carries something like a
femtofarad. Driving one bit across it costs on the order of ten femtojoules once
the driver and the receiver's sense amplifier are counted.

| | derived |
|---|---|
| energy, one bit | 10 fJ |
| energy, one pane of 2 MiB | 168 nJ |
| **energy to push the whole core through the pane** | **5.8 mJ** |
| panes needed for the whole core | 34,306 |
| **time, at one gigahertz** | **34.3 µs** |
| average power during that burst | 168 W |

Sixty-four gibibytes, moved somewhere else, in thirty-three microseconds. The same
transfer over a four hundred gigabit network link takes one and four tenths of a
*seconds* — the spout is forty-two thousand times faster, and it does it by having
sixteen million wires instead of four.

One hundred and sixty-eight watts sounds fatal until you notice it lasts thirty-three
microseconds and the silicon's thermal time constant is about a millisecond. The
burst deposits five and a half millijoules; the coolant carries away nineteen
hundred and ten watts continuously and never notices. **The spout has an energy
budget, not a power budget**, which is a genuinely unusual thing for a chip
interface and is what `026` has to model.

Sustained, rather than burst, the spout runs at about a hundred megahertz for
seventeen watts, which is still two hundred and ten terabytes a second.

## The hard part is not the wires

Sixteen million conductors is a manufacturing problem, and manufacturing problems
have prices. **Getting sixteen million edges to arrive at the same time is a
physics problem**, and it does not.

The bond itself is ten microns long, so it contributes nothing. The skew comes
from distributing the launch edge across fifty-two millimetres of silicon on the
sending side and gathering it across fifty-two millimetres on the receiving side.
Signals cross a die at about a third of the speed of light; corner to centre is
twenty-six millimetres, which is roughly two hundred and sixty picoseconds. At one
gigahertz that is a quarter of the whole cycle, spent on nothing.

The answer is to stop trying. The pane is divided into **four thousand and
ninety-six tiles of four thousand and ninety-six bits**, each tile six hundred and
forty microns square, and **each tile forwards its own strobe alongside its own
data**. Skew now has to be controlled only within a tile — six hundred and forty
microns, about six picoseconds — and the receiver deskews tile by tile. The tiles
may arrive in any order across a window of half a nanosecond; the receiver
reassembles them.

This turns one impossible timing closure into four thousand and ninety-six easy
ones, and it costs four thousand and ninety-six extra conductor pairs out of
twenty-one million available. `065` is where this is done properly and `072` is
the same trick applied to the clock inside the cube.

## The three grades

Because one design cannot be both permanent and detachable, phase 9 specifies
three and expects the third to be the one that ships.

| | conductors | rate | width | detachable |
|---|---|---|---|---|
| **bonded** (`066`) | 16.8 M, one per bit | 1 GHz burst | 2.1 PB/s | no — it is a bond |
| **byte mode** (`068`) | 2.1 M, one per byte | 8 pulses per transfer | 262 TB/s | at 32 µm, with difficulty |
| **cabled** (`067`) | 2,048 differential pairs | 32 Gb/s serial | 8.2 TB/s | yes |

**Bonded** is the vision taken as far as it goes. The receiving substrate is
permanently attached; the two objects are one object afterward. This is what you
build if the thing on the other side is another cube and the pair is meant to be a
unit.

**Byte mode** is the vision document's own retreat and it is the interesting one.
One conductor per byte instead of per bit divides the count by eight, which moves
the required pitch from ten microns — bondable only — to thirty-two microns, which
ordinary microbumps reach. It costs eight pulses instead of one and buys the
ability to *manufacture the part at all*. Whoever wrote that line had already
found the wall.

**Cabled** gives up a factor of two hundred and fifty in width to become a thing
you can unplug. Two thousand and forty-eight differential pairs at thirty-two
gigabits each is eight point two terabytes a second, which is thirty times a
current network interface and a rounding error next to the bonded grade. It is
here because a machine you cannot take apart is a machine you cannot service, and
`019` has opinions about that.

## What the far end has to be

Nothing in the pane is self-describing. Sixteen million conductors carry sixteen
million bits and no address, no length, and no type. The receiver must already
know what a pane means, and `069` specifies the small amount of out-of-band state
that makes that possible: which core window the pane was aliased to, a sequence
number, and a hash over the pane computed by the sending side while the pane was
being read.

The hash is checked after the fact rather than before, because there is no room
in a single edge to do anything conditionally. **A pane is always sent and
sometimes wrong**, and the recovery is to send it again. At thirty-three
microseconds for the entire core, resending is cheap enough that no cleverer
protocol earns its complexity.

## What is still open

**Whether the receiving side exists.** Everything above specifies a transmitter.
The only receiver this design assumes is another cube, which makes the spout a
cube-to-cube interconnect and not a general output. If the far end is a host
computer, something has to turn two mebibytes in a nanosecond into something a
host bus can absorb, and that thing is not designed. This is the largest
unspecified block in the project and it is carried in `009` as such.

**Whether the pane should be able to move while the core is being written.** As
specified, aliasing the pane region and generating tokens are mutually exclusive
for the duration of the read, which is fifty-four nanoseconds per pane and one and
three quarter milliseconds for the whole core — long enough to stall a token.
Whether a coherent snapshot is required, or whether the spout may read a torn view
and let the far end sort it out, is an ordering question `039` has not answered.

## Related

`062` states the idea in blueprint form. `063` is the pad array. `064` is the
circuit at each end of one conductor. `065` is skew. `066`, `067` and `068` are
the three grades. `069` is integrity. `008` is where this sits among the four
places the design departs from the page it came from.

---

*The figures in this document are rounded prose. The derived ones live in `101`, which lists every symbol in the project with its unit, its derivation and what it is for; `089` is the one-page version. `./run-checks` evaluates every constraint in under a second.*
