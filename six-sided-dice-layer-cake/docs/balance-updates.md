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
