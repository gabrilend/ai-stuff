# 000 — Concept overview

## What it is

A cube, sixty millimetres on a side, that holds a language model still and pours
tokens through it.

Six processors sit on the six faces, looking inward. The volume they enclose is
filled with memory that all six can reach. Coolant enters at four of the eight
corners, crosses every face, and leaves at the other four. Five of the faces
carry a storage connector on the outside; the sixth carries something else, and
that sixth face is the reason the shape was chosen rather than a rack of ordinary
cards.

The name has two meanings and both are literal. **Six sided dice** is the
arrangement: six compute surfaces on the faces of a die, corners pumped. **Layer
cake** is what is inside: the model's layers are cut into six consecutive slices,
one slice per face, and the memory in the middle is itself a stack of tiers
bonded one on top of another.

## The one sentence version

Instead of moving a model's weights past a processor, hold all the weights still
inside a block of static memory and move the *token* past them, falling through
six faces the way grain falls through a stack of sieves.

## Why a cube and not a board

Three reasons, and only the third is about geometry for its own sake.

**Six independent paths to storage.** A conventional accelerator has one edge
facing the host and everything — weights, activations, results — queues through
it. A cube has six outward surfaces, none of them privileged, so six storage
lines can be pulled at once with no arbitration between them. Loading a seventy
billion parameter model is six streams, not one.

**Everything is equidistant from the middle.** In a flat package, the far corner
of the die is ten times further from the memory controller than the near edge,
and the difference shows up as wire delay that has to be budgeted for in every
timing path. In a cube, all six compute faces are exactly the same distance from
the block of memory at the centre — one face thickness — so a single radial link
design serves all six, and one timing closure covers the whole machine instead of
six.

**The corners are free.** A cube's eight corners are the parts of the volume no
functional block wants: too small for a die, awkward to route through, structurally
the stiffest place. That is exactly where plumbing belongs. Every corner touches
three edges, every edge touches two corners, and the corners divide cleanly into
two sets of four such that no edge ever joins two corners of the same set. So the
coolant can enter at four corners and leave at the other four, with twelve
identical channels between them and no channel running in the wrong direction.
The geometry hands you a balanced manifold and asks nothing in return. This is
worked out in `023-corner-parity-plumbing`.

## What is inside, from the outside in

```
                       an edge rail                a corner manifold
                            │                             │
                            ▼                             ▼
       ╔═══════════════════════════════════════════════════╗
       ║  ┌─────────────────────────────────────────────┐  ║   ── face assembly
       ║  │  ┌───────────┬───────────┐                  │  ║      (compute)
       ║  │  │  die  0   │  die  1   │   four dies,     │  ║
       ║  │  ├───────────┼───────────┤   two by two     │  ║
       ║  │  │  die  2   │  die  3   │                  │  ║
       ║  │  └───────────┴───────────┘                  │  ║
       ║  └──────────────────┬──────────────────────────┘  ║
       ║                     │  radial link                ║
       ║       ┌─────────────▼──────────────────┐          ║
       ║       │░░░░░░░░░░░ the cage ░░░░░░░░░░░│          ║   ── the cavity
       ║       │░░┌──────────────────────────┐░░│          ║
       ║       │░░│▓▓▓▓▓▓▓▓ tier 31 ▓▓▓▓▓▓▓▓▓│░░│          ║
       ║       │░░│══════ copper lamina ═════│░░│          ║   ── the core:
       ║       │░░│▓▓▓▓▓▓▓▓ tier 30 ▓▓▓▓▓▓▓▓▓│░░│          ║      thirty-two
       ║       │░░│══════ copper lamina ═════│░░│          ║      tiers, each
       ║       │░░│            ⋮             │░░│          ║      one part
       ║       │░░│▓▓▓▓▓▓▓▓ tier  0 ▓▓▓▓▓▓▓▓▓│░░│          ║      silicon to
       ║       │░░└──────────────────────────┘░░│          ║      twenty-four
       ║       │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│          ║      parts copper
       ║       └────────────────────────────────┘          ║
       ║  ┌─────────────────────────────────────────────┐  ║
       ║  │           the opposite face                 │  ║
       ║  └─────────────────────────────────────────────┘  ║
       ╚═══════════════════════════════════════════════════╝
```

**The envelope.** Sixty millimetres to a side. Not chosen for elegance — it is
what falls out of putting four reticle-sized dies on a face with room for a
sealing ring and a four-millimetre coolant rail down each edge. `012` derives it.

**Six face assemblies.** Each one is four compute dies of twenty-four millimetres
square, mounted two by two on an interposer, with a microchannel cold plate
bonded to its back and a port field on its outward surface. All six are the same
part. What makes a face a storage face or an output face is which connector gets
populated on its port field, decided at assembly and never in silicon.

**The cavity.** What the six faces enclose: forty-six millimetres of clear space,
filled by two things.

**The cage.** A three millimetre shell lining the inside of the cavity. It is the
switch: six link terminations, the address decode, and a crossbar wide enough
that any one face can take the entire bandwidth of the memory behind it when the
other five are idle. That last property is not a luxury and `055` explains why —
it is what makes the sieve cost nothing for a single stream of tokens.

**The core.** The forty millimetre cube the cage encloses, and it is mostly not
silicon. Thirty-two memory tiers, each forty millimetres square and fifty microns
thick, laminated between copper cooling plates twelve hundred microns thick. Two
per cent silicon by volume and the rest a heat exchanger, which is the only way a
solid block of static memory at the geometric centre of a sealed cube can survive
its own leakage. Seventy-eight gigabytes raw, sixty-four gibibytes usable once
error correction, spare rows and redundant tiers are taken out. It is the layer
cake the project is named after, and every one of the six faces reads and writes
all of it.

## The sixth face

One face gives up its storage connector and becomes an **output tube**.

The idea in the vision document is one wire per bit of memory, so that the
contents can be put somewhere else in a single clock edge rather than serialised
into packets. Taken literally against sixty-four gigabytes that is five hundred
billion wires, which is not a thing. Taken against what a fifty-two millimetre
face can physically carry, it becomes buildable and remains startling.

At a ten micron hybrid-bond pitch a face holds twenty-seven million pads. Spend
one in five on power, ground and shielding and twenty-one million signal
conductors remain. Round down to a power of two and you get **two mebibytes,
sixteen million seven hundred and seventy-seven thousand two hundred and sixteen
conductors, one per bit, moved in one edge**. That window is called the **pane**,
and the whole of `062` through `069` is about making it real.

The vision document offers its own retreat and it is the right one: *alternatively,
each byte, so you can pulse 8 bits in a cycle*. One conductor per byte instead of
per bit divides the conductor count by eight, which moves the required pitch from
ten microns — bondable only, never detachable — to twenty-eight microns, which
ordinary microbumps reach. **Byte mode is what makes the spout a part rather than
a wish**, and it costs eight clock edges instead of one.

## What falls through it

A model is cut into six consecutive runs of layers, one run per face. A token's
activation vector enters at face zero, is transformed by that face's layers,
lands in the core, is picked up by face one, and so on around. Six stages. The
core is the surface between stages — nothing passes from face to face directly,
because a store to the middle is the same distance from everywhere and a
face-to-face wire would not be.

This is the sieve, and the obvious objection to it is wrong in an interesting
way. The objection: while face two is working the other five have nothing to do,
because in autoregressive generation the next token cannot be started until the
current one is finished, so a single stream uses one sixth of the machine.

That is true of the **matrix engines** and false of the **wall clock**. Generating
a token means reading every weight in the model exactly once, and reading weights
is what the machine spends its time on -- the arithmetic per weight is two
floating point operations, which the engines finish in a small fraction of the
time the read takes. Six faces working at once would be contending for the same
memory bandwidth and would not finish sooner. So the sieve costs almost nothing
for a single stream, because the resource it serialises was never the scarce one.

What the sieve does cost is engine utilisation, and that only starts to bind when
there is enough work to saturate the memory. `079` puts the crossover at a batch
of about twenty-eight: below it the machine is bandwidth-bound and the sieve is
free, above it the machine is compute-bound and the pipeline must be kept full
with at least six microbatches in flight or five sixths of the arithmetic is
wasted. `080` gives both numbers.

## What it refuses to promise

**It is not general purpose.** There is no operating system, no virtual memory,
no protection between the faces, and no expectation that anything other than a
tensor program runs on it. The instruction set in `043` is what a matrix engine
needs to be fed and nothing more.

**It does not fit a model bigger than the core.** Sixty-four gibibytes holds
seventy billion parameters at four bits with room for the key and value cache.
Larger than that and weights must stream from the storage lines every token,
which drops throughput by roughly the ratio of storage bandwidth to core
bandwidth — a factor of about two hundred. The machine does not degrade
gracefully here; it falls off a cliff, and `078` says exactly where the edge is.

**The corners do not do the cooling.** They do the plumbing. The vision says the
corners are pumped with coolant and they are, but a plain channel down each edge
removes about six watts per kelvin and the machine makes sixteen hundred and
fifty. The heat is actually taken out by microchannel fields bonded to the back
of every face, which the corners feed. `022` and `025` show the arithmetic, and
`008` collects this and the other three places where the original page and the
physics disagree.

**Nothing here has been built.** This is a design, expressed as blueprints with
their constraints written down in a form a program can check, and the program
reports that they are consistent with each other. Consistent is not the same as
correct, and neither is the same as manufacturable. `090` says what a materials
engineer would receive and what they would still have to find out.

## Where to go next

`001` for the phases and what each one contains. `002` for how to read a
blueprint, which you need before `010`. `003` through `007` follow one thing at a
time all the way through the machine — a token, a weight, a joule, an ampere, and
a pane of bits on its way out — and are the fastest way to understand how the
parts are joined. `008` is where the design admits what it changed. `009` is
every question still open, and there are more of them than there are answers.
