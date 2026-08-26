# 1107 — The sieve, run backwards

Produces `src/076a-the-sieve-in-reverse.md`.

## Current behavior

**Done.** `src/076a-the-sieve-in-reverse.md` exists.

The topology permits it, and the wall is memory. Six constraints, and `C-076a-5`
is asserted **in the failing direction on purpose**: training every parameter must
be out of reach by at least an order of magnitude. A blueprint set that is silent
about what a machine cannot do is worse than one that says so plainly.

What it costs is small: a second set of staging buffers, recomputation instead of
saved activations -- nearly free here because the machine has arithmetic to spare
below the crossover -- and `045`'s transposed multiply, which was priced three
ways and resolved by streaming differently rather than by changing the array.

`C-076a-2` asserts the property that makes it cheap: **backward traffic between
stages is the same size as forward traffic**, because the gradient with respect to
a face's own weights never leaves the face.

**Nothing here has been checked against a training run**, and whether a
rank-limited adapter trained this way learns anything useful is not a hardware
question. **The interleaved schedule is named and not designed.**

## Intended behavior

**What this machine can be made to learn, given the hardware it already has, and
where the wall is.**

### Why the topology permits it

Cutting a model into six consecutive runs of layers is pipeline parallelism. A
backward pass through a pipeline moves gradients from stage *n+1* to stage *n* —
the same stage-to-stage handoff the forward pass already makes, in the other
direction, through the same staging buffers in the core.

The all-reduce that training is usually said to demand belongs to two other
arrangements: data parallelism, which needs replicas to agree on gradients, and
tensor parallelism, which needs the faces of one layer to sum partial products.
**This machine does neither.** So the six spokes and no rim in `701` are as
sufficient for a backward pass as for a forward one.

### Where the wall actually is

Memory, and it is a cliff rather than a slope.

| what is being trained | state needed | fits in 64 GiB? |
|---|---|---|
| nothing — generation only | weights, 35 GB | comfortably |
| a low-rank adapter | weights, adapter master, gradient, two moments | **yes**, a few GB |
| the final layer only | weights, plus that layer at full precision | yes, tightly |
| every parameter | master weights, gradients, two moments, ~12 B/param | **no** — ~840 GB |

The middle two are the answer to *what the hardware naturally supports*. Full
training is out by more than a factor of ten and no arrangement of this cube
changes that.

### What has to be added, and it is not much

**A second set of staging buffers**, running the other way. `505` allocates the
forward six; this needs six more, and they are the same size.

**Somewhere to keep activations.** A backward pass needs what the forward pass
computed. For the reference model at one sequence of four thousand and ninety-six
positions, the saved tensors come to roughly twenty gigabytes — which fits beside
a thirty-five gigabyte model with room left, and does not fit at batch sizes above
about one. So the blueprint must present **recomputation** as the normal mode:
keep only the layer boundaries, recompute the inside of a layer during its
backward pass, and pay about a third more arithmetic for a large multiple less
memory. The machine has arithmetic to spare below the crossover, so this is nearly
free here in a way it is not on other hardware.

**A transposed multiply.** The gradient with respect to a layer's input needs the
weight matrix transposed. `605`'s array is weights-stationary, which makes the
transpose awkward: either the array can be read along both axes, or the weights
are held twice, or the backward pass streams differently. **This is the one real
silicon requirement in this ticket** and it belongs to `605`, which must price all
three.

**A schedule.** Forward and backward passes must be interleaved across the six
stages or half the machine idles. The standard arrangement — one forward, one
backward, alternating, with enough microbatches in flight to keep every stage busy
— is `704`'s to specify, and it needs more microbatches in flight than pure
generation does.

**Regions in the address map.** Activations or their checkpoints, adapter
parameters, gradients, optimiser moments. `505` has none of these.

### The gradient stays inside a face

Worth stating because it is the property that makes the whole thing cheap: the
gradient with respect to a face's **own** weights is computed from that face's own
activations and its own incoming gradient. Nothing leaves the face except the
gradient with respect to the layer's input, which is the same sixteen kibibytes
the forward handoff moves. **Training traffic between faces is the same size as
generation traffic between faces.**

## Symbols this must publish

State per parameter for each training mode. Total state for each mode against the
reference model. Activation storage with and without recomputation. Recomputation
arithmetic overhead. Reverse staging buffer size and count. Microbatches in flight
required. Transposed multiply cost, for each of the three options. Tokens per
second for adapter training.

## Constraints this must assert

- Total state for adapter training plus the resident model fits usable capacity
  from `501`.
- Activation storage under recomputation, at the stated batch and context, fits
  what is left.
- Reverse staging buffers fit `505`'s allocation.
- Backward traffic per stage equals forward traffic per stage. The property above,
  as a constraint, so it is noticed if the design drifts away from it.
- Full-parameter training state **exceeds** usable capacity. Asserted deliberately
  in the failing direction, so that the blueprint set states plainly what this
  machine cannot do rather than being silent about it.

## Suggested implementation steps

1. Work the state table for all four modes and find the cliff.
2. Specify recomputation as the default and derive its arithmetic overhead.
3. Hand the transposed multiply requirement to `605` with all three options
   priced.
4. Hand the interleaved schedule to `704` and the new regions to `505`.
5. Assert the impossibility constraint, on purpose.

## Blocks

`505`, `605`, `704`.

## Blocked by

`701`, `1101`, `1102`, `1104`.

## Related documents

`009` entry B1, which this ticket closes. `003` for the forward direction.
