# 606 — How numbers are written down

Produces `src/046-numeric-formats.md`.

## Current behavior

**Done.** `src/046-numeric-formats.md` exists with seven formats, one rounding
mode, and special values refused rather than propagated — which is a real
decision: a machine that carries a not-a-number through eighty layers has thrown
away the only place the fault was findable.

Seven constraints. Writing them exposed something small and general about the
notation: **a width is a number of bits and an exponent is a pure number**, and
two-to-the-width needs a conversion between them. One unit quantity, `b1`, is
declared for that purpose and is the only such thing in the project.

**`009` entry F1 is quantified and not closed.** The group scale costs about three
per cent of the read that dominates everything, and whether eight-bit scales would
cost measurable accuracy is a `077` measurement that does not exist.

**The expansion table's fitting rule is not here**, and how the table is fitted
changes the error by more than the bit width does.

## Intended behavior

**Every numeric format in the machine, where each is used, and the exact rule for
converting between them.**

| what | format | where |
|---|---|---|
| weights | 4-bit index, 16-entry table, group of 128, one scale | core, slice, engine input |
| the scale | 16-bit float | beside every group |
| activations, residual stream | 16-bit float | staging buffers, between layers |
| engine operands | 8-bit integer, per-tensor scale | inside the array |
| accumulators | 32-bit | inside the array |
| key and value cache | 8-bit | core |
| logits | 32-bit float | face five only |

### Why weights are four bits

Not storage. Sixty-four gibibytes would hold the reference model at eight bits,
barely. It is that **a weight is read once per token and the reading is the
bottleneck**, so halving the weight halves the machine's time to think. Precision
is being traded for speed one for one, which is a much starker bargain than usual
and the blueprint should say so.

### The exactness rule

Two implementations of this machine must agree bit for bit or `1205` cannot debug
anything. `603` owns the accumulation ordering; this blueprint owns everything
about **width and rounding**:

- Every conversion between formats has one specified rounding mode.
- Every accumulator has a specified width, and it is not the widest available but
  the narrowest that provably cannot overflow — which is a `1103` calculation.
- Denormals, infinities and not-a-number are either supported or refused, and the
  blueprint says which. **Refusing them is better here**: nothing in a transformer
  forward pass should produce one, and a machine that quietly propagates a
  not-a-number through eighty layers has thrown away the only place the fault was
  findable.

### The open question that belongs here

`009` entry F1: **should the group scale be sixteen bits or eight?** A hundred and
twenty-eight weights share one scale, so sixteen bits costs an eighth of a bit per
weight — about one and a half per cent of the read that dominates everything.
Whether eight bits costs measurable accuracy is a `1103` question, and this
blueprint should either resolve it with that measurement or state the cost of each
and hand it up.

### Where exactness stops

Anything downstream of an exponential. Multiplication, addition and square root
agree everywhere; the exponential does not, unless it is specified. `603` requires
it to be specified, so in principle exactness holds all the way through the
softmax. The blueprint must confirm that or mark the boundary, and it must not
leave the reader to guess.

## Symbols this must publish

Bit width and layout for every format. Group size and scale width. Rounding mode
per conversion. Accumulator width per operation. Dynamic range and worst-case
relative error per format. Bits per weight including the amortised scale.

## Constraints this must assert

- Bits per weight including the amortised scale, times the reference model's
  parameter count, equals the resident weight size in `1104`.
- Accumulator width is sufficient for the largest reduction in `1103` with a
  stated margin.
- Every conversion in the table has a specified rounding mode. Enumerated, so a
  format added later without one is caught.
- Key and value cache width times the context length in `1104` fits the residency
  budget.

## Suggested implementation steps

1. Write the table with an exact bit layout for each row.
2. Write the four-bit justification in terms of read time, not storage.
3. Specify rounding for every conversion and refuse the special values.
4. Get the accumulator widths from `1103`.
5. Resolve or price `009` entry F1.

## Blocks

`603`, `605`, `607`, `1103`, `1104`.

## Blocked by

`1103` for the error analysis, `502` for what the core can hold.

## Related documents

`004` for the weight's journey. `009` entry F1.
