# 003 — Datapath: one token

Follow a single token from the moment it arrives to the moment its successor is
chosen. Everything here is one pass through the machine; the numbers are for the
reference model in `078`, which is seventy billion parameters in eighty layers
with a hidden width of eight thousand one hundred and ninety-two, weights held at
four bits.

## The thing being carried

A token is not a word and it is not a number for very long. What actually moves
through the cube is an **activation vector**: eight thousand one hundred and
ninety-two numbers at sixteen bits each, sixteen kibibytes, describing the state
of one position in one sequence part-way through the model.

Sixteen kibibytes is the whole payload. Set that beside the thirty-five gigabytes
of weights that will be read to transform it and the shape of the machine
follows immediately: **the traffic is not the token, the traffic is the model.**
Everything in the design that looks extravagant — a solid block of static memory,
six links wide enough to swallow it, a cage that lets one face take all of it —
is there to move weights past a payload that would fit in a level-one cache.

## The path

```
   host link            face 0            core           face 1        ...
  ┌──────────┐      ┌───────────┐    ┌───────────┐   ┌───────────┐
  │  token   │─────▶│ embedding │───▶│  staging  │──▶│  layers   │──▶ ...
  │    id    │      │  layers   │    │  buffer   │   │  14..26   │
  └──────────┘      │   0..13   │    │     0     │   └───────────┘
                    └───────────┘    └───────────┘
                          ▲                 │
                          │                 │
                    weights read      the only surface
                    from the core     between two stages
```

Six stages. Nothing passes from one face to the next directly — every handoff is
a write into the core and a read out of it. That is a deliberate cost, and `050`
argues it: a face-to-face wire would have to run around the outside of the cube
or diagonally across the cavity, would be a different length for every pair, and
would need its own timing closure. A store to the middle is the same distance
from everywhere.

## Stage by stage

**Arrival.** A token identifier — one integer, typically under two hundred
thousand — arrives on whichever face is populated as a host link. It is written
into the core's request region (`038`) with the sequence it belongs to and the
position it occupies.

**Face zero, the embedding.** The identifier indexes a table with one row per
vocabulary entry and one column per hidden dimension. This is the only lookup in
the entire pass that is not a matrix multiply, and it is the reason face zero
carries one fewer transformer layer than its neighbours: the embedding table is
large, and holding it costs face zero a slice of the residency budget the others
spend on weights.

**Fourteen layers.** Each layer is the ordinary arrangement: normalise, project to
queries, keys and values, attend over every earlier position's cached keys and
values, project back, add to the residual, normalise again, the gated feedforward,
add again. `045` is the engine that does it and `048` is the sequencer that walks
it without the scalar core touching every step.

Per layer, per token, the arithmetic is two floating point operations per weight
— eight hundred and seventy-five million weights in a layer, so one and three
quarter gigaflop. Face zero's fourteen layers are about twenty-four and a half
gigaflop. Its four dies together do seven hundred and thirty-four teraflop a
second. **The arithmetic takes thirty-three microseconds.**

Reading the weights those operations consume takes far longer, and that gap is
the whole story of the machine's performance. Face zero's share of the model is
six point one gigabytes. Even at the full bandwidth of the core it arrives in
about a hundred and fifty microseconds. The engines spend four fifths of the
stage waiting.

**Into the core.** The transformed vector — still sixteen kibibytes — is written
to staging buffer zero. `053` sets the protocol: the write completes, a
completion flag is set with release ordering, and face one's sequencer is already
polling it. `039` is the rule that makes the flag mean what it looks like it
means, which matters because there is no operating system here to arbitrate a
race and nothing that would notice one.

**Faces one through four.** Thirteen layers each. Same shape, same arithmetic, no
embedding table. Each face reads only its own slice of the weights, which is the
point of cutting the model this way — a face never touches a weight belonging to
another face, so the six slices can sit in six different places and be loaded
from six different storage lines without any of them coordinating.

**Face five, and the head.** Thirteen layers, then the final normalisation and
the projection from eight thousand one hundred and ninety-two dimensions to one
score per vocabulary entry. That last projection is a matrix of about one and a
half billion weights — larger than any single transformer layer — which is why
face five, like face zero, carries a lighter share of the middle.

**The choice.** Scores become a probability distribution and one entry is drawn.
`043` has the instructions for it. The chosen identifier is written back to the
request region and the whole thing begins again at face zero.

## What it costs in time

| | |
|---|---|
| weights read, whole model, once per token | 35 GB |
| aggregate core read bandwidth | ≈ 39 TB/s |
| **time per token, bandwidth-bound** | **≈ 0.90 ms** |
| arithmetic per token | 140 GFLOP |
| aggregate arithmetic available | ≈ 4.4 PFLOP/s |
| time per token, compute-bound, one sequence | 0.032 ms |

The two columns are twenty-eight apart, and twenty-eight is the number that
governs everything about how this machine should be used. Below a batch of
twenty-eight it is waiting on memory and the arithmetic is nearly free. Above it,
the memory has been amortised and the engines are the wall.

## The thing that looks wrong and is not

While face two is working, five faces are idle. That looks like a machine running
at one sixth of itself, and for the arithmetic it is. For the clock on the wall it
is very nearly free, because the resource being serialised is not the scarce one:
six faces working at once would be pulling on the same core bandwidth and would
not finish sooner. The cage is built to let a single face take the whole of that
bandwidth for exactly this reason (`037`, `055`).

The serialisation becomes real the moment batching pushes the machine past the
crossover. Then the engines matter, and five sixths of them being idle is five
sixths of the machine being wasted — which is why `053` requires at least six
microbatches in flight whenever the batch is large, one per face, so that every
face has something of its own to work on.

## Where the time actually goes, per stage

```
        │◀────────────────── 150 µs ──────────────────▶│
face 0  │████ weights streaming ████████████│ math │   │
face 1  │                                   │      │████ weights ...
        │                                   ▲
        │                                   │
        │                          the handoff: 16 KiB
        │                          into the core, one flag set
```

The handoff is sixteen kibibytes against six gigabytes of weight traffic — four
parts in a million. Whatever else this machine's problems are, moving activations
between stages is not one of them.

## What is still open

**Whether the last projection should live on face five at all.** It is the single
largest matrix in the model and it is read once per token like everything else,
but unlike a transformer layer its output is thrown away except for one row. A
face that could compute only the rows it needs would read a fraction of it. Nobody
has worked out whether the sampler can be told which rows it will want before the
projection runs, and the answer changes face five's residency budget by more than
a gigabyte. Carried in `009`.

**What happens to a sequence that finishes mid-pipeline.** Six microbatches are in
flight; one of them contains a sequence that has just produced an end marker.
`053` currently lets the bubble propagate, which wastes a sixth of a step. Whether
a face may pull work forward to fill it is undecided, and it interacts with the
ordering model in `039` in a way nobody has traced.

## Related

`004` follows a weight rather than a token. `053` is the schedule. `076` is this
same path written as a constraint set rather than as a story. `080` is where the
two numbers above come from.
