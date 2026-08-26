# 603 — The small instruction set

Produces `src/043-instruction-set.md`.

## Current behavior

Nothing. The faces have been called processors and nothing has said what they
understand.

## Intended behavior

**Every instruction the machine has, which should be well under a hundred**, and an
explicit list of what has deliberately been left out.

### The shape of it

This is not a general purpose processor and the instruction set should make that
obvious on the first page. There is no operating system, no protection, no virtual
memory, no interrupt priority scheme, and nothing but a tensor program will ever
run. Designing for anything else costs area that the slice in `607` needs.

Four groups:

**Scalar.** Load, store, integer arithmetic, compare, branch, and the two barriers
from `506`. Perhaps twenty-five instructions. Their entire purpose is to build
descriptors and hand them to the sequencer; a scalar core that finds itself in an
inner loop is a bug in `608`.

**Sequencer control.** Start a descriptor chain, wait for one, query progress,
abort. Perhaps six. The interesting design content is in the descriptor format,
not the instructions, so the blueprint should spend its length there.

**Tensor operations**, invoked through descriptors rather than as instructions:
matrix by matrix, normalise, activate, elementwise combine, apply positional
rotation, attend over cached keys and values, transpose. Perhaps a dozen. Each is
a page of its own in `605` and `608`; here they need only their descriptor fields.

**Sampling.** Reduce to a maximum, exponentiate and normalise, select the top
entries, draw with a carried random state. Perhaps six. This is the only place in
the machine where a decision depends on a value rather than on a schedule, and it
is why a scalar core exists at all.

### The rule about arithmetic that must be written here

Two implementations of this machine — the silicon and whatever emulates it during
bring-up in `1205` — must produce **bit-identical** results, or every disagreement
becomes a judgement call about tolerance and nobody can debug anything.

That means the instruction set specifies not just what is computed but **in what
order it is accumulated and at what width**. Ascending index order, stated
accumulator width, stated rounding mode, for every reduction. `606` owns the
formats; this blueprint owns the ordering rule, and it must be stated as part of
the architecture rather than left to an implementation.

The exception is anything downstream of an exponential, which cannot be made to
agree across implementations without specifying the exponential itself. So the
blueprint must either specify it — range reduction, polynomial, clamps — or state
plainly where exactness stops. **Specifying it is better** and it is about a page.

### What is left out, and why

A list, with a reason each: no floating point divide, no square root outside
normalisation, no unaligned access, no byte addressing below the transfer
granularity in `703`, no privilege levels, no memory protection, no traps except
the two that matter in `609`.

## Symbols this must publish

Instruction count by group. Encoding width. Register file size and width.
Descriptor size and field layout. Accumulator widths. Rounding mode. The
exponential's specified form. Maximum descriptor chain length.

## Constraints this must assert

- Encoding width accommodates the instruction count with a stated reserve.
- Descriptor size is a multiple of the transfer granularity in `703`.
- Register file size fits the area in `601`.
- Every reduction in the set has a specified order and width. Checked by
  enumeration over the tensor operations, which is the constraint that keeps
  bit-exactness from quietly lapsing as operations are added.

## Suggested implementation steps

1. Write the four groups and keep the count down; every instruction is area.
2. Design the descriptor format, which is where the real work is.
3. Write the ordering and rounding rule as architecture.
4. Specify the exponential.
5. Write the omissions list with a reason each.

## Blocks

`604`, `605`, `608`, `1205`.

## Blocked by

`506`, `606`, `703`.

## Related documents

`003` for what the sampler does at the end of a pass.
