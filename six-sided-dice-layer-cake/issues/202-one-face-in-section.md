# 202 — One face, in section

Produces `src/014-face-assembly-stack.md`.

## Current behavior

Nothing. A face has been described as "four dies on an interposer with a cold
plate behind it" and the order of those things has never been settled, which is
the entire content of this ticket.

## Intended behavior

**The layer-by-layer section through one face assembly, inward surface to outward
surface, with a thickness for every layer and a material from `011` for every
one.** All six faces are this part; what differs between them is only which
connector is populated on the port field.

### The order, and why it is the order

The stack runs inward-to-outward, which is the opposite of how most packages are
drawn, and the reason is the single decision this ticket exists to make.

| # | layer | mm | material |
|---|---|---|---|
| 1 | radial interface pad field, facing the cage | 0.02 | copper pillar |
| 2 | face interposer: power planes, deep trench capacitors, routing | 1.50 | glass core |
| 3 | microbump array | 0.04 | solder |
| 4 | four compute dies, active side facing **inward** | 0.10 | silicon, thinned |
| 5 | bond | 0.01 | copper–copper hybrid |
| 6 | microchannel cold plate | 2.00 | **silicon**, channels etched |
| 7 | voltage regulator tier and port field substrate | 1.50 | organic |
| 8 | port field land array | 0.30 | plated |
| | **total** | **5.47** | against `t_face` of 7.00 |

**The dies face inward and are cooled from behind.** The alternative — cooling
from the inward side — puts a two millimetre plate of channels between the dies
and the cage, and the radial interface is five and a quarter million pads. Putting
five million connections through a water-cooled plate is not an engineering
problem, it is a refusal. Putting the *port field* through it is: the port field
carries forty-eight volts at seven amperes and a storage line of a few thousand
pairs, which is thousands of feedthroughs rather than millions.

So the cold plate is crossed by **via islands** — sixteen regions of three
millimetres square distributed across the plate, where the channels are
interrupted and insulated feedthroughs pass instead. This costs about five per
cent of the wetted area and is the price of the decision. It must be stated as a
cost in the blueprint, not hidden.

### Why the cold plate is silicon and not copper

Copper conducts three times better and is the obvious choice until `018` is
written. Copper expands at sixteen and a half parts per million per kelvin and
silicon at two and a half. Bonded across fifty-two millimetres over a sixty kelvin
swing, that is forty-three microns of differential motion at a rigid bond, and the
stress it induces in the silicon is around a hundred megapascals — inside the
range where a die with an ordinary surface finish simply breaks.

Etching the channels in silicon makes the mismatch zero. The cost is fin
efficiency: a silicon fin one millimetre tall conducts heat to its own tip at
about seventy-three per cent efficiency against copper's eighty-nine, so the
convection term rises from about one and a half kelvin to one and eight tenths.
**Three tenths of a kelvin to remove the dominant mechanical failure mode is the
best trade in the project.**

### The 1.53 mm that is not used

The stack adds to five and a half against a face thickness of seven. The remainder
is not slack — it is the plenum that distributes coolant from the edge rails
across the width of the cold plate, and the compression range for the seal in
`017`. It should be drawn, not left blank.

## Symbols this must publish

A thickness per layer, the sum, the via island geometry and count, the resulting
wetted-area derating, the cold plate fin efficiency, and the plenum height.

## Constraints this must assert

- The stack sum plus the plenum plus the seal compression equals `t_face` exactly.
  This is an equality, not an inequality, and it is what makes the face thickness
  a real dimension rather than a wish.
- The die block from `012` fits within the cold plate footprint.
- Via island count times island area times pad density exceeds the port field's
  conductor requirement from `056`.
- Wetted area after derating, times the coefficient from `022`, times the fin
  efficiency, exceeds what `020`'s heat load needs at the allowed rise.

## Suggested implementation steps

1. Draw the section. It is the most-referenced drawing in the project.
2. Fix the layer order and write the two paragraphs above into the blueprint as
   reasoning, because a reader who does not know why will reorder it.
3. Derive the fin efficiency from `011`'s silicon conductivity rather than quoting
   it, so that changing the material changes the number.
4. Lay out the via islands and derive the derating.
5. Close the thickness equality.

## Blocks

`303`, `403`, `601`, `702`, `801`.

## Blocked by

`103`, `201`, and `206` for the expansion argument.

## Related documents

`005` is where the fin efficiency lands. `018` is the stress this stack is shaped
by. `008` entry 1 for why there is a cold plate at all.
