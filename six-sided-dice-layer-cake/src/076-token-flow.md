# 076 — The dataflow of one pass

```meta
phase  | 11
issues | 1102
```

`003` tells this as a story for a person. This is the same thing as arrows with
sizes on them, because six other blueprints assert traffic fractions and every
one is a fraction of a number that has to be computed somewhere.

```drawing
one layer, one token, one sequence [not-dimensioned]

   residual in ──▶ normalise ──▶ ┌── queries ──┐
                                 ├── keys ─────┼──▶ attend ──▶ project ──┐
                                 └── values ───┘      ▲                  │
                                                      │                  ▼
                              the key and value cache ┘         add to residual
                                                                        │
   residual out ◀── add ◀── down ◀── gate ◀── up ◀── normalise ◀────────┘

   weights read:      [C_layer_weights]        the dominant term
   cache read:        grows with position
   residual carried:  [C_activation]           four parts in a million
```

## The class that changes character

**The key and value cache.** At short context it is noise. It is written once per
token per layer and read *entirely* every token, so its traffic grows linearly
with position while the weight traffic does not — and past some length the cache
is read more per token than the weights are.

`C-076-4` finds that length. Past it the machine's behaviour changes character and
nothing else in the project says where that is.

## What scales with batch and what does not

**Weights: read once regardless of batch.** That is the whole reason batching
works and the whole reason `079`'s crossover exists.

**Cache, residual stream and intermediates: all scale with batch.**

Every arrow is marked, because getting one wrong is how a performance model comes
out a factor of thirty wrong.

## Symbols

```symbols
C_qkv         | MB | derived | d_model * (n_head + 2 * n_kv_head) * d_head * w_weight_eff | one layer's query, key and value projections
C_proj        | MB | derived | d_model * n_head * d_head * w_weight_eff | its projection back
C_ffn         | MB | derived | 3 * d_model * d_ff * w_weight_eff        | its feedforward
C_inter_layer | MB | derived | (d_ff + 3 * d_model) * w_act             | intermediates inside one layer that never leave the die
C_kv_token    | MB | derived | 2 * n_kv_head * d_head * w_kv            | cache one layer writes for one token
C_kv_read     | MB | derived | C_kv_token * n_ctx                       | and reads back, at full context, per layer per token

B_weight_tok  | MB | derived | C_weights                                 | weight traffic per token: every weight once
B_kv_seq      | MB | derived | C_kv_read * n_layer                       | cache traffic for one token of one sequence, at full context
B_kv_tok      | MB | derived | B_kv_seq * batch_design                   | and across the whole batch, which is a different number and is the one 079 uses
B_act_tok     | MB | derived | C_activation * n_stage * batch_design     | activations crossing between stages
f_kv_traffic  | 1 | derived | B_kv_tok / B_weight_tok                    | the cache's traffic against the weights', which is the ratio that changes character with context
n_ctx_cross   | 1 | derived | n_ctx * B_weight_tok / B_kv_tok            | the context length at which the two are equal
f_act_traffic | 1 | derived | B_act_tok / B_weight_tok                   | the handoff's share, which 050 asserts is negligible and this is where the number comes from
C_handoff     | MB | derived | C_activation * batch_design / n_microbatch | one staging buffer's worth: a microbatch of activation vectors
```

## Constraints

```constraints
C-076-1 | C_qkv + C_proj + C_ffn ~= C_layer_weights | the tensors of one layer must account for the layer. Two routes to the same megabytes: 078 derives it from a parameter count and this derives it from the tensors themselves, and a shape error in either shows up here
C-076-2 | f_act_traffic < 0.001        | activations crossing between stages must be under a thousandth of the weight traffic, which is the number 050 asserts when it argues that a mesh would be carrying nothing
C-076-3 | C_inter_layer < C_face_slice | intermediates inside a layer must fit alongside the weights on a face, since they never leave the die and have nowhere else to be
C-076-4 | n_ctx_cross > n_ctx          | the context at which cache traffic overtakes weight traffic must be beyond the reference context. Past that point the machine is a different machine, and this is the only place in the project that says where the point is
C-076-5 | f_kv_traffic < 1             | at the reference context the weights still dominate, which is what makes every performance claim in 080 a claim about weight bandwidth
```

## What is still open

**Attention's own arithmetic is not counted.** Every term here is a weight read or
a cache read. The attention operation itself — queries against keys, the softmax,
the weighted sum of values — costs arithmetic proportional to context length and
no bandwidth beyond the cache, and `080` inherits that omission.

**Intermediates are counted once.** A layer's inner tensors are written and read
several times as the sequencer walks it, and `C-076-3` checks only that one copy
fits.
