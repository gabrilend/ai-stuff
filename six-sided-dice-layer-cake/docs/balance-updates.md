# Balance updates

Knobs turned and levers pulled, append-only, newest at the bottom. A number
changed here is one that moved without the design around it changing — a
dimension retuned, a budget reapportioned, a rate chosen differently. Anything
that changes *what a part is* belongs in an issue ticket instead.

Every entry says what moved, from what to what, and why. The blueprint that owns
the number is named so the change can be found.

---

**2026-08-25 — total heat, 1650 W to 1910 W.** `020`.
The original budget counted only power delivered to the point of load. Working
through `006` showed that two stages of voltage conversion on the face interposers
lose two hundred and sixty watts, and those watts are inside the cube. Everything
drawn from the supply leaves as heat, so the number the plumbing sees is the input
power and not the load power. Downstream: coolant flow from three litres a minute
to three and a half, coolant rise from eight kelvin to seven point eight,
convection term from one point two kelvin to one point three.

**2026-08-25 — core edge, 38 mm to 40 mm.** `012`.
The cavity is forty-six millimetres and the first sketch put a thirty-eight
millimetre core in it with a four millimetre plenum all round. Introducing the
cage — the switch shell that lets one face take the whole core's bandwidth — needs
three millimetres of that, not four. Giving the extra two millimetres to the core
rather than to clearance buys sixteen hundred square millimetres per tier instead
of fourteen hundred and forty-four, which is what lifts raw capacity past the
seventy-eight gigabytes the sixty-four gibibyte usable figure needs.

**2026-08-25 — face slice, forty per cent of die area to fifty.** `041`.
A transformer layer of the reference model is four hundred and thirty-seven
megabytes at four bits, and prefetch needs two of them resident at once. Forty per
cent of a compute die gave seven hundred and thirty-seven megabytes per face
against eight hundred and seventy-four needed. Fifty per cent gives nine hundred
and twenty-two. This is the constraint that ties the model shape to the die
floorplan and it is the tightest one in the project — forty-eight megabytes of
margin on a nine hundred megabyte number.

**2026-08-25 — face cold plate, copper to silicon.** `014`.
Not a knob so much as a material swap forced by arithmetic that had not been done
yet. Copper against silicon across fifty-two millimetres over a sixty kelvin swing
is forty-three microns of differential motion and about a hundred megapascals in
the die, which is where silicon with an ordinary surface finish fractures.
Matching the material zeroes the mismatch. Downstream: fin efficiency falls from
eighty-nine per cent to seventy-four, effective conductance from about thirteen
hundred watts per kelvin to one thousand and forty, and the convection term from
one and a third kelvin to one and four fifths. Three tenths of a kelvin to remove
the dominant mechanical failure mode.

**2026-08-25 — cold plate wetted area derated five per cent.** `014`.
The port field's conductors have to reach the interposer, and the cold plate is
between them. Sixteen islands of three millimetres square per plate, where the
channels stop and insulated feedthroughs pass instead. Costs about five per cent
of wetted area and buys the ability to power the face at all.

**2026-08-25 — core cooling laminae, copper to copper-molybdenum.** `036`.
Same expansion argument as the face cold plate, one axis further in. Forty
millimetre tiers, thirty-two interfaces, and copper would move thirty-three
microns against the silicon at each one. An eighty-five per cent molybdenum
composite sits at seven parts per million per kelvin instead of sixteen and a
half, which cuts the differential by a factor of three, and costs conductivity —
one hundred and ninety watts per metre per kelvin against four hundred. The core's
heat load is a tenth of the faces', so it can afford the loss and the faces could
not.

**2026-08-26 — corner manifold block, 8 mm to 12 mm; chamber 30 mm² to 14 mm².**
`015`. The first attempt asked two chambers, a wall between them and a wall
around them to fit inside eight millimetres and needed fifteen. Enlarging the
block to twelve and shrinking the chambers to fourteen square millimetres closes
it with half a millimetre to spare, and keeps the block under a quarter of the
cube's edge, which is the interference limit against its neighbours along an
edge.

**2026-08-26 — edge rail channels restated as width and height.** `016`. They
were a single area, which let a constraint written as two square roots ask for
six point seven millimetres inside a four millimetre rail. Stacking them —
three point two wide by one point three five tall, with a half millimetre web
and four tenths of wall — is what a four millimetre section will actually hold.

**2026-08-26 — the manifold transparency claim withdrawn.** `015`, `016`.
The design intended rails and corners together to cost under five per cent of
the loop, so that flow distribution would be insensitive to how well the manifold
was built. A four millimetre rail carrying a sixth of the machine's flow runs at
over two metres a second and costs about a third of the loop on its own. Rather
than adjust the number quietly, the claim is withdrawn: `024` must solve the
network instead of assuming the manifold is invisible, and what actually balances
this design is the parity topology in `023` — every point of the supply mesh
within one edge of a feed — which was always the stronger argument.

**2026-08-26 — silicon edge finish, sawn to plasma-diced.** `011`, `018`.
Not a knob. The tier-to-lamina interfaces carry about a hundred and nine
megapascals once the residual frozen in at bonding is counted, and a sawn or
laser-diced edge fractures near a hundred and fifty — a margin of one point four
on a failure that scraps a whole cube. A plasma-diced edge etches rather than
cuts and leaves no crack population, at three hundred and fifty, which gives
three point two. Plasma dicing is now a requirement on `1201`.

**2026-08-26 — face plate flatness, 15 µm to 50 µm; seal cord 1.0 mm to 2.5 mm;
plenum 1.20 mm to 1.13 mm.** `013`, `017`, `014`. One cascade, and it is the
clearest example so far of a number that could not have been chosen first.

Fifteen microns is what the process achieves at one temperature. `018` then found
that a face assembly, being eight bonded layers with an unbalanced neutral axis,
bows forty-five microns when it is hot — so fifteen was never a real figure for a
machine that runs warm. Flatness went to fifty. Four plates around a loop then
accumulate three hundred microns instead of a hundred and sixty, and a one
millimetre seal cord takes up a hundred and fifty. The cord went to two and a
half millimetres, which needs four tenths of a millimetre of travel instead of
a third, and the seventy microns came out of the coolant plenum.

The better answer, not taken, is to reorder the face stack so it does not bow.
That would give the seventy microns back and is recorded in `018`.

**2026-08-26 — mount bolt, M4 to M3.** `019`. Three bolt diameters of clearance
in a twelve millimetre corner block is exactly twelve millimetres for an M4,
which leaves no material around it. The shock load at a mount point is under a
hundred and forty newtons, so an M3 is generous.

**2026-08-26 — the cube ships dry.** `021`, and it goes into `082` and `085`.
Water freezes at zero and a cube may see minus twenty in transit, so the
constraint failed outright rather than marginally. The alternative was an
antifreeze additive at about fifteen per cent of the thermal performance and a
new set of properties in `011`. Shipping empty costs a filling and purging step
in the installation procedure instead, and it means a cube that arrives is not a
cube that can be switched on.

**2026-08-26 — leak rate re-expressed as a volume.** `017`, `027`. A helium leak
rate quoted in millibar litres per second is a pressure-volume throughput and
therefore has the dimensions of power, which the checker noticed when it was
compared against a reservoir emptying. Dividing it by the working pressure gives
a volume flow, which is the thing the reservoir actually loses. A hundred and
sixty-six joints come to a few cubic millimetres a year, which the reservoir
absorbs without noticing.

**2026-08-26 — the antipodal face ordering earns nothing.** `010`, `026`.
Recorded here rather than reverted, because the ordering is harmless and may yet
be useful. Consecutive pipeline stages were put on opposite faces so that the hot
region walking around the cube during single-stream generation would land
alternately at opposite ends. The silicon does not notice: a multiplier region's
thermal time constant against its own cold plate is about three milliseconds and
a pipeline stage is a hundred and fifty microseconds, so the array reaches five
per cent of its steady rise before the work moves on. The excursion is under a
kelvin under any ordering. The ordering is now free for something else, most
likely shorter storage line routing.

**2026-08-26 — core tiers, 32 to 24; lamina 1.200 mm to 1.617 mm.** `034`, `036`,
`012`. Thirty-two was the first sketch, chosen because it made the stack pitch a
round number. `035` then derived an areal density from the bitcell upward —
cell area, array efficiency, tier overhead — and at that density thirty-two tiers
hold half again what the reference model needs. That is silicon nobody uses
paying leakage forever. Twenty-four lands just above sixty-four gibibytes usable
and gives each tier a lamina a third thicker, which the core's own cooling wanted
anyway. **The tier count came out of the capacity chain rather than going into
it.**

**2026-08-26 — error correction line, 64 bits to 256.** `040`, `034`. Sixty-four
data bits need eight check bits, which is twelve and a half per cent of the
core's raw capacity. Two hundred and fifty-six need ten — nine to locate an error
among them and one to detect a second — which is under four per cent. The sieve's
reads are enormous and sequential so a wide line costs nothing, and the eight and
a half per cent recovered is most of what paid for dropping eight tiers.

**2026-08-26 — through-stack via, 3 µm to 5 µm to 7 µm.** `036`. A via running
the full forty millimetres of the stack is not a via, it is a resistance and a
capacitance in series, and its time constant goes as the reciprocal of its area.
Three microns was hopeless; five settled in two hundred and eleven picoseconds
against a two hundred picosecond budget; seven gives a hundred and eight. Copper
rather than tungsten for the same reason — three times the resistivity over forty
millimetres is the difference between settling inside a core cycle and not.

**2026-08-26 — core lamina channels, half the lamina's depth to 0.30 mm.** `036`,
`024`. Cutting the laminae half through put nearly forty cubic centimetres of
fluid inside a two hundred and sixteen cubic centimetre machine, which is a fifth
of it. The laminae are thick because the stack height demanded it, not because
seven watts a tier did; at three tenths of a millimetre deep a tier still sits
under a third of a kelvin above its coolant.

**2026-08-26 — bank interleave, 8192 bits to 32768.** `038`. Eight thousand is
narrower than a single cycle's read from one tier, so every transfer would have
straddled two banks — the opposite of what interleaving is for.

**2026-08-26 — three manual unit conversions removed.** `034`, `036`. A division
by a thousand to turn megabytes into gigabytes, and two more to turn millimetres
into metres, all in derivations where the notation already does the conversion.
Each was a dimensionless literal and therefore silent: the first made the core a
thousand times too small, the other two between them made a tier's temperature
rise a thousand times too large. This is the failure mode the whole notation
exists to prevent and it still took a checker to find them.

**2026-08-26 — die power grid, 3 µm of metal to 16 µm; regulators moved to 1.2 mm.**
`030`. Seventy amperes across a twenty-four millimetre die through three microns
of top metal is a hundred millivolts, which is four times the whole droop
allowance. A thick metal stack at sixteen microns, three quarters of it given to
power, with the regulators directly beneath the dies they feed, brings it to
about six. The intermediate planes went from two to four for the same reason.

**2026-08-26 — static drop given its own budget, separate from transient droop.**
`030`, `029`. The first constraint asked the accumulated static drop to fit
inside the droop allowance, which is the budget for transients. Static drop is
always present, so spending the transient allowance on it leaves the rail out of
specification the moment anything switches. Two per cent of nominal for static,
three for transient.

**2026-08-26 — antiresonant peak factor, 3 to 1.5.** `031`. An undamped two-stage
decoupling network peaks at about three times its target impedance, and that does
not fit inside the rail's five per cent tolerance band. Damping is therefore a
requirement rather than a refinement, and the figure records what a damped
network has to achieve.

**2026-08-26 — hold-up capacitance became a component rather than a derivation.**
`033`. It had been derived from what it needed to achieve, which meant the
constraint checking it was checking its own definition. Three hundred microfarads
is a capacitor somebody buys; the constraint now checks that choice against the
longest write in flight, and passes with about twice the margin.

**2026-08-26 — electromigration limit re-quoted from 350 K to 319 K.** `032`.
Three hundred and fifty was where the conductors were assumed to run before
`025`'s chain closed. They run cooler. A limit quoted hot is conservative rather
than wrong, but a limit quoted at the wrong temperature at all is exactly how
this goes wrong silently, so the constraint requiring the two to match is what
found it.

**2026-08-26 — sensors per die, 8 to 16.** `049`. Eight was a round number chosen
before `041` scattered the multiplier array into sixty-four tiles. At eight,
three quarters of the hot regions have no sensor near them.

**2026-08-26 — the leakage fixed point took one more turn.** `020`. The junction
temperature the leakage term is evaluated at was three hundred and fourteen
kelvin; `025`'s chain produces three hundred and eighteen point nine. The
constraint requiring the two to agree within a per cent is the iteration, and
this is the iteration converging.

**2026-08-26 — two more hand-written unit conversions removed.** `039`, and one
found earlier in `020`. A worst-case wait in seconds multiplied by a thousand
million to make nanoseconds, in a field already declared in nanoseconds, turned
nineteen nanoseconds into six and a half seconds. That is now five of these
found by the checker across four phases; they are the most common defect in this
project by a wide margin.

**2026-08-26 — outstanding requests on the scalar core, 16 to 128.** `044`.
Sixteen was a round number and covers about a seventh of a radial link round
trip, which means the core stalls on six descriptor fields out of every seven.
The utilisation claim that justifies the core being small depends on it not
stalling.

**2026-08-26 — two more duplicate declarations resolved.** `053` now owns the
pipeline stage time, which `026` had estimated before the schedule existed; `055`
renamed its bandwidth margin, which collided with the slice's capacity margin in
`047`. That is six duplicates the ledger has refused so far, every one of them a
blueprint guessing at something a later phase would own.

**2026-08-26 — the speed of light became a symbol.** `011`. A flight time
derivation had it as a bare literal, which made the result a length rather than a
time. It joins the permittivity as the second physical constant that has to be
declared rather than written, for the same reason: a literal here is always
dimensionless.

**2026-08-26 — the port field gained a burst allowance.** `020`, `057`. Ten watts
was a steady figure for six port fields during generation, when the storage lines
are idle and the spout is occasional. Loading a model runs five storage lines
flat out and draws fifty-one, which is five times the allocation. Two things
break that steady figure and both are bursts — a load for tens of milliseconds, a
pane for microseconds — so the budget now carries a transient allowance alongside
the steady one, and both are judged as energies against the thermal masses in
`026` rather than as powers against the coolant.

**2026-08-26 — seventh and eighth duplicate declarations.** `029` had given a
port field's current capability before `056` existed to derive it; `047` and
`055` had both used the name for a margin. Every one of the eight has been the
same shape: an earlier blueprint estimating something a later phase would own.
