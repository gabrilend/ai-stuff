# 047 — The memory a face keeps to itself

```meta
phase  | 6
issues | 607
```

## The constraint, which is the whole blueprint

    C_face_slice  >=  2 * C_layer_weights

The slice must hold the layer being computed **and** the layer being fetched
behind it. Without both, `060`'s prefetch cannot hide the core read and the
machine runs at the speed of an unoverlapped transfer.

**This is the tightest constraint in the project.** It is what made a compute die
twenty-four millimetres, which made a face fifty-two, which made the cube sixty.
Everything about the object's size traces back to a fact about how large a
transformer layer is.

## Why the density is lower than the core's

The core's tiers manage about two megabytes per square millimetre because they
are dedicated array with the periphery on a separate lamina. A face slice shares
its die with multipliers, a sequencer, a link and a power grid, so it carries its
own sense amplifiers, its own correction, its own three-port banking, and it
shares routing tracks with the engine beside it.

**Two different numbers for the same technology**, and saying why here is what
stops somebody unifying them and losing a quarter of the slice.

## The three clients

```drawing
what wants the slice, and when [not-dimensioned]

   the engine ──▶ buffer A ──▶  full rate, sequential, the design case
   the link   ──▶ buffer B ──▶  full rate, sequential, the other buffer
   the sequencer ─▶ anywhere ─▶ small, rare, latency-sensitive, awkward
```

The first two never contend because they are in different buffers. The third is
the problem: a small read that lands behind a long burst waits for the burst, and
`048`'s sequencer is on the critical path when it does.

## Symbols

```symbols
eta_slice     | 1 | given | 0.16   | share of the slice region that is bitcell rather than sense amplifiers, correction, banking and shared routing. Lower than the core's tiers because a slice lives on a logic die
n_slice_buf   | 1 | given | 2      | buffers: one being computed from, one being filled
n_slice_bank  | 1 | given | 64     | banks per die's slice
batch_design  | 1 | given | 28     | the batch the machine is provisioned for; 079 derives the crossover independently and C-079-1 requires the two to agree
e_slice_bit   | pJ/bit | derived | E_slice_bit | read energy per bit, under the name 020 uses
p_seq_conflict| 1 | given | 0.02   | chance a sequencer's small read finds its bank busy with a burst

a_bit_slice   | um^2/bit | derived | a_cell / eta_slice        | area one bit occupies in a face slice
d_slice       | MB/mm^2  | derived | 1 / a_bit_slice           | areal density on a logic die
C_slice_die   | MB       | derived | A_slice_die * d_slice     | capacity of one die's slice
C_face_slice  | MB       | derived | C_slice_die * n_die_face  | and of a whole face's
C_slice_need  | MB       | derived | n_slice_buf * C_layer_weights | what the two-buffer requirement actually demands
m_slice       | 1        | derived | C_face_slice / C_slice_need | margin on the tightest constraint in the project, which is worth having as a number rather than as a pass
B_slice_read  | bit/s    | derived | n_slice_bank * w_tier_port * f_face * n_die_face | rate a face's slice serves reads, all banks at once
t_seq_wait    | s        | derived | p_seq_conflict * w_transfer / (B_slice_read / n_slice_bank) | how long a sequencer's small read waits when it lands behind a burst
d_slice_ratio | 1        | derived | d_areal / d_slice         | how much denser a dedicated tier is than a slice on a logic die
```

## Constraints

```constraints
C-047-1 | C_face_slice >= C_slice_need  | the slice must hold two layers. The tightest constraint in the project and the one that sized the cube
C-047-2 | m_slice > 1.2                 | and with a fifth to spare, because the layer size follows from a model shape that 009 entry B4 has not settled
C-047-3 | B_slice_read >= B_operand_die * n_die_face | the slice must feed the array at the rate it consumes
C-047-4 | B_slice_read >= B_face_even   | and absorb the radial link writing into the other buffer at the same time, which is what makes the prefetch free rather than merely possible
C-047-5 | d_slice < d_areal             | a slice on a logic die is less dense than a dedicated tier. Asserted so that somebody unifying the two numbers fails here rather than silently losing a quarter of the slice
C-047-6 | t_seq_wait < t_link_rt        | a sequencer's small read must not wait longer than a link round trip, or the awkward third client has become the critical path
C-047-7 | n_slice_buf == 2              | two buffers. Three would let the prefetch run further ahead and does not fit; asserting two means the third has to argue for a larger die
```

## What is still open

**`009` entry F2 is priced and not decided.** A third buffer would let the
prefetch run two layers ahead and absorb contention between faces at large batch.
It costs another layer's worth of slice, which does not fit on this die, and
nobody has costed the larger die.

**The sequencer conflict probability is a `given`.** Two per cent is what a
sensible banking gives if the sequencer's structures are placed away from the
weight banks, and nothing has placed them.

**Nothing says what happens to the slice at a layer boundary.** The buffers swap;
whether the engine drains first, and what that costs, is `048`'s and is not
written.
