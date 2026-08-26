# 076a — The sieve, run backwards

```meta
phase  | 11
issues | 1107
```

## Why the topology permits it

Cutting a model into six consecutive runs of layers is **pipeline parallelism**,
and a backward pass through a pipeline moves gradients from stage *n+1* to stage
*n* — the same handoff the forward pass makes, in the other direction, through
the same kind of buffer.

The all-reduce that training is usually said to demand belongs to two other
arrangements: data parallelism, which needs replicas to agree, and tensor
parallelism, which needs the faces of one layer to sum partial products. **This
machine does neither**, so `050`'s six spokes and no rim are as sufficient
backwards as forwards.

## Where the wall is

Memory, and it is a cliff.

| what is trained | state per parameter | fits? |
|---|---|---|
| nothing | — | comfortably |
| a low-rank adapter | master, gradient, two moments — on the adapter only | **yes** |
| the final layer alone | the same, on one layer | yes, tightly |
| every parameter | master, gradient, two moments, at full width | **no, by an order of magnitude** |

The last row is asserted **in the failing direction** by `C-076a-5`, deliberately,
so that the blueprint set states plainly what this machine cannot do rather than
being silent about it.

## What has to be added, and it is not much

**A second set of staging buffers**, running the other way. `038` allocates them.

**Somewhere to keep activations** — or rather, somewhere not to. Saving every
intermediate for the backward pass costs far more than the model does, so
**recomputation is the normal mode**: keep only the layer boundaries and recompute
the inside of a layer during its backward pass, paying about a third more
arithmetic for a large multiple less memory. **The machine has arithmetic to
spare below the crossover**, so this is nearly free here in a way it is not on
other hardware.

**A transposed multiply**, which `045` priced three ways and resolved by streaming
differently rather than transposing the array.

**A schedule.** Forward and backward interleaved across the six stages, needing
more microbatches in flight than generation does.

## The property that makes it cheap

The gradient with respect to a face's **own** weights is computed from that face's
own activations and its own incoming gradient. Nothing leaves the face except the
gradient with respect to the layer's input — **which is the same size as the
forward handoff.**

## Symbols

```symbols
r_adapter     | 1 | given | 16       | rank of the low-rank adapter
w_master      | bit | given | 32     | width of a master weight during training
n_moment      | 1 | given | 2        | optimiser moments kept per trained parameter
f_recompute   | 1 | given | 1.33     | how much more arithmetic recomputation costs than saving everything
n_micro_train | 1 | given | 12       | microbatches in flight when training, twice generation's

p_adapter     | 1 | derived | n_layer * 2 * r_adapter * (d_model + d_ff) | parameters in a rank-limited adapter across every layer
C_adapter_st  | GB | derived | p_adapter * w_master * (2 + n_moment)     | its master weights, gradients and moments
C_ckpt_bound  | GB | derived | n_layer * n_ctx * d_model * w_act * batch_train | activations at layer boundaries only, which is what recomputation keeps
batch_train   | 1 | given | 1                                            | sequences trained at once; one, because the checkpoints scale with it and the core does not
C_full_train  | GB | derived | n_param * w_master * (2 + n_moment)       | what training every parameter would need, which is the number that does not fit
C_train_res   | GB | derived | C_weights + C_adapter_st + C_ckpt_bound   | resident during adapter training
ratio_full    | 1 | derived | C_full_train / C_core_usable              | how far out of reach full training is
flop_train    | flop | derived | flop_token * (1 + 2 * f_recompute)      | arithmetic per token when training: the forward pass, the backward pass, and the recomputation
B_grad_stage  | MB | derived | C_activation * batch_train                | what crosses between two stages on the way back
```

## Constraints

```constraints
C-076a-1 | C_train_res < C_core_usable  | adapter training must fit alongside the resident model
C-076a-2 | B_grad_stage ~= C_activation * batch_train | backward traffic between stages is the same size as forward traffic. The property that makes this cheap, asserted so that a design drifting away from it is noticed
C-076a-3 | n_micro_train >= 2 * n_stage | interleaving forward and backward needs at least two microbatches per stage, or half the pipeline is idle on every pass
C-076a-4 | C_staging_r ~= C_staging     | the reverse staging buffers must be the same size as the forward ones, which follows from the property above and is what lets 038 allocate them without a second calculation
C-076a-5 | ratio_full > 10              | training every parameter must be out of reach by at least an order of magnitude. Asserted in the failing direction on purpose: a blueprint set that is silent about what a machine cannot do is worse than one that says so
C-076a-6 | flop_train > flop_token * 3  | training costs at least three times generation's arithmetic, which is what recomputation buys its memory saving with
```

## What is still open

**Nothing here has been checked against a training run.** Every figure is a
capacity or a traffic count. Whether a rank-limited adapter trained this way
learns anything useful is not a hardware question and this blueprint should not
pretend to answer it.

**The interleaved schedule is named and not designed.** `053` owns it and has
only the generation case.

**`C-039-5` and `C-072-1` both fail the day this is implemented**, because the
reverse staging buffers are a fourth site where two faces touch the same memory
and both enumerations say three. That is the constraints behaving correctly and
it is recorded here so it is not a surprise.
