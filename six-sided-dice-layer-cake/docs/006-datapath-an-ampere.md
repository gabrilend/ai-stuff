# 006 — Datapath: one ampere

Follow current from the wall to the gate it switches. The interesting question is
not how much — it is *where the copper goes*, because the corners are full of
water and the faces are covered in connectors, and a sealed cube has no third
route to its own middle.

## The problem stated plainly

Nineteen hundred and ten watts. If it arrived at the voltage the transistors run
at, three quarters of a volt, that would be **two thousand five hundred amperes**
crossing the boundary of a sixty millimetre cube. Two and a half kiloamps is not a
connector. It is a pair of busbars the size of a wrist, and there is nowhere on
this object to bolt them.

So the current does not arrive at three quarters of a volt. It arrives at
forty-eight, at forty amperes, and the last two factors of sixty-four happen
inside.

## The route

```
   48 V in                on the face                     at the die
  ┌─────────┐        ┌──────────────────┐            ┌──────────────┐
  │ 40 A    │───────▶│  48 V → 5 V      │───────────▶│ 5 V → 0.75 V │
  │ total,  │  port  │  switched, on    │  interposer│ integrated   │
  │ 6.6 A   │  field │  the interposer  │  planes    │ regulators,  │
  │ per face│        │  96 % efficient  │            │ 90 % eff.    │
  └─────────┘        └──────────────────┘            └──────┬───────┘
                              │                             │
                              │  one sixth of the core's    ▼
                              │  share, sent inward     76.7 A per die
                              ▼
                        ┌──────────────┐
                        │  the cage    │
                        │  and the     │
                        │  core        │
                        └──────────────┘
```

**Every face brings in its own power through its own outward port field.** This is
the decision that makes the mechanical design possible, and it is worth naming as
a decision rather than letting it look inevitable. The alternative — a single
power entry somewhere and distribution inside — would have to cross the cavity,
and the cavity is a coolant plenum with a memory stack in it.

Bringing power in at each face means the copper never travels more than about
thirty millimetres and never shares space with water. **No current passes through
a corner or along an edge.** The corners are plumbing and nothing else, which is
why `023` can treat them as a pure hydraulic problem and `030` can treat power as
a purely radial one.

## What reaches the middle

The core and the cage need two hundred and sixty watts and they are at the centre
of a sealed object. That current goes **inward through the same interface the data
does**: the radial contact between a face's inward surface and the cage, a
forty-six millimetre square patch carrying about five and a quarter million pads
at a twenty micron pitch.

Spend two fifths of those pads on power and ground and there are two million
conductors available. At five milliamperes each — a fifth of what a twenty micron
copper pillar will carry — that is ten thousand amperes of capability against the
three hundred and six actually needed. **Power is not what limits the radial
interface**; signal integrity is, and `051` is where that fight happens.

Each face carries one sixth of the core's load, fifty-one amperes, which is
one seventh of what it is already delivering to its own dies. The core's supply is
therefore six-way redundant by construction: a face that loses its regulator stops
computing, and the core keeps running on the other five.

## The domains

| domain | volts | what it feeds | amperes |
|---|---|---|---|
| `V_logic` | 0.75 | compute die logic and matrix engines | 1840 |
| `V_array` | 0.85 | static memory arrays, core tiers and face slices | 306 |
| `V_link` | 0.60 | radial link drivers, low swing by design | 117 |
| `V_port` | 1.20 | port field transceivers, storage lines, the spout | 8 |
| `V_aux` | 3.30 | sensors, thermal telemetry, the interlock | 1 |

Five domains, and `029` argues about whether it should be four. The array domain
is separate from the logic domain because static memory cells need more voltage
than logic does to stay stable, and running the whole die at the higher of the two
would cost about eleven per cent of the total power for no return. The link domain
is separate because the link is short enough to swing six hundred millivolts and
every millivolt not swung is picojoules not spent at thirty-nine terabytes a
second.

## The hard part is not the average

Seventy-six point seven amperes per compute die is a large but ordinary number. The
difficulty is that a matrix engine can go from idle to fully switching **in one
clock cycle** — a two hundred and fifty-six by two hundred and fifty-six array
either has operands or it does not.

Seventy-six amperes appearing in about a nanosecond is seventy-seven billion
amperes a second. The supply has to hold three quarters of a volt to within about
twenty-two millivolts while that happens, and a voltage regulator, however good,
takes tens of nanoseconds to notice. In between, the only thing holding the rail
up is stored charge.

The charge required is the current times the response time divided by the droop
allowed. With an integrated regulator responding in ten nanoseconds, that is
**thirty-four microfarads per die** — which is why the interposer under every
compute die is a deep trench capacitor array of about three hundred and forty
square millimetres, and why `031` treats decoupling as a floorplan constraint
rather than a component to add at the end.

The other half of the answer is to refuse to make the step. The sequencer in `048`
ramps engine activity over sixty-four cycles rather than starting it all at once,
which cuts the peak slew by that factor and costs forty-five nanoseconds at the
start of a layer — against a layer that takes a hundred and fifty microseconds.
It is the cheapest twenty-two millivolts in the machine.

## Where the copper is thinnest

Electromigration sets the floor. A conductor carrying too much current per unit
of cross-section slowly moves its own atoms downstream and eventually opens. The
limit at the operating temperature and the ten-year target in `086` is about one
milliampere per square micron for the copper used in the upper metal layers.

Seventy-six point seven amperes therefore needs at least seventy-six thousand
square microns of cross-section arriving at each die, distributed across the power
grid rather than concentrated. `032` works this down to a minimum width for every
level of the power network, and the binding case is not the die at all — it is the
via array where the interposer's five volt plane necks down to feed a regulator.

## What is lost on the way

| stage | efficiency | watts lost |
|---|---|---|
| 48 V to 5 V, on the interposer | 96 % | 76 |
| 5 V to 0.75 V, integrated regulators | 90 % | 184 |
| resistive loss in planes and grids | 98.5 % | 25 |
| **delivered to the point of load** | | **1650** |
| **drawn from the supply** | | **1910** |

Two hundred and sixty watts is spent turning voltage into other voltage, and every
one of them becomes heat inside the cube, on the face interposers, a millimetre
from the microchannel field. That is convenient — it is the best-cooled place in
the machine — but it is fourteen per cent of the thermal budget spent on
conversion, and `029` should be read as an argument about whether it can be
twelve.

The two totals in that table are the same number seen twice: **everything drawn
from the supply leaves as heat.** `095` checks it as a constraint, because it is
the one energy statement in the project that cannot be approximately true.

## What is still open

**Whether five volts is the right intermediate.** Twelve would halve the current
in the interposer planes and cost a harder second-stage conversion ratio. Nobody
has priced the two against each other and the answer changes the plane thickness
in `014`, which changes the face thickness, which changes the cube.

**What the machine does on a brownout.** `033` sequences the power up. It does not
yet say what happens when the forty-eight volt input sags mid-token — whether the
faces stop cleanly, whether the core's contents survive, and whether there is
enough stored charge anywhere to write down what was happening. A machine that
loses sixty-four gibibytes of resident model on a flicker has to spend thirty
milliseconds reloading it, which is survivable, but a machine that loses it
*silently and half-way* is not.

## Related

`028` is the budget. `029` the domains. `030` the network. `031` decoupling. `032`
current density. `033` sequencing. `005` is where all of this ends up.

---

*The figures in this document are rounded prose. The derived ones live in `101`, which lists every symbol in the project with its unit, its derivation and what it is for; `089` is the one-page version. `./run-checks` evaluates every constraint in under a second.*
