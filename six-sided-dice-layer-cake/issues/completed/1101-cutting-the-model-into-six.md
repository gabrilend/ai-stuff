# 1101 — Cutting the model into six

Produces `src/075-layer-assignment.md`.

## Current behavior

**Done.** `src/075-layer-assignment.md` exists. Twelve layers on the two faces
carrying the embedding and the output projection, fourteen on each of the other
four, cut so that **bytes read per token** are as equal as possible rather than
layer counts.

Five constraints. `C-075-3` asserts that balancing by bytes beats balancing by
count -- which for a model with uniform layers would be false, and that is
precisely when somebody would simplify it away.

**One constraint was comparing the wrong things.** It asked a face's whole share
of reading -- everything it touches in a token -- to fit inside its slice. That is
not a thing that has to fit; what has to fit is the largest single item plus the
next one behind it.

**The rule is stated and the algorithm is not.** Given a different shape somebody
must apply it by hand, and `058`'s layout and `048`'s chains both depend on the
answer.

## Intended behavior

**How a model's layers are distributed across the six faces, and the rule that
produces the distribution for any model rather than for one.**

### The constraint the cut must satisfy

`704` says the slowest stage sets the rate and every other face waits. So the cut
must **balance time, not layer count** — and the two are not the same, because
face zero also does the embedding lookup and face five also does the output
projection.

The output projection is the awkward one. For the reference model it is about one
and a half billion weights — larger than any single transformer layer, and read
once per token like everything else. Face five carrying it plus an equal share of
layers would be the slowest stage by a wide margin, and the whole pipeline would
run at its speed.

So the rule is: **assign layers so that the bytes each face reads per token are
as equal as possible**, since the machine is bandwidth-bound below the crossover
and read bytes are the currency. Above the crossover the currency is arithmetic
and the balance is slightly different — the blueprint must produce both and say
which is used when.

### What else the cut has to respect

**Slice capacity.** `607` requires a face to hold two of its layers at once. Every
face's largest layer must fit, twice, in nine hundred and twenty-two megabytes.
For a model with uniform layers this is automatic; for one with a wider layer
somewhere it is not, and the cut must not place two large layers where they
straddle a boundary badly.

**Contiguity.** A face's layers must be consecutive, or the handoff pattern stops
being a simple pipeline and the media layout in `803` stops being six contiguous
regions.

**Residency.** The embedding table lives with face zero and is large. It is read
once per token, not once per layer, so it costs less time than its size suggests —
and the blueprint must be careful to count *time*, not bytes, when placing it.

### The question that changes the answer

`009` entry O2: **should the output projection live on face five at all?** All but
one row of its output is discarded. A face that could compute only the rows the
sampler will want would read a fraction of it, and face five's share would drop by
more than a gigabyte, which changes this cut. The blueprint should give the
assignment both ways.

### The rule, not the table

The deliverable is an algorithm, not the six numbers for one model. Given a
model's shape, produce an assignment. **Then** show what it produces for the
reference model, as an example rather than as the specification.

## Symbols this must publish

The assignment rule. Bytes read per face per token, and arithmetic per face per
token, under it. Imbalance as a fraction. Largest layer per face against slice
capacity. Embedding and projection placement and their cost in time. The
assignment for the reference model, both ways on `009` entry O2.

## Constraints this must assert

- Imbalance is within `704`'s tolerance.
- Every face's largest layer fits `607`'s slice, twice.
- Layers per face are contiguous and the six sets partition the model exactly.
- Bytes summed over faces equals the resident model size from `1104`.

## Suggested implementation steps

1. Write the balance rule for bytes and for arithmetic separately.
2. Place the embedding and the projection by time cost, not by size.
3. Check every face against slice capacity.
4. Run it on the reference model both ways on O2.

## Blocks

`704`, `803`, `1102`, `1106`, `1107`.

## Blocked by

`607`, `704`, `1104`.

## Related documents

`003`. `009` entry O2 and entry R1.
