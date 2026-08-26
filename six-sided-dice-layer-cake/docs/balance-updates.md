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
