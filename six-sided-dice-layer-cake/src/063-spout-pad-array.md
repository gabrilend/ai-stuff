# 063 — Sixteen million pads on a square

```meta
phase  | 9
issues | 902
```

## The counts

| bond technology | pitch | what it permits |
|---|---|---|
| hybrid bond, copper to copper | 10 µm | one conductor per bit, permanent |
| fine microbump | 30 µm | one conductor per byte, and reworkable |
| land grid, detachable | 250 µm | differential pairs on the perimeter |

One position in five goes to power, ground, shielding and strobes. **That ratio
has to be justified rather than assumed**, because sixteen million conductors
switching together is the worst simultaneous-switching case in the machine and
the ground return is the only thing that stops the array behaving as one large
antenna. `064` is where the justification is done and this blueprint reads it.

## The tiling

```drawing
the fine zone, tiled [not-dimensioned]

   ┌──────┬──────┬──────┬──────┬─── ... ───┬──────┐
   │ tile │ tile │ tile │ tile │           │ tile │  each tile is
   ├──────┼──────┼──────┼──────┼───────────┼──────┤  [w_tile_pad] pads
   │ tile │ tile │ tile │ tile │           │ tile │  square, forwards
   ├──────┼──────┼──────┼──────┼───────────┼──────┤  its own strobe,
   │      │      │      │      │           │      │  and is deskewed
   │  ⋮   │  ⋮   │  ⋮   │  ⋮   │           │  ⋮   │  on its own at
   │      │      │      │      │           │      │  the far end
   └──────┴──────┴──────┴──────┴───────────┴──────┘
```

**Not a packaging convenience.** It is the mechanism that makes `065` possible,
and the tile size is derived from the skew budget there rather than chosen here —
the two must agree, and `C-063-4` requires it. The tiling also matches `051`'s so
that one deskew design serves both the link and the spout.

## Spares

Sixteen million bonds, made once, never repairable, in a part whose value is the
whole cube. **A single failed bond must not scrap the machine.** Spares and a
remap at tile granularity, and `083`'s yield model must be told the count — with
none, cube yield is a function of sixteen million independent bonds and is
indistinguishable from zero.

Same problem as `051`'s and three times worse, so the two share a mechanism.

## Mapping bits to pads

Not arbitrary. Bit *n* of the pane lands where `038`'s bank interleaving stays
contiguous **within a tile**, so filling one tile is one bank's worth of read
rather than four thousand scattered ones. Getting this wrong makes the pane fill
much slower while every individual blueprint still checks.

## Symbols

```symbols
f_pane_spare  | 1 | given | 0.03    | share of the fine zone's positions held as spares against bonds that fail
w_tile_pad    | 1 | given | 64      | pads across one source-synchronous tile
f_gnd_ratio   | 1 | given | 0.20    | share of positions given to power, ground, shielding and strobes, from 064's switching analysis

n_pane_tile   | 1 | derived | n_pane_bit / b1 / w_tile_pad^2       | tiles the pane is divided into
L_tile_pad    | um | derived | w_tile_pad * p_bond_fine            | edge of one tile
n_strobe      | 1 | derived | n_pane_tile * 2                      | strobe conductors: one pair per tile
n_spare_pane  | 1 | derived | n_fine_pad * f_pane_spare            | conductors held in reserve
n_accounted   | 1 | derived | n_pane_bit / b1 + n_strobe + n_spare_pane + n_fine_pad * f_gnd_ratio | every position, by purpose
A_spout_need  | mm^2 | derived | n_fine_pad * p_bond_fine^2 | fine zone area the widest grade needs, which 056 must provide
n_bond_total  | 1 | derived | n_fine_pad                           | bonds made in one operation at the very end of assembly, which 083 has to survive
```

## Constraints

```constraints
C-063-1 | n_accounted <= n_fine_pad     | every position must be accounted for by purpose and they must fit. Written as an inequality rather than an equality because rounding the pane down to a power of two leaves some genuinely spare
C-063-2 | n_pane_tile * w_tile_pad^2 ~= n_pane_bit / b1 | the tiles must divide the pane exactly, which is one of the two reasons the pane is a power of two
C-063-3 | n_spare_pane > n_pane_bit / b1 / 200 | at least one spare per two hundred conductors, because a bonded array with none makes cube yield a function of sixteen million independent bonds
C-063-4 | L_tile_pad <= L_tile_skew     | the tile must be small enough that skew within it fits 065's budget. The tile size is derived there and read here, so neither can move alone
C-063-5 | A_spout_need <= A_fine        | the array must fit the fine zone 056 provides
C-063-6 | f_gnd_ratio >= f_gnd_min      | the share given to ground and shielding must be at least what 064's simultaneous switching analysis requires
```

## What is still open

**The bit-to-pad mapping is stated as a rule and not written out.** *Keep a tile
within one interleave unit* is the requirement; the actual permutation from pane
bit to pad position does not exist, and `069`'s receiver needs it to reassemble
anything.

**The spare fraction is a `given`, as it is in `051`.** `083` should be setting
both and has not.
