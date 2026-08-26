# 1102 — The dataflow of one pass

Produces `src/076-token-flow.md`.

## Current behavior

`003` tells this as a story. No blueprint states it as a dataflow with sizes on
every arrow.

## Intended behavior

**Every tensor that moves during one forward pass, its size, where it comes from
and where it goes** — the document that every bandwidth claim in the project is
ultimately checked against.

### Why the story is not enough

`003` is for a person. This is for the checker. Six other blueprints assert
traffic fractions — `701`'s four parts in a million, `706`'s under a per cent for
non-weight traffic, `602`'s inter-die estimate — and every one of them is a
fraction of a number that has to be computed somewhere. This is where.

### What must be enumerated

Per layer, per token, per sequence: every input, every intermediate, every output,
with a size derived from the model shape and the formats in `606`. Then the same
per face, then per pass.

The classes that matter, because they have different destinations:

- **Weights**, from core to slice. The dominant term by four orders of magnitude.
- **The residual stream**, sixteen kibibytes, carried between layers within a face
  and between faces through the core.
- **Key and value cache**, written once per token per layer, read entirely every
  token. **This grows with context and is the term that eventually rivals the
  weights**, which is what makes `1104`'s capacity surface two-dimensional.
- **Intermediates** inside a layer, which never leave the die and are the largest
  by count and the smallest by consequence.
- **Inter-die traffic**, whatever `602`'s partitioning failed to avoid.

### The cache term deserves its own treatment

At short context it is noise. At long context it is the whole machine: for the
reference model at eight-bit cache, each position costs a fixed number of bytes
per layer, and at sufficient length the cache is read per token more than the
weights are. The blueprint must give the crossover length, because past it the
machine's behaviour changes character and nobody has said where that is.

### Batch multiplies some arrows and not others

Weights: read once regardless of batch. That is the whole reason batching works.
Residual stream, cache, intermediates: all scale with batch. The blueprint must
mark every arrow with whether it scales, because getting one wrong is how a
performance model comes out a factor of twenty-eight off.

## Symbols this must publish

Size per tensor per layer, symbolically in the model shape. Traffic per class per
token, at batch one and at batch B. Cache growth per position. The context length
at which cache traffic equals weight traffic. Inter-die traffic. Totals per face
and per pass.

## Constraints this must assert

- Weight traffic per pass equals the resident model size from `1104`. The pass
  reads every weight exactly once, asserted.
- Non-weight traffic as a fraction agrees with the figure `706` assumed.
- Handoff traffic as a fraction agrees with `701`'s.
- Inter-die traffic agrees with `602`'s estimate.
- Every arrow is marked as batch-scaling or not, enumerated so none is missed.

## Suggested implementation steps

1. Enumerate the tensors of one layer symbolically.
2. Roll up to face and to pass.
3. Treat the cache separately and find the crossover length.
4. Mark the batch scaling per arrow.
5. Close the four cross-blueprint agreements.

## Blocks

`701`, `706`, `602`, `1104`, `1105`, `1106`, `1107`.

## Blocked by

`606`, `1101`, `1104`.

## Related documents

`003` is this as a story. `004` for the weight class.
