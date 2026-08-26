# 058 — How a model is laid out on the media

```meta
phase  | 8
issues | 803
```

## The property that matters

A drive delivers its rated bandwidth on long sequential reads and a fraction of
it on scattered ones. A transformer's weights arrive from training as a few
hundred named tensors in whatever order the framework serialised them. **Reading
those in the order the sequencer wants is a scatter.**

So the format is not a container. It is a **pre-sorted stream**, ordered exactly
as `048`'s descriptor chain walks it: slice by slice, layer by layer, and within
a layer, tensor by tensor in walk order.

```drawing
the media layout [not-dimensioned]

   ┌──────────┬─────────────┬─────────────┬─── ... ───┬─────────────┐
   │  header  │  slice 0    │  slice 1    │           │  slice 5    │
   └──────────┴─────────────┴─────────────┴───────────┴─────────────┘
                     │
                     ▼  one slice, in walk order
        ┌────────┬────────┬────────┬─── ... ───┬──────┐
        │ layer  │ layer  │ layer  │           │ hash │
        └────────┴────────┴────────┴───────────┴──────┘
                     │
                     ▼  one layer, in the order the sequencer asks
        ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┐
        │ norm │  q   │  k   │  v   │ out  │ gate │ down │
        └──────┴──────┴──────┴──────┴──────┴──────┴──────┘

   six contiguous regions, one per face; six lines read at once
   with none of them touching another's data
```

## What is in the file besides weights

**A header** naming the model's shape, because `048`'s chains are built from it
and the machine must not infer it.

**The quantisation tables**, interleaved with the weights rather than in a block
of their own, because `045`'s expansion path wants them alongside.

**The rotation table.** Positional rotations depend only on the position and the
pair, never on what the model is thinking, so they are computed once at packing
time and carried. **This removes sine and cosine from the machine entirely**,
which is what lets `043` claim bit-exactness through the whole forward pass.

**A hash per slice**, checked after load. `069`'s argument: a weight corrupted at
load and then read ten million times is a different problem from one corrupted in
flight, so checking is a load-time operation and not a per-transfer one.

## Symbols

```symbols
w_header_med  | bit | given | 32768 | the header: model shape, tensor table, format identifiers and version
n_tensor_layer| 1 | given | 9       | tensors in one layer, in walk order
w_hash        | bit | given | 256    | hash width per slice
p_align_med   | bit | derived | max(w_transfer, w_interleave) | alignment every tensor start must satisfy, being the larger of a transfer and a bank stride
f_pad_med     | 1 | given | 0.004    | share of the file that is padding to that alignment

C_rotation    | MB | derived | n_ctx * d_head * 2 * w_act / 8e6 / 2 | the carried rotation table: a cosine and a sine per position per pair
C_media       | GB | derived | C_weights + C_rotation / 1000 + (w_header_med + n_face * w_hash) / 8e9 + C_weights * f_pad_med | the whole file
C_slice_med   | GB | derived | C_media / n_face                     | one slice's region
f_sequential  | 1 | derived | 1 - f_pad_med                         | share of a slice read that is one contiguous run, which is the whole point of the format
n_seek        | 1 | derived | n_face                                | seeks in a whole load: one per slice region, and no more
```

## Constraints

```constraints
C-058-1 | C_media > C_weights            | the file is larger than the weights it carries, by the header, the rotation table, the hashes and the padding, and nothing else
C-058-2 | f_sequential > 0.99            | over ninety-nine per cent of a slice read must be one contiguous run. This is the format's whole purpose expressed as a number, and it is what separates a thirty millisecond load from a several second one
C-058-3 | n_seek <= n_face               | a whole load is one seek per slice and no more
C-058-4 | p_align_med >= w_transfer      | every tensor start must be aligned to at least a transfer, so the load path writes whole transfers
C-058-5 | p_align_med >= w_interleave    | and to a bank stride, so it writes into whole banks
C-058-6 | C_rotation * 1000 < C_weights  | the carried rotation table must be small against the weights. It removes every transcendental from the forward pass, and if it were large that trade would need arguing rather than asserting
```

## What is still open

**The tensor walk order is a count, not an order.** Nine tensors a layer is what
`048`'s chain touches; which nine, and in what sequence, is `048`'s to state and
this blueprint's to mirror, and neither has written the list.

**Nothing describes how the file is produced.** Something outside this machine
reads a trained model, quantises it, fits the expansion tables, computes the
rotations and writes this layout. It is the only substantial piece of software
the design assumes and does not specify, and `085` will need it on day one.
