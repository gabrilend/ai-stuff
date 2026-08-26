# 008 — Where the vision fights physics

Six places where the page in `notes/vision` says one thing and the world says
another. Each entry says what was asked, what the number turned out to be, what
the design does instead, and — the part that matters — **what of the original
idea survived**, because in five of the six cases the intent survives entirely and
only the mechanism changed.

This document exists because a specification that quietly fixes its own premises
is a specification nobody can argue with. Someone should be able to read this page,
disagree with a substitution, and go and change it.

---

## 1. The corners do not do the cooling

**The page says:** *The corners are pumped with coolant.*

**The number:** Twelve plain channels four millimetres square down the twelve
edges give about one hundred and fifteen square centimetres of wetted surface at a
heat transfer coefficient near five hundred and sixty watts per square metre per
kelvin. **Six and a half watts per kelvin.** The machine makes nineteen hundred and
ten. That is two hundred and ninety-seven kelvin of rise, which is not a hot chip,
it is a kettle.

**Why enlarging the channels does not help:** convection into a duct goes as the
fluid's conductivity divided by the duct's hydraulic diameter. Doubling a channel's
width doubles its surface and halves its coefficient. Wetted area per unit volume
is the only lever, and it points at *many small* rather than *few large*.

**What the design does:** the corners keep the job they are good at and lose the
one they were named for. They are the **manifold**: two networks of channels along
the twelve edges, joined at the eight corners, supplying and draining a
**microchannel field bonded to the back of every face** — a hundred and
seventy-three channels a hundred and fifty microns wide per face, one thousand two
hundred and forty square centimetres of wetted surface across the cube, fourteen
hundred and seventy watts per kelvin.

**What survived:** everything structural. Coolant still enters and leaves at the
corners, four in and four out, and the corner geometry turns out to be *better*
than the page could have known — the cube's own graph makes the four inlets a
regular tetrahedron and guarantees every point of the supply network is within one
edge of pressure (`023`).

**What it cost:** six etched copper plates, each of which is a water channel a
millimetre from live silicon. `017` is that seal, and it is the likeliest single
point of failure in the machine.

---

## 2. One wire per bit becomes one wire per bit of a window

**The page says:** *1 wire per bit in memory so that it can be almost instantly
replicated somewhere else.*

**The number:** the core holds sixty-four gibibytes. That is five hundred and
fifty billion bits. At the finest bond pitch anyone can make — ten microns,
copper to copper, permanent — a fifty-two millimetre square face holds twenty-seven
million positions. The ask exceeds the possible by a factor of about
**twenty thousand**.

**What the design does:** the face carries as many conductors as it physically
can, and memory is exposed through them as a sliding window. Two mebibytes,
sixteen million seven hundred and seventy-seven thousand two hundred and sixteen
conductors, one per bit, moved on one edge. The window — the **pane** — is
re-aliased to a different part of the core with a single store.

**What survived:** the property the page was actually reaching for. Sixty-four
gibibytes crosses the pane in thirty-three microseconds, which against a four
hundred gigabit network link is a speedup of forty-two thousand. *Almost instantly
replicated somewhere else* is delivered; it just takes thirty-two thousand seven
hundred and sixty-eight edges instead of one.

**And the page found the wall itself.** *Alternatively, each byte, so you can pulse
8 bits in a cycle* divides the conductor count by eight and moves the required
pitch from ten microns to thirty-two, which is the difference between a permanent
bond and an ordinary microbump. Byte mode is the grade most likely to be built
(`068`).

---

## 3. The block in the middle is mostly copper

**The page says:** *written to central block of shared memory, inside the center
of the die.*

**The number:** a solid forty millimetre cube of memory silicon is sixty-four
cubic centimetres of it. At fifty microns per thinned die that is about eight
hundred layers, roughly one and a half wafers of leading-node silicon per cube,
and the leakage alone would be several kilowatts before a single read.

**What the design does:** the core is still a solid forty millimetre block at the
geometric centre, and it is still all one shared memory. But it is **twenty-four
memory tiers laminated between copper–molybdenum cooling plates sixteen hundred
microns thick** — three per cent silicon by volume and the rest heat exchanger.
About eighty gigabytes raw, seventy-two usable.

**What survived:** the shape, the position, the sharing, and the capacity that
matters — sixty-four gibibytes holds a seventy billion parameter model at four
bits with room for its key and value cache. The block is where the page put it and
does what the page wanted.

**What it cost:** honesty about what is inside it. Anyone imagining a solid brick
of memory should imagine a layer cake instead, which is what the project is called.

---

## 4. Six disk lines become five

**The page says:** *the reason for the 6 cpu arrangement is because then they can
pull from 6 different hard disk lines.* And, two paragraphs later, *one of the
faces is allowed to be an output data tube.*

**The conflict:** a face has one outward surface. It can carry a storage connector
or a tube, not both. The two sentences want seven faces.

**What the design does:** all six faces carry the same **port field** (`056`) — an
identical outward interface, populated at assembly. A cube built without an output
tube has six storage lines. A cube built with one has five, and the sixth slice of
the model is loaded over one of the other five and relayed through the core.

**What survived:** the reason the six-face arrangement was chosen. Six independent
paths to storage remain available; spending one is a build option with a known
price. Load time rises by a fifth — from about thirty milliseconds to thirty-six —
and load happens once per power cycle, so the price is nothing.

**What it cost:** nothing measurable. This is the cheapest of the six.

---

## 5. The sieve does not make it faster; it makes it *not slower*

**The page says:** *the tokens are passed through filter sieve style.*

**The expectation this creates:** a pipeline, six stages deep, six times the
throughput.

**The number:** generating one token means reading every weight in the model
exactly once — thirty-five gigabytes — and doing two floating point operations per
weight. The reading takes nine tenths of a millisecond. The arithmetic takes
thirty-two microseconds. **The machine is memory-bound by a factor of twenty-eight**,
and six faces working at once would be pulling on the same memory.

**What this means for the sieve:** the serialisation is nearly free, which is
better than it sounds and different from what was expected. Face two working while
five faces idle costs no wall-clock time, because the idle faces would not have
been able to get at the memory anyway. The cage is deliberately built so a single
face can take the core's entire bandwidth, which is what converts the sieve from a
cost into a non-event (`037`, `055`).

**Where the sieve does pay:** above a batch of about twenty-eight, when the memory
traffic has been amortised across enough sequences that arithmetic becomes the
wall. Then all six faces matter and the pipeline must be kept full — at least six
microbatches in flight — or five sixths of the machine is idle for real.

**What survived:** the arrangement, entirely. What changed is the reason to want
it: the sieve is not a throughput multiplier, it is what lets a model larger than
any one face's memory be held resident at all.

---

## 6. They are not CPUs

**The page says:** *there's 6 CPU's arranged like the faces on a die.*

**What is actually on a face:** four dies, each with one two hundred and fifty-six
by two hundred and fifty-six multiplier array, a sequencer that walks a
transformer layer without software in the loop, and a small scalar core whose
entire job is to set up the sequencer and handle the sampler. There is no memory
protection, no interrupt controller worth the name, no privilege levels, no
virtual memory, and no expectation that anything but a tensor program ever runs.

**What survived:** the count and the arrangement, which is what the page was
actually specifying. Whether the thing on a face is called a processor is a matter
of taste; what matters is that there are six of them, they are identical, and each
one owns a slice of the model.

**What it cost:** the machine cannot host itself. Something else has to compile
for it, load it, and drive it. `085` is the bring-up procedure and it assumes an
attached host throughout.

---

## What did not have to change

Worth saying, because five of the six above are substitutions and the reader may
come away thinking the page was wrong. It mostly was not.

- **Six faces around a shared middle** is the right shape, and for the reason
  given: six independent storage paths and one distance from every face to the
  memory.
- **Coolant at the corners** is the right place for it, and the cube's geometry
  rewards it more than the page claimed.
- **Layers sliced across the faces, tokens passed inward** is the right mapping,
  and it is what makes a model larger than one face's memory run at all.
- **A face spent on output** is the right trade, and the byte-mode retreat written
  into the page is the exact engineering answer.

Four correct architectural decisions out of a single page of prose is a good
ratio. The six entries above are what it costs to build them.

---

*The figures in this document are rounded prose. The derived ones live in `101`, which lists every symbol in the project with its unit, its derivation and what it is for; `089` is the one-page version. `./run-checks` evaluates every constraint in under a second.*
