# 055 — The arithmetic the claim rests on

```meta
phase  | 7
issues | 706
```

## The chain

```drawing
where the bandwidth goes, and what must exceed what [not-dimensioned]

   the tiers          [B_core]        the intended bottleneck
        │
        ▼
   the crossbar       [B_bisect]      must exceed it
        │
        ▼
   one radial link    [B_link_pads]   must exceed it
        │
        ▼
   the slice          [B_slice_read]  must exceed it
        │
        ▼
   the engine         [B_operand_die] the consumer
```

**The bottleneck must be the array.** If any later stage is narrower, that stage
becomes the machine's speed and every performance number in `080` is wrong. This
blueprint's job is to show each one exceeds it, with a margin.

## The question it answers

*Can one face take all of it?*

This is the load-bearing claim of the whole architecture. `008` entry 5 argues
that passing tokens through six faces in series costs nothing, because the faces
would have been contending for the same memory anyway — **and that is only true if
a single face can pull the entire aggregate when the others are idle.**

Three things must each permit it, and any one failing kills it: `037`'s crossbar
must route the whole array to one port, `051`'s link must carry it inside its
power allocation, and `047`'s slice must absorb it.

## The other traffic

Accounted for so that nobody discovers later that it mattered: staging handoffs,
sequencer small reads, spout panes, scrub traffic, and polling. **All of them
together are expected to be under a per cent**, and if polling is not, `053`'s
back-off is wrong.

## Symbols

```symbols
B_stage_hand  | bit/s | derived | C_handoff * 8e6 / t_stage         | staging handoff traffic, one microbatch of activations per stage per step
B_seq_small   | bit/s | derived | n_small_tok * w_transfer / t_token | the sequencer's small control reads
B_spout_avg   | bit/s | derived | C_pane * 8e6 / t_spout_period      | the spout, averaged over how often a pane is actually taken
t_spout_period| s | given | 1.0e-3                                   | how often a pane is taken in ordinary operation, which is a use assumption rather than a hardware property
B_other       | bit/s | derived | B_stage_hand + B_seq_small + B_spout_avg + B_scrub + B_poll | everything that is not weight traffic
f_other       | 1 | derived | B_other / B_core                        | that as a share of the core
m_bisect      | 1 | derived | B_bisect / B_core                       | the crossbar's margin over the memory
m_link        | 1 | derived | B_link_pads / B_core                    | the link's, counting pads rather than power
m_slice_bw    | 1 | derived | B_slice_read / B_operand_die            | the slice's margin over what one die's engine consumes
B_face_single | bit/s | derived | B_face_max                          | what one face gets with the others idle, which must be the aggregate
f_single      | 1 | derived | B_face_single / B_core                  | that as a share, which is the claim reduced to a number that must be one
t_token_bw    | s | derived | C_weights * 8e9 / B_core                | time per token from this chain, which 061 and 080 must agree with
```

## Constraints

```constraints
C-055-1 | f_single ~= 1                | one face gets the whole aggregate. The architecture's central claim as a single number, and the reason 008 entry 5 is true rather than hopeful
C-055-2 | m_bisect >= 1                | the crossbar must not be the bottleneck
C-055-3 | m_link > 10                  | nor the link, and by an order of magnitude, because its pads permit far more than its power budget spends and that headroom is what makes the spare conductors in 051 affordable
C-055-4 | m_slice_bw > 1               | nor the slice
C-055-5 | f_other < 0.01               | everything that is not weight traffic must be under a hundredth of the core. If this fails it is almost certainly polling, and 053's back-off is what to fix
C-055-6 | t_token_bw ~= t_token        | time per token derived from this chain must equal what 053 derives from the same numbers by a different route
```

## What is still open

**The spout's average is a use assumption.** A pane every millisecond is an
ordinary operating rate and nothing about the hardware requires it. A machine
being used as memory through `069b` takes panes far more often, and `C-055-5`
would be the first thing to notice — which is worth saying, because it means the
memory mode has a bandwidth cost this blueprint has not budgeted for.

**The sensitivity table the ticket asked for is not here.** What happens to time
per token when the model doubles, when the weight width halves, when the context
grows: all of it belongs in `080`, and putting it in two places would have been
the duplication this project is built to avoid. But it means this blueprint
answers *does it keep up* and not *what if it changes*.
