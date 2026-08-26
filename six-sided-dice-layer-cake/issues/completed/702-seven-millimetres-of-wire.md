# 702 — Seven millimetres of wire

Produces `src/051-radial-link-physical.md`.

## Current behavior

**Done.** `src/051-radial-link-physical.md` exists, and it opens with the two
budgets in the order that matters: counting pads gives petabits a second,
counting picojoules gives hundreds of watts, and **power binds by more than an
order of magnitude**.

A constraint asserts that ratio explicitly, so that a reader who sizes this
interface by pad count finds out from the checker rather than from a thermal
failure.

Seven constraints, all holding. The link reads `029`'s swing and `029` reads its
noise margin, so neither can move alone.

**The spare fraction is a `given` that `083` should be setting**, and `C-051-6`
currently checks a guess against a rule of thumb. **Nothing says how a spare is
mapped in** — the conductors are bonded, so the remap has to be electrical, and
`084` does not mention the link.

## Intended behavior

**The physical layer of one radial link: the pad array, the driver, the receiver,
the signalling, and the two budgets — pads and picojoules — that bound it.**

### The interface

A face's inward surface meets the cage across a forty-six millimetre square patch.
At a twenty micron pitch that is two thousand three hundred by two thousand three
hundred, **five and a quarter million positions**. Spend two fifths on power and
ground — `006` needs them for the core's inward supply — and about three million
signal conductors remain.

### The two budgets, and which one binds

**Pads.** Three million conductors at two gigabits a second each is six petabits a
second, or seven hundred and fifty terabytes a second. Absurdly more than anything
needs.

**Energy.** At the tenth of a picojoule per bit a short low-swing link costs, six
petabits a second is six hundred watts. On one link. **Power is what bounds this
interface, by a factor of fifteen**, and the blueprint must open with that,
because a reader who counts pads will size the link wrong.

At the seventy watt allocation the whole sieve gets in `301`, and about forty watts
usable for one link at full rate, the link runs at four hundred terabits a second
— about fifty terabytes a second. Still five times what the core behind it can
supply, which is the right amount of headroom and no more.

### The circuit

Single-ended, low swing, no equalisation, no clock recovery. Seven millimetres and
a controlled impedance environment is short enough that all three can be omitted,
and each omission is area and power the design does not spend. The blueprint must
state the reach over which those omissions hold, so that nobody reuses the circuit
somewhere longer.

**The swing is `402`'s six hundred millivolts** and it must state the noise margin
that permits it, because `402` cites this blueprint for that number and the two
must not each be waiting for the other.

### Source-synchronous, per tile

Same problem as `904`'s spout and the same answer. Distributing one launch edge
across forty-six millimetres costs a quarter of a cycle at a gigahertz. So the
interface is tiled, each tile forwards its own strobe with its own data, and the
receiver deskews per tile. The blueprint should say the tiling matches `904`'s so
that one deskew design serves both.

### Redundancy

Five and a quarter million connections, made once, never repairable. Some will
fail at assembly and some will fail later. The blueprint must specify spare
conductors and the remap that uses them, and `1203`'s yield model must be told the
count — a link with no spares makes the whole cube's yield a function of five
million independent bonds, which is a yield of zero.

## Symbols this must publish

Pad pitch, array dimensions, total and signal pad counts. Bits per second per
conductor. Energy per bit. Link bandwidth at the power allocation. Swing and noise
margin. Reach limit for the omissions. Tile size and count. Strobe overhead. Spare
conductor count and remap granularity.

## Constraints this must assert

- Link bandwidth at the power allocation exceeds the per-face bandwidth in `501`.
- Signal pads plus power pads plus spares fit the array.
- Power pads times per-pad current capability exceeds the inward core supply in
  `401`.
- Noise margin exceeds what `402`'s swing requires.
- Spare count is sufficient for `1203`'s target yield at the per-bond defect rate.

## Suggested implementation steps

1. Do the pad count and the energy budget and show which binds. Put that first.
2. Specify the circuit and the reach over which its omissions are valid.
3. Fix the tiling to match `904`.
4. Size the spares against `1203` rather than choosing a round number.

## Blocks

`703`, `706`, `402`, `1203`.

## Blocked by

`202`, `301`, `401`, `501`.

## Related documents

`004`, `006`. `007` for the same skew problem at eight times the width.
