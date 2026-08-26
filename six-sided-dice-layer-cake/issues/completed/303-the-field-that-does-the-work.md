# 303 — The field that does the work

Produces `src/022-face-microchannel-field.md`.

## Current behavior

**Done.** `src/022-face-microchannel-field.md` exists, and all three of the
things the ticket asked to be derived are derived rather than quoted.

The Nusselt number is a fifth-order polynomial in the aspect ratio, evaluated at
the shape `012` specifies, with a stated correction for heat arriving on three
sides. Fin efficiency comes from the standard straight-fin result at silicon's
conductivity -- written as the exponential form because the notation has no
hyperbolic tangent -- and comes out near seven tenths, which is the entire price
of choosing silicon over copper in `014`. The aspect ratio limit is published
here so that `012`'s constraint has something real to check against.

Seven constraints. The one worth having is that the fields must be two orders of
magnitude better than the bare plumbing that feeds them: that ratio is the
justification for the whole cold plate, and asserting it means the justification
is checked rather than remembered.

**The three-sided correction is still a `given`** and the whole conductance is
proportional to it.

## Intended behavior

**The microchannel field etched into the back of each face's silicon cold plate:
the part that actually removes heat from this machine.** Everything the corners do
is manifolding; this is the heat exchanger.

### The mechanism, stated so a materials engineer can check it

Heat crosses from a solid into a moving fluid at a rate set by the convection
coefficient, and in a duct that coefficient is the fluid's conductivity times a
dimensionless number divided by the duct's hydraulic diameter:

    h = Nu * k_fluid / D_h

The dimensionless number is about five for laminar flow in a rectangular duct
heated on three sides, and — this is the important part — **it does not depend on
velocity.** So in laminar flow the only lever on the coefficient is the hydraulic
diameter, and it is a reciprocal. A channel ten times narrower is ten times
better.

That is the whole argument for microchannels and it is why the four-millimetre
corner ducts fail by two orders of magnitude while a hundred-and-fifty-micron
channel succeeds. The blueprint must derive `Nu` for the actual aspect ratio
rather than quoting five, because the aspect ratio here is nearly seven to one and
the value moves.

### The geometry

A hundred and seventy-three channels, a hundred and fifty microns wide, one
millimetre deep, on a three hundred micron pitch, running the full fifty-two
millimetres of the plate, interrupted by sixteen via islands from `202`.

Three things have to be derived rather than chosen:

**Fin efficiency.** The silicon between two channels is a fin, and a fin only
carries heat to its tip if it is short and conductive enough. Silicon at a hundred
and thirty watts per metre per kelvin, a hundred and fifty microns thick, one
millimetre tall, gives about seventy-four per cent. **This term is the entire cost
of choosing silicon over copper** and it must be visible.

**The aspect ratio limit.** Deeper channels are more surface for the same
footprint, until the fin stops reaching its tip. The blueprint should show the
efficiency falling with depth and mark where the added depth stops paying, which
is where `012`'s one millimetre came from.

**The derating for via islands.** Sixteen interruptions per plate, each costing a
little channel length and a little flow uniformity. The area loss is easy; the
flow maldistribution around an island is not, and the blueprint should say
honestly whether it was modelled or bounded.

### What comes out

About one thousand and forty watts per kelvin across all six faces, after both
deratings. Nineteen hundred and ten watts crosses it for one and four fifths of a
kelvin.

## Symbols this must publish

Channel and fin dimensions from `012`, channel count, hydraulic diameter, wetted
area per channel and per face and total, Nusselt number with its aspect ratio,
convection coefficient, fin efficiency, overall surface efficiency, via island
derating, and the resulting conductance and temperature rise.

## Constraints this must assert

- Overall conductance exceeds the heat load from `301` divided by the allowed
  convection rise.
- Aspect ratio stays under the value where fin efficiency drops below a stated
  floor.
- Channel width exceeds the filtration limit from `308` by a stated factor.
- Wetted area derived from geometry agrees with wetted area derived from channel
  count times per-channel area. Two routes, one number.
- The field's footprint fits inside `012`'s plate.

## Suggested implementation steps

1. Derive the Nusselt number for the actual aspect ratio and three-sided heating.
   Cite the correlation and its range of validity.
2. Derive fin efficiency from `011`'s silicon conductivity.
3. Build wetted area from geometry.
4. Apply the via island derating and say how the maldistribution was handled.
5. Produce the conductance and hand it to `306`.
6. Plot efficiency against depth and mark the chosen point.

## Blocks

`305`, `306`, `307`.

## Blocked by

`103`, `202`, `301`, `302`.

## Related documents

`005` for the chain this term sits in. `008` entry 1 for why the corners could not
do it.
