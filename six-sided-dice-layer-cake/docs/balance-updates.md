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
