# Phase 4 — The Rails: progress

**Where the current comes from, and how it reaches the middle. Complete.**

| ticket | blueprint | state |
|---|---|---|
| `401` | `028-power-budget` | done |
| `402` | `029-voltage-domains` | done |
| `403` | `030-power-delivery-network` | done |
| `404` | `031-decoupling-and-impedance` | done |
| `405` | `032-current-density-and-electromigration` | done |
| `406` | `033-power-sequencing` | done |

Ninety constraints hold across twenty-four blueprints. Seventy-five more are
written and waiting on phases 5 through 12.

## The rule the phase turns on

**No current passes through a corner or along an edge.** The corners are
hydraulic; mixing a power plane with water inside an object that cannot be opened
is a decision nobody should be able to make by accident. So power is purely
radial — in at a face, through that face's own stack, and one sixth of the core's
share continuing inward through the interface the data uses.

That last part produces a property nobody designed for: **the core's supply is
six-way redundant by construction.** A face that loses its regulator stops
computing and the middle keeps running on the other five.

## The two findings

**The ramp is worth a factor of nine, not a factor of sixty-four.** A die needs
twenty-seven microfarads of decoupling if its multiplier array starts all at
once, which is two hundred and seventy square millimetres of trench capacitor
under a five hundred and seventy-six square millimetre die and does not fit.
Admitting operands over sixty-four cycles does not change the total current — it
changes how fast it arrives, and the charge deficit while a regulator catches a
ramp is the area of a triangle rather than a rectangle. Three microfarads, for
forty-five nanoseconds at the start of a layer that takes a hundred and fifty
microseconds.

**The via islands are not the electromigration problem.** The ticket predicted
they would be, and at the supply voltage they carry a few amperes through several
hundred pads each with a hundredfold margin. The binding case is **the die's own
power grid**: seventy amperes needing seventy thousand square microns against
seventy-two thousand available. A margin of one and a half.

## The check worth copying

`C-032-5` requires the electromigration limit to be quoted at the temperature
`025` says the conductors actually reach. The ordinary way to get this wrong is
to take a datasheet figure from a cooler part, and nothing but a constraint
reaching across two phases catches it. There should be more of these.

## What the checker refused

A constraint written as `t_powerup < 0.1`. A literal in this notation is always
dimensionless, so a time can only ever be compared against a named time. The fix
is a symbol with a unit and a meaning, which is the rule doing exactly what it
exists for — there is no way to put an unlabelled physical quantity into this
project, including into a constraint.

## What is still open

**Five volts or twelve as the intermediate** (`009` entry P1, `030`). It changes
the interposer thickness, which changes the face thickness, which changes the
cube. It should not stay open.

**The regulator is nowhere specified** (`030`, `031`, `033`). Its response time
sizes the decoupling, its behaviour on a sagging input decides whether the
brownout scheme works, and neither is written.

**Nothing models twenty-four dies stepping together** (`031`). Whether their
load steps correlate is `053`'s schedule. If they do, the interposer planes and
the via islands see twenty-four times the slew and neither has been checked.

**The fault record has nowhere to go** (`033`). Energy is reserved to write one
and nothing inside this cube is non-volatile — the same gap `009` entry M4
records for the runtime repair map. **Two blueprints now need the same missing
thing**, which suggests it should stop being an open question and become a
ticket.

**Peak current is not distinguished from average anywhere** (`028`). And the
spout's burst — over a hundred amperes on the port rail for thirty-three
microseconds, fourteen times its average — has been shown to be thermally
nothing and never checked electrically.
