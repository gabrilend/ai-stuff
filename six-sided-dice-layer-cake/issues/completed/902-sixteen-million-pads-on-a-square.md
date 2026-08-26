# 902 — Sixteen million pads on a square

Produces `src/063-spout-pad-array.md`.

## Current behavior

**Done.** `src/063-spout-pad-array.md` exists with the tiling, the spares and the
bit-to-pad rule.

Six constraints. The tile size is derived in `065` from the skew budget and read
here, so neither blueprint can move it alone.

**The perimeter zone had to shrink** for this to work: four millimetres of
perimeter costs the fine zone a quarter of its area and halves the pane, while
the perimeter itself needs a few hundred conductors against several thousand
positions.

**The bit-to-pad mapping is a rule and not a permutation.** *Keep a tile within
one interleave unit* is the requirement; the actual mapping from pane bit to pad
position does not exist, and `069`'s receiver needs it to reassemble anything.

**The spare fraction is a `given`, as it is in `051`**, and `083` should be
setting both.

## Intended behavior

**The physical geometry of the conductor array: pitch, count, the split between
signal and everything else, and the tiling that `904` needs.**

### The count

| pitch | positions on 52 mm square | what it permits |
|---|---|---|
| 10 µm | 27,040,000 | bonded, one wire per bit |
| 32 µm | 2,640,000 | byte mode, microbump |
| 250 µm | 43,264 | detachable, differential |

Spend one position in five on power, ground and shielding — and the blueprint must
justify that ratio rather than assume it, because sixteen million conductors
switching together is the worst simultaneous-switching case in the machine and
the ground return is what stops the array from being one large antenna.

What remains at ten microns is about twenty-one and a half million. Two mebibytes
needs sixteen point eight, leaving nearly five million for strobes, spares and the
reverse channel `910` may want.

### The tiling

Four thousand and ninety-six tiles of four thousand and ninety-six bits, each six
hundred and forty microns square. This is not a packaging convenience — it is the
mechanism that makes `904` possible, and it must match `702`'s radial interface
tiling so that one deskew design serves both.

The blueprint must derive the tile size from the skew budget rather than choosing
a round number, and must show the trade: smaller tiles mean easier skew and more
strobes; larger tiles mean fewer strobes and a harder timing closure inside each.

### Spares

Sixteen million bonds, made once, never repairable, in a part whose value is the
whole cube. **A single failed bond must not scrap the machine.** Spare conductors
and a remap, at tile granularity or finer, and `1203`'s yield model must be told
the count — with no spares, cube yield is a function of sixteen million
independent bonds and is indistinguishable from zero.

This is the same problem as `702`'s and three times worse. The two should share a
mechanism.

### Mapping bits to pads

Not arbitrary. Bit *n* of the pane should land on a pad whose position keeps
`505`'s bank interleaving contiguous within a tile, so that filling a tile is one
bank's worth of read rather than four thousand scattered ones. Get this wrong and
the fifty-four nanosecond fill in `901` becomes much longer while every individual
blueprint still checks.

## Symbols this must publish

Pitch per grade. Array dimensions and total positions. Signal, power, ground,
strobe and spare counts. Tile dimensions, tile count and bits per tile. Spare
fraction and remap granularity. The bit-to-pad mapping rule. Array area against
`801`'s fine zone.

## Constraints this must assert

- Signal plus power plus ground plus strobes plus spares equals total positions.
- Signal count equals `901`'s pane size in bits.
- Tile count times bits per tile equals the pane.
- Tile size satisfies `904`'s intra-tile skew budget.
- Spare fraction meets `1203`'s yield target at the per-bond defect rate.
- The bit-to-pad mapping keeps a tile within one `505` interleave unit.

## Suggested implementation steps

1. Do the position count per grade and justify the one-in-five overhead from the
   switching case.
2. Derive tile size from `904`'s budget and show the trade.
3. Size the spares against `1203`, sharing the mechanism with `702`.
4. Define the bit-to-pad mapping against `505`'s interleave.

## Blocks

`903`, `904`, `905`, `907`, `801`, `1203`.

## Blocked by

`505`, `801`, `901`.

## Related documents

`007`. `702` for the same problem at an eighth the width.
