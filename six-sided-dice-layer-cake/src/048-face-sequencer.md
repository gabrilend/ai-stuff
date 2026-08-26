# 048 — The thing that walks a layer

```meta
phase  | 6
issues | 608
```

The state machine that executes a transformer layer from a descriptor chain
without the scalar core touching a single step.

## Why it exists

A layer is a dozen tensor operations, thirteen or fourteen times per token per
face, with every operand address a function of the layer index and the head
index. A scalar core issuing those would be in an inner loop, and `044`
established that a scalar core in an inner loop is a bug.

## What it also does, which is not obvious

**The prefetch.** While walking layer *n* it issues the core reads for layer
*n+1* into the other slice buffer. `060` owns the policy; this is the mechanism,
and the two must not disagree about who decides when.

**The current ramp.** `031` needs the engine to reach full activity over
sixty-four cycles rather than one, which divides the peak supply slew and takes
the required decoupling from twenty-seven microfarads to three. It is a few lines
of state machine and it is worth twenty-two millivolts.

**The barriers.** At the end of a layer chain the sequencer writes the staging
buffer and executes `039`'s release; at the start it waits on the acquire. These
are the only points in a whole token where a face touches another face's data.

**Four-way agreement.** `042` chose four sequencers in lockstep, so they must
agree at layer boundaries. The mechanism is a token passed around the four dies
on the interposer, which costs one inter-die crossing per layer rather than per
operation.

## The descriptor chain

A descriptor names an operation, its operands' addresses and shapes, its output,
and the next descriptor. A layer is a chain; a face's token is thirteen chains;
and **the chains for a given model are built once at load time and reused for
every token**, which is why `044`'s few hundred instructions per token are
enough.

The layout is specified exactly, because `085` will need somebody to build one by
hand on a bench.

## Symbols

```symbols
w_desc        | bit | given | 512   | width of one descriptor
w_desc_min    | bit | given | 256   | the least width that carries two addresses, two shapes, an operation and a link at the core's address width
n_desc_layer  | 1 | given | 34      | descriptors in one layer's chain: a dozen operations, several of them per head group
n_seq_state   | 1 | given | 12      | states in the sequencer's machine
n_ramp_cycle_s| 1 | derived | n_ramp_cycle | cycles the operand admission ramp takes, under the name 031 uses
n_small_read  | 1 | given | 8       | small control reads the sequencer makes per layer, which is the count 040 needed to choose its correction granularity
t_prefetch_lead | s | derived | t_link_rt + C_layer_weights / B_face_even | how far ahead the prefetch must start: a link round trip plus the time to move a whole layer
n_interdie_sync | 1 | given | 1     | inter-die crossings per layer for the four sequencers to agree

C_chain_layer | bit | derived | w_desc * n_desc_layer            | one layer's chain
C_chain_face  | bit | derived | C_chain_layer * n_layer_face     | all of a face's chains, built once at load
n_small_tok   | 1 | derived | n_small_read * n_layer_face        | small reads per token per face, which 040 asserts against its line width
t_layer       | s | derived | t_layer_comp                       | how long one layer takes at the design batch. It is the arithmetic time and not the transfer time, because below the crossover a prefetch and the compute it hides behind are the same memory traffic and cannot overlap at all -- double buffering earns itself above the crossover, where the arithmetic is the wall and the transfer can run underneath it
f_prefetch_lead | 1 | derived | t_prefetch_lead / t_layer        | how much of a layer's time the prefetch must run ahead by
```

## Constraints

```constraints
C-048-1 | C_chain_face * 1.25 < C_local_mem * n_die_face | a face's whole descriptor chain set, with a quarter over, must fit in the scalar cores' local memory, or the sequencer fetches descriptors while it is executing them
C-048-2 | f_prefetch_lead < 1            | the prefetch must start less than a layer ahead, or two buffers are not enough and 047's third buffer stops being optional
C-048-3 | n_ramp_cycle_s == n_ramp_cycle | the ramp length here must be the one 031 sized the decoupling against. Two blueprints, one number, and the electrical consequence of shortening it is invisible from this file
C-048-4 | n_small_tok < n_line_per_token | the sequencer's small reads must be rare against the correction lines a token touches, which is what let 040 choose a two hundred and fifty-six bit line
C-048-5 | n_interdie_sync <= 1           | the four sequencers must agree no more than once a layer. Once per operation would put thirteen times a dozen interposer crossings into every token
C-048-6 | w_desc >= w_desc_min           | a descriptor must carry two addresses, two shapes, an operation and a link
```

## What is still open

**Chains are built rather than patched.** `044` counts four hundred instructions
a token building thirteen chains. If the chains persist and only their addresses
change between tokens, the count collapses and the scalar core becomes even less
than it is. Nobody has worked out whether anything in a chain is
token-dependent besides the position.

**The buffer swap is not specified.** At a layer boundary the roles of the two
slice buffers exchange. Whether the engine drains first, and what a drain costs
in cycles, is not written, and it recurs thirteen times a token.

**The four-way agreement's cost is a `given` of one crossing.** What that
crossing actually is — a token, a barrier, a broadcast — and how long it takes is
not specified, and `042` is relying on it being cheap.
