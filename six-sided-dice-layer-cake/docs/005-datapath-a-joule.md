# 005 — Datapath: one joule

Follow one joule of waste heat from the transistor that made it to the air it
ends up in. The machine makes about nineteen hundred and ten of them every
millisecond and has nowhere to put them except through its own corners.

## Where it is made

| source | watts | why |
|---|---|---|
| twenty-four compute dies | 1380 | matrix engines, almost all of it |
| the core, twenty-four memory tiers | 160 | read energy at thirty-eight terabytes a second, plus leakage |
| the cage and six radial links | 70 | crossbar and link drivers |
| port fields, storage lines, the spout | 10 | idle during generation; the spout is a burst load |
| **delivered to the point of load** | **1650** | |
| power conversion, on the face interposers | 260 | forty-eight volts down to three quarters of one, in two stages (`006`) |
| **total heat to remove** | **1910** | |

The last row is what the plumbing sees, and it is the same number as the power
drawn from the supply, because everything drawn from a supply leaves as heat. Two
hundred and sixty watts of the budget is spent on nothing but changing voltage;
`029` is the argument about whether that can be smaller.

Nineteen hundred and ten watts in two hundred and sixteen cubic centimetres is
**nearly nine watts per cubic centimetre, sustained**. For comparison a domestic
oven element is about the same power in a volume forty times larger, and it is
allowed to glow.

## The chain, resistance by resistance

```
   junction
      │   ── spreading, silicon              ~15 K      the dominant term
      ▼
   die back face
      │   ── conduction, 100 µm silicon      0.03 K     negligible
      ▼
   bond
      │   ── copper to copper, hybrid        ~0 K       negligible
      ▼
   cold plate base
      │   ── conduction, 300 µm silicon      0.27 K     small
      ▼
   channel wall
      │   ── convection into the water        1.8 K     the whole coolant design
      ▼
   the water
      │   ── carried out of the cube          7.8 K     by choice; sets the flow
      ▼
   the radiator
      │   ── convection into air             ~12 K      outside the cube
      ▼
   the room
```

Read it and the surprise is where the heat gets stuck. It is not the coolant. The
coolant is responsible for one and four fifths of a kelvin out of a chain that
adds up to about thirty-six, and the largest single term by a factor of eight is heat
spreading sideways through a hundred microns of silicon to get out of the hot spot
it was made in. **This is a silicon floorplanning problem wearing a plumbing
costume**, and `041` is where it is actually solved, by not putting all the
multipliers in one place.

## The part the vision document names

*The corners are pumped with coolant.* They are. What has to be said clearly is
what that does and does not accomplish.

Twelve plain channels four millimetres square, one down each edge of the cube, with
water at a sensible velocity, present about one hundred and fifteen square
centimetres of wetted surface at a heat transfer coefficient of roughly five
hundred and sixty watts per square metre per kelvin. That is **six and a half
watts per kelvin**. The machine makes nineteen hundred and ten watts. Cooling it
this way would put the silicon two hundred and ninety-seven kelvin above the
water.

The needed figure is about fifteen hundred watts per kelvin — two hundred and
thirty times more. You do not get that by making the corner channels bigger.
Convection into a duct scales as the conductivity of the fluid divided by the
duct's hydraulic diameter, so a *bigger* channel is a *worse* one per unit area,
and the only lever with two orders of magnitude in it is to make the ducts very
small and have a great many of them.

So the corners keep their job and lose their claim. **The corners are the
manifold. The cooling happens in a microchannel field bonded to the back of every
face**, which the corners supply. `022` is the field, `023` is the manifold, `025`
is the chain above with every term derived rather than asserted, and `008` records
this as the first of the four places where the original page and the physics
disagree.

## The field

Each face carries, bonded directly to the backs of its four compute dies, a
**silicon** plate with a hundred and seventy-three parallel channels etched into
it. Each channel is a hundred and fifty microns wide, one millimetre deep,
fifty-two millimetres long, separated from its neighbours by a hundred and fifty
microns of silicon.

Silicon rather than copper, and this is a decision rather than an oversight.
Copper conducts three times better and expands seven times as much; bonded across
fifty-two millimetres over a sixty kelvin swing it would drag the die under it
through forty-three microns and load it to about a hundred megapascals, which is
where silicon with an ordinary surface finish breaks. Matching the material
matches the expansion exactly and costs only fin efficiency. `202` argues it and
`018` has the stress.

That geometry gives a hydraulic diameter of two hundred and sixty-one microns,
which is the number that matters, because the heat transfer coefficient is
inversely proportional to it. At two hundred and sixty-one microns, water in
laminar flow gives about **eleven thousand nine hundred watts per square metre per
kelvin** — twenty-one times better than the four-millimetre duct — and the field
presents two hundred and seven square centimetres of wetted surface per face
against the whole cube's one hundred and fifteen.

Six faces together present one thousand two hundred and forty square centimetres
of wetted surface. Two derations apply and both are honest costs rather than
safety factors: a silicon fin one millimetre tall delivers heat to its own tip at
about seventy-four per cent efficiency, and sixteen small islands per plate where
the channels are interrupted to let the port field's conductors through cost
another five per cent of area (`202`).

What is left is **about one thousand and forty watts per kelvin**. Nineteen
hundred and ten watts crosses it for one and four fifths of a kelvin — still the
second smallest term in the chain, and still fifteen hundred times better than
what the corners alone could do.

The flow is gentle. Three and a half litres a minute for the whole machine, four
tenths of a metre a second in each channel, Reynolds number ninety-eight —
solidly laminar, which is deliberate. Turbulence would improve the transfer coefficient and cost
far more pressure than it returns at this scale, and laminar flow in a
rectangular duct has a closed-form answer, which means `025` can derive the
number instead of borrowing a correlation.

## The corners, doing their actual job

Two independent networks share the cube's twelve edges. A **supply channel** and a
**return channel** run side by side down every edge; at each of the eight corners,
a manifold block joins that corner's three supply channels to each other, and
separately its three return channels to each other.

Four corners are fed and four are drained, and which four is not arbitrary. Label
each corner by whether the sum of its three coordinates is even or odd. Every edge
of a cube changes exactly one coordinate, so **every edge joins an even corner to
an odd one** — the cube's corners divide into two sets of four with no edge inside
either set.

Feed the four even corners and drain the four odd ones and three things follow at
once. Every corner is either a feed point or directly adjacent to three of them,
so no part of the supply network is more than one edge from pressure. The same
holds for the return. And the four fed corners, taken by themselves, are the
vertices of a regular tetrahedron inscribed in the cube; so are the four drained
ones; and the two tetrahedra are each other's mirror. The plumbing diagram of this
machine is a stella octangula, and nobody chose that. It is what a cube is.

`023` proves the domination property rather than asserting it, because the whole
pressure-balance argument rests on it.

## What it costs to move

Three and a half litres a minute against about four tenths of a bar. Hydraulic
power two and a third watts; with a pump of the efficiency one can actually buy,
about eight watts electrical. Eight watts to move nineteen hundred and ten is a
ratio of two hundred and forty to one, and it is that good only because the flow
was kept laminar and the channels short.

## The margin, and what to do with it

Junction temperature comes out around forty-five degrees with the coolant entering
at twenty-five. The silicon is qualified to a hundred and five. **There is sixty
kelvin of headroom**, which is not a triumph — it means the design is not balanced
and something upstream should be spending it.

Three things could:

- **Clock higher.** Power goes roughly as the cube of frequency near the top of
  the range, so sixty kelvin of headroom is worth perhaps a fifteen per cent
  clock increase before the hot spot term catches up. `074` would have to re-close.
- **Let the coolant in warmer.** A twenty-five degree inlet needs a chilled loop.
  A fifty degree inlet can be served by a radiator and a fan, which removes a
  refrigeration plant from the bill of materials and is worth more than the clock.
  `027` prefers this.
- **Put more silicon in.** The thermal solution would carry a third face die layer
  if there were anywhere to put one.

The margin is real and it is not free — one thousand two hundred and forty square
centimetres of microchannel is six copper plates that have to be etched, bonded,
and sealed against water at pressure a millimetre from live silicon. `017` is that
seal and it is the single most likely thing in this project to leak.

## What is still open

**The hot spot term came out at about ten kelvin rather than fifteen**, once
`041` produced a real floorplan and `025` derived it rather than estimating. It is
still the largest term in the chain by a factor of five, and it still rests on an
engine layout `045` has not laid out in detail — if the array turns out denser or
hotter than a tenth of the die at seventy per cent of its power, the term grows in
proportion.

The remedy nobody has costed is to **vary the channel density across the cold
plate to match the power map** — finer channels above the engine tiles. It is
manufacturable, it is not in `022`, and it is the best unexplored idea in the
thermal design.

**What happens when a channel blocks.** A hundred and seventy-three channels per
face, a hundred and fifty microns wide, in a loop with a pump and a radiator in
it. One particle of the wrong size stops one channel and its neighbours pick up
the heat. Nobody has worked out how many channels can be lost before the die
above them exceeds its limit, and the filtration spec in `027` is currently a
guess written down as if it were a requirement.

## Related

`020` is the budget. `022` is the field. `023` is the corner plumbing and the
tetrahedra. `025` is the chain with every term derived. `026` is what happens on a
load step. `027` is everything outside the cube. `008` is the honest list.

---

*The figures in this document are rounded prose. The derived ones live in `101`, which lists every symbol in the project with its unit, its derivation and what it is for; `089` is the one-page version. `./run-checks` evaluates every constraint in under a second.*
