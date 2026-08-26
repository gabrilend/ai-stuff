# 014 — One face, in section

```meta
phase  | 2
issues | 202
```

The layer-by-layer section through one face assembly. All six faces are this
part; what differs between them is only which connector is populated on the
outward surface.

## The order, and why it is the order

```drawing
one face assembly in section, inward at the top

   the cage
   ═══════════════════════════════════════════════   ── radial interface,
   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░      [t_radial_pad]
   ┌─────────────────────────────────────────────┐
   │      face interposer: planes, capacitors    │   [t_interposer]
   └──┬──────────────────────────────────────┬───┘
      ▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪      [t_microbump]
   ┌──┴─────────┐  ┌────────────┐  ┌──────────┴──┐
   │  die       │  │  die       │  │  die        │   [t_die]
   └────────────┘  └────────────┘  └─────────────┘
   ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬      [t_bond]
   ┌───────┬─────────────────────────┬───────────┐
   │╫╫╫╫╫╫╫│  ▪ via island ▪         │╫╫╫╫╫╫╫╫╫╫╫│   [t_coldplate]
   └───────┴─────────────────────────┴───────────┘
   ┌─────────────────────────────────────────────┐
   │   regulators and the port field substrate   │   [t_regulator]
   └─────────────────────────────────────────────┘
   ▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪      [t_land]
   the outside world
```

**The dies face inward and are cooled from behind.** This is the decision the
whole blueprint exists to make.

The alternative — cooling from the inward side — puts a two millimetre plate full
of water between the dies and the cage, and the radial interface is over five
million connections. Putting five million conductors through a water-cooled plate
is not an engineering problem, it is a refusal.

Putting the **port field** through it is possible: forty-eight volts at seven
amperes and a few thousand differential pairs is thousands of feedthroughs, not
millions. So the cold plate is crossed by **via islands** — sixteen small regions
where the channels stop and insulated conductors pass instead.

That costs about five per cent of the wetted area, and it creates ninety-six new
places where a conductor passes within a hundred microns of water at pressure.
`017` counts them, and this blueprint should be read with that count in view.

## Why the cold plate is silicon

Copper conducts three times better and expands seven times as much. Bonded across
a fifty-two millimetre plate over a sixty kelvin swing, copper drags the die
under it through about forty microns and loads it to something near a hundred
megapascals, which is where silicon with an ordinary edge finish breaks (`011`,
`018`).

Etching the channels in silicon makes the mismatch **exactly zero**. The cost is
fin efficiency: a one millimetre silicon fin delivers heat to its own tip at
about three quarters, against copper's nine tenths (`022`). Three tenths of a
kelvin to remove the dominant mechanical failure mode.

## The one and a half millimetres that is not slack

The stack adds to five and a half against a face thickness of seven. What is left
is the coolant plenum that distributes flow across the cold plate's width, and
the travel the compression seal in `017` needs. Both are drawn, neither is spare.

## Symbols

```symbols
t_radial_pad  | mm | given | 0.020 | copper pillar field on the inward surface, meeting the cage
t_microbump   | mm | given | 0.040 | solder microbump array between the dies and the interposer
t_bond        | mm | given | 0.010 | copper-to-copper hybrid bond from the die backs to the cold plate
t_regulator   | mm | given | 1.500 | the voltage regulator tier and the port field substrate together
t_land        | mm | given | 0.300 | the plated land array a connector mates to
h_plenum      | mm | given | 1.130 | height of the coolant distribution plenum across the cold plate's width; it gave seventy microns to the seal when the cord had to grow
t_seal_travel | mm | given | 0.400 | compression travel allowed for the face-to-rail seal, set by 017's cord after the bow in 018 forced the flatness allowance up

n_island      | 1  | given | 16    | via islands per cold plate, where channels stop and conductors pass
L_island      | mm | given | 3.000 | edge of one square via island
p_island_pad  | mm | given | 0.200 | pad pitch inside a via island

t_stack       | mm   | derived | t_radial_pad + t_interposer + t_microbump + t_die + t_bond + t_coldplate + t_regulator + t_land | everything solid in a face assembly, inward surface to outward
t_face_used   | mm   | derived | t_stack + h_plenum + t_seal_travel | the whole face thickness accounted for
A_island      | mm^2 | derived | L_island^2                    | area of one via island
A_island_all  | mm^2 | derived | n_island * A_island           | area taken out of the channel field by all sixteen
n_island_pad  | 1    | derived | n_island * floor(L_island / p_island_pad)^2 | conductors that can cross the cold plate, in total
f_island_area | 1    | derived | A_island_all / A_plate        | fraction of the cold plate given over to feedthroughs
n_island_seal | 1    | derived | n_island * n_face             | seal features created by this decision, one ring per island per plate
```

## Constraints

```constraints
C-014-1 | t_face_used ~= t_face          | the stack, the plenum and the seal travel must account for the whole face thickness exactly. This is an equality and not an inequality: leftover space in a face is space nobody drew, and space nobody drew is where a mistake lives
C-014-2 | L_dieblock <= L_plate          | the four dies must sit within the cold plate they are bonded to
C-014-3 | n_island_pad >= n_port_conductor | the sixteen islands must carry every conductor the port field needs to reach the interposer. If this fails, either the islands grow and take more wetted area or the port field carries less
C-014-4 | f_island_area < 0.10           | the feedthroughs must not take a tenth of the cooling surface; past that the decision to cross the plate should be revisited rather than the number adjusted
C-014-5 | L_island > 4 * p_island_pad    | an island must be several pad pitches across or its edge effects dominate its area
C-014-6 | t_coldplate > h_uchan          | the plate must be thicker than the channels etched into it, with base and cover left over
C-014-7 | h_plenum > w_uchan             | the plenum feeding the channels must be wider than a channel, or it is a channel
```

## What is still open

**Ninety-six via island seals.** Sixteen per plate, six plates, each a ring of
bond around a hole through a pressurised channel field. `017` counts them
alongside the seventy-two other seal features and the total is a very different
reliability proposition from the one this design would have without them. The
decision to cross the cold plate should be re-examined with that count in front
of it, and the alternative — a cold plate slightly smaller than the plate, with
the conductors passing around its perimeter — has not been priced.

**The flow around an island is not modelled.** The area lost is easy arithmetic.
What happens to the flow in the ten channels an island interrupts, and in their
neighbours, is not, and `022` currently bounds it rather than computing it.
