# 060 — Fetching the next layer while computing this one

```meta
phase  | 8
issues | 805
```

## The easiest prefetch problem there is

Almost every prefetcher in computing has to guess. This one does not: `048`'s
descriptor chain is built at load time and never changes, so **the address of
every byte a face will read for the rest of the token is known before the token
starts.**

No prediction, no history table, no confidence counter, no mis-speculation. A
reader arriving from general-purpose processors will expect a much more
complicated document, so the absence is stated first.

## What it does have to get right

**When to start.** Early enough that the layer is resident before the engine
wants it, and no earlier, because starting early means holding a buffer longer.
The lead is the core's **contended** worst-case latency plus the transfer time —
contended, not typical, because a prefetch that is usually early is a machine
that occasionally stalls.

**Not disturbing the engine.** The prefetch writes into one slice buffer while
the engine reads the other. `047`'s banking must let both run at full rate, and
this blueprint confirms the rate rather than assuming it.

**Sharing the core with five other faces.** Six faces prefetching at once is the
compute-bound regime's normal state, so the lead must be computed against a
sixth of the core rather than all of it.

## When it is late

It will be, occasionally: a bank conflict, a corrected error, a scrub cycle that
landed badly.

**The engine stalls.** Simple, correct, and measurable — `049` counts the cycles
so `080`'s model can be checked against reality. Beginning a layer on a partial
buffer is the kind of optimisation that works until the day it does not, and then
produces a wrong answer rather than a slow one.

## Symbols

```symbols
f_stall_prob  | 1 | given | 0.01   | share of layers whose prefetch arrives late at the design operating point
n_stall_cycle | 1 | given | 2000   | cycles the engine waits when one does

t_transfer_layer | s | derived | C_layer_weights / B_face_even | time to move one layer's weights at a face's contended share
t_lead        | s | derived | t_link_rt + t_transfer_layer          | how far ahead the prefetch must start
t_lead_unc    | s | derived | t_link_rt + C_layer_weights / B_core | and what it would be uncontended, which is the number that would have been used had nobody thought about the other five faces
f_lead_layer  | 1 | derived | t_lead / t_layer                      | the lead as a share of the arithmetic it has to hide behind
t_stall_token | s | derived | f_stall_prob * n_layer_face * n_stall_cycle / f_face | stall time per token per face
f_stall_token | 1 | derived | t_stall_token / t_token               | that as a share of a token
B_concurrent  | bit/s | derived | B_operand_die * n_die_face + B_face_even | what the slice must serve and absorb at the same time: the engine reading one buffer while the link fills the other
```

## Constraints

```constraints
C-060-1 | f_lead_layer < 1              | the prefetch must start less than one layer ahead. This is the constraint the whole scheme rests on: at more than a layer of lead, two buffers are not enough and 047's third buffer stops being optional
C-060-2 | B_concurrent <= B_slice_read  | the slice must serve the engine and absorb the link at the same time, which is what makes the prefetch free rather than merely possible
C-060-3 | f_stall_token < 0.01          | stalls must cost under a hundredth of a token at the design point
C-060-4 | t_lead > t_lead_unc           | the contended lead must exceed the uncontended one. Asserted in the obvious direction on purpose: computing this against the whole core rather than a face's share is the mistake that makes a prefetcher work in isolation and stall whenever the machine is busy
C-060-5 | C_face_slice >= n_slice_buf * C_layer_weights | the slice must hold as many layers as there are buffers. Restated from 047 so that changing the buffer count here fails there
```

## What is still open

**The stall probability is a `given`.** One layer in a hundred arriving late is a
plausible figure and nothing has produced it. `047` has a bank conflict
probability that is also a guess and the two are related; neither has been
derived from `038`'s interleaving, which is itself a stride rather than an
analysis. **Three guesses stacked**, and `049`'s counter is the only thing that
will ever settle them.

**Nobody has produced the number that decides the third buffer.** `009` entry F2
turns on how often a stall actually happens with two, and the figure above is
assumed rather than measured.
