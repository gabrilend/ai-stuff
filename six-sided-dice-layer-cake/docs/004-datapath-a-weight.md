# 004 — Datapath: one weight

Follow a single number — one of seventy billion — from the platter it was stored
on to the multiplier that consumes it. It makes the journey once at load time and
then repeats the last leg of it once per token, forever.

## What a weight is here

Four bits. Not a float, not a byte: a four-bit index into a sixteen-entry table
that is shared by a group of a hundred and twenty-eight neighbouring weights, with
one sixteen-bit scale per group. `046` is the format and `077` is what it costs in
accuracy.

The reason to care about four bits rather than eight is not storage — sixty-four
gibibytes would hold a seventy billion parameter model at eight bits too, barely.
It is that **the weight is read once per token and the reading is the bottleneck**,
so halving the weight halves the time the machine takes to think. Precision is
being traded for speed at a rate of one for one, which is a much starker bargain
than it usually is.

## The three homes

```
   media                core                 face slice            engine
 ┌─────────┐        ┌───────────┐         ┌─────────────┐      ┌──────────┐
 │ 35 GB   │  once  │  35 GB    │  once   │  437 MB     │ many │ 256×256  │
 │ on      │───────▶│  resident │────────▶│  one layer, │─────▶│   MACs   │
 │ eighty  │  ~30ms │  in SRAM  │ per tok │  plus the   │ per  │          │
 │ drives  │        │           │  ~150µs │  next one   │ tok  │          │
 └─────────┘        └───────────┘         └─────────────┘      └──────────┘
   read once         read once per          read B times        consumed
   per power cycle   token, forever         per token
```

Each arrow is a different order of magnitude and a different reason for existing.

## Leg one: media to core, once

A model is laid out on the storage lines as six slices, one per face, in the order
`058` specifies — layer by layer, and within a layer, tensor by tensor, in the
order the sequencer walks them. Laying it out in walk order rather than in the
order the training framework happened to write it is the difference between a
sequential read and eighty million random ones.

Five storage lines are populated on a cube with an output tube; six on a cube
without one. Each line aggregates sixteen drives at about sixteen gigabytes a
second, so a line moves two hundred and fifty-six gigabytes a second and five
lines move about one and a quarter terabytes a second. **Thirty-five gigabytes
lands in about thirty milliseconds.**

The sixth slice, on a cube whose sixth face became a tube, comes in over one of
the other five and is relayed through the core. It costs a fifth more load time
and nothing else, because load happens once.

Nothing is checked on the way in beyond the media's own error correction. `069`
argues that a weight corrupted at load and then read ten million times is a
different kind of problem from one corrupted in flight, and the answer is a
whole-slice hash verified after load rather than per-transfer checking that would
slow the steady state down for a fault that happens at load or not at all.

## Leg two: core to face slice, once per token

This is the leg that costs the machine its time.

A face reads the weights for one layer — four hundred and thirty-seven megabytes
at four bits — out of the core and into its own static memory slice. It does this
thirteen or fourteen times per token, once per layer it owns. Across six faces
that is the whole thirty-five gigabytes, once, for every token generated.

The transfer runs over the radial link (`051`) at up to fifty terabytes a second
of raw link capacity, but the link is not what limits it — the core is. Thirty-two
tiers each delivering eight thousand one hundred and ninety-two bits per cycle at
the core clock is **thirty-eight and a half terabytes a second aggregate**, and
that number, divided into the model's weights plus one sequence's cache, is the
machine's headline latency of about a millisecond per token — a thousand and
twenty-one tokens a second.

The cage (`037`) will give all of that to one face if the
other five are not asking. This is why the sieve's serial structure costs
essentially nothing when a single sequence is being generated, and it is the least
obvious load-bearing decision in the design.

## Leg three: slice to engine, once per token per sequence in the batch

Inside a face, the weight sits in the slice and is read by the matrix engine once
for **every sequence in the batch**. This is the reuse the whole architecture is
built to harvest: one expensive read from the core, then B cheap reads from
memory a millimetre away.

That reuse is why the face slice has to be as large as it is, and it produces the
sharpest cross-phase constraint in the project:

    C_face_slice  >=  2 * C_layer_weights

The slice must hold the layer being computed **and** the layer being fetched
behind it, or the prefetch in `060` cannot hide the core read and the machine
runs at the speed of the leg above with no overlap. Four hundred and thirty-seven
megabytes each, eight hundred and seventy-four megabytes together — which is what
forces a compute die to spend half its area on static memory (`041`), which sets
the die size, which sets the face size, which sets the cube. **The cube is sixty
millimetres on a side because a transformer layer is four hundred and thirty-seven
megabytes.**

Change the reference model and that chain moves. `012` is where it is anchored and
`095` is what tells you which link broke.

## What the weight meets at the end

A four-bit index and a shared scale arrive at a multiplier array of two hundred
and fifty-six by two hundred and fifty-six cells running at one point four
gigahertz. The index is expanded through the group's table into the engine's
internal format on the way in — `045` does this in the datapath rather than in a
separate pass, because a separate pass would mean writing the expanded weights
somewhere and expanded weights are four times the size.

The weight is multiplied by one activation, added into an accumulator, and
forgotten. It will be read from the slice again for the next sequence in the
batch, and from the core again for the next token, and from the media never
again until the machine is power-cycled.

## The three numbers that matter

| | derived |
|---|---|
| media to core, whole model | 34 ms, once |
| core to slices, whole model | 0.98 ms, per token |
| slice to engines, whole model | 0.039 ms × batch, per token |

The middle row is the machine. The top row is why the six storage lines exist and
is otherwise unimportant. The bottom row is why batching works.

## What is still open

**Whether the group scale should be sixteen bits.** A hundred and twenty-eight
weights share one scale, so the scale costs one eighth of a bit per weight — but
it is read at full width by the engine's expansion path and `045` has not
established whether eight bits would cost measurable accuracy. If it would not,
the format saves a percent of the read that dominates everything. Carried in
`009`.

**Whether a face should keep more than two layers resident.** With a batch large
enough to be compute-bound, a third buffered layer would let the core read run
further ahead and smooth out contention between faces. It costs another four
hundred and thirty-seven megabytes of slice, which does not fit on the current
die. Whether it is worth a larger die is a phase 6 question nobody has priced.

## Related

`003` follows a token rather than a weight. `058` is the media layout. `059` is
residency. `060` is the prefetch. `061` is the arithmetic that says a face never
starves.

---

*The figures in this document are rounded prose. The derived ones live in `091`, which lists every symbol in the project with its unit, its derivation and what it is for; `089` is the one-page version. `./run-checks` evaluates every constraint in under a second.*
