# 078 — What fits

```meta
phase  | 11
issues | 1104
```

**Every capacity, bandwidth and timing number in this project is anchored to one
model.** It sets the core size, which sets the cavity, which sets the cube. It
sets the layer size, which sets the face slice, which sets the die, which also
sets the cube.

`009` entry B4 is the question of whether that is the right anchor. This is where
it is written down so that the question can be asked.

## The reference model

```drawing
the shape everything is anchored to [not-dimensioned]

   [n_layer] layers, each:
        normalise
        project to queries, keys and values     [d_model] wide, [n_head] heads
        attend over the cached keys and values  [n_kv_head] key heads
        project back
        normalise
        gated feedforward                       [d_ff] wide
   plus:
        an embedding table                      [n_vocab] by [d_model]
        an output projection                    the same, the other way round
```

The shape is given as symbols and the parameter count is **derived from them**,
so that a different model is a different set of numbers rather than a different
document.

## Residency, in three terms

    resident  =  weights  +  key and value cache  +  working space

**Weights** scale with the model and nothing else. **Cache** scales with context
times batch times layer count — it is the term that turns capacity into a surface
rather than a number, and at long context it rivals the weights. **Working
space** is the staging buffers, the request region, the pane window, and — if
`076a`'s training is used — checkpoints and optimiser state.

## The cliff

`059` chose refusal over degradation, and the threshold is this surface. It is
an exact inequality rather than a rule of thumb, because a model half a gigabyte
too large must be refused rather than loaded and run badly.

## Symbols

```symbols
n_layer       | 1 | given | 80      | transformer layers
d_model       | 1 | given | 8192    | the residual stream's width
n_head        | 1 | given | 64      | attention heads
n_kv_head     | 1 | given | 8       | key and value heads, fewer than query heads so the cache is smaller
d_head        | 1 | given | 128     | width of one head
d_ff          | 1 | given | 28672   | the feedforward's inner width
n_vocab       | 1 | given | 128000  | vocabulary entries
n_ctx         | 1 | given | 4096    | context length the machine is provisioned for

p_attn        | 1 | derived | d_model * (n_head * d_head + 2 * n_kv_head * d_head + n_head * d_head) | parameters in one layer's attention: queries, keys, values and the projection back
p_ffn         | 1 | derived | 3 * d_model * d_ff              | parameters in one gated feedforward: two up, one down
p_layer       | 1 | derived | p_attn + p_ffn                   | parameters in one transformer layer
p_embed       | 1 | derived | n_vocab * d_model                | the embedding table
p_head        | 1 | derived | n_vocab * d_model                | the output projection, the same size
n_param       | 1 | derived | n_layer * p_layer + p_embed + p_head | the whole model
n_reduce_max  | 1 | derived | d_ff                             | the longest reduction anywhere in a forward pass, which 077 sizes the accumulator against

C_weights     | GB | derived | n_param * w_weight_eff           | the weights, resident, at the format in 046
C_layer_weights | MB | derived | p_layer * w_weight_eff         | one transformer layer's share
C_layer_max   | MB | derived | p_head * w_weight_eff            | the largest single thing a face must hold: the output projection, which is bigger than any layer
C_activation  | MB | derived | d_model * w_act                  | one token's activation vector, which is what crosses between stages
C_kv_seq      | MB | derived | 2 * n_layer * n_kv_head * d_head * n_ctx * w_kv | the cache one sequence needs at full context
C_kv          | GB | derived | C_kv_seq * batch_design          | and the whole batch's
C_checkpoint  | GB | given | 0                                  | activation checkpoints; zero unless 076a's training is in use
C_adapter     | GB | given | 0                                  | adapter and optimiser state; the same
flop_token    | flop | derived | 2 * n_param * n_flop_mac / 2    | operations to generate one token: two per weight
f_kv_of_res   | 1 | derived | C_kv / C_resident                 | the cache's share of residency, which is what makes capacity a surface
n_ctx_at_full | 1 | derived | n_ctx * (C_core_usable - C_weights) / C_kv | the longest context that fits at this model and batch
```

## Constraints

```constraints
C-078-1 | C_resident < C_core_usable  | the reference model at its reference context and batch must fit
C-078-2 | C_face_slice > C_layer_max + C_layer_weights | a face must hold the largest thing it will ever compute and the next thing behind it. The largest is the output projection rather than a transformer layer, which is the case a constraint written against an average layer would have missed
C-078-3 | f_kv_of_res > 0.1           | the cache must be a real part of residency at the reference context, or the surface has collapsed to a line and 059's degradation to a shorter context buys nothing
C-078-4 | n_ctx_at_full > n_ctx       | there must be room to grow the context beyond the reference, which is the graceful degradation 059 offers in the other direction
C-078-5 | n_head >= n_kv_head         | there are at least as many query heads as key heads, which is what makes the cache smaller than it would otherwise be
C-078-6 | d_head * n_head == d_model  | the heads must tile the residual stream exactly
C-078-7 | n_reduce_max >= d_model     | the longest reduction is at least the residual width, which catches a feedforward narrower than the stream it feeds
```

## What is still open

**`009` entry B4.** Every number in this project is anchored here, and nobody has
asked what a smaller model would do to the cube. The chain in `012` runs from a
layer's size to the cube's edge; a model half this size would let the cube shrink
and by how much is an afternoon's work nobody has done.

**Only one model shape is expressed.** A mixture-of-experts model, or one with a
different attention arrangement, would need this blueprint extended rather than
edited — and `058`'s media format and `048`'s descriptor chains both assume this
shape too.
