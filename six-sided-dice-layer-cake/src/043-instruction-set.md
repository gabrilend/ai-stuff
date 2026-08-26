# 043 — The small instruction set

```meta
phase  | 6
issues | 603
```

Every instruction the machine has, and an explicit list of what has been left
out.

## What it is not

There is no operating system, no protection, no virtual memory, no privilege
level, and no expectation that anything but a tensor program ever runs. Designing
for anything else costs area the slice in `047` needs, and the slice is the
tightest constraint in the project.

## Four groups

**Scalar.** Load, store, integer arithmetic, compare, branch, and `039`'s two
barriers. Their entire purpose is to build descriptors and hand them to the
sequencer; a scalar core that finds itself in an inner loop is a bug in `048`.

**Sequencer control.** Start a descriptor chain, wait, query, abort. The design
content is in the descriptor format rather than in these, so `048` is where the
length goes.

**Tensor operations**, invoked through descriptors rather than as instructions:
matrix by matrix, normalise, activate, combine elementwise, apply the carried
positional rotation, attend over cached keys and values, transpose.

**Sampling.** Reduce to a maximum, exponentiate and normalise, select the top
entries, draw with a carried random state. This is the only place in the machine
where a decision depends on a value rather than on a schedule, and it is why a
scalar core exists at all.

## The rule about arithmetic that lives here

Two implementations of this machine — the silicon, and whatever emulates it
during bring-up — must produce **bit-identical** results, or every disagreement
becomes a judgement call about tolerance and nobody can debug anything on a
machine with no debugger.

So the instruction set specifies not only what is computed but **in what order it
is accumulated and at what width**: ascending index order, a stated accumulator
width, a stated rounding mode, for every reduction. `046` owns the formats; this
owns the ordering, and it is architecture rather than an implementation detail.

**The exponential is specified rather than borrowed** — its range reduction, its
polynomial, its clamps — because it is the one operation that would otherwise
differ between two correct implementations, and specifying it is about a page. It
is also what lets the carried rotation table in `058` remove sine and cosine from
the machine entirely, so that exactness holds all the way through the softmax
rather than stopping at the first transcendental.

## What is left out, and why

No floating point divide; the two places a reciprocal is needed are
normalisations, which use a reciprocal square root with a specified iteration
count. No square root outside those. No unaligned access. No byte addressing
below `052`'s transfer granularity. No privilege levels, no memory protection.
Two traps only, both in `049`.

## Symbols

```symbols
n_inst_scalar | 1 | given | 25   | scalar instructions
n_inst_seq    | 1 | given | 6    | sequencer control instructions
n_inst_tensor | 1 | given | 12   | tensor operations, reachable only through descriptors
n_inst_sample | 1 | given | 6    | sampling instructions
w_inst        | bit | given | 32  | instruction encoding width
n_reg         | 1 | given | 32   | scalar registers
w_reg         | bit | given | 64  | width of one
n_trap        | 1 | given | 2    | trap conditions the machine recognises
n_exp_terms   | 1 | given | 6    | terms in the specified exponential's polynomial
n_rsqrt_iter  | 1 | given | 3    | Newton iterations in the specified reciprocal square root

n_inst        | 1 | derived | n_inst_scalar + n_inst_seq + n_inst_tensor + n_inst_sample | instructions altogether
n_opcode      | 1 | derived | 2^7                                        | opcodes the encoding reserves, taking seven bits of the word
f_opcode_used | 1 | derived | n_inst / n_opcode                          | how much of the opcode space is spent
C_regfile     | bit | derived | n_reg * w_reg                            | the scalar register file
n_reduce_op   | 1 | derived | n_inst_tensor + n_inst_sample              | operations that perform a reduction and therefore need a specified order and width
```

## Constraints

```constraints
C-043-1 | n_inst < 60                    | the whole instruction set must stay under sixty. Not an arbitrary bound: every instruction is decode area on a die whose slice is already the tightest constraint in the project, and a set that grows past this has stopped being a tensor machine
C-043-2 | f_opcode_used < 0.5            | under half the opcode space spent, so that adding an operation later does not mean re-encoding
C-043-3 | w_desc >= w_inst               | a descriptor must be at least an instruction wide, since it carries addresses and shapes rather than a single operation
C-043-4 | n_trap == 2                    | two traps. Asserted so that a third arrives with an argument, because every trap is a control path in a machine that has almost none
C-043-5 | n_reduce_op > 0                | there is at least one reduction, and therefore the ordering rule above is load-bearing rather than decorative
C-043-6 | n_exp_terms >= 5               | the specified exponential needs enough terms to be accurate over the range a softmax actually produces, which 077 measures
```

## What is still open

**The ordering rule is checked by counting, not by reading.** `C-043-5` confirms
that reductions exist. Nothing confirms that each has a specified order and
width, because the notation cannot hold a list of operations with properties.
That check exists only in a reviewer's head, and it is the one that keeps
bit-exactness from lapsing as operations are added.

**The sampler's placement is undecided.** `009` entry F3. It is here on face
five's scalar core; it could equally live in the cage, which would let a sequence
be routed to whichever face is free. Nobody has argued it either way.
