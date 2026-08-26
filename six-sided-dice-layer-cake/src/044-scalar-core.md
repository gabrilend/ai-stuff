# 044 — The small core that sets things up

```meta
phase  | 6
issues | 604
```

## What it actually does

Per token, per face, it builds descriptor chains for thirteen layers and hands
them to the sequencer. That is a few hundred instructions of pointer arithmetic
against a hundred and fifty microseconds of tensor work.

**The core is idle over ninety-nine per cent of the time**, and on face five it
additionally runs the sampler, which is the only genuinely data-dependent work in
the machine.

An eight square millimetre in-order core is therefore not a compromise. The
utilisation figure comes first in this blueprint because it justifies everything
after it being small.

## The design

In order, short pipeline, no speculation, no out-of-order machinery, no branch
predictor beyond a static hint. Every one of those omissions is area returned to
the slice, and none costs anything measurable in a block that is idle almost
always.

Three things do need care.

**The memory interface.** The core reads and writes the core memory across the
radial link like everything else, and a link round trip is long. A core that
stalls on every descriptor field would spend its whole budget waiting, so it
needs a small local memory and enough outstanding requests to cover the latency.

**The barriers.** `039`'s release and acquire are the only scalar instructions on
a critical path, and their latency lands directly in `053`'s stage budget.

**The random state.** It must be carried, reproducible and per-sequence, because
two runs of the same prompt with the same seed must produce the same text or
nothing in `085` can be tested against anything.

## Four cores or one

Four idle cores cost thirty-two square millimetres across a face to avoid putting
a link round trip inside every descriptor build. **Four**, and the arithmetic is
below rather than asserted: the area is one and a half per cent of a face and the
alternative puts a latency in the setup path that recurs thirteen times a token.

## Symbols

```symbols
n_pipe_stage  | 1 | given | 5     | pipeline stages
n_scalar_inst | 1 | given | 400   | scalar instructions executed per token per face, building thirteen layers of descriptor chain
C_local_mem   | bit | given | 262144 | local memory on the scalar core for descriptor construction
n_outstanding | 1 | given | 16    | memory requests the core may have in flight
w_rng_state   | bit | given | 128  | width of the carried random state, per sequence
w_rng_min     | bit | given | 64   | the least width at which two sequences will not collide over a long conversation
n_core_face   | 1 | derived | n_die_face | scalar cores on a face, one per die

t_scalar_tok  | s | derived | n_scalar_inst / (f_face * 1e9)         | time the core spends per token, at one instruction a cycle
util_scalar   | 1 | derived | t_scalar_tok / t_stage                 | how busy it is
A_scalar_face | mm^2 | derived | f_area_scalar * A_die * n_die_face  | area four scalar cores take on a face
f_scalar_face | 1 | derived | A_scalar_face / (A_die * n_die_face)   | that as a share of a face, which is the cost of choosing four over one
t_cover_link  | s | derived | n_outstanding * w_transfer / B_face_even | how long the outstanding requests cover, which must exceed a link round trip or the core stalls
```

## Constraints

```constraints
C-044-1 | util_scalar < 0.02             | the scalar core must be idle over ninety-eight per cent of the time. This is the claim that justifies it being small, stated as arithmetic so that a design change which put it in an inner loop would fail here rather than being discovered in 080
C-044-2 | t_cover_link > t_link_rt        | outstanding requests must cover a link round trip, or the core stalls on every descriptor field it reads
C-044-3 | f_scalar_face < 0.02           | four cores must cost under a fiftieth of a face, which is what makes choosing four over one obvious rather than a trade
C-044-4 | C_local_mem >= w_desc * n_desc_layer | the local memory must hold a whole layer's descriptor chain, or the core is fetching descriptors while it builds them
C-044-5 | w_rng_state >= w_rng_min       | the carried random state must be wide enough that two sequences do not collide over the length of a conversation
C-044-6 | n_core_face == n_die_face      | one core per die, which is what 042 chose and what keeps the four dies identical
```

## What is still open

**The instruction count per token is a `given`.** Four hundred is what building
thirteen descriptor chains looks like if the chains are built rather than copied.
`048` may make it far smaller by keeping the chains and only patching their
addresses, which would make the utilisation claim stronger still and has not been
worked out.

**Nothing says what the core does when it is not working.** Ninety-nine per cent
idle is ninety-nine per cent of a block that is still clocked and still leaking.
Whether it clock-gates, and what wakes it, is not specified, and at twenty-four
copies it is not nothing.
